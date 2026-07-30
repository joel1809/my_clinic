import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../repositories/schedule_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

/// Libellés français des jours ISO-8601 (1 = lundi … 7 = dimanche).
const Map<int, String> kWeekdayLabels = {
  1: 'Lundi',
  2: 'Mardi',
  3: 'Mercredi',
  4: 'Jeudi',
  5: 'Vendredi',
  6: 'Samedi',
  7: 'Dimanche',
};

/// Création d'une plage de disponibilité (hebdomadaire ou à dates précises)
/// ou modification des heures d'une plage existante.
class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key, this.schedule});

  /// Plage à modifier ; null pour une création.
  final Schedule? schedule;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  bool _weekly = true;
  final Set<int> _weekdays = {};
  final Set<DateTime> _dates = {};

  late TimeOfDay _start;
  late TimeOfDay _end;

  bool _saving = false;

  bool get _editing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    _start = _parseTime(widget.schedule?.startTime) ??
        const TimeOfDay(hour: 8, minute: 0);
    _end = _parseTime(widget.schedule?.endTime) ??
        const TimeOfDay(hour: 18, minute: 0);
  }

  static TimeOfDay? _parseTime(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'Heure de début' : 'Heure de fin',
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    // Horizon de réservation du backend : 2 mois par défaut
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year, today.month + 2, today.day),
      helpText: 'Date de la plage',
    );
    if (picked == null) return;
    setState(() => _dates.add(DateTime(picked.year, picked.month, picked.day)));
  }

  String? get _validationError {
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (startMinutes >= endMinutes) {
      return 'L\'heure de début doit précéder l\'heure de fin.';
    }
    if (!_editing && _weekly && _weekdays.isEmpty) {
      return 'Choisissez au moins un jour de la semaine.';
    }
    if (!_editing && !_weekly && _dates.isEmpty) {
      return 'Ajoutez au moins une date.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validationError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      return;
    }

    setState(() => _saving = true);
    final repository = context.read<ScheduleRepository>();
    try {
      if (_editing) {
        await repository.update(
          widget.schedule!.id,
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
        );
      } else {
        await repository.create(
          weekdays: _weekly ? (_weekdays.toList()..sort()) : const [],
          dates: _weekly
              ? const []
              : (_dates.toList()..sort())
                  .map(DateFormat('yyyy-MM-dd').format)
                  .toList(),
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
        );
      }
      if (!mounted) return;
      showSuccess(
          context, _editing ? 'Plage horaire modifiée.' : 'Plage(s) ajoutée(s).');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier la plage' : 'Nouvelle plage'),
      ),
      body: FadeSlideIn(
        child: ListView(
          // Marge basse augmentée de la zone système : en bord à bord, le
          // bouton d'enregistrement passerait sous la barre de navigation.
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            if (_editing)
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppPalette.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.schedule!.isWeekly
                            ? Icons.event_repeat_outlined
                            : Icons.event_outlined,
                        size: 19,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.schedule!.dayLabel, style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            widget.schedule!.isWeekly
                                ? 'Chaque semaine'
                                : 'Date précise',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              const SectionHeader(title: 'Jours concernés'),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white,
                  selectedBackgroundColor: AppPalette.primarySoft,
                  selectedForegroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.inkMuted,
                  side: const BorderSide(color: AppPalette.border),
                  textStyle: text.labelMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                ),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Chaque semaine'),
                    icon: Icon(Icons.event_repeat_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Dates précises'),
                    icon: Icon(Icons.event_outlined, size: 18),
                  ),
                ],
                selected: {_weekly},
                onSelectionChanged: (selection) =>
                    setState(() => _weekly = selection.first),
              ),
              const SizedBox(height: AppSpacing.gutter),
              if (_weekly)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in kWeekdayLabels.entries)
                      FilterPill(
                        label: entry.value,
                        selected: _weekdays.contains(entry.key),
                        onTap: () => setState(() =>
                            _weekdays.contains(entry.key)
                                ? _weekdays.remove(entry.key)
                                : _weekdays.add(entry.key)),
                      ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final date in _dates.toList()..sort())
                      InputChip(
                        label: Text(toBeginningOfSentenceCase(
                            DateFormat('EEE d MMM yyyy', 'fr_FR')
                                .format(date))!),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        onDeleted: () => setState(() => _dates.remove(date)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded,
                          size: 17, color: AppPalette.primary),
                      label: const Text('Ajouter une date'),
                      labelStyle: text.labelMedium
                          ?.copyWith(color: AppPalette.primary),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 28),
            const SectionHeader(title: 'Horaires'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _TimeRow(
                    label: 'Heure de début',
                    value: _formatTime(_start).replaceAll(':', 'h'),
                    onTap: () => _pickTime(start: true),
                  ),
                  const Divider(height: 1, indent: AppSpacing.gutter,
                      endIndent: AppSpacing.gutter),
                  _TimeRow(
                    label: 'Heure de fin',
                    value: _formatTime(_end).replaceAll(':', 'h'),
                    onTap: () => _pickTime(start: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gap),
            Text(
              'Les créneaux proposés aux patients sont découpés dans ces plages '
              'selon votre durée de consultation.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(_editing ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « libellé / heure » ouvrant le sélecteur d'heure.
class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 20, color: AppPalette.inkFaint),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(child: Text(label, style: text.bodyLarge)),
            Text(
              value,
              style: text.titleMedium?.copyWith(color: AppPalette.primary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: AppPalette.inkFaint),
          ],
        ),
      ),
    );
  }
}
