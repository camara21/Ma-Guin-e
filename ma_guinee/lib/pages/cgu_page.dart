import 'package:flutter/material.dart';

// Couleur principale de l'application (même que Splash / Login)
const Color kAppPrimary = Color(0xFF0175C2);

class CGUPage extends StatelessWidget {
  const CGUPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color smallColor = Colors.grey.shade700;
    final currentYear = DateTime.now().year;

    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: kAppPrimary,
            ),
          ),
        );

    Widget p(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
        );

    Widget small(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              color: smallColor,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conditions Générales d’Utilisation"),
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
      ),
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                small(
                  "Dernière mise à jour : $currentYear\n"
                  "Version 1.0 – République de Guinée",
                ),

                title("1. Présentation de l’application"),
                p(
                  "Soneya est une application mobile et web destinée à faciliter la vie quotidienne des citoyens guinéens. "
                  "Elle regroupe un ensemble de services accessibles depuis une seule plateforme.",
                ),
                p(
                  "Éditeur / Responsable de publication : Soneya (projet). "
                  "Contact : soneya.signaler@gmail.com.",
                ),
                p(
                  "L’application propose : annonces, logement, emplois, restauration, tourismes, "
                  "billetterie, prestataires, hôtels, services administratifs et messagerie sécurisée.",
                ),
                small(
                  "Toute utilisation de Soneya implique l’acceptation pleine et entière des présentes CGU.",
                ),

                title("2. Objet et champ d’application"),
                p(
                  "Les présentes CGU définissent les règles d’utilisation, les droits et les obligations "
                  "applicables entre Soneya et toute personne utilisant l’application, qu’elle soit "
                  "visiteuse ou inscrite.",
                ),

                title("3. Accès et disponibilité"),
                p(
                  "L’accès à l’application Soneya est gratuit. Certaines fonctionnalités nécessitent la création "
                  "d’un compte ou un paiement sécurisé.",
                ),
                small(
                  "Soneya peut suspendre temporairement l’accès au service pour maintenance, mise à jour ou raison de sécurité, "
                  "sans indemnisation.",
                ),

                title("4. Création de compte"),
                p(
                  "Pour accéder à certaines fonctionnalités, l’utilisateur doit créer un compte personnel "
                  "avec des informations exactes, complètes et à jour.",
                ),
                p(
                  "Les identifiants de connexion sont strictement personnels et ne doivent pas être partagés.",
                ),
                small(
                  "Soneya peut suspendre tout compte suspect, frauduleux ou non conforme.",
                ),

                title("5. Comportement et obligations des utilisateurs"),
                p(
                  "Les utilisateurs doivent respecter les lois guinéennes et adopter un comportement responsable et respectueux.",
                ),
                p("Il est strictement interdit de :"),
                p("• Publier des produits interdits (armes, drogues, médicaments non autorisés)."),
                p("• Vendre ou promouvoir alcool, tabac ou produits illicites."),
                p("• Publier du contenu pornographique, violent, haineux ou discriminatoire."),
                p("• Organiser des arnaques, jeux d’argent illégaux ou pratiques frauduleuses."),
                p("• Usurper une identité ou créer de faux comptes."),
                p("• Tenter d’accéder illégalement aux systèmes ou serveurs de Soneya."),
                small(
                  "Toute infraction pourra entraîner la suppression du compte et des poursuites judiciaires.",
                ),

                title("6. Contenus et publications"),
                p(
                  "Chaque utilisateur est entièrement responsable du contenu qu’il publie dans l’application "
                  "(annonces, photos, messages, commentaires).",
                ),
                p(
                  "Soneya se réserve le droit de retirer tout contenu jugé inapproprié, illégal ou contraire à l’éthique.",
                ),
                small(
                  "L’utilisateur garantit que ses contenus ne violent aucun droit d’auteur ni droit à l’image.",
                ),

                // ✅ MIS À JOUR (aligné 18+)
                title("7. Âge requis et protection des mineurs"),
                p(
                  "L’application Soneya est destinée à un public âgé de 18 ans et plus. "
                  "En créant un compte et en utilisant l’application, l’utilisateur déclare avoir l’âge requis.",
                ),
                p(
                  "Nous ne cherchons pas à collecter volontairement des données personnelles concernant des mineurs. "
                  "Si nous constatons qu’un compte est utilisé par une personne n’ayant pas l’âge requis, "
                  "nous pouvons suspendre ou supprimer ce compte et prendre les mesures appropriées.",
                ),
                small(
                  "Si vous êtes parent/tuteur et pensez qu’un mineur a créé un compte, contactez-nous : soneya.signaler@gmail.com.",
                ),

                title("8. Données personnelles et confidentialité"),
                p(
                  "Soneya accorde une importance primordiale à la confidentialité des données. "
                  "Les informations collectées servent uniquement à assurer les services de l’application.",
                ),
                p("Les données peuvent inclure : nom, e-mail, photo, numéro, localisation, etc."),
                p("Elles sont stockées de manière sécurisée et ne sont jamais revendues sans consentement."),
                small(
                  "Pour toute demande liée à vos données : soneya.signaler@gmail.com",
                ),

                title("9. Paiements et transactions"),
                p(
                  "Certaines fonctionnalités peuvent nécessiter un paiement sécurisé via des prestataires "
                  "accrédités. Soneya ne stocke aucune donnée bancaire.",
                ),
                small(
                  "En cas de litige entre utilisateurs, Soneya peut intervenir comme médiateur sans obligation.",
                ),

                title("10. Publicités et partenariats"),
                p(
                  "L’application peut afficher des publicités et contenus sponsorisés. "
                  "Aucune donnée personnelle n’est partagée sans accord explicite.",
                ),

                title("11. Propriété intellectuelle"),
                p(
                  "Le logo, l'interface, les textes, les images, le code source et la base de données "
                  "sont la propriété exclusive de Soneya et protégés par les lois sur la propriété intellectuelle.",
                ),
                small("Toute reproduction non autorisée est interdite."),

                title("12. Responsabilité de Soneya"),
                p("Soneya ne peut être tenue responsable des éléments suivants :"),
                p("• interruptions temporaires du service ;"),
                p("• bugs, erreurs techniques ou pertes de données ;"),
                p("• transactions réalisées entre utilisateurs."),
                small(
                  "L’utilisation de l’application relève de la seule responsabilité de l’utilisateur.",
                ),

                title("13. Sécurité, piratage et fraude"),
                p(
                  "Toute tentative de piratage, fraude, intrusion ou manipulation entraînera la "
                  "suspension immédiate du compte et un signalement aux autorités compétentes.",
                ),

                title("14. Force majeure"),
                p(
                  "Soneya ne pourra être tenue responsable d'un manquement dû à un événement de force majeure "
                  "(catastrophe naturelle, coupure réseau, grève, décision gouvernementale, etc.).",
                ),

                title("15. Suspension ou résiliation de compte"),
                p(
                  "Soneya peut suspendre ou supprimer un compte en cas de non-respect des CGU, "
                  "de comportement abusif ou d'activité frauduleuse.",
                ),
                small(
                  "Aucune compensation ne sera accordée en cas de suppression pour non-respect des règles.",
                ),

                title("16. Évolution des conditions"),
                p(
                  "Soneya peut mettre à jour les présentes CGU. Toute modification importante sera notifiée "
                  "aux utilisateurs via l’application.",
                ),
                small(
                  "L'utilisation continue vaut acceptation des nouvelles conditions.",
                ),

                title("17. Droit applicable et juridiction compétente"),
                p(
                  "Les présentes CGU sont régies par le droit guinéen. En cas de litige, les tribunaux compétents "
                  "de la République de Guinée seront saisis.",
                ),

                title("18. Contact et informations légales"),
                p("📧 E-mail : soneya.signaler@gmail.com"),
                p("📍 Siège : Dubréka (Kaléma), République de Guinée"),
                p("👤 Propriétaire et éditeur : Mohamed Camara"),

                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "© $currentYear Soneya – Propriété de Mohamed Camara\nTous droits réservés.",
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
