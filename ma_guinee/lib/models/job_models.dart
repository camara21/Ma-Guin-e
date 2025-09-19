class EmployeurModel {
  final String id, nom;
  final String? logoUrl, ville, commune;
  EmployeurModel({required this.id, required this.nom, this.logoUrl, this.ville, this.commune});
  factory EmployeurModel.from(Map m) => EmployeurModel(
    id: m['id'], nom: m['nom'], logoUrl: m['logo_url'],
    ville: m['ville'], commune: m['commune']
  );
}

class EmploiModel {
  final String id, titre, employeurId, typeContrat, periodeSalaire, ville;
  final String? commune, description, exigences, avantages;
  final bool teletravail;
  final num? salMin, salMax;
  final DateTime creeLe;
  final DateTime? dateLimite;

  EmploiModel({
    required this.id, required this.titre, required this.employeurId,
    required this.ville, this.commune, required this.typeContrat,
    this.salMin, this.salMax, this.periodeSalaire='mois',
    this.teletravail=false, this.description, this.exigences, this.avantages,
    required this.creeLe, this.dateLimite,
  });

  factory EmploiModel.from(Map m) => EmploiModel(
    id: m['id'],
    titre: m['titre'],
    employeurId: m['employeur_id'],
    ville: m['ville'],
    commune: m['commune'],
    typeContrat: m['type_contrat'],
    salMin: m['salaire_min_gnf'],
    salMax: m['salaire_max_gnf'],
    periodeSalaire: m['periode_salaire'] ?? 'mois',
    teletravail: m['teletravail'] ?? false,
    description: m['description'],
    exigences: m['exigences'],
    avantages: m['avantages'],
    creeLe: DateTime.parse(m['cree_le']),
    dateLimite: m['date_limite'] != null ? DateTime.parse(m['date_limite']) : null,
  );
}

class CandidatureModel {
  final String id, emploiId, statut;
  final DateTime creeLe;
  final String? cvUrl, lettre, telephone, email;
  CandidatureModel({
    required this.id, required this.emploiId, required this.statut,
    required this.creeLe, this.cvUrl, this.lettre, this.telephone, this.email
  });
  factory CandidatureModel.from(Map m) => CandidatureModel(
    id: m['id'],
    emploiId: m['emploi_id'],
    statut: m['statut'],
    creeLe: DateTime.parse(m['cree_le']),
    cvUrl: m['cv_url'],
    lettre: m['lettre'],
    telephone: m['telephone'],
    email: m['email'],
  );
}
