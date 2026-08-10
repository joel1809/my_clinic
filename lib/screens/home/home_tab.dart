import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/specialty.dart';
import '../../repositories/catalog_repository.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../doctors/doctors_screen.dart';

/// Accueil : salutation, accès rapide et liste des spécialités.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Specialty>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<CatalogRepository>().specialties();
  }

  void _reload() {
    setState(() {
      _future = context.read<CatalogRepository>().specialties();
    });
  }

  void _openDoctors([Specialty? specialty]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoctorsScreen(specialty: specialty)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pas d'AppBar : la salutation défile avec le contenu, l'écran gagne en
      // hauteur utile et l'attention va d'abord au bandeau de prise de RDV.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<Specialty>>(
            future: _future,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
                children: [
                  const _Greeting(),
                  const SizedBox(height: AppSpacing.page),
                  FadeSlideIn(child: _BookingBanner(onTap: _openDoctors)),
                  const SizedBox(height: 28),
                  if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: ErrorView(error: snapshot.error!, onRetry: _reload),
                    )
                  else ...[
                    SectionHeader(
                      title: 'Nos spécialités',
                      actionLabel: loading ? null : 'Voir les médecins',
                      onAction: loading ? null : _openDoctors,
                    ),
                    if (loading)
                      const _SpecialtyGridSkeleton()
                    else if ((snapshot.data ?? const []).isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: EmptyView(
                          icon: Icons.medical_services_outlined,
                          title: 'Aucune spécialité',
                          message:
                              'Les spécialités apparaîtront ici dès qu\'elles seront publiées.',
                        ),
                      )
                    else
                      _SpecialtyGrid(
                        specialties: snapshot.data!,
                        onSelected: _openDoctors,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Salutation en tête de page.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final text = Theme.of(context).textTheme;
    final firstName = user?.name.split(' ').first;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour', style: text.bodyMedium),
              const SizedBox(height: 2),
              Text(
                firstName == null ? 'Bienvenue' : '$firstName 👋',
                style: text.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (firstName != null)
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              firstName.characters.first.toUpperCase(),
              style: text.titleMedium?.copyWith(color: AppPalette.primary),
            ),
          ),
      ],
    );
  }
}

/// Bandeau de prise de rendez-vous : la seule surface colorée de l'écran, ce
/// qui en fait naturellement le point d'entrée principal.
class _BookingBanner extends StatelessWidget {
  const _BookingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.brand,
      ),
      child: Stack(
        children: [
          // Halo décoratif débordant du coin : donne du relief au dégradé sans
          // ajouter d'image à charger.
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin d\'une consultation ?',
                  style: text.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choisissez une spécialité, un médecin, et réservez votre créneau en quelques secondes.',
                  style: text.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .82),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: Colors.white,
                    foregroundColor: AppPalette.primary,
                  ),
                  onPressed: onTap,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Prendre rendez-vous'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille des spécialités.
class _SpecialtyGrid extends StatelessWidget {
  const _SpecialtyGrid({required this.specialties, required this.onSelected});

  final List<Specialty> specialties;
  final ValueChanged<Specialty> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppSpacing.gap,
        crossAxisSpacing: AppSpacing.gap,
        childAspectRatio: 1.05,
      ),
      itemCount: specialties.length,
      itemBuilder: (context, index) => FadeSlideIn(
        delay: Duration(milliseconds: 40 * (index % 8)),
        child: _SpecialtyCard(
          specialty: specialties[index],
          onTap: () => onSelected(specialties[index]),
        ),
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.specialty, required this.onTap});

  final Specialty specialty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = specialty.doctorsCount ?? 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpecialtyAvatar(specialty: specialty),
          const Spacer(),
          // Nom à la couleur de marque, comme la spécialité sur la fiche d'un
          // médecin : le nombre de médecins reste en gris sous lui.
          Text(
            specialty.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: AppPalette.primary),
          ),
          const SizedBox(height: 3),
          Text(
            count == 0
                ? 'Aucun médecin'
                : '$count médecin${count > 1 ? 's' : ''}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Grille en squelette pendant le chargement des spécialités.
class _SpecialtyGridSkeleton extends StatelessWidget {
  const _SpecialtyGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppSpacing.gap,
        crossAxisSpacing: AppSpacing.gap,
        childAspectRatio: 1.05,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const SkeletonBox(
        height: 100,
        radius: AppRadius.card,
      ),
    );
  }
}
