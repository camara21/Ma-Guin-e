import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ⬅️ Pour la locale française
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
    initializeDateFormatting('fr'); // ⬅️ Initialise le formatage français
  }

  void _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr'), // ⬅️ calendrier en français
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildCountrySelector() {
    return InkWell(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: true,
          onSelect: (Country country) {
            setState(() => _selectedCountry = country);
          },
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "Pays",
          border: OutlineInputBorder(),
        ),
        child: Text(
          _selectedCountry != null
              ? '${_selectedCountry!.flagEmoji} ${_selectedCountry!.name} (+${_selectedCountry!.phoneCode})'
              : "Sélectionner un pays",
        ),
      ),
    );
  }

  Future<void> _soumettreInscription() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs obligatoires.")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      // Création du compte
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final signUpResponse = await supabase.auth.signUp(email: email, password: password);

      final userId = signUpResponse.user?.id;
      if (userId == null) {
        throw Exception("Erreur lors de la création du compte. Email déjà utilisé ?");
      }

      // Insertion dans la table utilisateurs
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

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Inscription réussie"),
            content: const Text("Votre compte a été créé avec succès !"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.mainNav, (_) => false);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'authentification : ${e.message}")),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur base : ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}")),
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
      appBar: AppBar(title: const Text("Créer un compte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _prenomController,
                decoration: const InputDecoration(labelText: "Prénom", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Champ requis" : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Champ requis" : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (val) =>
                    val == null || !val.contains('@') ? "Email invalide" : null,
              ),
              const SizedBox(height: 12),
              _buildCountrySelector(),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telephoneController,
                decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (val) => val!.isEmpty ? "Téléphone requis" : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Genre", border: OutlineInputBorder()),
                value: _selectedGenre,
                items: const [
                  DropdownMenuItem(value: "Homme", child: Text("Homme")),
                  DropdownMenuItem(value: "Femme", child: Text("Femme")),
                ],
                onChanged: (value) => setState(() => _selectedGenre = value),
                validator: (val) => val == null ? "Genre requis" : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date de naissance",
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? "Sélectionner une date"
                        : DateFormat('dd MMMM yyyy', 'fr').format(_selectedDate!), // ⬅️ Français
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder()),
                obscureText: true,
                validator: (val) => val!.length < 6 ? "Minimum 6 caractères" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: "Confirmer le mot de passe", border: OutlineInputBorder()),
                obscureText: true,
                validator: (val) => val != _passwordController.text
                    ? "Les mots de passe ne correspondent pas"
                    : null,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _soumettreInscription,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE53935),
                                Color(0xFFFFEB3B),
                                Color(0xFF43A047),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "S'inscrire",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                letterSpacing: 1.2,
                              ),
                            ),
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
