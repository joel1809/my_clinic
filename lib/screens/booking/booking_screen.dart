import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/appointment.dart';
import '../../models/availability.dart';
import '../../models/doctor.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/catalog_repository.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import '../appointments/appointment_detail_screen.dart';

/// Prise de rendez-vous en trois étapes :
/// 1. choix du jour, 2. choix du créneau, 3. motif et confirmation.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.doctor});

  final Doctor doctor;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _step = 0;

  late Future<List<AvailableDay>> _daysFuture;
  Future<List<TimeSlot>>? _slotsFuture;

  AvailableDay? _selectedDay;
  TimeSlot? _selectedSlot;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _submitting = false;
  Map<String, List<String>> _apiErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadDays();
    // Pré-remplit le téléphone enregistré sur le compte
    final phone = context.read<AuthState>().user?.phone;
    if (phone != null) _phoneController.text = phone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _loadDays() {
    _daysFuture = context.read<CatalogRepository>().days(widget.doctor.id);
  }

  void _goTo(int step) => setState(() => _step = step);

  void _selectDay(AvailableDay day) {
    setState(() {
      _selectedDay = day;
      _selectedSlot = null;
      _slotsFuture =
          context.read<CatalogRepository>().slots(widget.doctor.id, day.date);
      _step = 1;
    });
  }

  Future<void> _submit() async {
    setState(() => _apiErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final appointment = await context.read<AppointmentRepository>().book(
            specialtyId: widget.doctor.specialty!.id,
            doctorId: widget.doctor.id,
            scheduledDate: _selectedDay!.date,
            startTime: _selectedSlot!.start,
            phone: _phoneController.text.trim(),
            reason: _reasonController.text.trim(),
          );

      if (!mounted) return;
      // Le téléphone du compte a pu être mis à jour côté serveur
      context.read<AuthState>().refreshUser();

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _BookingSuccessScreen(
            appointment: appointment,
            doctor: widget.doctor,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _apiErrors = e.errors);

      final slotError = e.firstError('start_time');
      if (slotError != null) {
        // Le créneau vient d'être pris : on recharge les créneaux du jour
        showError(context, e);
        _selectDay(_selectedDay!);
      } else if (e.errors.isEmpty) {
        showError(context, e);
      }
      _formKey.currentState?.validate();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le retour ramène à l'étape précédente avant de quitter l'écran
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              NetworkImageBox(
                url: widget.doctor.photoUrl,
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(10),
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctor.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.doctor.specialty?.name ?? 'Prendre rendez-vous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          toolbarHeight: 64,
        ),
        body: Column(
          children: [
            _StepIndicator(current: _step, onStepTapped: _onStepTapped),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _buildDayStep(),
                    1 => _buildSlotStep(),
                    _ => _buildConfirmStep(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Retour en arrière depuis l'indicateur d'étapes (une étape déjà franchie).
  void _onStepTapped(int step) {
    if (step < _step) _goTo(step);
  }

  // ── Étape 1 : choix du jour ────────────────────────────────────────────

  Widget _buildDayStep() {
    return FutureBuilder<List<AvailableDay>>(
      future: _daysFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_loadDays),
          );
        }

        final days = snapshot.data ?? const <AvailableDay>[];
        if (days.isEmpty) {
          return const EmptyView(
            icon: Icons.event_busy_outlined,
            message:
                'Ce médecin n\'a aucune disponibilité pour le moment.\nRevenez plus tard.',
          );
        }

        final openDays = days.where((day) => day.available).length;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: days.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _StepHeader(
                title: 'Quand souhaitez-vous consulter ?',
                subtitle: openDays > 0
                    ? '$openDays jour${openDays > 1 ? 's' : ''} de consultation '
                        'disponible${openDays > 1 ? 's' : ''} · '
                        '${widget.doctor.appointmentDuration} min par consultation'
                    : 'Toutes les journées affichées sont complètes.',
              );
            }

            final day = days[index - 1];
            return FadeSlideIn(
              delay: Duration(milliseconds: 40 * (index % 8)),
              child: _DayCard(day: day, onTap: () => _selectDay(day)),
            );
          },
        );
      },
    );
  }

  // ── Étape 2 : choix du créneau ─────────────────────────────────────────

  Widget _buildSlotStep() {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<TimeSlot>>(
            future: _slotsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(
                  error: snapshot.error!,
                  onRetry: () => _selectDay(_selectedDay!),
                );
              }

              final slots = snapshot.data ?? const <TimeSlot>[];
              final free = slots.where((slot) => slot.available).length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _SelectedDayBanner(
                    label: _selectedDay?.label ?? '',
                    onChange: () => _goTo(0),
                  ),
                  const SizedBox(height: 16),
                  _StepHeader(
                    title: 'Choisissez votre heure',
                    subtitle: slots.isEmpty
                        ? 'Aucun créneau pour cette date.'
                        : '$free créneau${free > 1 ? 'x' : ''} '
                            'encore libre${free > 1 ? 's' : ''} sur ${slots.length}',
                  ),
                  if (slots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyView(
                        icon: Icons.schedule_outlined,
                        message:
                            'Aucun créneau pour cette date.\nChoisissez un autre jour.',
                      ),
                    )
                  else
                    for (final period in _SlotPeriod.values)
                      ..._buildPeriodSection(period, slots),
                ],
              );
            },
          ),
        ),
        _BottomBar(
          child: FilledButton.icon(
            onPressed: _selectedSlot == null ? null : () => _goTo(2),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _selectedSlot == null
                  ? 'Sélectionnez un créneau'
                  : 'Continuer · ${_selectedSlot!.label}',
            ),
          ),
        ),
      ],
    );
  }

  /// Section « Matin / Après-midi / Soir » : titre puis grille de créneaux.
  List<Widget> _buildPeriodSection(_SlotPeriod period, List<TimeSlot> slots) {
    final periodSlots =
        slots.where((slot) => _SlotPeriod.of(slot) == period).toList();
    if (periodSlots.isEmpty) return const [];

    return [
      const SizedBox(height: 20),
      Row(
        children: [
          Icon(period.icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            period.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final slot in periodSlots)
            _SlotChip(
              slot: slot,
              selected: _selectedSlot?.start == slot.start,
              onTap: () => setState(() => _selectedSlot = slot),
            ),
        ],
      ),
    ];
  }

  // ── Étape 3 : motif, téléphone et confirmation ─────────────────────────

  Widget _buildConfirmStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StepHeader(
                    title: 'Dernière étape',
                    subtitle:
                        'Vérifiez le récapitulatif et précisez le motif de votre visite.',
                  ),
                  const SizedBox(height: 4),
                  _RecapCard(
                    doctor: widget.doctor,
                    day: _selectedDay,
                    slot: _selectedSlot,
                    onChangeSlot: () => _goTo(1),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Téléphone de contact',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      helperText: 'Utilisé pour les rappels de rendez-vous',
                      errorText: _apiErrors['phone']?.firstOrNull,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez indiquer un numéro de téléphone.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Motif de la consultation',
                      alignLabelWithHint: true,
                      hintText:
                          'Décrivez brièvement vos symptômes ou la raison de votre visite',
                      errorText: _apiErrors['reason']?.firstOrNull,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez indiquer le motif de la consultation.';
                      }
                      return null;
                    },
                  ),
                  // Motifs fréquents : remplissent le champ en un geste
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _reasonSuggestions)
                        ActionChip(
                          label: Text(suggestion,
                              style: const TextStyle(fontSize: 12.5)),
                          backgroundColor: Colors.white,
                          onPressed: () => setState(() {
                            _reasonController.text = suggestion;
                            _formKey.currentState?.validate();
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _BottomBar(
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_submitting
                ? 'Enregistrement…'
                : 'Confirmer le rendez-vous'),
          ),
        ),
      ],
    );
  }
}

