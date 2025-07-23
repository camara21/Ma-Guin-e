import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import 'modifier_profil_page.dart';

class ParametrePage extends StatelessWidget {
  final UtilisateurModel user;

  const ParametrePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        children: [
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text("Modifier mon profil"),
                  onTap: () async {
                    final modified = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModifierProfilPage(user: user),
                      ),
                    );
                    // Si modifié, on refresh le userProvider à la pop
                    if (modified == true) {
                      await Provider.of<UserProvider>(context, listen: false)
                          .chargerUtilisateurConnecte();
                      Navigator.pop(context, true);
                    }
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text("Mot de passe oublié ?"),
                  onTap: () async {
                    await Supabase.instance.client.auth.resetPasswordForEmail(user.email);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Un lien de réinitialisation a été envoyé par email.")),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                  title: const Text("Supprimer mon compte", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Supprimer mon compte"),
                        content: const Text("Cette action est irréversible. Es-tu sûr de vouloir supprimer ton compte ?"),
                        actions: [
                          TextButton(child: const Text("Annuler"), onPressed: () => Navigator.of(ctx).pop(false)),
                          TextButton(
                            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        // 1. Supprimer dans la table utilisateurs (optionnel selon RLS, à adapter)
                        await Supabase.instance.client
                            .from('utilisateurs')
                            .delete()
                            .eq('id', user.id);

                        // 2. Supprimer l'utilisateur auth Supabase
                        await Supabase.instance.client.auth.admin.deleteUser(user.id);

                        // 3. Déconnexion et retour accueil
                        await Supabase.instance.client.auth.signOut();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Compte supprimé avec succès.")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Erreur lors de la suppression : $e")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
