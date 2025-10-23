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
        title: const Text('Conditions Générales d’Utilisation — Soneya'),
        content: const SingleChildScrollView(
          child: SelectableText(
            '🧾 CONDITIONS GÉNÉRALES D’UTILISATION (CGU)\n\n'
            '1. Présentation de l’application\n\n'
            'L’application Soneya, éditée par Mohamed Camara, domicilié à Dubreka (Kaléma), République de Guinée, a pour objectif de proposer un ensemble de services numériques destinés à faciliter la vie quotidienne des utilisateurs en Guinée.\n\n'
            'Ces services comprennent notamment :\n\n'
            'la publication et la consultation d’offres d’emploi et de candidatures,\n\n'
            'la mise en relation pour des logements (vente, location, terrains),\n\n'
            'la recherche et la réservation de restaurants, hôtels, prestataires de services,\n\n'
            'la découverte du tourisme et de la culture guinéenne,\n\n'
            'la consultation d’événements, billetterie et annonces locales,\n\n'
            'un système de messagerie, de notifications et de cartes interactives,\n\n'
            'ainsi que tout autre service que l’éditeur pourra ajouter dans les versions futures.\n\n'
            'L’utilisation de l’application Soneya implique l’acceptation pleine et entière des présentes Conditions Générales d’Utilisation.\n\n'
            '2. Objet\n\n'
            'Les présentes CGU ont pour objet de définir les conditions d’accès, de consultation et d’utilisation des services proposés sur Soneya, que ce soit via mobile, tablette ou web.\n\n'
            '3. Accès à l’application\n\n'
            'L’application Soneya est accessible gratuitement à tout utilisateur disposant d’un accès Internet et d’un appareil compatible.\n'
            'Certains services pourront évoluer et devenir payants ou affichant de la publicité dans de futures versions, sans que cela ne remette en cause la validité des présentes CGU.\n\n'
            '4. Inscription et compte utilisateur\n\n'
            'L’accès à certaines fonctionnalités (publication, candidature, messagerie, etc.) nécessite la création d’un compte utilisateur.\n'
            'L’utilisateur s’engage à fournir des informations exactes, complètes et à jour lors de son inscription.\n'
            'Il est seul responsable de la confidentialité de ses identifiants (adresse e-mail, mot de passe) et de l’activité réalisée sous son compte.\n\n'
            '5. Services proposés\n\n'
            'Soneya offre un ensemble de services intégrés :\n\n'
            'Emploi : dépôt et consultation d’offres, candidatures, enregistrement de CV, échanges entre employeurs et candidats.\n\n'
            'Logement : publication et recherche de logements, terrains ou biens immobiliers à travers la Guinée.\n\n'
            'Tourisme & Culture : mise en valeur des sites, monuments, événements culturels et activités locales.\n\n'
            'Restaurants & Hôtels : guide interactif pour découvrir les meilleurs établissements.\n\n'
            'Prestataires & Annonces : vitrine numérique pour artisans, commerçants et indépendants.\n\n'
            'Messagerie et Notifications : communication entre utilisateurs dans le respect des règles de bonne conduite.\n\n'
            'Carte interactive : géolocalisation des services et offres à proximité.\n\n'
            'L’éditeur se réserve le droit d’ajouter, de modifier ou de supprimer tout service sans préavis.\n\n'
            '6. Obligations de l’utilisateur\n\n'
            'L’utilisateur s’engage à :\n\n'
            'utiliser Soneya de manière légale, respectueuse et responsable ;\n\n'
            'ne pas publier de contenu offensant, diffamatoire, discriminatoire, illégal ou contraire à la morale ;\n\n'
            'ne pas usurper l’identité d’autrui ;\n\n'
            'ne pas diffuser de fausses informations ou d’annonces trompeuses ;\n\n'
            'ne pas tenter d’accéder frauduleusement à des données ou à des serveurs.\n\n'
            'En cas de non-respect de ces règles, Mohamed Camara se réserve le droit de suspendre ou supprimer le compte fautif sans préavis.\n\n'
            '7. Responsabilité\n\n'
            'Soneya met tout en œuvre pour garantir la fiabilité et la sécurité de ses services, mais ne saurait être tenue responsable :\n\n'
            'des interruptions temporaires ou définitives du service ;\n\n'
            'des pertes de données ou d’informations publiées par les utilisateurs ;\n\n'
            'des contenus, annonces ou offres publiées par des tiers ;\n\n'
            'ni des dommages directs ou indirects résultant de l’usage de l’application.\n\n'
            'Les utilisateurs restent responsables de leurs interactions et transactions réalisées via la plateforme.\n\n'
            '8. Données personnelles et confidentialité\n\n'
            'Soneya collecte et traite certaines données personnelles nécessaires au bon fonctionnement de ses services :\n\n'
            'informations d’inscription (nom, e-mail, téléphone, photo de profil, CV, etc.) ;\n\n'
            'données de localisation pour certaines fonctionnalités (ex. : “autour de moi”) ;\n\n'
            'contenus publiés (annonces, messages, images, etc.).\n\n'
            'Ces données sont hébergées de manière sécurisée (notamment via Supabase, basé dans l’Union Européenne) et ne sont jamais revendues à des tiers sans consentement.\n\n'
            'L’utilisateur peut à tout moment demander la suppression de ses données via la page de contact de l’application.\n\n'
            '9. Publicité et partenariats\n\n'
            'Des publicités ou contenus sponsorisés pourront être intégrés dans les prochaines versions de l’application.\n'
            'Soneya s’engage à les présenter de manière claire, sans nuire à l’expérience utilisateur.\n\n'
            '10. Propriété intellectuelle\n\n'
            'Tous les éléments de l’application (logo, design, textes, code, images, base de données, etc.) sont la propriété exclusive de Mohamed Camara.\n'
            'Toute reproduction, distribution ou utilisation non autorisée est strictement interdite.\n\n'
            'Les contenus publiés par les utilisateurs restent leur propriété, mais ceux-ci accordent à Soneya une licence gratuite et non exclusive pour les afficher sur la plateforme.\n\n'
            '11. Sécurité et intégrité du réseau\n\n'
            'Soneya met en place des mesures techniques et organisationnelles pour protéger les données et prévenir les intrusions.\n'
            'Toute tentative de piratage, d’ingénierie inverse ou de perturbation du service entraînera des poursuites conformément à la loi guinéenne.\n\n'
            '12. Modération et signalement\n\n'
            'Les utilisateurs peuvent signaler tout contenu inapproprié via le bouton “Signaler” ou la page de contact.\n'
            'L’équipe de Soneya se réserve le droit de supprimer tout contenu non conforme ou de bloquer un utilisateur.\n\n'
            '13. Évolution des CGU\n\n'
            'Les présentes CGU peuvent être modifiées à tout moment afin de s’adapter à l’évolution des services, de la législation ou de la politique interne.\n'
            'La version la plus récente est disponible dans l’application et sur le site officiel de Soneya.\n\n'
            '14. Droit applicable et juridiction compétente\n\n'
            'Les présentes CGU sont régies par le droit guinéen.\n'
            'En cas de litige, les tribunaux compétents seront ceux de la République de Guinée, sauf disposition contraire.\n\n'
            '15. Contact\n\n'
            'Pour toute question, réclamation ou demande relative à l’application ou aux données personnelles :\n\n'
            'Mohamed Camara\n'
            '📍 Dubreka (Kaléma), République de Guinée\n'
            '📧 soneya.signaler@gmail.com\n',
            style: TextStyle(fontSize: 15, height: 1.45),
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
              "En utilisant l’application Soneya, vous vous engagez à respecter nos conditions. "
              "Vous pouvez consulter l’intégralité des CGU en cliquant ci-dessous.",
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
                backgroundColor: _isAccepted ? const Color(0xFF113CFC) : Colors.grey,
              ),
              child: const Text("Continuer"),
            ),
          ],
        ),
      ),
    );
  }
}
