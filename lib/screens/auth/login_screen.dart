import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/shared.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Connexion d'un patient (e-mail + mot de passe).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  Map<String, List<String>> _apiErrors = const {};

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _apiErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthState>().login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // La navigation est gérée par _RootGate quand l'état change
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _apiErrors = e.errors);
      if (e.errors.isEmpty) showError(context, e);
      _formKey.currentState!.validate();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ouvre le parcours « mot de passe oublié » (code reçu par e-mail, saisi
  /// dans l'application) et pré-remplit l'adresse déjà tapée ici.
  ///
  /// Au retour d'une réinitialisation réussie, l'adresse traitée revient : le
  /// patient n'a plus qu'à saisir son nouveau mot de passe.
  Future<void> _openPasswordReset() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
    if (email == null || !mounted) return;

    setState(() {
      _apiErrors = const {};
      _emailController.text = email;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeSlideIn(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo de la clinique, tel qu'administré sur le site
                      const BrandLogo(height: 104),
                      const SizedBox(height: 56),
                      Text(
                        'Bon retour',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connectez-vous pour prendre rendez-vous et suivre vos consultations.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (value) {
                          final apiError = _apiErrors['email']?.firstOrNull;
                          if (apiError != null) return apiError;
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez indiquer votre adresse e-mail.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                        validator: (value) {
                          final apiError = _apiErrors['password']?.firstOrNull;
                          if (apiError != null) return apiError;
                          if (value == null || value.isEmpty) {
                            return 'Veuillez indiquer votre mot de passe.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      // Réinitialisation : le parcours se poursuit sur le
                      // site, qui envoie l'e-mail et reçoit le lien.
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _openPasswordReset,
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                      const SizedBox(height: AppSpacing.page),
                      // Séparateur discret avant l'action secondaire : la page
                      // se lit en deux temps, se connecter puis s'inscrire.
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.page),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                        child: const Text('Créer un compte'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
