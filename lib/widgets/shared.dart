import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../models/specialty.dart';
import '../theme.dart';

/// Abréviation du mois en français sans point final, ex. « août », « janv ».
String monthShort(DateTime date) =>
    DateFormat('MMM', 'fr_FR').format(date).replaceAll('.', '');

/// Fait apparaître son enfant en fondu avec un léger glissement vers le haut.
///
/// Utilisé pour animer l'arrivée des cartes et du contenu dans toute l'app ;
/// [delay] permet de décaler les éléments d'une liste (effet cascade).
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Pastille ronde affichant l'emoji d'une spécialité.
class SpecialtyAvatar extends StatelessWidget {
  const SpecialtyAvatar({super.key, required this.specialty, this.radius = 22});

  final Specialty specialty;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        specialtyEmoji(specialty),
        style: TextStyle(fontSize: radius * .9),
      ),
    );
  }
}

/// Carte du système de design : fond blanc, coins arrondis, ombre douce.
///
/// Remplace `Card` là où il faut une ombre portée ; le `Card` de Material
/// reste utilisé pour les surfaces simplement délimitées par un filet.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.gutter),
    this.onTap,
    this.color = Colors.white,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: border ?? Border.all(color: AppPalette.hairline),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          // Sans écrêtage, l'onde de l'InkWell déborderait des coins arrondis.
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Intitulé de section : capitales espacées, avec une action facultative
/// alignée à droite (« Voir tout »).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gap),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelMedium,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Puce de filtre en pilule : pleine quand active, bordée sinon.
///
/// Un `FilterChip` de Material demande une demi-douzaine de surcharges pour
/// obtenir ce contraste ; le composant est donc écrit directement, et partagé
/// par les écrans Médecins, Rendez-vous et Actualités.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Contenu accolé au libellé, par exemple un compteur.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);

    return Material(
      color: selected ? AppPalette.primary : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppPalette.primary : AppPalette.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : AppPalette.inkMuted,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 7),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloc gris animé qui figure un contenu en cours de chargement.
///
/// Un squelette à la forme du contenu attendu se lit comme une page qui se
/// remplit, là où un rond de progression centré donne l'impression d'un écran
/// bloqué.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppPalette.hairline,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Liste de cartes en squelette, pour les écrans qui chargent une liste.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 4,
    this.height = 96,
    this.padding = const EdgeInsets.all(AppSpacing.page),
  });

  final int count;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gap),
      itemBuilder: (_, _) => SkeletonBox(
        height: height,
        radius: AppRadius.card,
      ),
    );
  }
}

/// Emoji représentant une spécialité médicale.
///
/// Le backend renvoie des classes Flaticon (`flaticon-…`) dont la police
/// n'est pas embarquée dans l'app : on associe donc chaque spécialité à un
/// emoji via son slug, avec un repli sur le nom Flaticon pour les
/// spécialités ajoutées côté backend sans correspondance ici.
String specialtyEmoji(Specialty specialty) {
  final bySlug = switch (specialty.slug) {
    'medecine-generale' => '🩺',
    'cardiologie' => '🫀',
    'pediatrie' => '👶',
    'gynecologie-obstetrique' => '🤰',
    'circoncision' => '🩹',
    'orl' => '👂',
    'dermatologie' => '🧴',
    'hematologie' => '🩸',
    'neurologie' => '🧠',
    'psychiatrie' => '🧘',
    'nutritionniste' => '🥗',
    'rhumatologie' => '🦴',
    'urologie' => '💧',
    'traumatologie-orthopedie' => '🦵',
    'endocrinologie' => '🧪',
    'diabetologie' => '💉',
    'kinesitherapie' => '💪',
    'odonto-stomatologie' => '🦷',
    'pneumologie' => '🫁',
    'hepato-gastrologie' => '💊',
    'enterologie' => '💊',
    'infectiologie' => '🦠',
    'cancerologie' => '🎗️',
    'chirurgie-generale' => '😷',
    'chirurgie-specialisee' => '🏥',
    _ => null,
  };
  if (bySlug != null) return bySlug;

  return switch (specialty.icon) {
    'flaticon-stethoscope' => '🩺',
    'flaticon-cardiogram' => '🫀',
    'flaticon-pediatrics' => '👶',
    'flaticon-doctor' => '🧑‍⚕️',
    'flaticon-first-aid-kit' => '🩹',
    'flaticon-first-aid-kit-1' => '🏥',
    'flaticon-healthcare' => '🏥',
    'flaticon-health-check' => '📋',
    'flaticon-blood-tube' => '🩸',
    'flaticon-human-brain' => '🧠',
    'flaticon-mental-disorder' => '🧘',
    'flaticon-treatment-plan' => '📋',
    'flaticon-tooth' => '🦷',
    'flaticon-injection' => '💉',
    'flaticon-diagnostic-report' => '📋',
    'flaticon-liver' => '💊',
    _ => '🩺',
  };
}

/// Message d'erreur lisible pour n'importe quelle exception.
String errorMessage(Object error) {
  if (error is ApiException) return error.displayMessage;
  if (error is NetworkException) return error.toString();
  // Message déjà rédigé pour l'utilisateur, passé tel quel par l'appelant.
  if (error is String) return error;
  return 'Une erreur inattendue est survenue.';
}

