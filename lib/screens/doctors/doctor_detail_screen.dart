import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor.dart';
import '../../repositories/catalog_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../booking/booking_screen.dart';

/// Fiche détaillée d'un médecin avec bouton de prise de rendez-vous.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key, required this.doctorId});

  final int doctorId;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  late Future<Doctor> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<CatalogRepository>().doctor(widget.doctorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche médecin')),
      body: FutureBuilder<Doctor>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }

          final doctor = snapshot.data!;

          final text = Theme.of(context).textTheme;

          return FadeSlideIn(
              child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Row(
                      children: [
                        NetworkImageBox(
                          url: doctor.photoUrl,
                          width: 100,
                          height: 100,
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          fallbackIcon: Icons.person,
                        ),
                        const SizedBox(width: AppSpacing.gutter),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.fullName,
                                style: text.headlineSmall,
                              ),
                              if (doctor.specialty != null) ...[
                                const SizedBox(height: 8),
                                // Étiquette alignée à gauche : dans un Column
                                // étiré, un Container prendrait toute la
                                // largeur disponible.
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppPalette.primarySoft,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.pill),
                                    ),
                                    child: Text(
                                      doctor.specialty!.name,
                                      style: text.labelMedium?.copyWith(
                                        color: AppPalette.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.page),
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
                            child: const Icon(Icons.schedule_rounded,
                                size: 19, color: AppPalette.primary),
                          ),
                          const SizedBox(width: AppSpacing.gap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Durée d\'une consultation',
                                    style: text.bodySmall),
                                const SizedBox(height: 2),
                                Text('${doctor.appointmentDuration} minutes',
                                    style: text.bodyLarge),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (doctor.bio != null &&
                        doctor.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionHeader(title: 'À propos'),
                      Text(
                        doctor.bio!,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.65,
                          color: AppPalette.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Barre d'action posée sur un fond blanc ombré : le bouton reste
              // lisible quel que soit le contenu qui défile dessous.
              DecoratedBox(
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12,
                        AppSpacing.page, 12),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(doctor: doctor),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 20),
                      label: const Text('Prendre rendez-vous'),
                    ),
                  ),
                ),
              ),
            ],
          ));
        },
      ),
    );
  }
}
