import 'package:flutter/material.dart';

class AidePage extends StatelessWidget {
  const AidePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Exemple de FAQ simple, tu peux étoffer ou rendre interactif
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aide & FAQ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          ExpansionTile(
            title: Text("Comment publier une annonce ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text("Allez dans Annonces, puis cliquez sur 'Publier'. Remplissez le formulaire."),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment contacter un prestataire ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text("Rendez-vous dans la section Prestataires et cliquez sur le prestataire souhaité."),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Problème ou suggestion ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text("Contactez-nous via le bouton d'assistance ou envoyez un mail à support@maguinee.app"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
