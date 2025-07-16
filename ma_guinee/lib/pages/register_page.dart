import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
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
  final _paysController = TextEditingController();

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _paysController.dispose();
    super.dispose();
  }

  void _soumettreInscription() {
    if (_formKey.currentState!.validate()) {
      final utilisateur = UtilisateurModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: "${_prenomController.text} ${_nomController.text}",
        email: _emailController.text,
        pays: _paysController.text,
      );

      context.read<UserProvider>().setUtilisateur(utilisateur);

      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _prenomController,
                decoration: const InputDecoration(labelText: "Prénom"),
                validator: (val) => val == null || val.isEmpty ? "Champ requis" : null,
              ),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(labelText: "Nom"),
                validator: (val) => val == null || val.isEmpty ? "Champ requis" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (val) =>
                    val == null || !val.contains('@') ? "Email invalide" : null,
              ),
              TextFormField(
                controller: _paysController,
                decoration: const InputDecoration(labelText: "Pays"),
                validator: (val) => val == null || val.isEmpty ? "Champ requis" : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _soumettreInscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009460),
                ),
                child: const Text(
                  "S'inscrire",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
