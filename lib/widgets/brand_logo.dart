import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/branding_state.dart';

/// Logo de la clinique, tel que téléversé dans « Paramètres du site ».
///
/// Le logo embarqué dans l'application sert de repli : il s'affiche pendant le
/// téléchargement, au tout premier lancement hors ligne, et si la clinique n'a
/// jamais téléversé de logo.
///
/// La hauteur réglée par l'administrateur (celle du site sur petit écran)
/// prime sur celle du widget : le logo garde la même allure sur le site et
/// dans l'application.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width, this.height, this.onDark = false});

  final double? width;
  final double? height;

  /// Version claire du logo, destinée aux fonds sombres (écran de démarrage).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<BrandingState>().branding;
    final url = onDark ? branding?.logoDarkUrl : branding?.logoUrl;
    final height = (onDark ? branding?.logoDarkHeight : branding?.logoHeight) ??
        this.height;

    final fallback = Image.asset(
      onDark ? 'assets/images/logo_white.png' : 'assets/images/logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );

    if (url == null) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
