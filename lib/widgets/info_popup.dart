import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/popup.dart';
import '../repositories/popup_repository.dart';
import '../theme.dart';

/// Pop-ups déjà affichés depuis le lancement : équivalent du sessionStorage
/// du site web pour la fréquence « une fois par visite ».
final Set<String> _shownThisSession = {};

/// Récupère le pop-up diffusé par la clinique et l'affiche si sa fréquence
/// l'autorise (mêmes règles que la page d'accueil du site web).
///
/// Toute erreur est silencieuse : le pop-up est un contenu d'appoint, il ne
/// doit jamais gêner l'entrée dans l'application.
Future<void> maybeShowInfoPopup(
  BuildContext context,
  PopupRepository repository,
) async {
  try {
    final popup = await repository.current();
    if (popup == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (_alreadySeen(popup, prefs)) return;

    if (popup.delaySeconds > 0) {
      await Future<void>.delayed(Duration(seconds: popup.delaySeconds));
    }
    if (!context.mounted) return;

    // Mémorisé à l'affichage, comme sur le site web
    await _remember(popup, prefs);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _InfoPopupDialog(popup: popup),
    );
  } catch (_) {
    // Réseau ou stockage indisponible : l'application démarre sans pop-up
  }
}

/// Date du jour au format Y-m-d, pour la fréquence quotidienne.
String _today() => DateTime.now().toIso8601String().substring(0, 10);

/// Nombre d'affichages déjà faits aujourd'hui : la valeur mémorisée est
/// « date|compteur » (une simple date vaut 1 affichage).
int _dailyViewsToday(String? stored) {
  final parts = (stored ?? '').split('|');
  if (parts.first != _today()) return 0;
  return parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
}

bool _alreadySeen(Popup popup, SharedPreferences prefs) {
  return switch (popup.frequency) {
    'always' => false,
    'session' => _shownThisSession.contains(popup.storageKey),
    'daily' => _dailyViewsToday(prefs.getString(popup.storageKey)) >=
        popup.dailyDisplayLimit,
    // « once » : jamais réaffiché tant que le pop-up n'est pas modifié
    _ => prefs.getString(popup.storageKey) != null,
  };
}

Future<void> _remember(Popup popup, SharedPreferences prefs) async {
  _shownThisSession.add(popup.storageKey);

  if (popup.frequency == 'daily') {
    final views = _dailyViewsToday(prefs.getString(popup.storageKey));
    await prefs.setString(popup.storageKey, '${_today()}|${views + 1}');
  } else if (popup.frequency != 'always' && popup.frequency != 'session') {
    await prefs.setString(popup.storageKey, _today());
  }

  // Purge les clés des versions précédentes de ce pop-up
  for (final storedKey in prefs.getKeys()) {
    if (storedKey != popup.storageKey &&
        storedKey.startsWith(popup.storagePrefix)) {
      await prefs.remove(storedKey);
    }
  }
}

/// Carte du pop-up : illustration pleine largeur, titre, message et bouton
/// d'action facultatif, dans le style des cartes de l'application.
class _InfoPopupDialog extends StatelessWidget {
  const _InfoPopupDialog({required this.popup});

  final Popup popup;

  Future<void> _openButtonUrl(BuildContext context) async {
    final uri = Uri.tryParse(popup.buttonUrl ?? '');
    // Seules les adresses web sont ouvertes : l'URL vient de l'administration
    // mais on refuse tout autre schéma (tel:, intent:…) par prudence.
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = popup.plainContent;
    final hasButton = (popup.buttonText ?? '').isNotEmpty &&
        (popup.buttonUrl ?? '').isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.page),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (popup.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: popup.imageUrl!,
                      width: double.infinity,
                      // L'image est affichée en entier : la hauteur suit ses
                      // proportions naturelles, comme sur le site web
                      fit: BoxFit.fitWidth,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      children: [
                        Text(
                          popup.title,
                          textAlign: TextAlign.center,
                          style: text.headlineSmall,
                        ),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.gap),
                          Text(
                            content,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(height: 1.6),
                          ),
                        ],
                        if (hasButton) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => _openButtonUrl(context),
                              child: Text(popup.buttonText!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bouton de fermeture par-dessus l'illustration
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: AppPalette.shadow.withValues(alpha: .4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: AppPalette.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
