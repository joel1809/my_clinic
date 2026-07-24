import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/doctor.dart';
import '../../models/specialty.dart';
import '../../repositories/catalog_repository.dart';
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
      appBar: AppBar(title: const Text('Nos médecins')),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Rechercher un médecin…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
            ),
          ),
          // Filtre par spécialité
          SizedBox(
            height: 56,
            child: FutureBuilder<List<Specialty>>(
              future: _specialtiesFuture,
              builder: (context, snapshot) {
                final specialties = snapshot.data ?? const <Specialty>[];
                if (specialties.isEmpty) return const SizedBox.shrink();

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Toutes'),
                        selected: _selected == null,
                        onSelected: (_) => _selectSpecialty(null),
                      ),
                    ),
                    for (final specialty in specialties)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(specialty.name),
                          selected: _selected?.id == specialty.id,
                          onSelected: (_) => _selectSpecialty(specialty),
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
                  return const Center(child: CircularProgressIndicator());
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
                    message: _search.trim().isEmpty
                        ? 'Aucun médecin disponible pour cette spécialité.'
                        : 'Aucun médecin ne correspond à « ${_search.trim()} ».',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoctorDetailScreen(doctorId: doctor.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              NetworkImageBox(
                url: doctor.photoUrl,
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(14),
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    if (doctor.specialty != null)
                      Text(
                        doctor.specialty!.name,
                        style: TextStyle(
                            color: scheme.primary, fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Consultation : ${doctor.appointmentDuration} min',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
