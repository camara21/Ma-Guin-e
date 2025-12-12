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

  // ---- Texte CGU (année dynamique uniquement) ----
  String get _fullCguText {
    final year = DateTime.now().year;
    return '🧾 CONDITIONS GÉNÉRALES D’UTILISATION (CGU)\n\n'
        '1. Présentation de l’application\n\n'
        'Soneya est une entreprise numérique guinéenne fondée par Mohamed Camara. '
        'Elle développe et exploite l’application mobile et web « Soneya », un ensemble de services destinés à faciliter la vie quotidienne des citoyens guinéens.\n\n'
        'L’application propose : annonces, logement, emplois, restauration, tourismes, billetterie, prestataires, hôtels, '
        'services administratifs et messagerie sécurisée.\n\n'
        'Toute utilisation de Soneya implique l’acceptation pleine et entière des présentes Conditions Générales d’Utilisation.\n\n'
        '2. Objet et champ d’application\n\n'
        'Les présentes CGU définissent les règles d’utilisation, les droits et les obligations applicables entre Soneya '
        'et toute personne utilisant l’application, qu’elle soit visiteuse ou inscrite.\n\n'
        '3. Accès et disponibilité\n\n'
        'L’accès à l’application Soneya est gratuit. Certaines fonctionnalités nécessitent la création d’un compte ou un paiement sécurisé. '
        'Soneya peut suspendre temporairement l’accès au service pour maintenance sans indemnisation.\n\n'
        '4. Création de compte\n\n'
        'Pour accéder à certaines fonctionnalités, l’utilisateur doit créer un compte personnel avec des informations exactes, complètes et à jour. '
        'Les identifiants de connexion sont strictement personnels et ne doivent pas être partagés. '
        'Soneya peut suspendre tout compte suspect, frauduleux ou non conforme.\n\n'
        '5. Comportement et obligations des utilisateurs\n\n'
        'Les utilisateurs doivent respecter les lois guinéennes et adopter un comportement responsable et respectueux.\n\n'
        'Il est strictement interdit de :\n'
        '• Publier des produits interdits (armes, drogues, médicaments non autorisés, contrefaçons) ;\n'
        '• Vendre ou promouvoir alcool, tabac ou produits illicites ;\n'
        '• Publier du contenu pornographique, violent, haineux ou discriminatoire ;\n'
        '• Organiser des arnaques, jeux d’argent illégaux ou pratiques frauduleuses ;\n'
        '• Usurper une identité ou créer de faux comptes ;\n'
        '• Tenter d’accéder illégalement aux systèmes ou serveurs de Soneya.\n\n'
        'Toute infraction pourra entraîner la suppression du compte et des poursuites judiciaires.\n\n'
        '6. Contenus et publications\n\n'
        'Chaque utilisateur est entièrement responsable du contenu qu’il publie dans l’application (annonces, photos, messages, commentaires, avis, etc.). '
        'Soneya se réserve le droit de retirer tout contenu jugé inapproprié, illégal ou contraire à l’éthique, sans préavis. '
        'L’utilisateur garantit que ses contenus ne violent aucun droit d’auteur, droit à l’image ni loi en vigueur.\n\n'
        '7. Protection des mineurs\n\n'
        'L’application Soneya est accessible au public dès 7 ans. '
        'Les utilisateurs de moins de 18 ans doivent utiliser l’application sous la supervision d’un parent ou tuteur légal.\n\n'
        'Soneya interdit strictement toute publication, diffusion ou mise en avant de contenus à caractère sexuel, violent, choquant, '
        'discriminatoire ou inadapté aux mineurs.\n\n'
        'Toute violation entraîne des sanctions pouvant aller jusqu’à la suppression définitive du compte.\n\n'
        '8. Données personnelles et confidentialité\n\n'
        'Soneya accorde une importance primordiale à la confidentialité des données. '
        'Les informations collectées (nom, e-mail, téléphone, photo, localisation, etc.) sont utilisées uniquement pour fournir et améliorer les services proposés.\n\n'
        'Les données sont stockées de manière sécurisée et ne sont jamais revendues sans consentement explicite.\n\n'
        'Pour toute demande liée à vos données (accès, rectification, suppression), vous pouvez nous contacter : soneya.signaler@gmail.com.\n\n'
        '9. Paiements et transactions\n\n'
        'Certaines fonctionnalités (billetterie, réservations, mise en avant d’annonces, etc.) peuvent nécessiter un paiement. '
        'Les paiements sont traités par des prestataires agréés et sécurisés. '
        'Soneya ne conserve aucune donnée bancaire et décline toute responsabilité en cas d’incident imputable à un prestataire tiers.\n\n'
        'En cas de litige entre utilisateurs (vendeur / acheteur, prestataire / client, etc.), Soneya peut intervenir comme médiateur sans obligation de résultat.\n\n'
        '10. Publicités et partenariats\n\n'
        'L’application peut afficher des publicités, promotions ou contenus sponsorisés. '
        'Ces contenus sont sélectionnés dans le respect des lois en vigueur. '
        'Aucune donnée personnelle n’est partagée avec des partenaires sans accord explicite de l’utilisateur.\n\n'
        '11. Propriété intellectuelle\n\n'
        'Le logo, le nom « Soneya », l’interface, les textes, les images, le code source et la base de données sont la propriété exclusive de Soneya et '
        'sont protégés par les lois sur la propriété intellectuelle.\n\n'
        'Toute reproduction, modification ou diffusion non autorisée est strictement interdite.\n\n'
        '12. Responsabilité de Soneya\n\n'
        'Soneya s’efforce de fournir un service fiable, mais ne garantit pas l’absence totale d’erreurs, de bugs ou d’interruptions. '
        'Soneya ne pourra être tenue responsable des interruptions temporaires du service, des pertes de données, ni des dommages indirects liés à l’utilisation de l’application.\n\n'
        'Les transactions réalisées entre utilisateurs (ventes, prestations, locations, etc.) se font sous leur seule responsabilité.\n\n'
        '13. Sécurité, piratage et fraude\n\n'
        'Toute tentative de piratage, d’accès non autorisé, de contournement des systèmes de sécurité ou de fraude entraînera la suspension immédiate du compte '
        'et pourra faire l’objet d’un signalement aux autorités compétentes.\n\n'
        '14. Force majeure\n\n'
        'Soneya ne pourra être tenue responsable en cas de défaillance liée à un événement de force majeure, tels que : catastrophe naturelle, coupure réseau, '
        'grève, troubles politiques, décision gouvernementale, etc.\n\n'
        '15. Suspension ou résiliation de compte\n\n'
        'Soneya se réserve le droit de suspendre ou supprimer tout compte en cas de non-respect des présentes CGU, de comportement abusif ou d’activité frauduleuse. '
        'Aucune compensation ne sera accordée en cas de suppression d’un compte pour non-respect des règles.\n\n'
        '16. Droit applicable et juridiction compétente\n\n'
        'Les présentes CGU sont régies par le droit guinéen. En cas de litige, les tribunaux compétents de la République de Guinée pourront être saisis.\n\n'
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
          .update({'cgu_accepte': true}).eq('id', userId);
    }

    Navigator.pop(context);
  }

  void _showFullCGU() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conditions Générales d’Utilisation — Soneya'),
        content: SingleChildScrollView(
          child: SelectableText(
            _fullCguText,
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
