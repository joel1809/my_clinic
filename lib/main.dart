import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session_store.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/article_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/medical_record_repository.dart';
import 'repositories/schedule_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'state/auth_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  final api = ApiClient();
  final store = SessionStore();
  final authRepository = AuthRepository(api);

  runApp(MyClinicApp(
    authState: AuthState(api: api, repository: authRepository, store: store),
    catalogRepository: CatalogRepository(api),
    appointmentRepository: AppointmentRepository(api),
    articleRepository: ArticleRepository(api),
    medicalRecordRepository: MedicalRecordRepository(api),
    scheduleRepository: ScheduleRepository(api),
  ));
}

class MyClinicApp extends StatelessWidget {
  const MyClinicApp({
    super.key,
    required this.authState,
    required this.catalogRepository,
    required this.appointmentRepository,
    required this.articleRepository,
    required this.medicalRecordRepository,
    required this.scheduleRepository,
  });

  final AuthState authState;
  final CatalogRepository catalogRepository;
  final AppointmentRepository appointmentRepository;
  final ArticleRepository articleRepository;
  final MedicalRecordRepository medicalRecordRepository;
  final ScheduleRepository scheduleRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        Provider.value(value: catalogRepository),
        Provider.value(value: appointmentRepository),
        Provider.value(value: articleRepository),
        Provider.value(value: medicalRecordRepository),
        Provider.value(value: scheduleRepository),
      ],
      child: MaterialApp(
        title: 'Medolia',
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo blanc du site web, lisible sur le fond bleu primaire
            Image.asset(
              'assets/images/logo_white.png',
              width: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: scheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
