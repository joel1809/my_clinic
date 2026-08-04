import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session_store.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/article_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/branding_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/medical_record_repository.dart';
import 'repositories/popup_repository.dart';
import 'repositories/schedule_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'state/auth_state.dart';
import 'state/branding_state.dart';
import 'theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  // Affichage bord à bord : le contenu s'étend sous la barre d'état et sous la
  // barre de navigation du téléphone, qui deviennent transparentes au lieu de
  // fermer l'écran par deux bandes opaques. Les écrans gardent leurs marges
  // grâce aux encarts système (SafeArea, MediaQuery.paddingOf).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final api = ApiClient();
  final store = SessionStore();
  final authRepository = AuthRepository(api);

  // Identité visuelle de la clinique : la dernière connue est relue avant le
  // premier rendu, pour que l'écran de démarrage porte déjà ses couleurs et
  // son logo. La revalidation auprès de l'API se fait ensuite (voir
  // `_RootGate`), sans retarder l'affichage.
  final brandingState = BrandingState(BrandingRepository(api));
  await brandingState.loadCached();

  runApp(MyClinicApp(
    authState: AuthState(api: api, repository: authRepository, store: store),
    brandingState: brandingState,
    catalogRepository: CatalogRepository(api),
    appointmentRepository: AppointmentRepository(api),
    articleRepository: ArticleRepository(api),
    medicalRecordRepository: MedicalRecordRepository(api),
    scheduleRepository: ScheduleRepository(api),
    popupRepository: PopupRepository(api),
  ));
}

class MyClinicApp extends StatelessWidget {
  const MyClinicApp({
    super.key,
    required this.authState,
    required this.brandingState,
    required this.catalogRepository,
    required this.appointmentRepository,
    required this.articleRepository,
    required this.medicalRecordRepository,
    required this.scheduleRepository,
    required this.popupRepository,
  });

  final AuthState authState;
  final BrandingState brandingState;
  final CatalogRepository catalogRepository;
  final AppointmentRepository appointmentRepository;
  final ArticleRepository articleRepository;
  final MedicalRecordRepository medicalRecordRepository;
  final ScheduleRepository scheduleRepository;
  final PopupRepository popupRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        ChangeNotifierProvider.value(value: brandingState),
        Provider.value(value: catalogRepository),
        Provider.value(value: appointmentRepository),
        Provider.value(value: articleRepository),
        Provider.value(value: medicalRecordRepository),
        Provider.value(value: scheduleRepository),
        Provider.value(value: popupRepository),
      ],
      child: Consumer<BrandingState>(
        // La charte du site pilote les couleurs du système de design, que les
        // écrans lisent dans `AppPalette` : changer de charte demande donc de
        // reconstruire l'arbre entier, d'où la clé portée par l'application.
        // Cela n'arrive qu'au premier lancement et après une modification
        // faite par l'administrateur.
        builder: (context, branding, _) => MaterialApp(
          key: ValueKey(branding.version),
          title: branding.siteName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const _RootGate(),
        ),
      ),
    );
  }
}

/// Aiguille vers l'accueil ou la connexion selon la session restaurée.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  @override
  void initState() {
    super.initState();
    // Restaure le token enregistré puis charge le profil
    context.read<AuthState>().restore();
    // Revalide l'identité visuelle : l'API répond 304 tant que la clinique
    // n'a changé ni son logo ni ses couleurs.
    context.read<BrandingState>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthState>().status;

    // Fondu entre splash, connexion et accueil quand la session change
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: switch (status) {
        AuthStatus.unknown => const _SplashScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
        AuthStatus.authenticated => const HomeShell(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Dégradé de marque plutôt qu'un aplat : l'écran d'attente donne déjà
      // le ton du reste de l'application.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo clair de la clinique, lisible sur le fond de marque
              const BrandLogo(width: 200, onDark: true),
              const SizedBox(height: 36),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
