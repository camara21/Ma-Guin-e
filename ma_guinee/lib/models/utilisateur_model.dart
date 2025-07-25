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

  final Map<String, dynamic>? espacePrestataire;
  final List<Map<String, dynamic>> restos;
  final List<Map<String, dynamic>> hotels;
  final List<Map<String, dynamic>> cliniques;
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
    this.restos = const [],
    this.hotels = const [],
    this.cliniques = const [],
    this.annonces = const [],
  });

  factory UtilisateurModel.fromJson(Map<String, dynamic> json) {
    print("🧩 Données reçues du backend :");
    print(json);

    List<Map<String, dynamic>> extractList(String key) {
      final list = json[key];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    final prestataire = json['espacePrestataire'];
    final restos = extractList('restos');
    final hotels = extractList('hotels');
    final cliniques = extractList('cliniques');

    print("📦 Prestataire : $prestataire");
    print("🍽️ Restos : $restos");
    print("🏨 Hotels : $hotels");
    print("🏥 Cliniques : $cliniques");

    return UtilisateurModel(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      email: json['email'] as String? ?? '',
      pays: json['pays'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      dateInscription: json['date_inscription'] != null
          ? DateTime.tryParse(json['date_inscription'] as String)
          : null,
      dateNaissance: json['date_naissance'] != null
          ? DateTime.tryParse(json['date_naissance'] as String)
          : null,
      favoris: (json['favoris'] as List?)?.map((e) => e.toString()).toList() ?? [],
      espacePrestataire: prestataire != null
          ? Map<String, dynamic>.from(prestataire)
          : null,
      restos: restos,
      hotels: hotels,
      cliniques: cliniques,
      annonces: extractList('annonces'),
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
      'espacePrestataire': espacePrestataire,
      'restos': restos,
      'hotels': hotels,
      'cliniques': cliniques,
      'annonces': annonces,
    };
  }
}
