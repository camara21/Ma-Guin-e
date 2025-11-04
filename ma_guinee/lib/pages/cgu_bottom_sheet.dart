import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CGUBottomSheet extends StatefulWidget {
  const CGUBottomSheet({super.key});

  @override
  State<CGUBottomSheet> createState() => _CGUBottomSheetState();
}

class _CGUBottomSheetState extends State<CGUBottomSheet> {
  bool _isAccepted = false;

  // ---- Texte CGU (on insère l'année dynamiquement) ----
  String get _fullCguText {
    final year = DateTime.now().year;
    return
        '🧾 CONDITIONS GÉNÉRALES D’UTILISATION (CGU)\n\n'
        '1. Présentation de l’application\n\n'
        'Soneya est une entreprise numérique guinéenne fondée par Mohamed Camara. '
        'Elle développe et exploite l’application mobile et web « Soneya », un ensemble de services destinés à faciliter la vie quotidienne des citoyens guinéens.\n\n'
        'L’application regroupe divers services : offres d’emploi, annonces, logement, restauration, billetterie, tourisme, prestataires, hôtels, services administratifs et messagerie sécurisée.\n\n'
        'Toute utilisation de Soneya implique l’acceptation sans réserve des présentes Conditions Générales d’Utilisation.\n\n'
        '2. Objet et champ d’application\n\n'
        'Les présentes CGU ont pour objet de définir les droits, devoirs et responsabilités applicables entre Soneya et les utilisateurs de ses services. '
        'Elles s’appliquent à toute personne accédant à l’application, qu’elle soit simple visiteuse ou utilisatrice inscrite.\n\n'
        '3. Accès et disponibilité\n\n'
        'L’accès à l’application Soneya est gratuit pour les utilisateurs disposant d’un appareil compatible et d’une connexion Internet. '
        'Certaines fonctionnalités peuvent nécessiter la création d’un compte ou un paiement sécurisé. '
        'Soneya se réserve le droit de suspendre temporairement ses services pour maintenance ou mise à jour, sans indemnisation.\n\n'
        '4. Création de compte\n\n'
        'Pour utiliser certaines fonctionnalités, l’utilisateur doit créer un compte personnel et fournir des informations exactes, complètes et à jour. '
        'Les identifiants sont strictement personnels et ne doivent pas être partagés. Toute utilisation frauduleuse d’un compte engage la responsabilité de son titulaire. '
        'Soneya se réserve le droit de suspendre tout compte suspect, inactif ou non conforme.\n\n'
        '5. Comportement et obligations des utilisateurs\n\n'
        'Les utilisateurs s’engagent à utiliser Soneya dans le respect des lois et des valeurs de la République de Guinée. '
        'Ils doivent adopter un comportement courtois, honnête et responsable.\n\n'
        'Il est formellement interdit de :\n'
        '• Publier ou promouvoir des produits illicites (drogues, armes, contrefaçons, médicaments non autorisés) ;\n'
        '• Diffuser ou vendre de l’alcool, du tabac ou tout produit interdit par la loi ;\n'
        '• Publier du contenu pornographique, violent, discriminatoire, haineux ou diffamatoire ;\n'
        '• Organiser des escroqueries, jeux d’argent, paris non autorisés ou systèmes frauduleux ;\n'
        '• Usurper l’identité d’autrui ou créer de faux profils ;\n'
        '• Tenter d’accéder illégalement aux serveurs, bases de données ou systèmes de Soneya.\n\n'
        'Toute violation pourra entraîner la suppression immédiate du compte et des poursuites judiciaires.\n\n'
        '6. Contenus et publications\n\n'
        'Chaque utilisateur est responsable du contenu qu’il publie : texte, photo, vidéo, annonce, commentaire, etc. '
        'Soneya ne modère pas automatiquement tous les contenus, mais peut retirer sans préavis ceux jugés inappropriés. '
        'Les utilisateurs garantissent que leurs publications ne violent aucun droit d’auteur, droit à l’image ou loi en vigueur.\n\n'
        '7. Protection des mineurs\n\n'
        'L’inscription sur Soneya est réservée aux personnes âgées d’au moins 4 ans. '
        'Les mineurs de moins de 4 ans doivent utiliser l’application sous la surveillance d’un parent ou tuteur légal. '
        'Toute diffusion de contenu à caractère sexuel, violent ou inadapté aux mineurs est strictement interdite.\n\n'
        '8. Données personnelles et confidentialité\n\n'
        'Soneya accorde une importance primordiale à la confidentialité des données de ses utilisateurs. '
        'Les informations collectées (nom, e-mail, téléphone, photo, localisation, etc.) sont utilisées uniquement pour assurer le bon fonctionnement des services. '
        'Ces données sont hébergées de manière sécurisée et ne sont jamais revendues à des tiers sans consentement explicite.\n\n'
        'Conformément aux lois en vigueur, chaque utilisateur peut demander la suppression de ses données personnelles via : soneya.signaler@gmail.com.\n\n'
        '9. Paiements et transactions\n\n'
        'Certaines fonctionnalités (billetterie, réservation, mise en avant d’annonces, etc.) peuvent nécessiter un paiement. '
        'Les paiements sont traités par des prestataires agréés et sécurisés. '
        'Soneya ne conserve aucune donnée bancaire et décline toute responsabilité en cas d’incident lié à un prestataire tiers.\n\n'
        '10. Publicités et partenariats\n\n'
        'Soneya peut diffuser des publicités, promotions ou contenus sponsorisés identifiés comme tels. '
        'Ces partenariats respectent les lois guinéennes et les principes éthiques de la marque.\n\n'
        '11. Propriété intellectuelle\n\n'
        'Tous les éléments de l’application (logo, marque, interface, code source, textes, images, base de données) '
        'sont protégés par le droit de la propriété intellectuelle et appartiennent à Soneya. '
        'Toute reproduction ou diffusion sans autorisation écrite est strictement interdite.\n\n'
        '12. Responsabilité de Soneya\n\n'
        'Soneya s’engage à fournir ses services avec soin, mais ne garantit pas une disponibilité permanente. '
        'Soneya ne saurait être tenue responsable des interruptions, erreurs, pertes de données ou dommages indirects liés à l’utilisation du service.\n\n'
        '13. Sécurité, piratage et fraude\n\n'
        'Toute tentative d’accès non autorisé, de piratage, d’ingénierie inverse ou de fraude entraînera une suspension immédiate du compte et un signalement aux autorités compétentes.\n\n'
        '14. Force majeure\n\n'
        'Soneya ne pourra être tenue responsable des défaillances liées à un cas de force majeure (catastrophe naturelle, coupure réseau, grève, guerre, etc.).\n\n'
        '15. Suspension ou résiliation de compte\n\n'
        'Soneya se réserve le droit de suspendre ou supprimer tout compte en cas de non-respect des présentes conditions, d’abus ou de fraude. '
        'Aucune compensation ne sera due en cas de suppression pour manquement aux règles.\n\n'
        '16. Droit applicable\n\n'
        'Les présentes CGU sont régies par le droit guinéen. '
        'En cas de litige, les tribunaux compétents seront ceux de la République de Guinée.\n\n'
        '17. Contact\n\n'
        '📧 Email : soneya.signaler@gmail.com\n'
        '📍 Siège : Dubréka (Kaléma), République de Guinée\n'
        '👤 Propriétaire et éditeur : Mohamed Camara\n\n'
        '© $year Soneya – Propriété de Mohamed Camara. Tous droits réservés.\n';
  }

  Future<void> _onAccept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cgu_accepted', true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await Supabase.instance.client
          .from('utilisateurs')
          .update({'cgu_accepte': true})
          .eq('id', userId);
    }

    Navigator.pop(context);
  }

  void _showFullCGU() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conditions Générales d’Utilisation — Soneya'),
        content: SingleChildScrollView(
          // <-- plus de "const" ici
          child: SelectableText(
            _fullCguText, // <-- interpolation autorisée
            style: const TextStyle(fontSize: 15, height: 1.45),
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
              "En utilisant l’application Soneya, vous confirmez avoir pris connaissance et accepté nos Conditions Générales d’Utilisation. "
              "Vous pouvez consulter la version complète ci-dessous.",
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
                    _isAccepted ? const Color(0xFF113CFC) : Colors.grey,
              ),
              child: const Text("Continuer"),
            ),
          ],
        ),
      ),
    );
  }
}
