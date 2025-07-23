import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Exemple d'affichage statique, tu peux ensuite connecter à la base pour les vraies notifications
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ListTile(
            leading: Icon(Icons.info, color: Colors.orange[700]),
            title: const Text("Bienvenue sur Ma Guinée !"),
            subtitle: const Text("Merci d'avoir rejoint l'application."),
          ),
          ListTile(
            leading: Icon(Icons.payment, color: Colors.green[700]),
            title: const Text("Nouveau service ajouté !"),
            subtitle: const Text("Vous pouvez désormais payer vos factures en ligne."),
          ),
          // Ajoute tes vraies notifications ici
        ],
      ),
    );
  }
}
