class PrestataireModel {
  final String nom;
  final String specialite;
  final String ville;
  final String image;
  final String categorie;
  final String telephone;
  final String? whatsapp;
  final double? note;

  PrestataireModel({
    required this.nom,
    required this.specialite,
    required this.ville,
    required this.image,
    required this.categorie,
    required this.telephone,
    this.whatsapp,
    this.note,
  });

  factory PrestataireModel.fromJson(Map<String, dynamic> json) {
    return PrestataireModel(
      nom: json['nom'],
      specialite: json['specialite'],
      ville: json['ville'],
      image: json['image'],
      categorie: json['categorie'],
      telephone: json['telephone'],
      whatsapp: json['whatsapp'],
      note: (json['note'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'specialite': specialite,
      'ville': ville,
      'image': image,
      'categorie': categorie,
      'telephone': telephone,
      'whatsapp': whatsapp,
      'note': note,
    };
  }
}
