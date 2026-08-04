import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../models/appointment.dart';
import '../../models/availability.dart';
import '../../models/doctor.dart';
import '../../models/insurance.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/catalog_repository.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
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
  late Future<List<Insurance>> _insurancesFuture;
  Future<List<TimeSlot>>? _slotsFuture;

  AvailableDay? _selectedDay;
  TimeSlot? _selectedSlot;
  final Set<int> _selectedInsuranceIds = {};

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _submitting = false;
  Map<String, List<String>> _apiErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadDays();
    // Assurances partenaires proposées à l'étape de confirmation
    _insurancesFuture = context.read<CatalogRepository>().insurances();
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
            insuranceIds: _selectedInsuranceIds.toList(),
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
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(AppRadius.control),
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: AppSpacing.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctor.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.doctor.specialty?.name ?? 'Prendre rendez-vous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          toolbarHeight: 68,
          // Pas de trait d'ombre au défilement : le fil des étapes juste en
          // dessous fait déjà la transition avec le contenu.
          scrolledUnderElevation: 0,
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
          return const SkeletonList(
            height: 82,
            padding: EdgeInsets.fromLTRB(
                AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
          );
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
            title: 'Aucune disponibilité',
            message:
                'Ce médecin n\'a pas encore ouvert de créneau. Revenez un peu plus tard.',
          );
        }

        final openDays = days.where((day) => day.available).length;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
          itemCount: days.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gap),
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
                return const SkeletonList(
                  height: 64,
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
                );
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
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
                children: [
                  _SelectedDayBanner(
                    label: _selectedDay?.label ?? '',
                    onChange: () => _goTo(0),
                  ),
                  const SizedBox(height: AppSpacing.page),
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
                        title: 'Journée complète',
                        message:
                            'Aucun créneau n\'est disponible ce jour-là. Choisissez une autre date.',
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
      const SizedBox(height: 24),
      Row(
        children: [
          Icon(period.icon, size: 15, color: AppPalette.inkFaint),
          const SizedBox(width: 7),
          Text(
            period.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.gap),
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
                        FilterPill(
                          label: suggestion,
                          selected: _reasonController.text == suggestion,
                          onTap: () => setState(() {
                            _reasonController.text = suggestion;
                            _formKey.currentState?.validate();
                          }),
                        ),
                    ],
                  ),
                  _buildInsuranceSection(),
                ],
              ),
            ),
          ),
        ),
        _BottomBar(
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 20),
            // Le libellé garde tous ses mots sur une ligne : sur un écran
            // étroit il se réduit plutôt que de se couper.
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _submitting ? 'Enregistrement…' : 'Confirmer le rendez-vous',
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Assurances partenaires : sélection multiple facultative. La section
  /// n'apparaît pas si le catalogue est vide ou momentanément inaccessible,
  /// la déclaration restant possible auprès de la clinique.
  Widget _buildInsuranceSection() {
    return FutureBuilder<List<Insurance>>(
      future: _insurancesFuture,
      builder: (context, snapshot) {
        final insurances = snapshot.data ?? const <Insurance>[];
        if (insurances.isEmpty) return const SizedBox.shrink();

        final text = Theme.of(context).textTheme;
        final error = _apiErrors['insurances']?.firstOrNull ??
            _apiErrors.entries
                .firstWhere(
                  (entry) => entry.key.startsWith('insurances.'),
                  orElse: () => const MapEntry('', <String>[]),
                )
                .value
                .firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Vos assurances', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Facultatif : indiquez la ou les couvertures dont vous bénéficiez.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.gap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final insurance in insurances)
                  FilterPill(
                    label: insurance.name,
                    selected: _selectedInsuranceIds.contains(insurance.id),
                    onTap: () => setState(() {
                      if (!_selectedInsuranceIds.remove(insurance.id)) {
                        _selectedInsuranceIds.add(insurance.id);
                      }
                    }),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: text.bodySmall?.copyWith(color: AppPalette.danger),
              ),
            ],
          ],
        );
      },
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
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
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
    final text = Theme.of(context).textTheme;
    final date = DateTime.tryParse(day.date);
    // Une journée complète reste affichée mais se retire visuellement : pas
    // d'accent bleu, pas d'ombre, texte estompé.
    final color = day.available ? AppPalette.primary : AppPalette.inkFaint;

    return AppCard(
      onTap: day.available ? onTap : null,
      padding: const EdgeInsets.all(AppSpacing.gap),
      color: day.available ? Colors.white : AppPalette.canvas,
      child: Row(
        children: [
          Container(
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
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date != null
                      ? toBeginningOfSentenceCase(
                          DateFormat('EEEE', 'fr_FR').format(date))
                      : day.label,
                  style: day.available
                      ? text.titleSmall
                      : text.titleSmall?.copyWith(color: AppPalette.inkMuted),
                ),
                const SizedBox(height: 3),
                Text(
                  day.available ? 'Créneaux disponibles' : 'Journée complète',
                  style: text.bodySmall?.copyWith(
                    color: day.available
                        ? AppPalette.success
                        : AppPalette.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          if (day.available)
            Icon(Icons.chevron_right_rounded,
                size: 22, color: AppPalette.inkFaint)
          else
            Icon(Icons.event_busy_outlined,
                size: 19, color: AppPalette.inkFaint),
        ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded,
              size: 19, color: AppPalette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: Theme.of(context).textTheme.labelMedium,
            ),
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
    final radius = BorderRadius.circular(AppRadius.control);

    return InkWell(
      borderRadius: radius,
      onTap: slot.available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !slot.available
              ? AppPalette.canvas
              : selected
                  ? AppPalette.primary
                  : Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: !slot.available
                ? AppPalette.hairline
                : selected
                    ? AppPalette.primary
                    : AppPalette.border,
            width: selected ? 1.6 : 1,
          ),
          // Le créneau retenu se détache du reste de la grille.
          boxShadow: selected ? AppShadows.brand : null,
        ),
        child: Text(
          // Seule l'heure de début est utile : « 09h00 »
          slot.start.replaceAll(':', 'h'),
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            decoration: slot.available ? null : TextDecoration.lineThrough,
            decorationColor: AppPalette.inkFaint,
            color: !slot.available
                ? AppPalette.inkFaint
                : selected
                    ? Colors.white
                    : AppPalette.ink,
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
    final text = Theme.of(context).textTheme;

    return AppCard(
        child: Column(
          children: [
            Row(
              children: [
                NetworkImageBox(
                  url: doctor.photoUrl,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  fallbackIcon: Icons.person,
                ),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.fullName, style: text.titleSmall),
                      if (doctor.specialty != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          doctor.specialty!.name,
                          style: text.labelMedium
                              ?.copyWith(color: AppPalette.primary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
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
                style: TextButton.styleFrom(
                  textStyle: text.labelMedium,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                label: const Text('Changer de créneau'),
              ),
            ),
          ],
        ));
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
            color: AppPalette.shadow.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.page, 12, AppSpacing.page, 12),
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
    return Container(
      color: AppPalette.canvas,
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color:
                        i <= current ? AppPalette.primary : AppPalette.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            InkWell(
              onTap: () => onStepTapped(i),
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // L'étape en cours est pleine, les précédentes cochées,
                      // les suivantes simplement cerclées.
                      color: i <= current ? AppPalette.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i <= current
                            ? AppPalette.primary
                            : AppPalette.border,
                      ),
                    ),
                    child: i < current
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: i <= current
                                  ? Colors.white
                                  : AppPalette.inkFaint,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == current ? FontWeight.w600 : FontWeight.w500,
                      color: i <= current
                          ? AppPalette.primary
                          : AppPalette.inkFaint,
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

  /// Libellé le plus long du récapitulatif : la colonne se dimensionne sur lui
  /// pour que les valeurs démarrent toutes au même endroit, sans qu'aucun
  /// libellé ne se coupe en deux lignes.
  static const _widestLabel = 'Assurance';

  /// Marge de sécurité après le libellé mesuré.
  static const _labelGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: AppPalette.inkMuted,
      // Même interligne que la valeur pour que les deux premières lignes
      // reposent sur la même ligne de base.
      height: 1.35,
      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Largeur mesurée à la taille de texte réellement appliquée : une
          // largeur fixe finit par couper le libellé quand l'utilisateur
          // agrandit le texte du système.
          final painter = TextPainter(
            text: TextSpan(text: _widestLabel, style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final labelWidth = math.min(
            painter.width + _labelGap,
            constraints.maxWidth * .5,
          );

          return Row(
            // Icône et libellé restent au niveau de la première ligne quand la
            // valeur passe sur deux lignes (« Samedi 25 juillet 2026 »).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: AppPalette.inkFaint),
              const SizedBox(width: AppSpacing.gap),
              SizedBox(
                width: labelWidth,
                child: Text(label, style: labelStyle),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppPalette.ink,
                  ),
                ),
              ),
            ],
          );
        },
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
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
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.success.withValues(alpha: .10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 52, color: AppPalette.success),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Rendez-vous enregistré',
                      style: text.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre demande est en attente de confirmation par la clinique. '
                      'Vous serez prévenu(e) dès qu\'un médecin l\'aura validée.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    AppCard(
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
                          if (appointment.insurances.isNotEmpty)
                            _SummaryRow(
                              icon: Icons.health_and_safety_outlined,
                              label: 'Assurance',
                              value: appointment.insurances
                                  .map((i) => i.name)
                                  .join(', '),
                            ),
                        ],
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
              const SizedBox(height: AppSpacing.gap),
              OutlinedButton(
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
