import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor.dart';
import '../../models/specialty.dart';
import '../../repositories/catalog_repository.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'doctor_detail_screen.dart';

/// Liste des médecins, filtrable par spécialité.
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key, this.specialty});

  /// Si fournie, la liste est pré-filtrée sur cette spécialité.
  final Specialty? specialty;

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late Future<List<Doctor>> _doctorsFuture;
  late Future<List<Specialty>> _specialtiesFuture;
  Specialty? _selected;

  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.specialty;
    _specialtiesFuture = context.read<CatalogRepository>().specialties();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Minuscules sans accents, pour une recherche tolérante.
  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  List<Doctor> _applySearch(List<Doctor> doctors) {
    final query = _normalize(_search.trim());
    if (query.isEmpty) return doctors;
    return doctors
        .where((doctor) =>
            _normalize(doctor.fullName).contains(query) ||
            (doctor.specialty != null &&
                _normalize(doctor.specialty!.name).contains(query)))
        .toList();
  }

  void _loadDoctors() {
    _doctorsFuture =
        context.read<CatalogRepository>().doctors(specialtyId: _selected?.id);
  }

  void _selectSpecialty(Specialty? specialty) {
    setState(() {
      _selected = specialty;
      _loadDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nos médecins'),
        titleSpacing: AppSpacing.page,
        // Pas de trait d'ombre au défilement : la barre de recherche juste
        // en dessous fait déjà la transition avec le contenu.
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 4, AppSpacing.page, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Rechercher un médecin, une spécialité…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
            ),
          ),
          // Filtre par spécialité, aéré d'une marge au-dessus et en dessous
          SizedBox(
            height: 76,
            child: FutureBuilder<List<Specialty>>(
              future: _specialtiesFuture,
              builder: (context, snapshot) {
                final specialties = snapshot.data ?? const <Specialty>[];
                if (specialties.isEmpty) return const SizedBox.shrink();

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page,
                      AppSpacing.gutter, AppSpacing.page, AppSpacing.gutter),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterPill(
                        label: 'Toutes',
                        selected: _selected == null,
                        onTap: () => _selectSpecialty(null),
                      ),
                    ),
                    for (final specialty in specialties)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterPill(
                          label: specialty.name,
                          selected: _selected?.id == specialty.id,
                          onTap: () => _selectSpecialty(specialty),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Doctor>>(
              future: _doctorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonList(height: 92);
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    error: snapshot.error!,
                    onRetry: () => setState(_loadDoctors),
                  );
                }

                final doctors = _applySearch(snapshot.data ?? const <Doctor>[]);
                if (doctors.isEmpty) {
                  return EmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'Aucun médecin',
                    message: _search.trim().isEmpty
                        ? 'Aucun médecin n\'exerce dans cette spécialité pour le moment.'
                        : 'Aucun médecin ne correspond à « ${_search.trim()} ».',
                  );
                }

                return ListView.separated(
                  // Marge basse augmentée de la zone système : en bord à bord,
                  // la dernière carte passerait sous la barre de navigation.
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page,
                    AppSpacing.page + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: doctors.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.gap),
                  itemBuilder: (context, index) => FadeSlideIn(
                    delay: Duration(milliseconds: 50 * (index % 6)),
                    child: _DoctorCard(doctor: doctors[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gap),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DoctorDetailScreen(doctorId: doctor.id),
        ),
      ),
      child: Row(
        children: [
          NetworkImageBox(
            url: doctor.photoUrl,
            width: 66,
            height: 66,
            borderRadius: BorderRadius.circular(AppRadius.control),
            fallbackIcon: Icons.person,
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.fullName, style: text.titleSmall),
                if (doctor.specialty != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    doctor.specialty!.name,
                    style: text.labelMedium?.copyWith(
                      color: AppPalette.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                // Durée de consultation présentée comme une étiquette : c'est
                // une caractéristique du médecin, pas une phrase à lire.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.canvas,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: AppPalette.inkFaint),
                      const SizedBox(width: 5),
                      Text(
                        '${doctor.appointmentDuration} min',
                        style: text.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              color: AppPalette.inkFaint, size: 22),
        ],
      ),
    );
  }
}
