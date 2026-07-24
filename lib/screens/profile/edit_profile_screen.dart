import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/auth_state.dart';
import '../../widgets/shared.dart';

/// Modification du profil : identité, contact et informations patient.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String? _gender;
  DateTime? _birthDate;
  bool _isPatient = false;
  bool _saving = false;
  Map<String, List<String>> _apiErrors = const {};

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController =
        TextEditingController(text: user?.patient?.address ?? '');
    _isPatient = user?.role == 'patient';
    _gender = user?.patient?.gender;
    if (user?.patient?.birthDate != null) {
      _birthDate = DateTime.tryParse(user!.patient!.birthDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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

  Future<void> _save() async {
    setState(() => _apiErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    final fields = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    };

    if (_isPatient) {
      if (_gender != null) fields['gender'] = _gender;
      if (_birthDate != null) {
        fields['birth_date'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
      }
      fields['address'] = _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim();
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthState>().updateProfile(fields);
      if (!mounted) return;
      showSuccess(context, 'Profil mis à jour.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _apiErrors = e.errors);
      if (e.errors.isEmpty) showError(context, e);
      _formKey.currentState!.validate();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _fieldError(String field) => _apiErrors[field]?.firstOrNull;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                          return 'Le nom ne peut pas être vide.';
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
                          return 'L\'adresse e-mail ne peut pas être vide.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (_) => _fieldError('phone'),
                    ),
                    if (_isPatient) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Informations patient',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'male',
                            label: Text('Homme'),
                            icon: Icon(Icons.male),
                          ),
                          ButtonSegment(
                            value: 'female',
                            label: Text('Femme'),
                            icon: Icon(Icons.female),
                          ),
                        ],
                        emptySelectionAllowed: true,
                        selected: {?_gender},
                        onSelectionChanged: (selection) => setState(
                            () => _gender = selection.firstOrNull),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _saving ? null : _pickBirthDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date de naissance',
                            prefixIcon: const Icon(Icons.cake_outlined),
                            errorText: _fieldError('birth_date'),
                          ),
                          child: Text(
                            _birthDate == null
                                ? 'Choisir une date'
                                : DateFormat('d MMMM yyyy', 'fr_FR')
                                    .format(_birthDate!),
                            style: TextStyle(
                              color: _birthDate == null
                                  ? Colors.grey.shade600
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        validator: (_) => _fieldError('address'),
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
