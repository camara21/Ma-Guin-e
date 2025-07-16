class UtilisateurModel {
  final String id;
  final String nom;
  final String prenom; // ✅ AJOUTÉ
  final String email;
  final String telephone;
  final String pays;
  final String? genre;
  final String? photoUrl;
  final DateTime? dateInscription;

  UtilisateurModel({
    required this.id,
    required this.nom,
    required this.prenom, // ✅ AJOUTÉ
    required this.email,
    required this.telephone,
    required this.pays,
    this.genre,
    this.photoUrl,
    this.dateInscription,
  });

  factory UtilisateurModel.fromJson(Map<String, dynamic> json) {
    return UtilisateurModel(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '', // ✅ AJOUTÉ
      email: json['email'] ?? '',
      telephone: json['telephone'] ?? '',
      pays: json['pays'] ?? '',
      genre: json['genre'],
      photoUrl: json['photoUrl'],
      dateInscription: json['dateInscription'] != null
          ? DateTime.tryParse(json['dateInscription'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom, // ✅ AJOUTÉ
      'email': email,
      'telephone': telephone,
      'pays': pays,
      'genre': genre,
      'photoUrl': photoUrl,
      'dateInscription': dateInscription?.toIso8601String(),
    };
  }

  UtilisateurModel copyWith({
    String? id,
    String? nom,
    String? prenom, // ✅ AJOUTÉ
    String? email,
    String? telephone,
    String? pays,
    String? genre,
    String? photoUrl,
    DateTime? dateInscription,
  }) {
    return UtilisateurModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom, // ✅ AJOUTÉ
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      pays: pays ?? this.pays,
      genre: genre ?? this.genre,
      photoUrl: photoUrl ?? this.photoUrl,
      dateInscription: dateInscription ?? this.dateInscription,
    );
  }
}
