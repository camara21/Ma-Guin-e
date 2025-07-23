import 'dart:convert';

class AnnonceModel {
  final String id;
  final String userId;
  final String titre;
  final String description;
  final String categorie;
  final int? categorieId;
  final String ville;
  final double prix;
  final String telephone;
  final List<String> images;
  final String devise;
  bool estFavori;

  AnnonceModel({
    required this.id,
    required this.userId,
    required this.titre,
    required this.description,
    required this.categorie,
    this.categorieId,
    required this.ville,
    required this.prix,
    required this.telephone,
    required this.images,
    this.devise = 'GNF',
    this.estFavori = false,
  });

  /// Helper pour parser un double
  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
    }

  /// Helper pour parser une liste d’images
  static List<String> _toImages(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        return List<String>.from(jsonDecode(raw));
      } catch (_) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return <String>[];
  }

  factory AnnonceModel.fromJson(Map<String, dynamic> json) => AnnonceModel(
        id: (json['id'] ?? '').toString(),
        userId: (json['user_id'] ?? '').toString(),
        titre: json['titre'] ?? '',
        description: json['description'] ?? '',
        categorie: json['categorie'] ?? '',
        categorieId: json['categorie_id'] is int
            ? json['categorie_id'] as int
            : int.tryParse(json['categorie_id']?.toString() ?? ''),
        ville: json['ville'] ?? '',
        prix: _toDouble(json['prix']),
        telephone: json['telephone'] ?? '',
        images: _toImages(json['images']),
        devise: json['devise'] ?? 'GNF',
        estFavori: json['estFavori'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'titre': titre,
        'description': description,
        'categorie': categorie,
        'categorie_id': categorieId,
        'ville': ville,
        'prix': prix,
        'telephone': telephone,
        'images': images,
        'devise': devise,
        'estFavori': estFavori,
      };

  /// Copie modifiable
  AnnonceModel copyWith({
    String? id,
    String? userId,
    String? titre,
    String? description,
    String? categorie,
    int? categorieId,
    String? ville,
    double? prix,
    String? telephone,
    List<String>? images,
    String? devise,
    bool? estFavori,
  }) {
    return AnnonceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      categorie: categorie ?? this.categorie,
      categorieId: categorieId ?? this.categorieId,
      ville: ville ?? this.ville,
      prix: prix ?? this.prix,
      telephone: telephone ?? this.telephone,
      images: images ?? this.images,
      devise: devise ?? this.devise,
      estFavori: estFavori ?? this.estFavori,
    );
  }
}
