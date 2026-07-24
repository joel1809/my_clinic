import 'package:flutter/material.dart';
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

    setState(() => _submitting = true);
    try {
      final appointment =
          await context.read<AppointmentRepository>().book(
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
          builder: (_) => _BookingSuccessScreen(appointment: appointment),
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prendre rendez-vous',
                style: TextStyle(fontSize: 17)),
            Text(
              widget.doctor.fullName,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
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
    );
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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final day = days[index];
            return FadeSlideIn(
                delay: Duration(milliseconds: 40 * (index % 8)),
                child: Card(
              color: Colors.white,
              child: ListTile(
                enabled: day.available,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(
                  day.available
                      ? Icons.event_available_outlined
                      : Icons.event_busy_outlined,
                  color: day.available
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: Text(day.label),
                subtitle: day.available ? null : const Text('Complet'),
                trailing: day.available
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: day.available ? () => _selectDay(day) : null,
              ),
            ));
          },
        );
      },
    );
  }

  // ── Étape 2 : choix du créneau ─────────────────────────────────────────

  Widget _buildSlotStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _selectedDay?.label ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
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
              if (slots.isEmpty) {
                return const EmptyView(
                  icon: Icons.schedule_outlined,
                  message: 'Aucun créneau pour cette date.',
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.9,
                ),
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final selected = _selectedSlot?.start == slot.start;
                  final scheme = Theme.of(context).colorScheme;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: slot.available
                        ? () => setState(() {
                              _selectedSlot = slot;
                              _step = 2;
                            })
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !slot.available
                            ? Colors.grey.shade200
                            : selected
                                ? scheme.primary
                                : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: slot.available
                              ? scheme.primary.withValues(alpha: .4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        slot.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: slot.available
                              ? null
                              : TextDecoration.lineThrough,
                          color: !slot.available
                              ? Colors.grey
                              : selected
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Étape 3 : motif, téléphone et confirmation ─────────────────────────

  Widget _buildConfirmStep() {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.arrow_back),
                ),
                const Text(
                  'Récapitulatif',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(
                      icon: Icons.person_outline,
                      label: 'Médecin',
                      value: widget.doctor.fullName,
                    ),
                    if (widget.doctor.specialty != null)
                      _SummaryRow(
                        icon: Icons.medical_services_outlined,
                        label: 'Spécialité',
                        value: widget.doctor.specialty!.name,
                      ),
                    _SummaryRow(
                      icon: Icons.event_outlined,
                      label: 'Date',
                      value: _selectedDay?.label ?? '',
                    ),
                    _SummaryRow(
                      icon: Icons.schedule_outlined,
                      label: 'Créneau',
                      value: _selectedSlot?.label ?? '',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
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
                errorText: _apiErrors['reason']?.firstOrNull,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez indiquer le motif de la consultation.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Confirmer le rendez-vous'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  static const _labels = ['Jour', 'Créneau', 'Confirmation'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i <= current
                      ? scheme.primary
                      : Colors.grey.shade300,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      i <= current ? scheme.primary : Colors.grey.shade300,
                  child: Text(
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
                const SizedBox(height: 2),
                Text(_labels[i], style: const TextStyle(fontSize: 11)),
              ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation visuelle après la réservation.
class _BookingSuccessScreen extends StatelessWidget {
  const _BookingSuccessScreen({required this.appointment});

  final Appointment appointment;

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
                    'Vous retrouverez ce rendez-vous dans l\'onglet « Rendez-vous ».',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey.shade600, height: 1.5),
                  ),
                ],
              )),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => AppointmentDetailScreen(
                        appointmentId: appointment.id),
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
