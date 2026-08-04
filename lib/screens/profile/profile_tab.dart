import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/auth_state.dart';
import '../../theme.dart';
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
        content: const Text(
            'Vous devrez vous reconnecter pour accéder à vos rendez-vous.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester connecté'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: AppPalette.danger,
            ),
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
      body: SafeArea(
        bottom: false,
        child: FadeSlideIn(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, 8, AppSpacing.page, AppSpacing.page),
            children: [
              _ProfileHeader(name: user.name, email: user.email),
              const SizedBox(height: 28),
              const SectionHeader(title: 'Mes informations'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Téléphone',
                      value: user.phone ?? 'Non renseigné',
                    ),
                    if (user.patient != null) ...[
                      const _TileDivider(),
                      _InfoTile(
                        icon: Icons.wc_outlined,
                        label: 'Sexe',
                        value: user.patient!.genderLabel,
                      ),
                      const _TileDivider(),
                      _InfoTile(
                        icon: Icons.cake_outlined,
                        label: 'Date de naissance',
                        value: birthDateLabel ?? 'Non renseignée',
                      ),
                      const _TileDivider(),
                      _InfoTile(
                        icon: Icons.home_outlined,
                        label: 'Adresse',
                        value: user.patient!.address ?? 'Non renseignée',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Mon compte'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    if (user.isPatient) ...[
                      _ActionTile(
                        icon: Icons.folder_shared_outlined,
                        label: 'Mon dossier médical',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicalRecordScreen.mine(),
                          ),
                        ),
                      ),
                      const _TileDivider(),
                    ],
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Modifier mon profil',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                    const _TileDivider(),
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      label: 'Se déconnecter',
                      tint: AppPalette.danger,
                      busy: _loggingOut,
                      onTap: _loggingOut ? null : _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// En-tête du profil : initiale sur un disque teinté, nom et adresse e-mail.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppPalette.primary, AppPalette.primaryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: AppShadows.brand,
          ),
          child: Text(
            name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
            style: text.headlineMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.gutter),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: text.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filet de séparation entre deux lignes d'une carte, aligné sur le texte.
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 58, endIndent: 16);
}

/// Ligne d'information : libellé discret au-dessus de la valeur.
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
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppPalette.inkFaint),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne d'action avec chevron, ou indicateur de progression si occupée.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Couleur de l'icône ; la couleur de marque par défaut.
  final Color? tint;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = this.tint ?? AppPalette.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: busy
                  ? CircularProgressIndicator(strokeWidth: 2, color: tint)
                  : Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Text(
                label,
                style: text.bodyLarge?.copyWith(
                  color: tint == AppPalette.danger ? tint : AppPalette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppPalette.inkFaint),
          ],
        ),
      ),
    );
  }
}
