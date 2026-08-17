import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
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
  final _scrollController = ScrollController();
  final List<Appointment> _appointments = [];

  _Filter _filter = _Filter.upcoming;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  /// Page affichée et nombre total de pages (pagination numérotée).
  int _page = 1;
  int _lastPage = 1;

  /// Dernière page demandée, pour la retenter après une erreur réseau.
  int _requestedPage = 1;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Appointment> get _visible =>
      _appointments.where(_filter.matches).toList();

  /// Charge une page et remplace la liste affichée par son contenu.
  Future<void> _loadPage(int page) async {
    if (_loading) return;
    _requestedPage = page;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await context.read<AppointmentRepository>().list(page: page);
      if (!mounted) return;
      setState(() {
        _appointments
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _initialLoaded = true;
      });
      // Nouvelle page : la lecture reprend en haut de la liste
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _loadPage(_page);

  void _selectFilter(_Filter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
  }

  /// Remplace un rendez-vous par sa version mise à jour (après confirmation,
  /// clôture ou annulation) sans recharger toute la liste.
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
        titleSpacing: AppSpacing.page,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStaff ? 'Rendez-vous des patients' : 'Mes rendez-vous',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 2),
            Text(
              isStaff
                  ? 'Confirmez ou annulez les demandes reçues'
                  : 'Suivez vos consultations à venir',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        toolbarHeight: 76,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _FilterBar(
            filters: filters,
            selected: _filter,
            // Le décompte n'est fiable que si tout tient sur une seule page
            badgeCount: _lastPage == 1
                ? _appointments.where(_Filter.toConfirm.matches).length
                : null,
            onSelected: _selectFilter,
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: _buildBody(isStaff)),
    );
  }

  Widget _buildBody(bool isStaff) {
    // Le squelette couvre le premier chargement comme les changements de
    // page : la liste affichée est remplacée dans les deux cas.
    if (_loading) {
      return const SkeletonList(height: 128);
    }
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: () => _loadPage(_requestedPage),
      );
    }
    if (!_initialLoaded) return const SizedBox.shrink();

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
            title: switch (_filter) {
              _Filter.toConfirm => 'Tout est à jour',
              _Filter.upcoming => 'Aucun rendez-vous à venir',
              _Filter.history => 'Historique vide',
            },
            message: switch (_filter) {
              _Filter.toConfirm =>
                'Aucune demande de rendez-vous n\'attend votre confirmation.',
              _Filter.upcoming =>
                isStaff
                    ? 'Aucune consultation n\'est programmée pour le moment.'
                    : 'Prenez rendez-vous depuis l\'accueil pour retrouver votre consultation ici.',
              _Filter.history => 'Aucun rendez-vous passé ou annulé.',
            },
          ),
          // D'autres pages peuvent contenir des rendez-vous que le filtre
          // ne trouve pas sur celle-ci : la navigation reste disponible.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: PaginationBar(
              currentPage: _page,
              lastPage: _lastPage,
              onPageSelected: _loadPage,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: appointments.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        // Barre de pages en pied de liste
        if (index >= appointments.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.gap),
            child: PaginationBar(
              currentPage: _page,
              lastPage: _lastPage,
              onPageSelected: _loadPage,
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
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          4,
          AppSpacing.page,
          12,
        ),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == selected;
          final count = filter == _Filter.toConfirm ? badgeCount : null;

          return FilterPill(
            label: filter.label,
            selected: isSelected,
            onTap: () => onSelected(filter),
            // Compteur des demandes en attente, réservé au filtre « À
            // confirmer » et masqué tant qu'il vaut zéro.
            trailing: count != null && count > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: .25)
                          : AppPalette.warning.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppPalette.warning,
                      ),
                    ),
                  )
                : null,
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

  /// Appelé avec le rendez-vous mis à jour après confirmation, clôture ou
  /// annulation.
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

  /// Action principale de la carte : bouton plein qui laisse place à un
  /// indicateur de chargement pendant l'appel à l'API.
  Widget _filledAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: color,
        textStyle: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: _busy ? null : onPressed,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 17),
      label: Text(label),
    );
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
    // Clôture proposée dès que le créneau du rendez-vous confirmé est écoulé
    final canComplete = isStaff && appointment.isCompletable;
    final canCancel = appointment.isCancellable;

    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                AppointmentDetailScreen(appointmentId: appointment.id),
          ),
        );
        if (changed == true) await widget.onOpened();
      },
      child: Stack(
        children: [
          // Liseré vertical à la couleur du statut : l'état du rendez-vous se
          // lit d'un coup d'œil en balayant la liste. Positionné plutôt
          // qu'étiré, pour ne pas imposer de hauteur au contenu de la carte.
          Positioned(
            left: 0,
            top: AppSpacing.gutter,
            bottom: AppSpacing.gutter,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter + 6,
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateBadge(date: appointment.date, color: statusColor),
                    const SizedBox(width: AppSpacing.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
                                color: AppPalette.primary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppPalette.inkFaint,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  appointment.timeRangeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall,
                                ),
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
                  const SizedBox(height: AppSpacing.gap),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.canvas,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Text(
                      appointment.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
                if (canConfirm || canComplete || canCancel) ...[
                  const SizedBox(height: AppSpacing.gap),
                  Row(
                    children: [
                      if (canCancel)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              foregroundColor: AppPalette.danger,
                              side: BorderSide(
                                color: AppPalette.danger.withValues(alpha: .35),
                              ),
                              textStyle: text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => cancelAppointment(
                                      context,
                                      appointment,
                                      asStaff: isStaff,
                                      onBusy: _setBusy,
                                    ),
                                  ),
                            icon: const Icon(Icons.close_rounded, size: 17),
                            label: const Text('Annuler'),
                          ),
                        ),
                      if (canCancel && (canConfirm || canComplete))
                        const SizedBox(width: 10),
                      if (canConfirm)
                        Expanded(
                          child: _filledAction(
                            icon: Icons.check_rounded,
                            label: 'Confirmer',
                            color: AppPalette.success,
                            onPressed: () => _run(
                              () => confirmAppointment(
                                context,
                                appointment,
                                onBusy: _setBusy,
                              ),
                            ),
                          ),
                        ),
                      if (canComplete)
                        Expanded(
                          child: _filledAction(
                            icon: Icons.task_alt_rounded,
                            label: 'Terminer',
                            color: AppPalette.inkMuted,
                            onPressed: () => _run(
                              () => completeAppointment(
                                context,
                                appointment,
                                onBusy: _setBusy,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date != null ? '${date.day}' : '—',
            style: TextStyle(
              fontSize: 21,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
              color: color,
            ),
          ),
          if (date != null)
            Text(
              monthShort(date),
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(appointment.statusIcon, size: large ? 18 : 14, color: color),
          const SizedBox(width: 5),
          // Le libellé se tronque plutôt que de déborder de la pastille quand
          // la taille de texte du système est agrandie.
          Flexible(
            child: Text(
              appointment.statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
