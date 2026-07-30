import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/auth_state.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

/// Inscription d'un nouveau patient.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();

  String _gender = 'male';
  DateTime? _birthDate;
  bool _obscure = true;
  bool _loading = false;
  Map<String, List<String>> _apiErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _apiErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      showError(context, ApiException(422, 'Veuillez indiquer votre date de naissance.'));
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthState>().register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim().toLowerCase(),
            gender: _gender,
            birthDate: DateFormat('yyyy-MM-dd').format(_birthDate!),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _passwordConfirmationController.text,
          );
      if (!mounted) return;
      // La session est ouverte : on revient à la racine, _RootGate affiche l'accueil
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  String? _fieldError(String field) => _apiErrors[field]?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
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
                      'Vos informations',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elles nous servent à constituer votre dossier et à vous identifier lors des consultations.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final apiError = _fieldError('name');
                        if (apiError != null) return apiError;
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez indiquer votre nom complet.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
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
                    const SizedBox(height: 16),
                    // Sexe
                    Text('Sexe', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white,
                        selectedBackgroundColor: AppPalette.primarySoft,
                        selectedForegroundColor: AppPalette.primary,
                        foregroundColor: AppPalette.inkMuted,
                        side: const BorderSide(color: AppPalette.border),
                        textStyle: Theme.of(context).textTheme.labelMedium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                        ),
                      ),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'male',
                          label: Text('Homme'),
                          icon: Icon(Icons.male, size: 18),
                        ),
                        ButtonSegment(
                          value: 'female',
                          label: Text('Femme'),
                          icon: Icon(Icons.female, size: 18),
                        ),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (selection) =>
                          setState(() => _gender = selection.first),
                    ),
                    const SizedBox(height: 16),
                    // Date de naissance
                    InkWell(
                      onTap: _loading ? null : _pickBirthDate,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date de naissance',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          errorText: _fieldError('birth_date'),
                          suffixIcon: const Icon(Icons.expand_more_rounded,
                              size: 20, color: AppPalette.inkFaint),
                        ),
                        child: Text(
                          _birthDate == null
                              ? 'Choisir une date'
                              : DateFormat('d MMMM yyyy', 'fr_FR')
                                  .format(_birthDate!),
                          style: _birthDate == null
                              ? Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppPalette.inkFaint)
                              : Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (facultatif)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (_) => _fieldError('phone'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Créer mon compte'),
                    ),
                  ],
                ),
              )),
            ),
          ),
        ),
      ),
    );
  }
}
