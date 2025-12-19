// lib/education/education_donnees.dart
//
// Données statiques V1 (Guinée) — 20 questions par catégorie.
// ✅ Multi-réponses : indicesBonnesReponses peut contenir 1 ou plusieurs indices.
// ✅ Pas de "const evaluation error" (on utilise static final, pas static const).

class CategorieQuiz {
  final String id;
  final String titre;
  final String description;

  const CategorieQuiz({
    required this.id,
    required this.titre,
    required this.description,
  });
}

class QuestionQuiz {
  final String id;
  final String categorieId;
  final String question;
  final List<String> choix;
  final List<int> indicesBonnesReponses;
  final String explication;

  const QuestionQuiz({
    required this.id,
    required this.categorieId,
    required this.question,
    required this.choix,
    required this.indicesBonnesReponses,
    required this.explication,
  }) : assert(indicesBonnesReponses.length > 0,
            'indicesBonnesReponses ne peut pas être vide');

  bool get estMultiChoix => indicesBonnesReponses.length > 1;

  bool estBonneReponseIndex(int i) => indicesBonnesReponses.contains(i);

  /// Vrai si la sélection correspond EXACTEMENT aux bonnes réponses.
  bool selectionEstParfaite(Set<int> selection) {
    if (selection.length != indicesBonnesReponses.length) return false;
    for (final idx in indicesBonnesReponses) {
      if (!selection.contains(idx)) return false;
    }
    return true;
  }
}

class RessourceEducation {
  final String id;
  final String categorie;
  final String titre;
  final String contenu;

  const RessourceEducation({
    required this.id,
    required this.categorie,
    required this.titre,
    required this.contenu,
  });
}

class EducationDonnees {
  // ✅ Garder en const est OK (pas d’évaluation complexe)
  static const List<CategorieQuiz> categoriesQuiz = [
    CategorieQuiz(
      id: 'histoire',
      titre: 'Histoire de la Guinée',
      description: 'Personnalités, dates et événements clés.',
    ),
    CategorieQuiz(
      id: 'geographie',
      titre: 'Géographie de la Guinée',
      description: 'Régions, villes, relief, pays voisins.',
    ),
    CategorieQuiz(
      id: 'culture',
      titre: 'Culture & Symboles',
      description: 'Symboles nationaux, langues, monnaie, repères.',
    ),
  ];

