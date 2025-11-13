// lib/pages/wontanara/models.dart

// ===================== PUBLICATION =====================
// Utilisée pour les actualités / infos locales / alertes / etc.

class Publication {
  final String id;
  final String zoneId;

  /// info_locale, alerte, entraide, service_local, collecte, vote, actualite_verifiee
  final String type;

  final String titre;
  final String? contenu;

  final DateTime createdAt;
  final DateTime? expiresAt;

  // --- Nouveaux champs pour la version prod ---
  /// Nom de l’auteur (citoyen, mairie, entreprise…)
  final String? auteurNom;

  /// Libellé lisible de la zone (quartier, commune…)
  final String? zoneLabel;

  /// Distance (en km) par rapport à l’utilisateur, si calculée côté SQL
  final double? distanceKm;

  /// Liste d’URL d’images (max 5 dans l’UI)
  final List<String> photos;

  /// true si l’actualité est vérifiée / officielle
  final bool verifiee;

  Publication({
    required this.id,
    required this.zoneId,
    required this.type,
    required this.titre,
    this.contenu,
    required this.createdAt,
    this.expiresAt,
    this.auteurNom,
    this.zoneLabel,
    this.distanceKm,
    this.photos = const [],
    this.verifiee = false,
  });

  factory Publication.fromMap(Map<String, dynamic> m) {
    // photos peut être une liste JSON, une string séparée par des virgules, etc.
    final rawPhotos = m['photos'];
    List<String> photos = const [];

    if (rawPhotos is List) {
      photos = rawPhotos.map((e) => e.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.trim().isNotEmpty) {
      photos = rawPhotos.split(',').map((e) => e.trim()).toList();
    }

    return Publication(
      id: m['id'].toString(),
      zoneId: m['zone_id'].toString(),
      type: m['type']?.toString() ?? '',
      titre: m['titre']?.toString() ?? '',
      contenu: m['contenu'] as String?,
      createdAt: DateTime.parse(m['created_at'].toString()),
      expiresAt: m['expires_at'] != null
          ? DateTime.parse(m['expires_at'].toString())
          : null,
      auteurNom: m['auteur_nom']?.toString(),
      zoneLabel: m['zone_label']?.toString(),
      distanceKm: m['distance_km'] != null
          ? (m['distance_km'] as num).toDouble()
          : null,
      photos: photos,
      verifiee: (m['verifiee'] as bool?) ?? false,
    );
  }
}

// ===================== MESSAGE (CHAT) =====================

class Message {
  final String id;
  final String roomId;
  final String? senderId;
  final String contenu;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    this.senderId,
    required this.contenu,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'].toString(),
        roomId: m['room_id'].toString(),
        senderId: m['sender_id']?.toString(),
        contenu: m['contenu']?.toString() ?? '',
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

// ===================== SERVICE LOCAL =====================
// (Marketplace de services locaux si tu en as besoin plus tard)

class ServiceLocal {
  final String id;
  final String userId;
  final String zoneId;
  final String categorie;
  final String? description;
  final String? tarif;
  final bool dispo;
  final num fiabilite;

  ServiceLocal({
    required this.id,
    required this.userId,
    required this.zoneId,
    required this.categorie,
    this.description,
    this.tarif,
    required this.dispo,
    required this.fiabilite,
  });

  factory ServiceLocal.fromMap(Map<String, dynamic> m) => ServiceLocal(
        id: m['id'].toString(),
        userId: m['user_id'].toString(),
        zoneId: m['zone_id'].toString(),
        categorie: m['categorie']?.toString() ?? '',
        description: m['description'] as String?,
        tarif: m['tarif'] as String?,
        dispo: (m['disponibilite'] as bool?) ?? false,
        fiabilite: m['fiabilite'] ?? 0,
      );
}

// ===================== DEMANDE D’AIDE =====================
// Utilisée par la page Entraide (chat éphémère 48h)

class DemandeAide {
  final String id;
  final String zoneId;
  final String userId;
  final String titre;
  final String? description;

  /// ouverte, en_cours, terminee, expiree…
  final String statut;

  /// Points de réputation gagnés si quelqu’un aide
  final int reputation;

  /// Date de création
  final DateTime createdAt;

  /// Date d’expiration de la demande (pour fermer le chat)
  final DateTime? expiresAt;

  /// Distance en km par rapport à l’utilisateur (optionnel)
  final double? distanceKm;

  DemandeAide({
    required this.id,
    required this.zoneId,
    required this.userId,
    required this.titre,
    this.description,
    required this.statut,
    required this.reputation,
    required this.createdAt,
    this.expiresAt,
    this.distanceKm,
  });

