import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import 'appointment_actions.dart';
import 'appointment_detail_screen.dart';

/// Filtres proposés en tête de liste.
enum _Filter {
  toConfirm('À confirmer'),
  upcoming('À venir'),
  history('Historique');

  const _Filter(this.label);

  final String label;

  bool matches(Appointment appointment) => switch (this) {
        // Le serveur calcule `is_confirmable` : en attente et pas encore passé
        _Filter.toConfirm => appointment.isConfirmable,
        _Filter.upcoming => appointment.isUpcoming,
        _Filter.history => !appointment.isUpcoming,
      };
}

/// Liste paginée des rendez-vous.
///
/// Patient : ses propres rendez-vous. Médecin / administrateur : ceux de leurs
/// patients, avec les actions de confirmation et d'annulation.
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  /// Nombre de rendez-vous visibles en dessous duquel on charge
  /// automatiquement la page suivante (le filtre peut en masquer beaucoup).
  static const _minVisible = 8;

  /// Pages chargées automatiquement au maximum pour remplir un filtre, afin de
  /// ne pas parcourir tout l'historique d'un médecin sans action de sa part.
  static const _maxAutoFill = 4;

  final _scrollController = ScrollController();
  final List<Appointment> _appointments = [];

  _Filter _filter = _Filter.upcoming;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;
  int _page = 0;
  bool _hasMore = true;
  int _autoFilled = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Appointment> get _visible =>
      _appointments.where(_filter.matches).toList();

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _autoFilled = 0; // défilement manuel : on autorise à nouveau le remplissage
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page =
          await context.read<AppointmentRepository>().list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _appointments.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _initialLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    // Le filtre actif peut ne laisser passer qu'une poignée de rendez-vous :
    // on enchaîne sur la page suivante jusqu'à remplir l'écran.
    if (mounted &&
        _error == null &&
        _hasMore &&
        _autoFilled < _maxAutoFill &&
        _visible.length < _minVisible) {
      _autoFilled++;
      await _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _appointments.clear();
      _page = 0;
      _hasMore = true;
      _autoFilled = 0;
      _initialLoaded = false;
    });
    await _loadMore();
  }

  void _selectFilter(_Filter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _autoFilled = 0;
    });
    _loadMore();
  }

  /// Remplace un rendez-vous par sa version mise à jour (après confirmation
  /// ou annulation) sans recharger toute la liste.
  void _replace(Appointment appointment) {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index == -1) return;
    setState(() => _appointments[index] = appointment);
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthState>().user?.isStaff ?? false;
    final filters = isStaff
        ? _Filter.values
        : [_Filter.upcoming, _Filter.history];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStaff ? 'Rendez-vous des patients' : 'Mes rendez-vous',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              isStaff
                  ? 'Confirmez ou annulez les demandes reçues'
                  : 'Suivez vos consultations à venir',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        toolbarHeight: 68,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FilterBar(
            filters: filters,
            selected: _filter,
            // Le décompte n'est fiable qu'une fois toutes les pages chargées
            badgeCount: !_hasMore
                ? _appointments.where(_Filter.toConfirm.matches).length
                : null,
            onSelected: _selectFilter,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(isStaff),
      ),
    );
  }

  Widget _buildBody(bool isStaff) {
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_initialLoaded && _error != null) {
      return ErrorView(error: _error!, onRetry: _loadMore);
    }

    final appointments = _visible;
    if (appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(
            icon: switch (_filter) {
              _Filter.toConfirm => Icons.task_alt_rounded,
              _Filter.upcoming => Icons.event_available_outlined,
              _Filter.history => Icons.history_rounded,
            },
            message: switch (_filter) {
              _Filter.toConfirm => 'Aucune demande en attente.\nTout est à jour !',
              _Filter.upcoming => isStaff
                  ? 'Aucun rendez-vous à venir pour le moment.'
                  : 'Vous n\'avez pas de rendez-vous à venir.\nPrenez-en un depuis l\'accueil !',
              _Filter.history => 'Aucun rendez-vous passé ou annulé.',
            },
          ),
          if (_hasMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  onPressed: _loading ? null : _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Charger plus de rendez-vous'),
                ),
              ),
            ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: appointments.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= appointments.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return FadeSlideIn(
          delay: Duration(milliseconds: 50 * (index % 6)),
          child: AppointmentCard(
            appointment: appointments[index],
            isStaff: isStaff,
            onUpdated: _replace,
            onOpened: _refresh,
          ),
        );
      },
    );
  }
}