  // ✅ IMPORTANT : static final (pas const) => plus d’erreur d’évaluation constante
  static final List<QuestionQuiz> questionsQuiz = [
    // =========================================================
    // HISTOIRE (20)
    // =========================================================
    QuestionQuiz(
      id: 'h_01',
      categorieId: 'histoire',
      question:
          'Parmi ces personnalités, lesquelles ont été présidents de la Guinée ? (plusieurs réponses)',
      choix: [
        'Ahmed Sékou Touré',
        'Lansana Conté',
        'Alpha Condé',
        'Félix Houphouët-Boigny',
      ],
      indicesBonnesReponses: [0, 1, 2],
      explication:
          'Sékou Touré, Lansana Conté et Alpha Condé ont été présidents de la Guinée.',
    ),
    QuestionQuiz(
      id: 'h_02',
      categorieId: 'histoire',
      question: 'Quelle est la date de la fête nationale de la Guinée ?',
      choix: ['2 octobre', '1er janvier', '25 décembre', '14 juillet'],
      indicesBonnesReponses: [0],
      explication: 'La fête nationale guinéenne est célébrée le 2 octobre.',
    ),
    QuestionQuiz(
      id: 'h_03',
      categorieId: 'histoire',
      question: 'En quelle année la Guinée a-t-elle obtenu son indépendance ?',
      choix: ['1956', '1958', '1960', '1962'],
      indicesBonnesReponses: [1],
      explication: 'La Guinée a obtenu son indépendance en 1958.',
    ),
    QuestionQuiz(
      id: 'h_04',
      categorieId: 'histoire',
      question: 'Quel est le nom de la capitale de la Guinée ?',
      choix: ['Kankan', 'Conakry', 'Labé', 'Kindia'],
      indicesBonnesReponses: [1],
      explication: 'La capitale de la Guinée est Conakry.',
    ),
    QuestionQuiz(
      id: 'h_05',
      categorieId: 'histoire',
      question:
          'Dans quel contexte la Guinée a-t-elle choisi l’indépendance en 1958 ?',
      choix: [
        'Référendum de 1958',
        'Conférence de Berlin',
        'Accords de Lomé',
        'Traité de Versailles'
      ],
      indicesBonnesReponses: [0],
      explication:
          'La Guinée a pris la voie de l’indépendance après le référendum de 1958.',
    ),
    QuestionQuiz(
      id: 'h_06',
      categorieId: 'histoire',
      question: 'Quel était le nom du parti politique de Sékou Touré ?',
      choix: ['PDG (Parti Démocratique de Guinée)', 'RPG', 'UFDG', 'PUP'],
      indicesBonnesReponses: [0],
      explication:
          'Sékou Touré a dirigé le PDG (Parti Démocratique de Guinée).',
    ),
    QuestionQuiz(
      id: 'h_07',
      categorieId: 'histoire',
      question:
          'Quel pays colonisateur administrait la Guinée avant l’indépendance ?',
      choix: ['France', 'Portugal', 'Espagne', 'Belgique'],
      indicesBonnesReponses: [0],
      explication: 'Avant 1958, la Guinée était administrée par la France.',
    ),
    QuestionQuiz(
      id: 'h_08',
      categorieId: 'histoire',
      question: 'Dans quel ensemble colonial la Guinée était-elle intégrée ?',
      choix: [
        'Afrique-Occidentale française (AOF)',
        'Afrique-Équatoriale française (AEF)',
        'Indochine française',
        'Maghreb français'
      ],
      indicesBonnesReponses: [0],
      explication: 'La Guinée faisait partie de l’AOF.',
    ),
    QuestionQuiz(
      id: 'h_09',
      categorieId: 'histoire',
      question: 'Quel type d’événement est le 2 octobre en Guinée ?',
      choix: [
        'Jour férié national',
        'Fête religieuse',
        'Journée sportive',
        'Marché hebdomadaire'
      ],
      indicesBonnesReponses: [0],
      explication: 'Le 2 octobre est un jour férié national en Guinée.',
    ),
    QuestionQuiz(
      id: 'h_10',
      categorieId: 'histoire',
      question:
          'Quel président guinéen a été élu en 2010, après une période de transition ?',
      choix: ['Alpha Condé', 'Sékou Touré', 'Lansana Conté', 'Modibo Keïta'],
      indicesBonnesReponses: [0],
      explication: 'Alpha Condé a été élu en 2010.',
    ),
    QuestionQuiz(
      id: 'h_11',
      categorieId: 'histoire',
      question: 'La monnaie “franc guinéen” est associée à quel pays ?',
      choix: ['Guinée', 'Côte d’Ivoire', 'Sénégal', 'Gabon'],
      indicesBonnesReponses: [0],
      explication: 'Le franc guinéen (GNF) est la monnaie de la Guinée.',
    ),
    QuestionQuiz(
      id: 'h_12',
      categorieId: 'histoire',
      question: 'La Guinée a une façade maritime sur :',
      choix: [
        'Océan Atlantique',
        'Océan Indien',
        'Mer Rouge',
        'Mer Méditerranée'
      ],
      indicesBonnesReponses: [0],
      explication:
          'La Guinée possède une façade maritime sur l’océan Atlantique.',
    ),
    QuestionQuiz(
      id: 'h_13',
      categorieId: 'histoire',
      question:
          'Quels éléments sont liés à l’indépendance ? (plusieurs réponses)',
      choix: ['2 octobre', '1958', '14 juillet', 'Référendum'],
      indicesBonnesReponses: [0, 1, 3],
      explication: 'Indépendance : 2 octobre 1958, référendum de 1958.',
    ),
    QuestionQuiz(
      id: 'h_14',
      categorieId: 'histoire',
      question:
          'Quel domaine est fortement associé à la Guinée grâce à ses ressources ?',
      choix: ['Bauxite', 'Pétrole offshore', 'Charbon', 'Uranium du Sahara'],
      indicesBonnesReponses: [0],
      explication:
          'La Guinée est connue pour ses importantes réserves de bauxite.',
    ),
    QuestionQuiz(
      id: 'h_15',
      categorieId: 'histoire',
      question: 'Le port principal du pays se trouve dans quelle ville ?',
      choix: ['Conakry', 'Labé', 'Kankan', 'Nzérékoré'],
      indicesBonnesReponses: [0],
      explication: 'Le port principal est situé à Conakry.',
    ),
    QuestionQuiz(
      id: 'h_16',
      categorieId: 'histoire',
      question: 'Quel évènement a précédé l’indépendance de 1958 ?',
      choix: [
        'Référendum constitutionnel',
        'Révolution industrielle',
        'Traité de Rome',
        'Conférence de Yalta'
      ],
      indicesBonnesReponses: [0],
      explication: 'Le référendum constitutionnel de 1958 est un repère clé.',
    ),
    QuestionQuiz(
      id: 'h_17',
      categorieId: 'histoire',
      question: 'Le 2 octobre est lié à quelle notion ?',
      choix: ['Indépendance', 'Nouvel an', 'Carnaval', 'Saison des pluies'],
      indicesBonnesReponses: [0],
      explication: 'Le 2 octobre correspond à l’indépendance.',
    ),
    QuestionQuiz(
      id: 'h_18',
      categorieId: 'histoire',
      question: 'Un quiz éducatif dans l’app sert surtout à :',
      choix: [
        'Apprendre et réviser',
        'Remplacer l’école',
        'Vendre des produits',
        'Créer des comptes anonymes'
      ],
      indicesBonnesReponses: [0],
      explication: 'Un quiz sert d’abord à apprendre et réviser.',
    ),
    QuestionQuiz(
      id: 'h_19',
      categorieId: 'histoire',
      question: 'Quelles informations sont vraies ? (plusieurs réponses)',
      choix: [
        'Conakry est la capitale',
        'La Guinée est en Europe',
        'La fête nationale est le 2 octobre',
        'La monnaie est le GNF'
      ],
      indicesBonnesReponses: [0, 2, 3],
      explication:
          'Vrai : Conakry capitale, fête nationale 2 octobre, monnaie GNF.',
    ),
    QuestionQuiz(
      id: 'h_20',
      categorieId: 'histoire',
      question: 'La Guinée est située sur quel continent ?',
      choix: ['Afrique', 'Europe', 'Asie', 'Amérique'],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est un pays africain.',
    ),

    // =========================================================
    // GEOGRAPHIE (20)
    // =========================================================
    QuestionQuiz(
      id: 'g_01',
      categorieId: 'geographie',
      question: 'Dans quelle partie de l’Afrique se situe la Guinée ?',
      choix: [
        'Afrique de l’Ouest',
        'Afrique du Nord',
        'Afrique centrale',
        'Afrique australe'
      ],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est en Afrique de l’Ouest.',
    ),
    QuestionQuiz(
      id: 'g_02',
      categorieId: 'geographie',
      question: 'Quelle est la capitale de la Guinée ?',
      choix: ['Conakry', 'Boké', 'Mamou', 'Labé'],
      indicesBonnesReponses: [0],
      explication: 'La capitale est Conakry.',
    ),
    QuestionQuiz(
      id: 'g_03',
      categorieId: 'geographie',
      question:
          'Parmi ces pays, lesquels sont voisins de la Guinée ? (plusieurs réponses)',
      choix: ['Sierra Leone', 'Mali', 'Ghana', 'Sénégal'],
      indicesBonnesReponses: [0, 1, 3],
      explication: 'Voisins : Sierra Leone, Mali, Sénégal.',
    ),
    QuestionQuiz(
      id: 'g_04',
      categorieId: 'geographie',
      question: 'Sur quel océan la Guinée a-t-elle une façade maritime ?',
      choix: ['Océan Atlantique', 'Océan Indien', 'Mer Rouge', 'Mer Noire'],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est bordée par l’océan Atlantique.',
    ),
    QuestionQuiz(
      id: 'g_05',
      categorieId: 'geographie',
      question: 'Conakry est située :',
      choix: [
        'Sur la côte',
        'Dans le désert',
        'Au sommet d’un glacier',
        'En pleine steppe'
      ],
      indicesBonnesReponses: [0],
      explication: 'Conakry est une ville côtière.',
    ),
    QuestionQuiz(
      id: 'g_06',
      categorieId: 'geographie',
      question: 'Le Fouta-Djalon est surtout connu comme :',
      choix: [
        'Un massif montagneux',
        'Une mer intérieure',
        'Un désert',
        'Une île'
      ],
      indicesBonnesReponses: [0],
      explication: 'Le Fouta-Djalon est un massif montagneux.',
    ),
    QuestionQuiz(
      id: 'g_07',
      categorieId: 'geographie',
      question: 'La Guinée est souvent appelée “château d’eau” car :',
      choix: [
        'Plusieurs fleuves y prennent leur source',
        'Il y neige toute l’année',
        'Elle est entièrement désertique',
        'Elle n’a aucun cours d’eau'
      ],
      indicesBonnesReponses: [0],
      explication: 'Des fleuves importants prennent leur source en Guinée.',
    ),
    QuestionQuiz(
      id: 'g_08',
      categorieId: 'geographie',
      question: 'Quels éléments sont vrais ? (plusieurs réponses)',
      choix: [
        'La Guinée a une côte Atlantique',
        'La Guinée est une île',
        'Le Fouta-Djalon est en Guinée',
        'Conakry est au Canada'
      ],
      indicesBonnesReponses: [0, 2],
      explication: 'Vrai : côte Atlantique, Fouta-Djalon en Guinée.',
    ),
    QuestionQuiz(
      id: 'g_09',
      categorieId: 'geographie',
      question: 'Quels sont des villes guinéennes ? (plusieurs réponses)',
      choix: ['Labé', 'Mamou', 'Paris', 'Kankan'],
      indicesBonnesReponses: [0, 1, 3],
      explication: 'Labé, Mamou et Kankan sont en Guinée.',
    ),
    // 11 questions supplémentaires (pour rester à 20)
    QuestionQuiz(
      id: 'g_10',
      categorieId: 'geographie',
      question: 'Kankan est :',
      choix: [
        'Une grande ville intérieure',
        'Une île',
        'Un désert',
        'Un volcan'
      ],
      indicesBonnesReponses: [0],
      explication: 'Kankan est une grande ville intérieure.',
    ),
    QuestionQuiz(
      id: 'g_11',
      categorieId: 'geographie',
      question: 'La capitale Conakry se situe principalement :',
      choix: [
        'En Guinée Maritime',
        'Dans le Sahara',
        'En Arctique',
        'Dans l’Himalaya'
      ],
      indicesBonnesReponses: [0],
      explication: 'Conakry est sur la côte (Guinée Maritime).',
    ),
    QuestionQuiz(
      id: 'g_12',
      categorieId: 'geographie',
      question: 'Quels pays sont voisins ? (plusieurs réponses)',
      choix: ['Libéria', 'Côte d’Ivoire', 'Kenya', 'Guinée-Bissau'],
      indicesBonnesReponses: [0, 1, 3],
      explication: 'Voisins : Libéria, Côte d’Ivoire, Guinée-Bissau.',
    ),
    QuestionQuiz(
      id: 'g_13',
      categorieId: 'geographie',
      question: 'La Guinée est un pays :',
      choix: ['Africain', 'Européen', 'Américain', 'Océanien'],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est un pays africain.',
    ),
    QuestionQuiz(
      id: 'g_14',
      categorieId: 'geographie',
      question: 'Conakry est une ville :',
      choix: ['Côtière', 'Désertique', 'Polaire', 'Volcanique'],
      indicesBonnesReponses: [0],
      explication: 'Conakry est située sur la côte atlantique.',
    ),
    QuestionQuiz(
      id: 'g_15',
      categorieId: 'geographie',
      question: 'Dans quel pays se trouve Conakry ?',
      choix: ['Guinée', 'Ghana', 'Gabon', 'Cameroun'],
      indicesBonnesReponses: [0],
      explication: 'Conakry est en Guinée.',
    ),
    QuestionQuiz(
      id: 'g_16',
      categorieId: 'geographie',
      question: 'La Guinée a une façade maritime sur :',
      choix: ['Atlantique', 'Indien', 'Méditerranée', 'Mer Baltique'],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est bordée par l’Atlantique.',
    ),
    QuestionQuiz(
      id: 'g_17',
      categorieId: 'geographie',
      question: 'Kindia est :',
      choix: [
        'Une ville de Guinée',
        'Une ville du Canada',
        'Une île',
        'Un désert'
      ],
      indicesBonnesReponses: [0],
      explication: 'Kindia est une ville de Guinée.',
    ),
    QuestionQuiz(
      id: 'g_18',
      categorieId: 'geographie',
      question: 'Nzérékoré est :',
      choix: [
        'Une ville de Guinée',
        'Une ville d’Europe',
        'Un volcan',
        'Une mer'
      ],
      indicesBonnesReponses: [0],
      explication: 'Nzérékoré est une ville de Guinée.',
    ),
    QuestionQuiz(
      id: 'g_19',
      categorieId: 'geographie',
      question: 'La Guinée se situe en Afrique :',
      choix: ['de l’Ouest', 'de l’Est', 'du Nord', 'Australe'],
      indicesBonnesReponses: [0],
      explication: 'La Guinée est en Afrique de l’Ouest.',
    ),
    QuestionQuiz(
      id: 'g_20',
      categorieId: 'geographie',
      question: 'Le Fouta-Djalon est en :',
      choix: ['Guinée', 'Australie', 'Japon', 'Norvège'],
      indicesBonnesReponses: [0],
      explication: 'Le Fouta-Djalon est en Guinée.',
    ),

    // =========================================================
    // CULTURE (20)
    // =========================================================
    QuestionQuiz(
      id: 'c_01',
      categorieId: 'culture',
      question: 'Quel est l’hymne national de la Guinée ?',
      choix: ['Liberté', 'Fraternité', 'Fidélité', 'Unité'],
      indicesBonnesReponses: [0],
      explication: 'L’hymne national s’appelle “Liberté”.',
    ),
    QuestionQuiz(
      id: 'c_02',
      categorieId: 'culture',
      question:
          'Quelles couleurs composent le drapeau guinéen ? (plusieurs réponses)',
      choix: ['Rouge', 'Jaune', 'Vert', 'Bleu'],
      indicesBonnesReponses: [0, 1, 2],
      explication: 'Le drapeau guinéen est rouge-jaune-vert.',
    ),
    QuestionQuiz(
      id: 'c_03',
      categorieId: 'culture',
      question: 'Quelle est la monnaie de la Guinée ?',
      choix: ['Franc guinéen (GNF)', 'Franc CFA', 'Euro', 'Dollar'],
      indicesBonnesReponses: [0],
      explication: 'La monnaie est le franc guinéen (GNF).',
    ),
    QuestionQuiz(
      id: 'c_04',
      categorieId: 'culture',
      question: 'Quelle langue est la langue officielle en Guinée ?',
      choix: ['Français', 'Anglais', 'Espagnol', 'Allemand'],
      indicesBonnesReponses: [0],
      explication: 'La langue officielle est le français.',
    ),
    QuestionQuiz(
      id: 'c_05',
      categorieId: 'culture',
      question:
          'Parmi ces langues, lesquelles sont couramment parlées en Guinée ? (plusieurs réponses)',
      choix: ['Soussou', 'Pular', 'Malinké', 'Japonais'],
      indicesBonnesReponses: [0, 1, 2],
      explication: 'Soussou, Pular et Malinké sont courantes en Guinée.',
    ),
    QuestionQuiz(
      id: 'c_06',
      categorieId: 'culture',
      question: 'Quelle est la devise de la Guinée ?',
      choix: [
        'Travail, Justice, Solidarité',
        'Liberté, Égalité, Fraternité',
        'Paix, Pain, Terre',
        'Dieu, Patrie, Roi'
      ],
      indicesBonnesReponses: [0],
      explication: 'La devise est “Travail, Justice, Solidarité”.',
    ),
    QuestionQuiz(
      id: 'c_07',
      categorieId: 'culture',
      question:
          'Quel instrument est fortement associé à la musique traditionnelle guinéenne ?',
      choix: ['Djembé', 'Cornemuse', 'Harpe celtique', 'Didgeridoo'],
      indicesBonnesReponses: [0],
      explication: 'Le djembé est très associé aux traditions musicales.',
    ),
    QuestionQuiz(
      id: 'c_08',
      categorieId: 'culture',
      question: 'Quel sport est le plus populaire en Guinée ?',
      choix: ['Football', 'Hockey sur glace', 'Baseball', 'Cricket'],
      indicesBonnesReponses: [0],
      explication: 'Le football est très populaire.',
    ),
    QuestionQuiz(
      id: 'c_09',
      categorieId: 'culture',
      question:
          'Quels éléments sont des symboles/repères nationaux ? (plusieurs réponses)',
      choix: [
        'Drapeau rouge-jaune-vert',
        'Hymne “Liberté”',
        'Euro',
        'Devise “Travail, Justice, Solidarité”'
      ],
      indicesBonnesReponses: [0, 1, 3],
      explication: 'Repères : drapeau, hymne Liberté, devise nationale.',
    ),
    // 11 questions supplémentaires (pour rester à 20)
    QuestionQuiz(
      id: 'c_10',
      categorieId: 'culture',
      question: 'Le drapeau guinéen a combien de bandes verticales ?',
      choix: ['3', '2', '4', '5'],
      indicesBonnesReponses: [0],
      explication: 'Il y a 3 bandes verticales.',
    ),
    QuestionQuiz(
      id: 'c_11',
      categorieId: 'culture',
      question: 'Conakry est la capitale de quel pays ?',
      choix: ['Guinée', 'Guinée-Bissau', 'Ghana', 'Gambie'],
      indicesBonnesReponses: [0],
      explication: 'Conakry est la capitale de la Guinée.',
    ),
    QuestionQuiz(
      id: 'c_12',
      categorieId: 'culture',
      question: 'Quand la réponse est fausse, on doit montrer :',
      choix: ['Une explication', 'Rien', 'Un crash', 'Un écran noir'],
      indicesBonnesReponses: [0],
      explication: 'En cas d’erreur, une explication aide à apprendre.',
    ),
    QuestionQuiz(
      id: 'c_13',
      categorieId: 'culture',
      question: 'Le GNF est :',
      choix: ['La monnaie guinéenne', 'Une ville', 'Une langue', 'Un fleuve'],
      indicesBonnesReponses: [0],
      explication: 'GNF = franc guinéen.',
    ),
    QuestionQuiz(
      id: 'c_14',
      categorieId: 'culture',
      question: 'Le djembé est surtout associé à :',
      choix: [
        'La musique traditionnelle',
        'Le hockey',
        'La voile',
        'Le patinage'
      ],
      indicesBonnesReponses: [0],
      explication: 'Le djembé est un instrument traditionnel.',
    ),
    QuestionQuiz(
      id: 'c_15',
      categorieId: 'culture',
      question: 'Quels sont des objectifs du quiz ? (plusieurs réponses)',
      choix: [
        'Apprendre',
        'Réviser',
        'Faire payer obligatoirement',
        'S’amuser'
      ],
      indicesBonnesReponses: [0, 1, 3],
      explication:
          'Un quiz sert à apprendre, réviser, et rendre l’étude motivante.',
    ),
    QuestionQuiz(
      id: 'c_16',
      categorieId: 'culture',
      question: 'Quelle est la langue officielle en Guinée ?',
      choix: ['Français', 'Portugais', 'Arabe', 'Chinois'],
      indicesBonnesReponses: [0],
      explication: 'La langue officielle est le français.',
    ),
    QuestionQuiz(
      id: 'c_17',
      categorieId: 'culture',
      question: 'Le drapeau guinéen est :',
      choix: [
        'Rouge-Jaune-Vert',
        'Bleu-Blanc-Rouge',
        'Noir-Jaune-Rouge',
        'Vert-Blanc-Orange'
      ],
      indicesBonnesReponses: [0],
      explication: 'Le drapeau est rouge-jaune-vert.',
    ),
    QuestionQuiz(
      id: 'c_18',
      categorieId: 'culture',
      question: 'La devise de la Guinée est :',
      choix: [
        'Travail, Justice, Solidarité',
        'Liberté, Égalité, Fraternité',
        'Unité, Discipline, Travail',
        'Paix et Progrès'
      ],
      indicesBonnesReponses: [0],
      explication: 'La devise est “Travail, Justice, Solidarité”.',
    ),
    QuestionQuiz(
      id: 'c_19',
      categorieId: 'culture',
      question: 'Quelles couleurs sont correctes ? (plusieurs réponses)',
      choix: ['Rouge', 'Jaune', 'Vert', 'Violet'],
      indicesBonnesReponses: [0, 1, 2],
      explication: 'Les couleurs officielles sont rouge, jaune et vert.',
    ),
    QuestionQuiz(
      id: 'c_20',
      categorieId: 'culture',
      question: 'Quel pays utilise le franc guinéen (GNF) ?',
      choix: ['Guinée', 'Sénégal', 'Gabon', 'Cameroun'],
      indicesBonnesReponses: [0],
      explication: 'Le GNF est la monnaie de la Guinée.',
    ),
  ];

  static List<QuestionQuiz> questionsParCategorie(String categorieId) {
    return questionsQuiz.where((q) => q.categorieId == categorieId).toList();
  }

  static const List<RessourceEducation> ressources = [
    RessourceEducation(
      id: 'r_h1',
      categorie: 'Histoire',
      titre: 'Indépendance de la Guinée',
      contenu: 'La Guinée a accédé à l’indépendance le 2 octobre 1958.',
    ),
    RessourceEducation(
      id: 'r_g1',
      categorie: 'Géographie',
      titre: 'Repères géographiques',
      contenu: 'Pays d’Afrique de l’Ouest, façade Atlantique, régions variées.',
    ),
    RessourceEducation(
      id: 'r_c1',
      categorie: 'Culture',
      titre: 'Symboles nationaux',
      contenu:
          'Drapeau rouge-jaune-vert, hymne “Liberté”, devise “Travail, Justice, Solidarité”.',
    ),
  ];
}