const _reasonSuggestions = [
  'Consultation générale',
  'Suivi de traitement',
  'Résultats d\'examens',
  'Douleurs persistantes',
];

/// Moment de la journée d'un créneau, pour regrouper la grille.
enum _SlotPeriod {
  morning('Matin', Icons.wb_twilight_rounded),
  afternoon('Après-midi', Icons.wb_sunny_outlined),
  evening('Soirée', Icons.nightlight_round);

  const _SlotPeriod(this.label, this.icon);

  final String label;
  final IconData icon;

  static _SlotPeriod of(TimeSlot slot) {
    final hour = int.tryParse(slot.start.split(':').first) ?? 0;
    if (hour < 12) return _SlotPeriod.morning;
    if (hour < 18) return _SlotPeriod.afternoon;
    return _SlotPeriod.evening;
  }
}

/// Titre d'étape avec sous-titre explicatif.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un jour de consultation : pastille de date puis libellé.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onTap});

  final AvailableDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(day.date);
    final color = day.available ? scheme.primary : Colors.grey;

    return Opacity(
      opacity: day.available ? 1 : .6,
      child: Card(
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: day.available ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
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
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date != null
                            ? toBeginningOfSentenceCase(
                                DateFormat('EEEE', 'fr_FR').format(date))
                            : day.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.available
                            ? 'Créneaux disponibles'
                            : 'Journée complète',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: day.available
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (day.available)
                  Icon(Icons.chevron_right_rounded, color: scheme.primary)
                else
                  Icon(Icons.event_busy_outlined,
                      size: 20, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rappel du jour choisi à l'étape 2, avec retour rapide à l'étape 1.
class _SelectedDayBanner extends StatelessWidget {
  const _SelectedDayBanner({required this.label, required this.onChange});

  final String label;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }
}

/// Créneau horaire sélectionnable (barré quand il est déjà réservé).
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final TimeSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: slot.available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !slot.available
              ? Colors.grey.shade200
              : selected
                  ? scheme.primary
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !slot.available
                ? Colors.grey.shade300
                : selected
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: .35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          // Seule l'heure de début est utile : « 09h00 »
          slot.start.replaceAll(':', 'h'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: slot.available ? null : TextDecoration.lineThrough,
            color: !slot.available
                ? Colors.grey
                : selected
                    ? scheme.onPrimary
                    : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Récapitulatif de l'étape 3.
class _RecapCard extends StatelessWidget {
  const _RecapCard({
    required this.doctor,
    required this.day,
    required this.slot,
    required this.onChangeSlot,
  });

  final Doctor doctor;
  final AvailableDay? day;
  final TimeSlot? slot;
  final VoidCallback onChangeSlot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                NetworkImageBox(
                  url: doctor.photoUrl,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(12),
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (doctor.specialty != null)
                        Text(
                          doctor.specialty!.name,
                          style:
                              TextStyle(fontSize: 13, color: scheme.primary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _SummaryRow(
              icon: Icons.event_outlined,
              label: 'Date',
              value: day?.label ?? '',
            ),
            _SummaryRow(
              icon: Icons.schedule_outlined,
              label: 'Horaire',
              value: slot?.label ?? '',
            ),
            _SummaryRow(
              icon: Icons.timelapse_outlined,
              label: 'Durée',
              value: '${doctor.appointmentDuration} minutes',
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onChangeSlot,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Changer de créneau'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre d'action fixe en bas des étapes 2 et 3.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

/// Fil des trois étapes : pastilles reliées, cochées une fois franchies.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.onStepTapped});

  final int current;
  final ValueChanged<int> onStepTapped;

  static const _labels = ['Jour', 'Créneau', 'Confirmation'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: i <= current ? scheme.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            InkWell(
              onTap: () => onStepTapped(i),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i <= current
                          ? scheme.primary
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: i < current
                        ? Icon(Icons.check_rounded,
                            size: 16, color: scheme.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: i <= current
                                  ? scheme.onPrimary
                                  : Colors.grey.shade600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current
                          ? scheme.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Largeur réservée au libellé pour que les valeurs des lignes successives
  /// (Date, Horaire, Durée) démarrent toutes sur la même colonne.
  static const _labelWidth = 78.0;

  /// Plafond de la colonne de libellé : au-delà, la valeur n'aurait plus assez
  /// de place sur un écran étroit.
  static const _maxLabelWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    // La colonne suit la taille de texte du système, sinon « Médecin » passe
    // sur deux lignes dès que l'utilisateur agrandit le texte.
    final labelWidth = MediaQuery.textScalerOf(context)
        .scale(_labelWidth)
        .clamp(_labelWidth, _maxLabelWidth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        // Icône et libellé restent au niveau de la première ligne quand la
        // valeur passe sur deux lignes (« Samedi 25 juillet 2026 »).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              // Même interligne que la valeur pour que les deux premières
              // lignes reposent sur la même ligne de base.
              style: TextStyle(color: Colors.grey.shade600, height: 1.35),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation visuelle après la réservation.
class _BookingSuccessScreen extends StatelessWidget {
  const _BookingSuccessScreen({required this.appointment, required this.doctor});

  final Appointment appointment;
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              FadeSlideIn(
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: .6, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle,
                            size: 72, color: Colors.green.shade600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rendez-vous enregistré !',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre demande est en attente de confirmation par la clinique. '
                      'Vous serez prévenu(e) dès qu\'un médecin l\'aura validée.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _SummaryRow(
                              icon: Icons.person_outline,
                              label: 'Médecin',
                              value: doctor.fullName,
                            ),
                            _SummaryRow(
                              icon: Icons.event_outlined,
                              label: 'Date',
                              value: appointment.longDateLabel,
                            ),
                            _SummaryRow(
                              icon: Icons.schedule_outlined,
                              label: 'Horaire',
                              value: appointment.timeRangeLabel,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        AppointmentDetailScreen(appointmentId: appointment.id),
                  ),
                ),
                child: const Text('Voir le rendez-vous'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  foregroundColor: scheme.primary,
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
