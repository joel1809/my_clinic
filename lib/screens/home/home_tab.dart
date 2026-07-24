import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/specialty.dart';
import '../../repositories/catalog_repository.dart';
import '../../state/auth_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour${user != null ? ', ${user.name.split(' ').first}' : ''} 👋',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Comment pouvons-nous vous aider ?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        toolbarHeight: 68,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Specialty>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _reload);
            }

            final specialties = snapshot.data ?? const [];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Bandeau prise de rendez-vous
                FadeSlideIn(
                    child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.primary.withValues(alpha: .75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Besoin d\'une consultation ?',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choisissez une spécialité puis un médecin, et réservez votre créneau en quelques secondes.',
                        style: TextStyle(
                          color: scheme.onPrimary.withValues(alpha: .9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: scheme.onPrimary,
                          foregroundColor: scheme.primary,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DoctorsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Prendre rendez-vous'),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                Text(
                  'Nos spécialités',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (specialties.isEmpty)
                  const EmptyView(
                    icon: Icons.medical_services_outlined,
                    message: 'Aucune spécialité disponible pour le moment.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: specialties.length,
                    itemBuilder: (context, index) => FadeSlideIn(
                      delay: Duration(milliseconds: 40 * (index % 8)),
                      child: _SpecialtyCard(specialty: specialties[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.specialty});

  final Specialty specialty;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoctorsScreen(specialty: specialty),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SpecialtyAvatar(specialty: specialty),
              const Spacer(),
              Text(
                specialty.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '${specialty.doctorsCount ?? 0} médecin${(specialty.doctorsCount ?? 0) > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
