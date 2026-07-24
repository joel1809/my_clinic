import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import 'appointment_detail_screen.dart';

/// Liste paginée des rendez-vous du patient.
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  final _scrollController = ScrollController();
  final List<Appointment> _appointments = [];

  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;
  int _page = 0;
  bool _hasMore = true;

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

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
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
      final page = await context
          .read<AppointmentRepository>()
          .list(page: _page + 1);
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
  }

  Future<void> _refresh() async {
    setState(() {
      _appointments.clear();
      _page = 0;
      _hasMore = true;
      _initialLoaded = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = context.watch<AuthState>().user?.isStaff ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isStaff ? 'Rendez-vous des patients' : 'Mes rendez-vous'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_initialLoaded && _error != null) {
      return ErrorView(error: _error!, onRetry: _loadMore);
    }
    if (_appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyView(
            icon: Icons.event_note_outlined,
            message:
                'Vous n\'avez pas encore de rendez-vous.\nPrenez-en un depuis l\'accueil !',
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _appointments.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return FadeSlideIn(
          delay: Duration(milliseconds: 50 * (index % 6)),
          child: _AppointmentCard(
            appointment: _appointments[index],
            onChanged: _refresh,
          ),
        );
      },
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({required this.appointment, required this.onChanged});

  final Appointment appointment;
  final Future<void> Function() onChanged;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _cancelling = false;
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await context
          .read<AppointmentRepository>()
          .confirm(widget.appointment.id);
      if (!mounted) return;
      showSuccess(context, 'Rendez-vous confirmé.');
      await widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text(
            'Le créneau sera libéré et redeviendra disponible pour les autres patients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler le RDV'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<AppointmentRepository>()
          .cancel(widget.appointment.id);
      if (!mounted) return;
      showSuccess(context, 'Rendez-vous annulé.');
      await widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final isStaff = context.watch<AuthState>().user?.isStaff ?? false;
    final statusColor = appointment.statusColor(context);
    final date = DateTime.tryParse(appointment.scheduledDate);
    final dateLabel = date != null
        ? toBeginningOfSentenceCase(
            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date))
        : appointment.scheduledDate;

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
          if (changed == true) await widget.onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appointment.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$dateLabel · ${appointment.startTime} - ${appointment.endTime}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              if (appointment.isCancellable ||
                  (isStaff && appointment.isConfirmable)) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (appointment.isCancellable)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _cancelling ? null : _cancel,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Annuler'),
                      ),
                    if (isStaff && appointment.isConfirmable) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          backgroundColor: Colors.green.shade600,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _confirming ? null : _confirm,
                        icon: _confirming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline,
                                size: 18),
                        label: const Text('Confirmer'),
                      ),
                    ],
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