/// Barre de filtres horizontale sous l'AppBar.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.badgeCount,
    required this.onSelected,
  });

  final List<_Filter> filters;
  final _Filter selected;
  final int? badgeCount;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == selected;
          final count = filter == _Filter.toConfirm ? badgeCount : null;

          return ChoiceChip(
            selected: isSelected,
            showCheckmark: false,
            backgroundColor: Colors.white,
            selectedColor: scheme.primary,
            side: BorderSide(
              color: isSelected ? scheme.primary : Colors.grey.shade300,
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? scheme.onPrimary : Colors.grey.shade700,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(filter.label),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.onPrimary.withValues(alpha: .25)
                          : Colors.orange.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? scheme.onPrimary
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onSelected: (_) => onSelected(filter),
          );
        },
      ),
    );
  }
}

/// Carte d'un rendez-vous : pastille de date, informations et actions.
class AppointmentCard extends StatefulWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isStaff,
    required this.onUpdated,
    required this.onOpened,
  });

  final Appointment appointment;
  final bool isStaff;

  /// Appelé avec le rendez-vous mis à jour après confirmation / annulation.
  final ValueChanged<Appointment> onUpdated;

  /// Appelé au retour de l'écran de détail si quelque chose y a changé.
  final Future<void> Function() onOpened;

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _busy = false;

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  Future<void> _run(Future<Appointment?> Function() action) async {
    final updated = await action();
    if (updated != null) widget.onUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final isStaff = widget.isStaff;
    final statusColor = appointment.statusColor(context);

    // Le personnel voit le patient en titre ; le patient voit son médecin
    final title = isStaff
        ? (appointment.patient?.name ?? 'Patient')
        : (appointment.doctor?.fullName ?? 'Médecin');
    final subtitle = isStaff
        ? [
            appointment.doctor?.fullName,
            appointment.doctor?.specialty?.name,
          ].whereType<String>().join(' · ')
        : appointment.doctor?.specialty?.name;

    final canConfirm = isStaff && appointment.isConfirmable;
    final canCancel = appointment.isCancellable;

    return Card(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) =>
                  AppointmentDetailScreen(appointmentId: appointment.id),
            ),
          );
          if (changed == true) await widget.onOpened();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DateBadge(date: appointment.date, color: statusColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 15, color: Colors.grey.shade600),
                            const SizedBox(width: 5),
                            Text(
                              appointment.timeRangeLabel,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(appointment: appointment),
                ],
              ),
              if (appointment.reason.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    appointment.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade800),
                  ),
                ),
              ],
              if (canConfirm || canCancel) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                            side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: .5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _run(() => cancelAppointment(
                                    context,
                                    appointment,
                                    asStaff: isStaff,
                                    onBusy: _setBusy,
                                  )),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Annuler'),
                        ),
                      ),
                    if (canConfirm && canCancel) const SizedBox(width: 10),
                    if (canConfirm)
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            backgroundColor: Colors.green.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _run(() => confirmAppointment(
                                  context, appointment, onBusy: _setBusy)),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Confirmer'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de date : jour en gros, mois en dessous.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, required this.color});

  final DateTime? date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final date = this.date;

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date != null ? '${date.day}' : '—',
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (date != null)
            Text(
              monthShort(date),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: .85),
              ),
            ),
        ],
      ),
    );
  }
}

/// Badge de statut coloré (En attente, Confirmé, …).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.appointment, this.large = false});

  final Appointment appointment;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = appointment.statusColor(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(appointment.statusIcon, size: large ? 18 : 14, color: color),
          const SizedBox(width: 5),
          Text(
            appointment.statusLabel,
            style: TextStyle(
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
