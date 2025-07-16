import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../models/utilisateur_model.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final utilisateur = context.watch<UserProvider>().utilisateur;

    if (utilisateur == null) {
      return const Scaffold(
        body: Center(child: Text("Aucun utilisateur connecté.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Mon Profil",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: utilisateur.photoUrl != null
                      ? NetworkImage(utilisateur.photoUrl!)
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                const SizedBox(height: 12),
                Text(
                  "${utilisateur.prenom} ${utilisateur.nom}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  utilisateur.email,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildInfoRow(Icons.public, "Pays", utilisateur.pays),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone, "Téléphone", utilisateur.telephone),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.wc, "Genre", utilisateur.genre ?? "Non précisé"),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/modifier_profil');
            },
            icon: const Icon(Icons.edit),
            label: const Text("Modifier mon profil"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE1126),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          const Text("Mes Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildServiceTile(Icons.favorite, "Mes favoris", "/favoris"),
          _buildServiceTile(Icons.event, "Mes réservations", "/reservations"),
          _buildServiceTile(Icons.history, "Historique", "/historique"),
          _buildServiceTile(Icons.campaign, "Mes annonces", "/mes_annonces"),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          const Text("Paramètres", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildServiceTile(Icons.lock, "Modifier mot de passe", "/changer_mot_de_passe"),
          _buildServiceTile(Icons.delete, "Supprimer mon compte", "/supprimer_compte"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "$label : $value",
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTile(IconData icon, String label, String route) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Navigue vers la page associée
      },
    );
  }
}
