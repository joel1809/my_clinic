import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../widgets/shared.dart';
import '../medical/medical_record_screen.dart';
import 'edit_profile_screen.dart';

/// Profil de l'utilisateur connecté : informations et déconnexion.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content:
            const Text('Vous devrez vous reconnecter pour accéder à vos rendez-vous.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester connecté'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await context.read<AuthState>().logout();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String? birthDateLabel;
    if (user.patient?.birthDate != null) {
      final date = DateTime.tryParse(user.patient!.birthDate!);
      if (date != null) {
        birthDateLabel = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: FadeSlideIn(
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.trim()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Informations
          Card(
            color: Colors.white,
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  value: user.phone ?? 'Non renseigné',
                ),
                if (user.patient != null) ...[
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.wc_outlined,
                    label: 'Sexe',
                    value: user.patient!.genderLabel,
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Date de naissance',
                    value: birthDateLabel ?? 'Non renseignée',
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoTile(
                    icon: Icons.home_outlined,
                    label: 'Adresse',
                    value: user.patient!.address ?? 'Non renseignée',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            child: Column(
              children: [
                if (user.isPatient) ...[
                  ListTile(
                    leading: Icon(Icons.folder_shared_outlined,
                        color: scheme.primary),
                    title: const Text('Mon dossier médical'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MedicalRecordScreen.mine(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                ],
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: scheme.primary),
                  title: const Text('Modifier mon profil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: _loggingOut
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.logout, color: scheme.error),
                  title: Text(
                    'Se déconnecter',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: _loggingOut ? null : _logout,
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}
