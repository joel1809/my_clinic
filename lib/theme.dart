import 'package:flutter/material.dart';

/// Système de design Medolia : « clinique lumineuse ».
///
/// Blanc dominant, ombres douces et étagées, bleu Medolia réservé aux accents,
/// et une échelle typographique construite sur Inter. Les écrans puisent leurs
/// couleurs et leurs styles ici plutôt que de les redéfinir localement.
///
/// Couleur de marque reprise du site web (--primary-color: #4F6BD6).
ThemeData buildTheme() {
  final seed = AppPalette.primary;

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    // Surfaces neutres et lumineuses : la teinte bleutée que Material 3
    // applique par défaut aux surfaces grisait les cartes.
    surface: Colors.white,
    surfaceTint: Colors.transparent,
  ).copyWith(
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    secondary: AppPalette.accent,
    error: AppPalette.danger,
  );

  final text = _buildTextTheme();

  OutlineInputBorder border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    textTheme: text,
    scaffoldBackgroundColor: AppPalette.canvas,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      // L'en-tête se fond dans le fond de page : la séparation vient de
      // l'ombre qui apparaît au défilement, pas d'un aplat différent.
      backgroundColor: AppPalette.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppPalette.shadow,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: AppPalette.ink, size: 22),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Filet très clair : donne un bord net aux cartes sur fond blanc, là
        // où l'ombre seule ne suffit pas.
        side: const BorderSide(color: AppPalette.hairline),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppPalette.hairline,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(AppPalette.border),
      enabledBorder: border(AppPalette.border),
      focusedBorder: border(scheme.primary, width: 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 1.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: text.bodyMedium?.copyWith(color: AppPalette.inkFaint),
      labelStyle: text.bodyMedium?.copyWith(color: AppPalette.inkMuted),
      prefixIconColor: AppPalette.inkMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        side: const BorderSide(color: AppPalette.border),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: text.labelLarge,
        foregroundColor: scheme.primary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      insetPadding: const EdgeInsets.all(16),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppPalette.border),
      labelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: AppPalette.inkMuted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      strokeWidth: 2.5,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
  );
}

/// Échelle typographique.
///
/// Inter est dessiné pour les interfaces : resserrer l'espacement des grands
/// titres et aérer les petits libellés est ce qui fait la différence entre un
/// rendu « par défaut » et un rendu soigné.
TextTheme _buildTextTheme() {
  const family = 'Inter';

  TextStyle style({
    required double size,
    required FontWeight weight,
    required double height,
    double spacing = 0,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        // Texte principal par défaut, dans la couleur des titres du site.
        color: color ?? AppPalette.ink,
      );

  return TextTheme(
    // Titres de page et chiffres mis en avant : graisse forte, interlignes
    // serrés, léger resserrement des lettres.
    displaySmall:
        style(size: 32, weight: FontWeight.w700, height: 1.15, spacing: -.8),
    headlineMedium:
        style(size: 26, weight: FontWeight.w700, height: 1.2, spacing: -.6),
    headlineSmall:
        style(size: 22, weight: FontWeight.w700, height: 1.25, spacing: -.4),
    titleLarge:
        style(size: 18, weight: FontWeight.w600, height: 1.3, spacing: -.2),
    titleMedium:
        style(size: 16, weight: FontWeight.w600, height: 1.35, spacing: -.1),
    titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.4),
    // Textes courants : interligne généreux pour la lisibilité des paragraphes.
    bodyLarge: style(size: 15, weight: FontWeight.w400, height: 1.5),
    bodyMedium: style(
        size: 14,
        weight: FontWeight.w400,
        height: 1.5,
        color: AppPalette.inkMuted),
    bodySmall: style(
        size: 12.5,
        weight: FontWeight.w400,
        height: 1.45,
        color: AppPalette.inkMuted),
    // Libellés de boutons et d'onglets.
    labelLarge: style(size: 15, weight: FontWeight.w600, height: 1.2),
    labelMedium: style(size: 13, weight: FontWeight.w500, height: 1.2),
    // Intitulés de section en capitales : très espacés, jamais en gras plein.
    labelSmall: style(
      size: 11.5,
      weight: FontWeight.w600,
      height: 1.2,
      spacing: 1.1,
      color: AppPalette.inkFaint,
    ),
  );
}

/// Couleurs du système de design.
///
/// Les couleurs de marque (bleu primaire, couleurs de texte) sont celles que
/// l'administrateur choisit dans « Paramètres du site » : l'API `/branding`
/// les renvoie au démarrage et [applyBrand] les installe ici, pour que toute
/// l'application suive la charte du site. Les valeurs par défaut ci-dessous
/// restent en place tant qu'aucune charte n'a été reçue.
abstract final class AppPalette {
  /// Bleu de marque par défaut, repris du site web.
  static const defaultPrimary = Color(0xFF4F6BD6);
  static const _defaultPrimaryDeep = Color(0xFF3A50AC);
  static const _defaultPrimarySoft = Color(0xFFEEF1FC);

