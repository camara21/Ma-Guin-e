import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // pour la mise à jour Supabase

class CGUBottomSheet extends StatefulWidget {
  const CGUBottomSheet({super.key});

  @override
  State<CGUBottomSheet> createState() => _CGUBottomSheetState();
}

class _CGUBottomSheetState extends State<CGUBottomSheet> {
  bool _isAccepted = false;

  void _onAccept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cgu_accepted', true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client
          .from('utilisateurs')
          .update({'cgu_accepte': true}).eq('id', userId);
    }

    Navigator.pop(context);
  }

  void _showFullCGU() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Conditions Générales d’Utilisation de "Ma Guinée"',
        ),
        content: const SingleChildScrollView(
          child: Text(
            '''
Bienvenue sur l’application "Ma Guinée". En utilisant nos services, vous acceptez les conditions suivantes :

Objet de l’application : "Ma Guinée" est une plateforme qui centralise divers services essentiels, incluant les petites annonces, la mise en relation avec des prestataires locaux, une carte interactive des points d’intérêt, ainsi que des informations sur les services administratifs, lieux de culte, restaurants, hôtels, boîtes de nuit et plus encore.

Droits et responsabilités de l’utilisateur : Vous vous engagez à utiliser l’application de manière légale et respectueuse. Il est interdit de publier des contenus offensants, trompeurs ou illégaux dans les petites annonces, et vous devez respecter les règles de bonne conduite lors de l’utilisation des services comme la carte, les avis sur les restaurants, ou les réservations d’hôtel.

Responsabilités du fournisseur : Nous nous engageons à offrir une plateforme stable et à jour, mais nous ne pouvons pas garantir l’absence totale d’interruptions ou d’erreurs. Nous ne sommes pas responsables des interactions entre utilisateurs, ni des informations fournies par des tiers.

Résiliation : Vous pouvez désactiver votre compte à tout moment. Nous nous réservons le droit de suspendre ou de supprimer un compte en cas de violation des présentes conditions, notamment en cas d’abus sur les annonces, les avis ou les réservations.

Propriété intellectuelle : L’ensemble du contenu de l’application, y compris les textes, images, logos et toute autre ressource, est protégé par le droit d’auteur. Toute reproduction non autorisée est interdite.

En continuant à utiliser "Ma Guinée", vous acceptez ces Conditions Générales d’Utilisation.
            ''',
            style: TextStyle(fontSize: 15),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          children: [
            const Text(
              "Conditions Générales d'Utilisation",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              "En utilisant l’application Ma Guinée, vous vous engagez à respecter nos conditions. Vous pouvez consulter l’intégralité des CGU en cliquant ci-dessous.",
              style: TextStyle(fontSize: 15),
            ),
            TextButton(
              onPressed: _showFullCGU,
              child: const Text("Lire les CGU complètes"),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text("J’ai lu et j’accepte les CGU"),
              value: _isAccepted,
              onChanged: (val) => setState(() => _isAccepted = val),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isAccepted ? _onAccept : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isAccepted ? Color(0xFF113CFC) : Colors.grey,
              ),
              child: const Text("Continuer"),
            ),
          ],
        ),
      ),
    );
  }
}
