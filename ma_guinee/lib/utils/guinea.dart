// lib/utils/guinea.dart

/// -------------------------------
/// VILLES / PRÉFECTURES DE GUINÉE
/// -------------------------------
const List<String> villesGN = [
  // Spécial
  'Conakry',
  // Région de Boké
  'Boké','Boffa','Fria','Gaoual','Koundara',
  // Région de Kindia
  'Kindia','Coyah','Dubréka','Forécariah','Télimélé',
  // Région de Labé
  'Labé','Koubia','Lélouma','Mali','Tougué',
  // Région de Mamou
  'Mamou','Dalaba','Pita',
  // Région de Faranah
  'Faranah','Dabola','Dinguiraye','Kissidougou',
  // Région de Kankan
  'Kankan','Kérouané','Kouroussa','Mandiana','Siguiri',
  // Région de Nzérékoré
  'Nzérékoré','Beyla','Guéckédou','Lola','Macenta','Yomou',
];

/// Communes de Conakry (utilisées quand ville == 'Conakry')
const List<String> communesConakry = [
  'Kaloum','Dixinn','Matam','Ratoma','Matoto',
];

/// (Optionnel) Communes par ville si tu veux étendre plus tard.
const Map<String, List<String>> communesByVilleGN = {
  'Conakry': communesConakry,
  // Ailleurs, la “commune urbaine” = la ville elle-même
  'Boké': ['Boké'], 'Boffa': ['Boffa'], 'Fria': ['Fria'], 'Gaoual': ['Gaoual'], 'Koundara': ['Koundara'],
  'Kindia': ['Kindia'], 'Coyah': ['Coyah'], 'Dubréka': ['Dubréka'], 'Forécariah': ['Forécariah'], 'Télimélé': ['Télimélé'],
  'Labé': ['Labé'], 'Koubia': ['Koubia'], 'Lélouma': ['Lélouma'], 'Mali': ['Mali'], 'Tougué': ['Tougué'],
  'Mamou': ['Mamou'], 'Dalaba': ['Dalaba'], 'Pita': ['Pita'],
  'Faranah': ['Faranah'], 'Dabola': ['Dabola'], 'Dinguiraye': ['Dinguiraye'], 'Kissidougou': ['Kissidougou'],
  'Kankan': ['Kankan'], 'Kérouané': ['Kérouané'], 'Kouroussa': ['Kouroussa'], 'Mandiana': ['Mandiana'], 'Siguiri': ['Siguiri'],
  'Nzérékoré': ['Nzérékoré'], 'Beyla': ['Beyla'], 'Guéckédou': ['Guéckédou'], 'Lola': ['Lola'], 'Macenta': ['Macenta'], 'Yomou': ['Yomou'],
};

/// -----------------------------------------
/// CONTRATS (ENUM Postgres + helpers d’affichage)
/// -----------------------------------------
const kContratsDb = <String>[
  'cdi', 'cdd', 'stage', 'freelance', 'apprentissage', 'temps_partiel', 'temps_plein',
];

/// Libellé lisible pour un code de contrat.
String contratLabel(String v) {
  switch (v) {
    case 'cdi': return 'CDI';
    case 'cdd': return 'CDD';
    case 'stage': return 'Stage';
    case 'freelance': return 'Freelance';
    case 'apprentissage': return 'Apprentissage';
    case 'temps_partiel': return 'Temps partiel';
    case 'temps_plein': return 'Temps plein';
    default: return v;
  }
}

/// Si tu reçois un libellé et dois revenir au code ENUM.
String contratCodeFromLabel(String label) {
  switch (label.toLowerCase()) {
    case 'cdi': return 'cdi';
    case 'cdd': return 'cdd';
    case 'stage': return 'stage';
    case 'freelance': return 'freelance';
    case 'apprentissage': return 'apprentissage';
    case 'temps partiel': return 'temps_partiel';
    case 'temps plein': return 'temps_plein';
    default: return label; // renvoie tel quel si déjà un code
  }
}

/// -----------------------------------------
/// DATES
/// -----------------------------------------

/// 'YYYY-MM-DD' (pour colonne DATE)
String? dateForDb(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4,'0')}-'
      '${d.month.toString().padLeft(2,'0')}-'
      '${d.day.toString().padLeft(2,'0')}';