  /// Texte principal par défaut : un bleu-noir plutôt qu'un noir pur, moins
  /// dur à l'œil.
  static const defaultInk = Color(0xFF141A2E);

  /// Texte secondaire par défaut.
  static const defaultInkMuted = Color(0xFF5C6480);
  static const _defaultInkFaint = Color(0xFF98A0B8);

  static Color _primary = defaultPrimary;
  static Color _primaryDeep = _defaultPrimaryDeep;
  static Color _primarySoft = _defaultPrimarySoft;
  static Color _ink = defaultInk;
  static Color _inkMuted = defaultInkMuted;
  static Color _inkFaint = _defaultInkFaint;

  /// Couleur de marque.
  static Color get primary => _primary;

  /// Variante sombre, pour les dégradés et les états pressés.
  static Color get primaryDeep => _primaryDeep;

  /// Fond très clair des zones teintées (bandeaux, pastilles).
  static Color get primarySoft => _primarySoft;

  /// Accent secondaire, réservé aux confirmations et aux illustrations.
  static const accent = Color(0xFF2BB3A3);

  /// Fond de page : un blanc cassé légèrement froid qui fait ressortir les
  /// cartes blanches sans les faire flotter.
  static const canvas = Color(0xFFF6F8FC);

  /// Texte principal.
  static Color get ink => _ink;

  /// Texte secondaire.
  static Color get inkMuted => _inkMuted;

  /// Texte tertiaire : légendes, intitulés de section.
  static Color get inkFaint => _inkFaint;

  /// Installe les couleurs de la charte du site.
  ///
  /// Les déclinaisons (variante sombre, fond teinté, texte tertiaire) sont
  /// dérivées de la couleur reçue : l'administrateur ne choisit que trois
  /// couleurs, mais l'interface en utilise davantage. Un paramètre `null`
  /// laisse la couleur par défaut du système de design.
  ///
  /// Les écrans lisent ces couleurs à la construction : appeler cette méthode
  /// suppose donc de reconstruire l'arbre (voir `MyClinicApp`).
  static void applyBrand({Color? primary, Color? heading, Color? text}) {
    _primary = primary ?? defaultPrimary;
    // Le bleu du site a des déclinaisons dessinées à la main : on ne les
    // recalcule que si l'administrateur a réellement choisi une autre couleur.
    final custom = _primary != defaultPrimary;
    _primaryDeep = custom ? _shade(_primary, .78) : _defaultPrimaryDeep;
    _primarySoft =
        custom ? Color.lerp(_primary, Colors.white, .92)! : _defaultPrimarySoft;

    _ink = heading ?? defaultInk;
    _inkMuted = text ?? defaultInkMuted;
    _inkFaint = text == null
        ? _defaultInkFaint
        : Color.lerp(_inkMuted, Colors.white, .45)!;
  }

  /// Éclaircit ou assombrit une couleur en conservant sa teinte.
  static Color _shade(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
  }

  /// Bordure des champs et des boutons secondaires.
  static const border = Color(0xFFDDE2EE);

  /// Filet des cartes, plus discret que [border].
  static const hairline = Color(0xFFEDF0F7);

  /// Base des ombres portées.
  static const shadow = Color(0xFF9CA7C4);

  static const success = Color(0xFF1E9E6A);
  static const warning = Color(0xFFE0921F);
  static const danger = Color(0xFFD64545);
}

/// Rayons d'arrondi.
abstract final class AppRadius {
  static const card = 20.0;
  static const control = 14.0;
  static const field = 14.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

/// Rythme d'espacement et hauteurs de contrôles.
abstract final class AppSpacing {
  static const page = 20.0;
  static const gutter = 16.0;
  static const gap = 12.0;
  static const controlHeight = 52.0;
}

/// Ombres du système, du plus discret au plus marqué.
///
/// Deux couches à chaque niveau : un contact resserré et une diffusion large.
/// C'est ce qui donne une profondeur crédible plutôt qu'un halo gris.
abstract final class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppPalette.shadow.withValues(alpha: .10),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: AppPalette.shadow.withValues(alpha: .10),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppPalette.shadow.withValues(alpha: .12),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: AppPalette.shadow.withValues(alpha: .16),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Ombre colorée, pour les surfaces qui portent la couleur de marque.
  static List<BoxShadow> get brand => [
        BoxShadow(
          color: AppPalette.primary.withValues(alpha: .28),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}
