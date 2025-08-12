import 'package:flutter/material.dart';

class AidePage extends StatelessWidget {
  const AidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Aide & FAQ",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.6,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          // ——— Annonces & Services ———
          ExpansionTile(
            title: Text("Comment publier une annonce ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Ouvrez l’onglet Annonces.\n"
                  "2. Appuyez sur « Publier ».\n"
                  "3. Remplissez le formulaire (catégorie, titre, description, photos, prix, ville).\n"
                  "4. Validez pour mettre en ligne.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment contacter un annonceur ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Sur la page de l’annonce, appuyez sur « Contacter ».\n"
                  "2. Vous pouvez aussi appeler ou envoyer un message WhatsApp.\n"
                  "3. Retrouvez toutes vos conversations dans l’onglet Messages.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment trouver et réserver un restaurant ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Allez dans l’onglet Restaurants.\n"
                  "2. Parcourez la liste ou utilisez la carte interactive.\n"
                  "3. Ouvrez la fiche pour voir profil et avis.\n"
                  "4. Contactez le restaurant pour réserver.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment réserver un hôtel ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Rendez-vous dans l’onglet Hôtels.\n"
                  "2. Explorez les établissements.\n"
                  "3. Consultez détails et photos.\n"
                  "4. Contactez l’hôtel pour réserver.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment découvrir des activités touristiques ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Ouvrez l’onglet Tourisme & Loisirs.\n"
                  "2. Découvrez circuits, événements et bons plans.\n"
                  "3. Cliquez sur une activité pour plus d’infos et contact.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment trouver une clinique ou un centre de santé ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Accédez à l’onglet Santé & Bien-être.\n"
                  "2. Sélectionnez « Cliniques ».\n"
                  "3. Visualisez coordonnées et spécialités.\n"
                  "4. Contactez la clinique directement.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment localiser un lieu de culte ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Dans l’onglet Carte, activez le filtre « Lieux de culte ».\n"
                  "2. Touchez un marqueur pour les détails.\n"
                  "3. Obtenez l’itinéraire via votre GPS.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment utiliser la carte interactive ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Ouvrez l’onglet Carte.\n"
                  "2. Activez/désactivez les couches (restaurants, hôtels, prestataires…).\n"
                  "3. Zoomez/déplacez la carte pour explorer.\n"
                  "4. Sélectionnez un point pour voir les détails.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment gérer mes favoris ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Pour ajouter aux favoris, appuyez sur ❤️.\n"
                  "2. Retrouvez-les dans l’onglet Favoris.\n"
                  "3. Pour retirer, appuyez de nouveau sur ❤️.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Où retrouver mes messages ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Vos conversations sont dans l’onglet Messages (barre de navigation).",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment modifier mon profil ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Allez dans l’onglet Profil.\n"
                  "2. Appuyez sur « Modifier mon compte ».\n"
                  "3. Mettez à jour vos informations et enregistrez.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Comment voir mes annonces publiées ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Profil → Mes annonces : voir, modifier ou supprimer vos annonces.",
                ),
              ),
            ],
          ),

          // ——— Billetterie (NOUVEAU) ———
          ExpansionTile(
            title: Text("Billetterie — Comment acheter un billet ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Ouvrez l’onglet Événements / Billetterie.\n"
                  "2. Choisissez un événement et un type de billet.\n"
                  "3. Validez le panier puis payez (méthodes disponibles affichées).\n"
                  "4. Recevez votre billet (QR code / code) dans « Mes billets » et par e-mail.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Billetterie — Où retrouver mes billets ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Allez dans Profil → Mes billets.\n"
                  "2. Le billet contient un QR code / code unique à présenter à l’entrée.\n"
                  "3. Vous pouvez télécharger ou partager votre billet depuis la fiche.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Billetterie — Vendre des billets (organisateurs)"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Demandez l’accès Organisateur : administration@ma-guinee.com.\n"
                  "2. Créez l’événement (infos, visuel, capacité, catégories de billets, prix, dates).\n"
                  "3. Suivez les ventes en temps réel et téléchargez la liste d’accès.\n"
                  "4. Contrôlez les entrées avec le scan QR via l’app.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Billetterie — Annulation & remboursement"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "• Les conditions d’annulation sont définies par l’organisateur et affichées sur la fiche événement.\n"
                  "• En cas d’événement annulé, un e-mail d’information est envoyé et le remboursement est traité selon le moyen de paiement d’origine.\n"
                  "• Pour toute demande : support@ma-guinee.com (joindre n° de commande).",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Billetterie — Problème de paiement"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "• Vérifiez votre connexion et votre solde / plafond.\n"
                  "• Réessayez ou essayez un autre moyen de paiement.\n"
                  "• Si le débit est passé sans billet, contactez support@ma-guinee.com avec le reçu.",
                ),
              ),
            ],
          ),

          // ——— Support ———
          ExpansionTile(
            title: Text("Problème ou suggestion ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Contactez-nous : support@ma-guinee.com\n"
                  "Nous vous répondrons dans les meilleurs délais.",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Administration"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Pour toute question relative à la gestion de la plateforme (signalement, contenu abusif, droits d’accès), "
                  "écrivez à : administration@ma-guinee.com",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
