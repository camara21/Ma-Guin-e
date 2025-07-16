class AnnonceModel {
  final String id;
  final String titre;
  final String description;
  final String categorie;
  final double prix;
  final String ville;
  final List<String> images;
  final String userId;
  final DateTime createdAt;
  final String telephone; // ✅ ajouté

  AnnonceModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.categorie,
    required this.prix,
    required this.ville,
    required this.images,
    required this.userId,
    required this.createdAt,
    required this.telephone, // ✅ ajouté
  });

  AnnonceModel copyWith({
    String? id,
    String? titre,
    String? description,
    String? categorie,
    double? prix,
    String? ville,
    List<String>? images,
    String? userId,
    DateTime? createdAt,
    String? telephone, // ✅ ajouté
  }) {
    return AnnonceModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      categorie: categorie ?? this.categorie,
      prix: prix ?? this.prix,
      ville: ville ?? this.ville,
      images: images ?? this.images,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      telephone: telephone ?? this.telephone, // ✅ ajouté
    );
  }

  factory AnnonceModel.fromJson(Map<String, dynamic> json) {
    return AnnonceModel(
      id: json['id'],
      titre: json['titre'],
      description: json['description'],
      categorie: json['categorie'],
      prix: (json['prix'] as num).toDouble(),
      ville: json['ville'],
      images: List<String>.from(json['images']),
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      telephone: json['telephone'] ?? '', // ✅ ajouté
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titre': titre,
      'description': description,
      'categorie': categorie,
      'prix': prix,
      'ville': ville,
      'images': images,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'telephone': telephone, // ✅ ajouté
    };
  }
}
