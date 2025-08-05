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
          ExpansionTile(
            title: Text("Comment publier une annonce ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "1. Ouvrez l’onglet Annonces.\n"
                  "2. Appuyez sur le bouton « Publier ».\n"
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
                  "3. Sélectionnez un restaurant pour voir son profil et ses avis.\n"
                  "4. Contactez-le directement pour réserver.",
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
                  "2. Explorez les établissements disponibles.\n"
                  "3. Consultez les détails et photos.\n"
                  "4. Contactez l’hôtel pour la réservation.",
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
                  "3. Visualisez les coordonnées et spécialités.\n"
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
                  "2. Touchez un marqueur pour voir les détails.\n"
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
                  "3. Zoomez et déplacez la carte pour explorer votre zone.\n"
                  "4. Sélectionnez un point pour accéder aux détails.",
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
                  "1. Pour ajouter aux favoris, appuyez sur l’icône ❤️.\n"
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
                  "Toutes vos conversations sont dans l’onglet Messages, sur la barre de navigation.",
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
                  "Dans Profil → Mes annonces, vous pouvez voir, modifier ou supprimer vos annonces.",
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
                  "contactez l’administrateur à : administration@gmail.com",
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Problème ou suggestion ?"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Contactez-nous à : support@gmail.com\n"
                  "Nous vous répondrons dans les plus brefs délais.",
                ),
              ),
            ],
          ),
          Divider(),
          ExpansionTile(
            title: Text("Politique de confidentialité"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Nous collectons les données strictement nécessaires à l’utilisation des services de l'application Ma Guinée, "
                  "telles que nom, prénom, téléphone, e-mail, ville, ainsi que les contenus publiés par les utilisateurs. "
                  "Ces données ne sont ni revendues ni partagées à des tiers sans consentement explicite. "
                  "Elles servent uniquement à l’exploitation de la plateforme (annonces, géolocalisation, messagerie, recommandations). "
                  "Chaque utilisateur peut demander la suppression de ses données en nous contactant à support@gmail.com."
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Mentions légales"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "L’application Ma Guinée est éditée par Mohamed Camara. Tous les contenus proposés (textes, images, annonces, profils, etc.) "
                  "sont soumis à modération et propriété de leurs auteurs respectifs. "
                  "Toute reproduction ou diffusion sans autorisation est interdite. Pour toute question juridique : administration@gmail.com."
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Politique de modération"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Les contenus sont vérifiés par notre équipe afin de garantir le respect des lois et des règles communautaires. "
                  "Tout contenu abusif, frauduleux, offensant ou contraire aux lois en vigueur sera immédiatement supprimé. "
                  "Les utilisateurs peuvent signaler un contenu via les boutons prévus à cet effet ou par mail à : signalement@ma-guinee.com."
                ),
              ),
            ],
          ),
          ExpansionTile(
            title: Text("Charte d’utilisation"),
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "En utilisant l’application Ma Guinée, vous vous engagez à :\n"
                  "- Fournir des informations exactes et à jour.\n"
                  "- Ne publier aucun contenu illicite, haineux ou diffamatoire.\n"
                  "- Respecter les autres utilisateurs et ne pas harceler.\n"
                  "- Ne pas créer de faux comptes ou d’usurpation d’identité.\n\n"
                  "Tout manquement pourra entraîner une suspension ou suppression de compte."
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
