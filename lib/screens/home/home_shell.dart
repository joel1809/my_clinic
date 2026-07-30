import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/popup_repository.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
import '../../widgets/info_popup.dart';
import '../appointments/appointments_tab.dart';
import '../articles/articles_tab.dart';
import '../profile/profile_tab.dart';
import '../schedule/schedules_tab.dart';
import 'home_tab.dart';

/// Structure principale : navigation par onglets.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  // Fondu de l'onglet entrant ; l'IndexedStack conserve l'état de chaque onglet.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    // Pop-up informationnel de la clinique, comme sur la page d'accueil du
    // site web : affiché une fois l'écran en place, selon sa fréquence.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        maybeShowInfoPopup(context, context.read<PopupRepository>());
      }
    });
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le personnel (médecin/admin) n'a pas l'onglet Accueil (réservation) :
    // il gère les rendez-vous de ses patients. Le médecin gère en plus
    // ses plages de disponibilité (onglet Créneaux).
    final user = context.watch<AuthState>().user;
    final isStaff = user?.isStaff ?? false;
    final isDoctor = user?.isDoctor ?? false;

    final tabs = isStaff
        ? [
            const AppointmentsTab(),
            if (isDoctor) const SchedulesTab(),
            const ArticlesTab(),
            const ProfileTab(),
          ]
        : const [HomeTab(), AppointmentsTab(), ArticlesTab(), ProfileTab()];
    final items = isStaff
        ? [
            (Icons.event_note_outlined, Icons.event_note_rounded,
                'Rendez-vous'),
            if (isDoctor)
              (Icons.edit_calendar_outlined, Icons.edit_calendar_rounded,
                  'Créneaux'),
            (Icons.article_outlined, Icons.article_rounded, 'Actualités'),
            (Icons.person_outline, Icons.person_rounded, 'Profil'),
          ]
        : const [
            (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
            (Icons.event_note_outlined, Icons.event_note_rounded,
                'Rendez-vous'),
            (Icons.article_outlined, Icons.article_rounded, 'Actualités'),
            (Icons.person_outline, Icons.person_rounded, 'Profil'),
          ];

    final index = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: IndexedStack(
          index: index,
          children: tabs,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: _FloatingNavBar(
        index: index,
        items: items,
        onSelected: _select,
      ),
    );
  }
}

/// Barre de navigation flottante : pastille animée sur l'onglet actif.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.index,
    required this.items,
    required this.onSelected,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Marge ajoutée à la zone système (boutons ou geste de navigation) et non
    // fusionnée avec elle : la barre flottante garde toujours un espace visible
    // au-dessus de la navigation du téléphone.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, bottomInset + 12),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          border: Border.all(color: AppPalette.hairline),
          boxShadow: AppShadows.raised,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 5 : 3,
                child: _NavItem(
                  icon: items[i].$1,
                  selectedIcon: items[i].$2,
                  label: items[i].$3,
                  selected: i == index,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppPalette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 23,
              color: selected ? Colors.white : AppPalette.inkFaint,
            ),
            if (selected) ...[
              const SizedBox(width: 7),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
