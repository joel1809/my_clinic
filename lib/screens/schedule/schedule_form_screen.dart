import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../repositories/schedule_repository.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier la plage' : 'Nouvelle plage'),
      ),
      body: FadeSlideIn(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_editing)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(
                    widget.schedule!.isWeekly
                        ? Icons.event_repeat_outlined
                        : Icons.event_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    widget.schedule!.dayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(widget.schedule!.isWeekly
                      ? 'Chaque semaine'
                      : 'Date précise'),
                ),
              )
            else ...[
              _SectionTitle('Jours concernés'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Chaque semaine'),
                    icon: Icon(Icons.event_repeat_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Dates précises'),
                    icon: Icon(Icons.event_outlined),
                  ),
                ],
                selected: {_weekly},
                onSelectionChanged: (selection) =>
                    setState(() => _weekly = selection.first),
              ),
              const SizedBox(height: 12),
              if (_weekly)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in kWeekdayLabels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _weekdays.contains(entry.key),
                        onSelected: (selected) => setState(() => selected
                            ? _weekdays.add(entry.key)
                            : _weekdays.remove(entry.key)),
                      ),
                  ],
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final date in _dates.toList()..sort())
                      InputChip(
                        label: Text(toBeginningOfSentenceCase(
                            DateFormat('EEE d MMM yyyy', 'fr_FR')
                                .format(date))!),
                        onDeleted: () => setState(() => _dates.remove(date)),
                      ),
                    ActionChip(
                      avatar: Icon(Icons.add, size: 18, color: scheme.primary),
                      label: const Text('Ajouter une date'),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            _SectionTitle('Horaires'),
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.schedule_outlined, color: scheme.primary),
                    title: const Text('Heure de début'),
                    trailing: Text(
                      _formatTime(_start).replaceAll(':', 'h'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _pickTime(start: true),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.schedule, color: scheme.primary),
                    title: const Text('Heure de fin'),
                    trailing: Text(
                      _formatTime(_end).replaceAll(':', 'h'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _pickTime(start: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Les créneaux proposés aux patients sont découpés dans ces plages '
              'selon votre durée de consultation.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_editing ? 'Enregistrer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}
