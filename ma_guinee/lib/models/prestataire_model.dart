class PrestataireModel {
  final String id;
  final String userId;
  final String metier;
  final String category;
  final String ville;
  final String phone;
  final String description;
  final String photoUrl;
  final double? noteMoyenne; // si tu l’utilises

  PrestataireModel({
    required this.id,
    required this.userId,
    required this.metier,
    required this.category,
    required this.ville,
    required this.phone,
    required this.description,
    required this.photoUrl,
    this.noteMoyenne,
  });

  factory PrestataireModel.fromJson(Map<String, dynamic> json) {
    return PrestataireModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      metier: (json['metier'] ?? json['job'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      ville: (json['ville'] ?? '').toString(),
      phone: (json['phone'] ?? json['telephone'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      photoUrl: (json['photo_url'] ?? json['image'] ?? '').toString(),
      noteMoyenne: json['note_moyenne'] == null
          ? null
          : (json['note_moyenne'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'metier': metier,
        'category': category,
        'ville': ville,
        'phone': phone,
        'description': description,
        'photo_url': photoUrl,
        'note_moyenne': noteMoyenne,
      };
}
