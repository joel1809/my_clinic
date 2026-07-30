import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../repositories/schedule_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'schedule_form_screen.dart';

/// Plages de disponibilité du médecin connecté : liste, ajout,
/// modification des heures et suppression.
class SchedulesTab extends StatefulWidget {
  const SchedulesTab({super.key});

  @override
  State<SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<SchedulesTab> {
  List<Schedule>? _schedules;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schedules = await context.read<ScheduleRepository>().list();
      if (!mounted) return;
      setState(() => _schedules = schedules);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Schedule? schedule}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleFormScreen(schedule: schedule),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(Schedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette plage ?'),
        content: Text(
            '${schedule.dayLabel} · ${schedule.timeLabel}\n\nLes créneaux correspondants ne seront plus proposés aux patients. '
            'Les rendez-vous déjà pris sont conservés.'),
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ScheduleRepository>().remove(schedule.id);
      if (!mounted) return;
      showSuccess(context, 'Plage horaire supprimée.');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mes créneaux',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              'Vos plages de disponibilité pour les patients',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        toolbarHeight: 76,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-schedule',
        onPressed: () => _openForm(),
        elevation: 0,
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text('Ajouter',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                )),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_schedules == null && _loading) {
      return const SkeletonList(height: 76);
    }
    if (_schedules == null && _error != null) {
      return ErrorView(error: _error!, onRetry: _load);
    }

    final schedules = _schedules ?? const [];
    if (schedules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyView(
            icon: Icons.event_busy_outlined,
            title: 'Aucune disponibilité',
            message:
                'Ajoutez une plage horaire pour que les patients puissent réserver une consultation.',
          ),
        ],
      );
    }

    final weekly = schedules.where((s) => s.isWeekly).toList();
    final dated = schedules.where((s) => !s.isWeekly).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (weekly.isNotEmpty) ...[
          const _SectionHeader(
              icon: Icons.event_repeat_outlined, title: 'Chaque semaine'),
          for (final (index, schedule) in weekly.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 50 * (index % 6)),
              child: _ScheduleCard(
                schedule: schedule,
                onEdit: () => _openForm(schedule: schedule),
                onDelete: () => _delete(schedule),
              ),
            ),
        ],
        if (dated.isNotEmpty) ...[
          if (weekly.isNotEmpty) const SizedBox(height: 16),
          const _SectionHeader(
              icon: Icons.event_outlined, title: 'Dates précises'),
          for (final (index, schedule) in dated.indexed)
            FadeSlideIn(
              delay: Duration(milliseconds: 50 * (index % 6)),
              child: _ScheduleCard(
                schedule: schedule,
                onEdit: () => _openForm(schedule: schedule),
                onDelete: () => _delete(schedule),
              ),
            ),
        ],
      ],
    );
  }
}

/// Intitulé de groupe, repris du système mais précédé d'une icône qui
/// distingue les plages hebdomadaires des dates ponctuelles.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppPalette.inkFaint),
          const SizedBox(width: 7),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final Schedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap),
      child: AppCard(
        onTap: onEdit,
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.dayLabel, style: text.titleSmall),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppPalette.inkFaint),
                      const SizedBox(width: 5),
                      Text(
                        schedule.timeLabel,
                        style: text.labelMedium
                            ?.copyWith(color: AppPalette.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppPalette.inkMuted,
              tooltip: 'Modifier les heures',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppPalette.danger,
              tooltip: 'Supprimer',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
