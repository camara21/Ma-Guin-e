import 'package:flutter/material.dart';

// Couleur principale de l'application (Splash / Login / Branding)
const Color kAppPrimary = Color(0xFF0175C2);

class PolitiqueConfidentialitePage extends StatelessWidget {
  const PolitiqueConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color smallColor = Colors.grey.shade700;

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
            style: const TextStyle(
              height: 1.45,
              fontSize: 14,
            ),
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

    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Politique de confidentialité"),
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
                  "🔐 POLITIQUE DE CONFIDENTIALITÉ",
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

                // 1. Présentation
                title("1. Qui sommes-nous ?"),
                p(
                  "Soneya est une application mobile et web destinée à faciliter le quotidien des citoyens guinéens. "
                  "Elle regroupe plusieurs services (annonces, logements, hôtels, billetterie, prestataires, lieux, avis, "
                  "messagerie, etc.).",
                ),
                p(
                  "Éditeur / Responsable de publication : Soneya (projet). "
                  "Contact : soneya.signaler@gmail.com.",
                ),
                p(
                  "L’application regroupe plusieurs services, notamment : ANP, Annonces, Prestataires, "
                  "Services Admin, Restaurants, Lieux de culte, Divertissement, Tourisme, Santé, Hôtels, "
                  "Logement, Wali fen, Billetterie et le module Wontanara.",
                ),
                p(
                  "La présente Politique de confidentialité explique comment nous collectons, utilisons, "
                  "stockons et protégeons les données personnelles des utilisateurs de Soneya.",
                ),

                // 2. Données collectées
                title("2. Données personnelles collectées"),
                p(
                  "Selon votre utilisation de l’application, nous pouvons collecter différentes catégories de données personnelles :",
                ),
                p(
                  "• Données d’identification : nom, prénom, adresse e-mail, numéro de téléphone, photo de profil, identifiant utilisateur.\n"
                  "• Données de compte : informations de connexion, préférences, annonces publiées, réservations, candidatures, avis.\n"
                  "• Données de localisation : position approximative ou précise, lorsque vous autorisez l’accès à la géolocalisation.\n"
                  "• Données techniques : adresse IP, modèle d’appareil, système d’exploitation, identifiant de périphérique, logs d’erreurs.\n"
                  "• Données de communication : messages envoyés et reçus via la messagerie interne, pièces jointes (photos, documents).\n"
                  "• Données de notifications : jeton de notification (Firebase Cloud Messaging – FCM) permettant l’envoi de notifications push.",
                ),

                // 3. Collecte
                title("3. Comment vos données sont-elles collectées ?"),
                p("Les données peuvent être collectées :"),
                p(
                  "• Lors de la création ou la mise à jour de votre compte ;\n"
                  "• Lors de la publication d’une annonce, d’un logement, d’un événement ou d’un service ;\n"
                  "• Lors d’une réservation (hôtels, cliniques, prestataires, billetterie, etc.) ;\n"
                  "• Lors de l’utilisation de la messagerie interne ;\n"
                  "• Lors de l’activation de la géolocalisation dans l’application ;\n"
                  "• Par l’intermédiaire de journaux techniques et de mesures de sécurité (logs, détection d’anomalies).",
                ),

                // 4. Finalités
                title("4. À quelles fins utilisons-nous vos données ?"),
                p("Vos données sont utilisées pour :"),
                p(
                  "• Fournir et exploiter l’ensemble des services de l’application Soneya (ANP, Annonces, Prestataires, "
                  "Services Admin, Restaurants, Lieux de culte, Divertissement, Tourisme, Santé, Hôtels, Logement, "
                  "Wali fen, Billetterie, Wontanara) ;\n"
                  "• Créer et gérer votre compte, vos annonces, vos réservations et vos messages ;\n"
                  "• Assurer le bon fonctionnement de la messagerie sécurisée entre utilisateurs ;\n"
                  "• Vous envoyer des notifications pertinentes (nouveaux messages, confirmations, rappels, alertes importantes) ;\n"
                  "• Lutter contre la fraude, les faux comptes, les contenus illégaux ou inappropriés ;\n"
                  "• Améliorer l’application grâce à des statistiques anonymisées ;\n"
                  "• Assurer la sécurité de la plateforme, des utilisateurs et des données.",
                ),
                small(
                  "Nous ne vendons pas vos données personnelles. Elles ne sont utilisées que dans le cadre des services Soneya.",
                ),

                // 5. Base légale
                title("5. Base légale du traitement"),
                p("En fonction du contexte, le traitement de vos données repose sur :"),
                p(
                  "• L’exécution du contrat : fourniture des services Soneya, gestion du compte, des annonces et des réservations ;\n"
                  "• Votre consentement : géolocalisation, notifications push, certaines communications ;\n"
                  "• L’intérêt légitime de Soneya : sécurité, prévention de la fraude, amélioration continue des services ;\n"
                  "• Le respect d’obligations légales ou réglementaires, le cas échéant.",
                ),

                // 6. Partage
                title("6. Avec qui vos données peuvent-elles être partagées ?"),
                p("Vos données peuvent être partagées uniquement dans les cas suivants :"),
                p(
                  "• Prestataires techniques : hébergement (Supabase), notifications (Firebase), services de paiement sécurisés, "
                  "et autres sous-traitants techniques indispensables au fonctionnement de l’application ;\n"
                  "• Partenaires de service : hôtels, cliniques, prestataires, organisateurs d’événements, lorsque cela est nécessaire "
                  "pour traiter une réservation, une demande ou un service que vous avez sollicité ;\n"
                  "• Autorités administratives ou judiciaires : lorsque la loi l’exige ou en cas d’enquête liée à des activités illégales.",
                ),
                small(
                  "Dans tous les cas, seules les données strictement nécessaires sont transmises et aucun partage n’est effectué à des fins de revente.",
                ),

