import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

/// Étape du parcours : demander le code, puis choisir le nouveau mot de passe.
enum _Step { request, confirm }

/// Mot de passe oublié : l'API envoie un code à six chiffres par e-mail, que
/// le patient recopie ici pour choisir un nouveau mot de passe.
///
/// Le parcours reste dans l'application (le site, lui, envoie un lien) : le
/// code se saisit à l'écran, sans passer par le navigateur.
///
/// Renvoie l'adresse traitée à l'écran de connexion, qui la pré-remplit.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  /// Adresse déjà saisie sur l'écran de connexion.
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController =
      TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  _Step _step = _Step.request;
  bool _obscure = true;
  bool _loading = false;
  Map<String, List<String>> _apiErrors = const {};

  /// Message renvoyé par l'API après l'envoi du code.
  String? _sentMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  String? _fieldError(String field) => _apiErrors[field]?.firstOrNull;

  /// Exécute un appel à l'API en gérant l'indicateur de chargement et les
  /// erreurs de validation, affichées sous les champs concernés.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _apiErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await action();
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

  /// Demande l'envoi d'un code, puis passe à sa saisie.
  Future<void> _sendCode() => _run(() async {
        final message = await context
            .read<AuthState>()
            .requestPasswordResetCode(email: _email);
        if (!mounted) return;
        setState(() {
          _sentMessage = message;
          _step = _Step.confirm;
        });
      });

  /// Fixe le nouveau mot de passe et revient à la connexion.
  Future<void> _resetPassword() => _run(() async {
        final message = await context.read<AuthState>().resetPassword(
              email: _email,
              code: _codeController.text.trim(),
              password: _passwordController.text,
              passwordConfirmation: _passwordConfirmationController.text,
            );
        if (!mounted) return;
        showSuccess(context, message);
        Navigator.of(context).pop(_email);
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
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
                      Text(
                        _step == _Step.request
                            ? 'Retrouver votre compte'
                            : 'Choisir un nouveau mot de passe',
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _step == _Step.request
                            ? 'Indiquez l\'adresse e-mail de votre compte : un code à six chiffres vous y sera envoyé.'
                            : 'Saisissez le code reçu par e-mail, puis votre nouveau mot de passe.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      ..._step == _Step.request
                          ? _requestFields()
                          : _confirmFields(text),
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

  /// Première étape : l'adresse du compte.
  List<Widget> _requestFields() => [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Adresse e-mail',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          validator: (value) {
            final apiError = _fieldError('email');
            if (apiError != null) return apiError;
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez indiquer votre adresse e-mail.';
            }
            if (!value.contains('@')) {
              return 'L\'adresse e-mail n\'est pas valide.';
            }
            return null;
          },
        ),
        const SizedBox(height: 28),
        _submitButton(label: 'Envoyer le code', onPressed: _sendCode),
      ];

  /// Seconde étape : le code reçu et le nouveau mot de passe.
  List<Widget> _confirmFields(TextTheme text) => [
        // Réponse de l'API : volontairement la même que l'adresse soit
        // inscrite ou non, d'où la formulation prudente.
        if (_sentMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.gap),
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    size: 20, color: AppPalette.primary),
                const SizedBox(width: AppSpacing.gap),
                Expanded(child: Text(_sentMessage!, style: text.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
        ],
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          autofillHints: const [AutofillHints.oneTimeCode],
          style: const TextStyle(fontSize: 22, letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: 'Code reçu par e-mail',
            prefixIcon: Icon(Icons.password_outlined),
            counterText: '',
          ),
          validator: (value) {
            final apiError = _fieldError('code');
            if (apiError != null) return apiError;
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez saisir le code reçu par e-mail.';
            }
            if (value.trim().length != 6) {
              return 'Le code de réinitialisation comporte six chiffres.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (value) {
            final apiError = _fieldError('password');
            if (apiError != null) return apiError;
            if (value == null || value.isEmpty) {
              return 'Veuillez choisir un mot de passe.';
            }
            if (value.length < 8) {
              return 'Le mot de passe doit contenir au moins 8 caractères.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordConfirmationController,
          obscureText: _obscure,
          decoration: const InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'La confirmation du mot de passe ne correspond pas.';
            }
            return null;
          },
        ),
        const SizedBox(height: 28),
        _submitButton(
          label: 'Réinitialiser le mot de passe',
          onPressed: _resetPassword,
        ),
        const SizedBox(height: 4),
        // Code jamais reçu, ou expiré (une heure) : on repart de l'adresse,
        // une nouvelle demande remplace la précédente côté serveur.
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _apiErrors = const {};
                    _codeController.clear();
                    _step = _Step.request;
                  }),
          child: const Text('Je n\'ai pas reçu de code'),
        ),
      ];

  Widget _submitButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: _loading ? null : onPressed,
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
          : Text(label),
    );
  }
}
