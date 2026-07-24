import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../models/specialty.dart';

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
  const SpecialtyAvatar({super.key, required this.specialty, this.radius = 20});

  final Specialty specialty;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        specialtyEmoji(specialty),
        style: TextStyle(fontSize: radius * .95),
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
  return 'Une erreur inattendue est survenue.';
}

/// Affiche l'erreur dans une SnackBar.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(errorMessage(error)),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
}

/// Affiche un message de succès dans une SnackBar.
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
    ));
}

/// Vue d'erreur pleine page avec bouton « Réessayer ».
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vue vide (aucune donnée) avec icône et message.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
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
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .4),
      child: Icon(fallbackIcon,
          color: Theme.of(context).colorScheme.primary, size: 32),
    );

    final image = url == null
        ? fallback
        : Image.network(
            url!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback,
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