/// Bandeau flottant, base commune aux messages d'erreur et de succès.
void _showBanner(
  BuildContext context, {
  required String message,
  required IconData icon,
  required Color color,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      // L'icône colorée porte le statut : le fond reste sombre et neutre, ce
      // qui évite les grands aplats rouges ou verts en bas d'écran.
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.gap),
          Expanded(child: Text(message)),
        ],
      ),
    ));
}

/// Affiche l'erreur dans un bandeau.
void showError(BuildContext context, Object error) => _showBanner(
      context,
      message: errorMessage(error),
      icon: Icons.error_outline_rounded,
      color: AppPalette.danger,
    );

/// Affiche un message de succès dans un bandeau.
void showSuccess(BuildContext context, String message) => _showBanner(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      color: AppPalette.accent,
    );

/// Mise en page commune aux états sans contenu : une icône posée dans un
/// disque teinté, un titre, un texte d'explication et une action facultative.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.tint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: tint),
            ),
            const SizedBox(height: AppSpacing.page),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.page),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Vue d'erreur pleine page avec bouton « Réessayer ».
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final network = error is NetworkException;

    return _StateView(
      icon: network ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: network ? 'Connexion interrompue' : 'Une erreur est survenue',
      message: errorMessage(error),
      tint: AppPalette.danger,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        ),
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text('Réessayer'),
      ),
    );
  }
}

/// Vue vide (aucune donnée) avec icône et message.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.message,
    this.title = 'Rien à afficher',
    this.action,
  });

  final IconData icon;
  final String message;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: icon,
      title: title,
      message: message,
      tint: AppPalette.primary,
      action: action,
    );
  }
}

/// Image réseau avec repli élégant en cas d'échec.
class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: AppPalette.primarySoft,
      child: Icon(fallbackIcon,
          color: AppPalette.primary.withValues(alpha: .55), size: 28),
    );

    final image = url == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: fit,
            // Décodage à la taille d'affichage : une photo pleine résolution
            // gardée en mémoire pour une vignette sature le cache de Flutter,
            // qui évince alors les images et les recharge au moindre scroll.
            memCacheWidth: _decodeWidth(context),
            // Fondu court : la photo remplace le repli sans à-coup.
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  /// Largeur de décodage, en pixels physiques.
  ///
  /// Seule la largeur est transmise au décodeur : donner aussi la hauteur
  /// étirerait l'image pour remplir exactement la cible. La hauteur suit donc
  /// le rapport d'origine, ce qui couvre le recadrage `BoxFit.cover` des
  /// bandeaux pleine largeur.
  int _decodeWidth(BuildContext context) {
    final box = width;
    // Boîte extensible (`double.infinity`) : la largeur de l'écran est le
    // maximum que l'image occupera jamais.
    final logical = (box == null || !box.isFinite)
        ? MediaQuery.sizeOf(context).width
        : box;
    return (logical * MediaQuery.devicePixelRatioOf(context)).round();
  }
}

/// Barre de pages numérotée (« ◀ 1 … 4 5 6 … 9 ▶ ») placée sous les listes
/// paginées, comme sur le site web. Masquée quand tout tient sur une page.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.lastPage,
    required this.onPageSelected,
    this.enabled = true,
  });

  final int currentPage;
  final int lastPage;
  final ValueChanged<int> onPageSelected;

  /// Boutons inertes pendant un chargement.
  final bool enabled;

  /// Pages à afficher, `null` figurant une ellipse : la première, la dernière
  /// et les voisines de la page courante.
  List<int?> get _pages {
    if (lastPage <= 5) return [for (var i = 1; i <= lastPage; i++) i];
    return [
      1,
      if (currentPage > 3) null,
      for (var i = currentPage - 1; i <= currentPage + 1; i++)
        if (i > 1 && i < lastPage) i,
      if (currentPage < lastPage - 2) null,
      lastPage,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (lastPage <= 1) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        _PageButton(
          icon: Icons.chevron_left_rounded,
          onTap: enabled && currentPage > 1
              ? () => onPageSelected(currentPage - 1)
              : null,
        ),
        for (final page in _pages)
          if (page == null)
            SizedBox(
              width: 24,
              child: Text(
                '…',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.inkFaint),
              ),
            )
          else
            _PageButton(
              label: '$page',
              selected: page == currentPage,
              onTap: enabled && page != currentPage
                  ? () => onPageSelected(page)
                  : null,
            ),
        _PageButton(
          icon: Icons.chevron_right_rounded,
          onTap: enabled && currentPage < lastPage
              ? () => onPageSelected(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}

/// Bouton d'une page (numéro ou chevron) de la [PaginationBar].
class _PageButton extends StatelessWidget {
  const _PageButton({this.label, this.icon, this.selected = false, this.onTap});

  final String? label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !selected;
    final radius = BorderRadius.circular(AppRadius.control);

    return Material(
      color: selected ? AppPalette.primary : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppPalette.primary
                  : disabled
                      ? AppPalette.hairline
                      : AppPalette.border,
            ),
          ),
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: disabled ? AppPalette.inkFaint : AppPalette.ink,
                  )
                : Text(
                    label!,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : AppPalette.inkMuted,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
