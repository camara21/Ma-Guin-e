import 'package:flutter/material.dart';

class CGUPage extends StatelessWidget {
  const CGUPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color smallColor = Colors.grey.shade700;

    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        );

    Widget p(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(height: 1.45)),
        );

    Widget small(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(color: smallColor, fontSize: 12, height: 1.3),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text("Conditions Générales d’Utilisation")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🧾 CONDITIONS GÉNÉRALES D’UTILISATION (CGU)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.4),
                ),
                const SizedBox(height: 12),
                small(
                    "Dernière mise à jour : novembre ${DateTime.now().year}\nVersion 1.0 – République de Guinée"),

                title("1. Présentation de l’application"),
                p(
                    "Soneya est une entreprise numérique guinéenne fondée par Mohamed Camara. "
                    "Elle développe et exploite l’application mobile et web « Soneya », un ensemble de services destinés à faciliter la vie quotidienne des citoyens guinéens."),
                p(
                    "L’application regroupe divers services : offres d’emploi, annonces, logement, restauration, billetterie, tourisme, prestataires, hôtels, services administratifs et messagerie sécurisée."),
                small(
                    "Toute utilisation de Soneya implique l’acceptation sans réserve des présentes Conditions Générales d’Utilisation."),

                title("2. Objet et champ d’application"),
                p(
                    "Les présentes CGU ont pour objet de définir les droits, devoirs et responsabilités applicables entre Soneya et les utilisateurs de ses services. "
                    "Elles s’appliquent à toute personne accédant à l’application, qu’elle soit simple visiteuse ou utilisatrice inscrite."),

                title("3. Accès et disponibilité"),
                p(
                    "L’accès à l’application Soneya est gratuit pour les utilisateurs disposant d’un appareil compatible et d’une connexion Internet. "
                    "Certaines fonctionnalités peuvent nécessiter la création d’un compte ou un paiement sécurisé."),
                small(
                    "Soneya se réserve le droit de suspendre temporairement ses services pour maintenance ou mise à jour, sans indemnisation."),

                title("4. Création de compte"),
                p(
                    "Pour utiliser certaines fonctionnalités, l’utilisateur doit créer un compte personnel et fournir des informations exactes, complètes et à jour."),
                p(
                    "Les identifiants sont strictement personnels et ne doivent pas être partagés. "
                    "Toute utilisation frauduleuse d’un compte engage la responsabilité de son titulaire."),
                small(
                    "Soneya se réserve le droit de suspendre tout compte suspect, inactif ou non conforme."),

                title("5. Comportement et obligations des utilisateurs"),
                p(
                    "Les utilisateurs s’engagent à utiliser Soneya dans le respect des lois et des valeurs de la République de Guinée. "
                    "Ils doivent adopter un comportement courtois, honnête et responsable."),
                p("Il est formellement interdit de :"),
                p("• Publier ou promouvoir des produits illicites (drogues, armes, contrefaçons, médicaments non autorisés)."),
                p("• Diffuser ou vendre de l’alcool, du tabac ou tout produit interdit par la loi."),
                p("• Publier du contenu pornographique, violent, discriminatoire, haineux ou diffamatoire."),
                p("• Organiser des escroqueries, jeux d’argent, paris non autorisés ou systèmes frauduleux."),
                p("• Usurper l’identité d’autrui ou créer de faux profils."),
                p("• Tenter d’accéder illégalement aux serveurs, bases de données ou systèmes de Soneya."),
                small(
                    "Toute violation pourra entraîner la suppression immédiate du compte et des poursuites judiciaires."),

                title("6. Contenus et publications"),
                p(
                    "Chaque utilisateur est responsable du contenu qu’il publie : texte, photo, vidéo, annonce, commentaire, etc. "
                    "Soneya ne modère pas automatiquement tous les contenus, mais peut retirer sans préavis ceux jugés inappropriés."),
                small(
                    "Les utilisateurs garantissent que leurs publications ne violent aucun droit d’auteur, droit à l’image ou loi en vigueur."),

                title("7. Protection des mineurs"),
                p(
                    "L’inscription sur Soneya est réservée aux personnes âgées d’au moins 4 ans. "
                    "Les mineurs de moins de 4 ans doivent utiliser l’application sous la surveillance d’un parent ou tuteur légal."),
                small(
                    "Toute diffusion de contenu à caractère sexuel, violent ou inadapté aux mineurs est strictement interdite."),

                title("8. Données personnelles et confidentialité"),
                p(
                    "Soneya accorde une importance primordiale à la confidentialité des données de ses utilisateurs. "
                    "Les informations collectées (nom, e-mail, téléphone, photo, localisation, etc.) sont utilisées uniquement pour assurer le bon fonctionnement des services."),
                p(
                    "Ces données sont hébergées de manière sécurisée et ne sont jamais revendues à des tiers sans consentement explicite."),
                small(
                    "Conformément aux lois en vigueur, chaque utilisateur peut demander la suppression de ses données personnelles via l’adresse : soneya.signaler@gmail.com."),

                title("9. Paiements et transactions"),
                p(
                    "Certaines fonctionnalités (billetterie, réservation, mise en avant d’annonces, etc.) peuvent nécessiter un paiement."),
                p(
                    "Les paiements sont traités par des prestataires agréés et sécurisés. "
                    "Soneya ne conserve aucune donnée bancaire et décline toute responsabilité en cas d’incident lié à un tiers."),
                small(
                    "En cas de litige, Soneya peut agir en médiateur sans être tenue responsable du différend entre vendeur et acheteur."),

                title("10. Publicités et partenariats"),
                p(
                    "Soneya peut diffuser des publicités, promotions ou contenus sponsorisés identifiés comme tels. "
                    "Ces partenariats sont sélectionnés dans le respect des lois guinéennes et de l’éthique commerciale."),
                small(
                    "Aucune donnée utilisateur n’est transmise à des partenaires sans accord préalable."),

                title("11. Propriété intellectuelle"),
                p(
                    "Tous les éléments de l’application (logo, marque, interface, code source, textes, images, base de données) "
                    "sont protégés par le droit de la propriété intellectuelle et appartiennent à Soneya."),
                small(
                    "Toute reproduction, diffusion ou modification sans autorisation écrite est interdite et expose son auteur à des poursuites."),

                title("12. Responsabilité de Soneya"),
                p(
                    "Soneya s’engage à fournir ses services avec soin et professionnalisme, mais ne garantit pas une disponibilité permanente."),
                p(
                    "Soneya ne saurait être tenue responsable des :"),
                p("• Interruptions temporaires du service ;"),
                p("• Erreurs ou bugs techniques ;"),
                p("• Pertes de données ou d’informations ;"),
                p("• Transactions ou échanges réalisés entre utilisateurs."),
                small(
                    "L’application est utilisée sous la responsabilité exclusive de l’utilisateur."),

                title("13. Sécurité, piratage et fraude"),
                p(
                    "Toute tentative d’accès non autorisé, de piratage, d’ingénierie inverse ou de fraude entraînera une suspension immédiate du compte et un signalement aux autorités."),
                small(
                    "Soneya coopère pleinement avec les forces de l’ordre en cas d’enquête liée à des activités illégales."),

                title("14. Force majeure"),
                p(
                    "Soneya ne pourra être tenue responsable en cas de défaillance liée à un événement de force majeure, "
                    "tel qu’une catastrophe naturelle, une panne de réseau, une grève ou un acte gouvernemental."),
                small("Ces événements suspendent temporairement l’exécution des obligations contractuelles."),

                title("15. Suspension ou résiliation de compte"),
                p(
                    "Soneya se réserve le droit de suspendre ou de supprimer tout compte en cas de violation des CGU, "
                    "de comportement abusif ou d’activité frauduleuse."),
                small(
                    "Aucune compensation financière ne sera accordée en cas de suppression d’un compte pour manquement aux règles."),

                title("16. Évolution des conditions"),
                p(
                    "Soneya peut mettre à jour les présentes CGU à tout moment. "
                    "Les utilisateurs seront informés de toute modification importante via une notification dans l’application."),
                small("L’utilisation continue du service après modification vaut acceptation des nouvelles conditions."),

                title("17. Droit applicable et juridiction compétente"),
                p(
                    "Les présentes CGU sont régies par le droit guinéen. "
                    "Tout différend relatif à leur interprétation ou à leur exécution sera soumis aux tribunaux compétents de la République de Guinée."),
                small("Une résolution amiable est privilégiée avant toute action judiciaire."),

                title("18. Contact et informations légales"),
                p("📧 E-mail : soneya.signaler@gmail.com"),
                p("📍 Siège : Dubréka (Kaléma), République de Guinée"),
                p("👤 Propriétaire et éditeur : Mohamed Camara"),

                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "© ${DateTime.now().year} Soneya – Propriété de Mohamed Camara\nTous droits réservés.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: smallColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
