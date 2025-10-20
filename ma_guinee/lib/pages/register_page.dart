// lib/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGenre;
  Country? _selectedCountry;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr');
  }

  // ---- Décoration arrondie réutilisable (couleurs fixes) ----
  InputDecoration _dec(String label) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF0077B6), // mainPrimary
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr'),
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickCountry() async {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (c) => setState(() => _selectedCountry = c),
    );
  }

  Future<void> _soumettreInscription() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final signUpResponse =
          await supabase.auth.signUp(email: email, password: password);
      final userId = signUpResponse.user?.id;
      if (userId == null) {
        throw Exception(
          'Erreur lors de la création du compte. E-mail déjà utilisé ?',
        );
      }

      await supabase.from('utilisateurs').insert({
        'id': userId,
        'prenom': _prenomController.text.trim(),
        'nom': _nomController.text.trim(),
        'email': email,
        'pays': _selectedCountry!.name,
        'telephone': _telephoneController.text.trim(),
        'genre': _selectedGenre,
        'date_naissance': _selectedDate!.toIso8601String(),
        'photo_url': null,
        'date_inscription': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Inscription réussie'),
          content: const Text('Votre compte a été créé avec succès !'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.mainNav, (_) => false);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'authentification : ${e.message}")),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur base : ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar blanc + éléments bleus fixes
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Créer un compte',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0.6,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0077B6), // mainPrimary
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _prenomController,
                decoration: _dec('Prénom'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ requis' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nomController,
                decoration: _dec('Nom'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ requis' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                decoration: _dec('E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
              ),
              const SizedBox(height: 12),

              // Pays (champ readOnly arrondi)
              TextFormField(
                readOnly: true,
                onTap: _pickCountry,
                decoration: _dec('Pays').copyWith(
                  hintText: _selectedCountry != null
                      ? '${_selectedCountry!.flagEmoji} ${_selectedCountry!.name} (+${_selectedCountry!.phoneCode})'
                      : 'Sélectionner un pays',
                  suffixIcon: const Icon(Icons.public),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _telephoneController,
                decoration: _dec('Téléphone'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Téléphone requis' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                decoration: _dec('Genre'),
                value: _selectedGenre,
                items: const [
                  DropdownMenuItem(value: 'Homme', child: Text('Homme')),
                  DropdownMenuItem(value: 'Femme', child: Text('Femme')),
                ],
                onChanged: (v) => setState(() => _selectedGenre = v),
                validator: (v) => v == null ? 'Genre requis' : null,
              ),
              const SizedBox(height: 12),

              // Date de naissance (champ readOnly arrondi)
              TextFormField(
                readOnly: true,
                onTap: _pickDate,
                decoration: _dec('Date de naissance').copyWith(
                  hintText: _selectedDate == null
                      ? 'Sélectionner une date'
                      : DateFormat('dd MMMM yyyy', 'fr').format(_selectedDate!),
                  suffixIcon: const Icon(Icons.calendar_month),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passwordController,
                decoration: _dec('Mot de passe'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimum 6 caractères' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordController,
                decoration: _dec('Confirmer le mot de passe'),
                obscureText: true,
                validator: (v) => v != _passwordController.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              const SizedBox(height: 24),

              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _soumettreInscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0077B6), // mainPrimary
                          foregroundColor: const Color(0xFFFFFFFF), // onPrimary
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "S'inscrire",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