  factory DemandeAide.fromMap(Map<String, dynamic> m) => DemandeAide(
        id: m['id'].toString(),
        zoneId: m['zone_id'].toString(),
        userId: m['user_id'].toString(),
        titre: m['titre']?.toString() ?? '',
        description: m['description'] as String?,
        statut: m['statut']?.toString() ?? '',
        reputation: (m['reputation'] as int?) ?? 0,
        createdAt: DateTime.parse(m['created_at'].toString()),
        expiresAt: m['expires_at'] != null
            ? DateTime.parse(m['expires_at'].toString())
            : null,
        distanceKm: m['distance_km'] != null
            ? (m['distance_km'] as num).toDouble()
            : null,
      );
}

// ===================== VOTES =====================

class VoteItem {
  final String id;
  final String zoneId;
  final String titre;
  final String? description;
  final String mode; // public, verifie, qr_local
  final String statut; // brouillon, ouvert, ferme, resultats

  VoteItem({
    required this.id,
    required this.zoneId,
    required this.titre,
    this.description,
    required this.mode,
    required this.statut,
  });

  factory VoteItem.fromMap(Map<String, dynamic> m) => VoteItem(
        id: m['id'].toString(),
        zoneId: m['zone_id'].toString(),
        titre: m['titre']?.toString() ?? '',
        description: m['description'] as String?,
        mode: m['mode']?.toString() ?? '',
        statut: m['statut']?.toString() ?? '',
      );
}

class VoteOption {
  final String id;
  final String voteId;
  final String libelle;
  final int ordre;

  VoteOption({
    required this.id,
    required this.voteId,
    required this.libelle,
    required this.ordre,
  });

  factory VoteOption.fromMap(Map<String, dynamic> m) => VoteOption(
        id: m['id'].toString(),
        voteId: m['vote_id'].toString(),
        libelle: m['libelle']?.toString() ?? '',
        ordre: (m['ordre'] as int?) ?? 0,
      );
}

// ===================== COLLECTE (signalements simples) =====================
// Ancien modèle, peut encore servir pour afficher l’historique.

class Collecte {
  final String id;
  final String zoneId;
  final String type; // menager, plastique, verre, mixte
  final String statut; // signalee, prise_en_charge, nettoyee
  final DateTime createdAt;

  Collecte({
    required this.id,
    required this.zoneId,
    required this.type,
    required this.statut,
    required this.createdAt,
  });

  factory Collecte.fromMap(Map<String, dynamic> m) => Collecte(
        id: m['id'].toString(),
        zoneId: m['zone_id'].toString(),
        type: m['type']?.toString() ?? '',
        statut: m['statut']?.toString() ?? '',
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

// ===================== COLLECTE — BUSINESS / ABONNEMENTS =====================
// Pour ton vrai système d’abonnement citoyen ↔ entreprise de ramassage.

class OffreCollecte {
  final String id;
  final String prestataireId;
  final String zoneId;

  /// Nom du prestataire (entreprise, jeune entrepreneur…)
  final String prestataireNom;

  /// menager, mixte, pro, etc.
  final String type;

  /// Hebdo, 2x/semaine, mensuel, etc.
  final String frequence;

  final String? description;

  /// Prix mensuel en GNF (ou autre)
  final num prixMensuel;

  /// Note moyenne (1–5) si tu gères les avis
  final num? note;

  OffreCollecte({
    required this.id,
    required this.prestataireId,
    required this.zoneId,
    required this.prestataireNom,
    required this.type,
    required this.frequence,
    this.description,
    required this.prixMensuel,
    this.note,
  });

  factory OffreCollecte.fromMap(Map<String, dynamic> m) => OffreCollecte(
        id: m['id'].toString(),
        prestataireId: m['prestataire_id'].toString(),
        zoneId: m['zone_id'].toString(),
        prestataireNom: m['prestataire_nom']?.toString() ?? '',
        type: m['type']?.toString() ?? '',
        frequence: m['frequence']?.toString() ?? '',
        description: m['description'] as String?,
        prixMensuel: m['prix_mensuel'] ?? 0,
        note: m['note'] as num?,
      );
}

class AbonnementCollecte {
  final String id;
  final String userId;
  final String offreId;
  final String adresse;

  /// actif, suspendu, resilie
  final String statut;

  final DateTime createdAt;
  final DateTime? nextPassage;

  AbonnementCollecte({
    required this.id,
    required this.userId,
    required this.offreId,
    required this.adresse,
    required this.statut,
    required this.createdAt,
    this.nextPassage,
  });

  factory AbonnementCollecte.fromMap(Map<String, dynamic> m) =>
      AbonnementCollecte(
        id: m['id'].toString(),
        userId: m['user_id'].toString(),
        offreId: m['offre_id'].toString(),
        adresse: m['adresse']?.toString() ?? '',
        statut: m['statut']?.toString() ?? '',
        createdAt: DateTime.parse(m['created_at'].toString()),
        nextPassage: m['next_passage'] != null
            ? DateTime.parse(m['next_passage'].toString())
            : null,
      );
}