                // 7. Hébergement & sécurité
                title("7. Hébergement et sécurité des données"),
                p(
                  "Les données de Soneya sont principalement hébergées sur la plateforme Supabase, "
                  "qui offre une infrastructure sécurisée (chiffrement, politiques d’accès, journalisation). "
                  "Les jetons de notifications sont gérés via Firebase Cloud Messaging (FCM).",
                ),
                p(
                  "Nous mettons en place des mesures raisonnables pour protéger vos données contre l’accès non autorisé, "
                  "la perte, la modification ou la divulgation non autorisée.",
                ),
                small(
                  "Aucun système n’est totalement invulnérable. L’utilisateur est également responsable de la sécurité de son appareil et de ses identifiants.",
                ),

                // 8. Durée de conservation
                title("8. Durée de conservation des données"),
                p(
                  "Nous conservons vos données personnelles tant que votre compte est actif et pour une durée raisonnable après sa suppression, "
                  "uniquement pour répondre à nos obligations légales, résoudre des litiges ou prévenir des fraudes.",
                ),
                p(
                  "Certaines données peuvent être anonymisées de manière irréversible et conservées à des fins statistiques.",
                ),

                // 9. Droits
                title("9. Vos droits sur vos données"),
                p("Conformément aux lois applicables, vous disposez notamment des droits suivants :"),
                p(
                  "• Droit d’accès : obtenir une copie des données personnelles vous concernant ;\n"
                  "• Droit de rectification : corriger les données inexactes ou incomplètes ;\n"
                  "• Droit à l’effacement : demander la suppression de vos données, dans les limites prévues par la loi ;\n"
                  "• Droit à la limitation : demander une limitation temporaire de l’utilisation de vos données ;\n"
                  "• Droit d’opposition : vous opposer à certains traitements, notamment à des fins de prospection ;\n"
                  "• Droit à la portabilité : obtenir les données que vous avez fournies dans un format structuré, lorsque cela est techniquement possible.",
                ),
                small(
                  "Pour exercer vos droits, vous pouvez nous contacter à l’adresse : soneya.signaler@gmail.com.",
                ),

                // 10. Compte & suppression
                title("10. Compte utilisateur et suppression"),
                p(
                  "Vous pouvez demander la suppression de votre compte directement depuis l’application (lorsque cette option est disponible) "
                  "ou en nous contactant par e-mail. La suppression de votre compte entraîne la désactivation de vos accès et, à terme, "
                  "la suppression ou l’anonymisation de vos données, sous réserve de nos obligations légales.",
                ),

                // 11. Mineurs (corrigé pour 18+)
                title("11. Protection des mineurs"),
                p(
                  "L’application Soneya est destinée à un public âgé de 18 ans et plus. "
                  "Nous ne cherchons pas à collecter volontairement des données personnelles concernant des mineurs.",
                ),
                p(
                  "Si nous constatons qu’un compte est utilisé par une personne n’ayant pas l’âge requis, "
                  "nous pouvons suspendre ou supprimer ce compte et prendre les mesures appropriées, conformément aux règles applicables.",
                ),
                small(
                  "Si vous êtes parent/tuteur et pensez qu’un mineur nous a transmis des données, contactez-nous : soneya.signaler@gmail.com.",
                ),

                // 12. Notifications
                title("12. Notifications push"),
                p(
                  "Avec votre accord, Soneya peut vous envoyer des notifications push (nouveaux messages, rappels de réservation, "
                  "alertes importantes concernant vos activités dans l’application).",
                ),
                p(
                  "Vous pouvez à tout moment désactiver les notifications dans les paramètres de votre appareil ou de l’application.",
                ),

                // 13. Cookies / stockage local
                title("13. Cookies, traceurs et stockage local"),
                p(
                  "Soneya peut utiliser des mécanismes de stockage local ou des traceurs techniques afin de :",
                ),
                p(
                  "• maintenir votre session ;\n"
                  "• mémoriser certaines préférences ;\n"
                  "• garantir la sécurité et la prévention de la fraude ;\n"
                  "• réaliser des statistiques d’utilisation anonymisées.",
                ),
                small(
                  "Nous n’utilisons pas de cookies publicitaires au sein de l’application mobile.",
                ),

                // 14. Évolutions
                title("14. Modifications de la présente politique"),
                p(
                  "Nous pouvons mettre à jour la présente Politique de confidentialité pour refléter l’évolution de l’application, "
                  "de nos pratiques ou de la réglementation.",
                ),
                p(
                  "En cas de modification importante, une information sera affichée au sein de l’application.",
                ),

                // 15. Contact
                title("15. Contact"),
                p("Pour toute question relative à vos données personnelles ou à cette politique :"),
                p("📧 E-mail : soneya.signaler@gmail.com"),
                p("📍 Localisation : Dubréka (Kaléma), République de Guinée"),
                p("👤 Responsable : Mohamed Camara"),

                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "© $currentYear Soneya – Politique de confidentialité\nTous droits réservés.",
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
