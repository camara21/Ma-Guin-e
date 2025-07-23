class UtilisateurModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String pays;
  final String telephone;
  final String genre;
  final String? photoUrl;
  final DateTime? dateInscription;
  final DateTime? dateNaissance;
  final List<String> favoris;

  // Extensions pour les espaces gérés :
  final Map<String, dynamic>? espacePrestataire;
  final Map<String, dynamic>? resto;
  final Map<String, dynamic>? hotel;
  final Map<String, dynamic>? clinique;
  final List<Map<String, dynamic>> annonces;

  UtilisateurModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.pays,
    required this.telephone,
    required this.genre,
    this.photoUrl,
    this.dateInscription,
    this.dateNaissance,
    this.favoris = const [],
    this.espacePrestataire,
    this.resto,
    this.hotel,
    this.clinique,
    this.annonces = const [],
  });

  factory UtilisateurModel.fromJson(Map<String, dynamic> json) {
    return UtilisateurModel(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'] ?? '',
      pays: json['pays'] ?? '',
      telephone: json['telephone'] ?? '',
      genre: json['genre'] ?? '',
      photoUrl: json['photo_url'],
      dateInscription: json['date_inscription'] != null
          ? DateTime.tryParse(json['date_inscription'])
          : null,
      dateNaissance: json['date_naissance'] != null
          ? DateTime.tryParse(json['date_naissance'])
          : null,
      favoris: (json['favoris'] as List?)?.map((e) => e.toString()).toList() ?? [],
      espacePrestataire: json['espace_prestataire'] as Map<String, dynamic>?,
      resto: json['resto'] as Map<String, dynamic>?,
      hotel: json['hotel'] as Map<String, dynamic>?,
      clinique: json['clinique'] as Map<String, dynamic>?,
      annonces: (json['annonces'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'pays': pays,
      'telephone': telephone,
      'genre': genre,
      'photo_url': photoUrl,
      'date_inscription': dateInscription?.toIso8601String(),
      'date_naissance': dateNaissance?.toIso8601String(),
      'favoris': favoris,
      'espace_prestataire': espacePrestataire,
      'resto': resto,
      'hotel': hotel,
      'clinique': clinique,
      'annonces': annonces,
    };
  }
}
