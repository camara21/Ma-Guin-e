// lib/education/education_donnees.dart
//
// Données statiques (Guinée) — Questions par catégorie.
// ✅ Multi-réponses : indicesBonnesReponses peut contenir 1 ou plusieurs indices.
// ✅ Compatible avec des données "raw" en Map (ex: {"bonnes":[0,2]}).
// ✅ Pas de "const evaluation error" : on privilégie static final pour les listes converties.

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

  /// Constructeur de conversion depuis Map (tes listes collées).
  /// Attendu :
  /// {
  ///   "id": "C001",
  ///   "categorieId": "culture",
  ///   "question": "...",
  ///   "choix": ["A","B","C","D"],
  ///   "bonnes": [0,2],
  ///   "explication": "..."
  /// }
  factory QuestionQuiz.fromMap(Map<String, dynamic> m) {
    final choixRaw = m['choix'];
    final bonnesRaw = m['bonnes'];

    final choix = (choixRaw is List)
        ? choixRaw.map((e) => e.toString()).toList(growable: false)
        : <String>[];

    final bonnes = (bonnesRaw is List)
        ? bonnesRaw.map((e) => int.parse(e.toString())).toList(growable: false)
        : <int>[];

    return QuestionQuiz(
      id: (m['id'] ?? '').toString(),
      categorieId: (m['categorieId'] ?? '').toString(),
      question: (m['question'] ?? '').toString(),
      choix: choix,
      indicesBonnesReponses: bonnes,
      explication: (m['explication'] ?? '').toString(),
    );
  }

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
  // ✅ OK en const (objets const)
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

  // =========================
  // ✅ QUESTIONS RAW (à coller ici)
  // IMPORTANT :
  // - c’est BIEN "static final" (évite les erreurs de const)
  // - c’est BIEN typé List<Map<String, dynamic>>
  // =========================

  static final List<Map<String, dynamic>> _rawHistoireGuinee = [
  {
    "id": "H001",
    "categorieId": "histoire",
    "question": "Quelle date correspond au référendum de 1958 où la Guinée a choisi la rupture avec la France ?",
    "choix": ["28 septembre 1958", "1er janvier 1960", "5 septembre 2021", "11 novembre 1918"],
    "bonnes": [0],
    "explication": "Le 28 septembre 1958, la Guinée vote « non » au référendum et ouvre la voie à l’indépendance."
  },
  {
    "id": "H002",
    "categorieId": "histoire",
    "question": "Quel leader guinéen est associé au choix du « non » en 1958 et aux débuts de la Guinée indépendante ?",
    "choix": ["Ahmed Sékou Touré", "Alpha Condé", "Mamady Doumbouya", "Lansana Conté"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré est la figure centrale du « non » de 1958 et du premier pouvoir post-indépendance."
  },
  {
    "id": "H003",
    "categorieId": "histoire",
    "question": "Le Fouta-Djalon (Fuuta Jalon) a été historiquement connu comme :",
    "choix": ["Un imamat (almaamiya) islamique", "Un royaume viking", "Une colonie portugaise", "Un empire maya"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon a été organisé en Imamat, avec des almamys et une forte tradition islamique."
  },
  {
    "id": "H004",
    "categorieId": "histoire",
    "question": "Quelle ville est souvent citée comme capitale historique de l’Imamat du Fouta-Djalon ?",
    "choix": ["Timbo", "Conakry", "Kankan", "Boké"],
    "bonnes": [0],
    "explication": "Timbo est classiquement citée comme capitale de l’Imamat du Fouta-Djalon."
  },
  {
    "id": "H005",
    "categorieId": "histoire",
    "question": "L’Imamat du Fouta-Djalon est généralement daté entre :",
    "choix": ["1725–1912", "1200–1300", "1960–1990", "2000–2025"],
    "bonnes": [0],
    "explication": "Les repères souvent donnés situent l’Imamat du Fouta-Djalon de 1725 à 1912."
  },
  {
    "id": "H006",
    "categorieId": "histoire",
    "question": "Samory Touré est surtout connu en Guinée et en Afrique de l’Ouest pour :",
    "choix": ["La résistance à l’expansion coloniale française", "La fondation de Conakry", "La création de la CEDEAO", "La découverte de l’or en bauxite"],
    "bonnes": [0],
    "explication": "Samory Touré est une figure majeure de la résistance face à la conquête coloniale française."
  },
  {
    "id": "H007",
    "categorieId": "histoire",
    "question": "Quelle affirmation décrit le mieux le référendum de 1958 pour la Guinée ?",
    "choix": [
      "La Guinée est le seul territoire à rejeter la Constitution et choisir l’indépendance",
      "Tous les territoires votent « non »",
      "La Guinée vote « oui » et reste département français",
      "Le référendum concerne uniquement la monnaie"
    ],
    "bonnes": [0],
    "explication": "La Guinée se distingue en votant « non » et en optant pour l’indépendance, contrairement à la plupart des territoires."
  },
  {
    "id": "H008",
    "categorieId": "histoire",
    "question": "Quel événement politique majeur a eu lieu à Conakry le 5 septembre 2021 ?",
    "choix": ["Un coup d’État", "Une indépendance", "Une union avec le Mali", "Un traité de paix mondiale"],
    "bonnes": [0],
    "explication": "Le 5 septembre 2021, un coup d’État renverse le président Alpha Condé."
  },
  {
    "id": "H009",
    "categorieId": "histoire",
    "question": "Lors du coup d’État du 5 septembre 2021, quel président est renversé ?",
    "choix": ["Alpha Condé", "Ahmed Sékou Touré", "Lansana Conté", "N’Zérékoré"],
    "bonnes": [0],
    "explication": "Le coup d’État de 2021 dépose le président Alpha Condé."
  },
  {
    "id": "H010",
    "categorieId": "histoire",
    "question": "Quel nom porte l’organe mis en avant par les putschistes de 2021 ?",
    "choix": ["CRND", "ONU", "UEMOA", "UADE"],
    "bonnes": [0],
    "explication": "Le pouvoir de transition est annoncé sous le nom de « Comité national du rassemblement et du développement (CRND) »."
  },
  {
    "id": "H011",
    "categorieId": "histoire",
    "question": "Quel officier est associé à la prise de pouvoir de 2021 et à la transition annoncée ?",
    "choix": ["Mamady Doumbouya", "Nelson Mandela", "Thomas Sankara", "Patrice Lumumba"],
    "bonnes": [0],
    "explication": "Mamady Doumbouya apparaît comme figure centrale de la prise de pouvoir du 5 septembre 2021."
  },
  {
    "id": "H012",
    "categorieId": "histoire",
    "question": "Le Fouta-Djalon est surtout lié historiquement à quel espace de la Guinée ?",
    "choix": ["Les hautes terres du centre-nord (Moyenne Guinée)", "Le littoral de Basse Guinée uniquement", "Le désert saharien", "Une île au large de l’Atlantique"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon correspond aux hautes terres, cœur historique de l’Imamat."
  },
  {
    "id": "H013",
    "categorieId": "histoire",
    "question": "Le titre traditionnel du chef de l’Imamat du Fouta-Djalon est :",
    "choix": ["Almamy", "Empereur", "Pape", "Chancelier"],
    "bonnes": [0],
    "explication": "Le chef de l’Imamat est souvent désigné par le titre « Almamy »."
  },
  {
    "id": "H014",
    "categorieId": "histoire",
    "question": "Dans l’histoire du Fouta-Djalon, le mouvement de fondation est souvent décrit comme :",
    "choix": ["Un jihad mené par des leaders peuls musulmans", "Une croisade chrétienne", "Une invasion viking", "Une révolution industrielle"],
    "bonnes": [0],
    "explication": "Les récits historiques décrivent une dynamique religieuse et politique menant à la formation de l’Imamat au XVIIIe siècle."
  },
  {
    "id": "H015",
    "categorieId": "histoire",
    "question": "Parmi ces propositions, lesquelles sont des repères majeurs de l’histoire politique récente de la Guinée ?",
    "choix": ["Indépendance (1958)", "Coup d’État (2021)", "Chute de Rome (476)", "Révolution française (1789)"],
    "bonnes": [0, 1],
    "explication": "1958 (indépendance) et 2021 (coup d’État) sont des repères guinéens majeurs."
  },
  {
    "id": "H016",
    "categorieId": "histoire",
    "question": "Dans le récit historique guinéen, Samory Touré est surtout associé à quelle zone culturelle/linguistique ?",
    "choix": ["Mandé / Haute Guinée et alentours", "Scandinavie", "Andes", "Asie du Sud-Est"],
    "bonnes": [0],
    "explication": "Samory Touré est une figure mandingue et son aire d’action concerne l’espace mandé en Afrique de l’Ouest."
  },
  {
    "id": "H017",
    "categorieId": "histoire",
    "question": "Quel enchaînement est le plus logique pour situer la Guinée dans le temps (du plus ancien au plus récent) ?",
    "choix": ["Imamat du Fouta-Djalon → Référendum 1958 → Coup 2021", "Coup 2021 → Référendum 1958 → Imamat", "Référendum 1958 → Imamat → Coup 2021", "Tout se passe en 2021"],
    "bonnes": [0],
    "explication": "L’Imamat précède l’indépendance ; le coup d’État de 2021 est le repère le plus récent."
  },
  {
    "id": "H018",
    "categorieId": "histoire",
    "question": "Le référendum de 1958 concernait principalement :",
    "choix": ["L’adoption d’une nouvelle constitution française et l’adhésion à la Communauté française", "La création de la monnaie guinéenne", "Un traité minier sur la bauxite", "L’élection du président de l’ONU"],
    "bonnes": [0],
    "explication": "Le vote de 1958 porte sur la Constitution et le statut au sein de la Communauté française."
  },
  {
    "id": "H019",
    "categorieId": "histoire",
    "question": "Après le coup de 2021, quelle mesure institutionnelle est annoncée par les putschistes ?",
    "choix": ["Dissolution de la constitution et du gouvernement", "Annexion par un pays voisin", "Fin de toutes les frontières de l’Afrique de l’Ouest", "Remplacement immédiat par une monarchie"],
    "bonnes": [0],
    "explication": "Les annonces incluent la dissolution des institutions et la suspension/annulation de la constitution."
  },
  {
    "id": "H020",
    "categorieId": "histoire",
    "question": "Le Fouta-Djalon est historiquement une zone importante notamment pour :",
    "choix": ["Le rôle religieux et l’enseignement islamique", "Les temples aztèques", "Les fjords", "Les pyramides d’Égypte"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon est reconnu pour son organisation religieuse et ses centres d’enseignement."
  },
  {
    "id": "H021",
    "categorieId": "histoire",
    "question": "Quel couple (lieu + date) correspond correctement au coup d’État guinéen mentionné dans les sources ?",
    "choix": ["Conakry + 5 septembre 2021", "Labé + 28 septembre 1958", "Kankan + 1er janvier 1960", "Boké + 14 juillet 1789"],
    "bonnes": [0],
    "explication": "Le coup d’État est rapporté à Conakry le 5 septembre 2021."
  },
  {
    "id": "H022",
    "categorieId": "histoire",
    "question": "Dans l’histoire guinéenne, quel terme correspond le mieux à « période coloniale française » ?",
    "choix": ["Guinée française", "Guinée byzantine", "Guinée viking", "Guinée romaine"],
    "bonnes": [0],
    "explication": "On parle de « Guinée française » pour désigner la période coloniale sous administration française."
  },
  {
    "id": "H023",
    "categorieId": "histoire",
    "question": "Quel est l’enjeu principal des figures de résistance comme Samory Touré dans la mémoire historique ?",
    "choix": ["La défense de l’autonomie face à la conquête coloniale", "L’invention de l’imprimerie", "La conquête de la Lune", "La création d’Internet"],
    "bonnes": [0],
    "explication": "Ces figures sont souvent vues comme symboles de résistance face à l’expansion coloniale."
  },
  {
    "id": "H024",
    "categorieId": "histoire",
    "question": "Le titre « almamy » est le plus directement lié à quelle région/structure historique guinéenne ?",
    "choix": ["L’Imamat du Fouta-Djalon", "Le littoral exclusivement", "Le Sahara", "Une colonie portugaise"],
    "bonnes": [0],
    "explication": "Le terme « almamy » est associé à l’autorité dans l’Imamat du Fouta-Djalon."
  },
  {
    "id": "H025",
    "categorieId": "histoire",
    "question": "Quels éléments sont corrects concernant la transition de 2021 ?",
    "choix": ["Alpha Condé est renversé", "La constitution est dissoute/annulée", "Le CRND est annoncé", "La Guinée devient une province française"],
    "bonnes": [0, 1, 2],
    "explication": "Les annonces mentionnent le renversement, la dissolution des institutions et la mise en avant du CRND."
  },
  {
    "id": "H026",
    "categorieId": "histoire",
    "question": "Quel repère (année) correspond à la naissance de l’Imamat du Fouta-Djalon dans les repères conventionnels ?",
    "choix": ["1725", "1958", "2021", "1492"],
    "bonnes": [0],
    "explication": "Les repères donnent 1725 comme année de début conventionnelle de l’Imamat."
  },
  {
    "id": "H027",
    "categorieId": "histoire",
    "question": "Quel repère (année) correspond à la fin de l’Imamat du Fouta-Djalon dans les repères conventionnels ?",
    "choix": ["1912", "1958", "1960", "2021"],
    "bonnes": [0],
    "explication": "Les repères indiquent souvent 1912 comme fin de la structure politique de l’Imamat."
  },
  {
    "id": "H028",
    "categorieId": "histoire",
    "question": "Le référendum de 1958 a opposé principalement deux options pour la Guinée :",
    "choix": ["Rester dans une Communauté française ou choisir l’indépendance", "Entrer dans l’Union européenne ou la quitter", "Choisir une monarchie ou un empire", "Choisir une guerre mondiale ou la paix mondiale"],
    "bonnes": [0],
    "explication": "Le vote porte sur l’acceptation de la Constitution et l’option de rester liée à la France, ou la rupture menant à l’indépendance."
  },
  {
    "id": "H029",
    "categorieId": "histoire",
    "question": "Quel fait est correct à propos du coup d’État du 5 septembre 2021 ?",
    "choix": ["Il a lieu à Conakry", "Il a lieu à Timbo", "Il a lieu à Paris", "Il a lieu à New York"],
    "bonnes": [0],
    "explication": "Les sources situent le coup d’État à Conakry, capitale de la Guinée."
  },
  {
    "id": "H030",
    "categorieId": "histoire",
    "question": "Quel enchaînement d’événements correspond le mieux à l’histoire contemporaine (version simplifiée) ?",
    "choix": ["Indépendance (1958) puis transformations politiques successives jusqu’au coup (2021)", "Coup (2021) puis indépendance (1958)", "Imamat (1725) après 2021", "Tout commence en 2021"],
    "bonnes": [0],
    "explication": "L’indépendance est en 1958 ; le coup d’État de 2021 intervient bien plus tard."
  },
  {
    "id": "H031",
    "categorieId": "histoire",
    "question": "Le Fouta-Djalon est un repère historique important surtout pour :",
    "choix": ["La Moyenne Guinée et l’histoire peule (Fulɓe)", "Le Canada", "Le Japon", "L’Australie"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon est un centre historique lié aux hautes terres et à l’histoire fulɓe/peule."
  },
  {
    "id": "H032",
    "categorieId": "histoire",
    "question": "Quel élément est typique d’un État islamique comme l’Imamat du Fouta-Djalon ?",
    "choix": ["Une autorité religieuse et des institutions liées à l’enseignement", "Un sénat romain", "Des pharaons", "Des empereurs chinois"],
    "bonnes": [0],
    "explication": "Les descriptions classiques parlent d’un État islamique structuré autour d’une autorité religieuse et de la diffusion du savoir."
  },
  {
    "id": "H033",
    "categorieId": "histoire",
    "question": "Quel repère est le plus lié au choix d’indépendance de la Guinée ?",
    "choix": ["1958", "1725", "1912", "2021"],
    "bonnes": [0],
    "explication": "Le choix d’indépendance se cristallise autour du référendum de 1958."
  },
  {
    "id": "H034",
    "categorieId": "histoire",
    "question": "Parmi ces propositions, lesquelles sont associées à la Guinée (repères historiques) ?",
    "choix": ["Imamat du Fouta-Djalon", "Référendum de 1958", "Coup du 5 septembre 2021", "Réforme de l’Empire romain"],
    "bonnes": [0, 1, 2],
    "explication": "Fouta-Djalon, 1958 et 2021 sont des repères guinéens ; l’Empire romain n’est pas un repère national."
  },
  {
    "id": "H035",
    "categorieId": "histoire",
    "question": "Le terme « Communauté française » (1958) renvoie surtout à :",
    "choix": ["Un cadre institutionnel proposé aux territoires français d’Afrique", "Une association sportive", "Un parti unique guinéen", "Un traité minier"],
    "bonnes": [0],
    "explication": "La Communauté française est un dispositif institutionnel proposé aux territoires, au moment du référendum de 1958."
  },
  {
    "id": "H036",
    "categorieId": "histoire",
    "question": "Quelle combinaison (personne + événement) est correcte ?",
    "choix": ["Ahmed Sékou Touré + référendum/indépendance 1958", "Samory Touré + coup de 2021", "Mamady Doumbouya + 1725", "Almamy + 1958"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré est lié au contexte du référendum de 1958 et au début de la Guinée indépendante."
  },
  {
    "id": "H037",
    "categorieId": "histoire",
    "question": "Quelle combinaison (lieu + structure) est correcte pour l’histoire du Fouta-Djalon ?",
    "choix": ["Timbo + Imamat", "Conakry + Empire romain", "Kankan + Vikings", "Boké + Dynastie Ming"],
    "bonnes": [0],
    "explication": "Timbo est classiquement associé à l’Imamat du Fouta-Djalon."
  },
  {
    "id": "H038",
    "categorieId": "histoire",
    "question": "Le coup du 5 septembre 2021 est décrit comme « réussi » parce que :",
    "choix": ["Le président est capturé et les institutions sont annoncées dissoutes", "Il n’y a eu aucun changement", "La Guinée disparaît", "La capitale devient Timbo"],
    "bonnes": [0],
    "explication": "La capture du président et l’annonce de dissolution des institutions caractérisent une prise effective du pouvoir."
  },
  {
    "id": "H039",
    "categorieId": "histoire",
    "question": "Quel mot décrit le mieux la nature du pouvoir du Fouta-Djalon à son apogée ?",
    "choix": ["Théocratie / imamat", "République fédérale européenne", "Empire maritime viking", "Sultanat d’Asie"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon est décrit comme un Imamat, structure politique à forte dimension religieuse."
  },
  {
    "id": "H040",
    "categorieId": "histoire",
    "question": "Quel repère est le plus récent parmi ces choix pour l’histoire politique de la Guinée ?",
    "choix": ["5 septembre 2021", "1912", "1725", "1958"],
    "bonnes": [0],
    "explication": "Le 5 septembre 2021 est un repère récent (coup d’État)."
  },
  {
    "id": "H041",
    "categorieId": "histoire",
    "question": "Quel repère est le plus ancien parmi ces choix liés à la Guinée ?",
    "choix": ["1725", "1912", "1958", "2021"],
    "bonnes": [0],
    "explication": "1725 est le début conventionnel de l’Imamat du Fouta-Djalon."
  },
  {
    "id": "H042",
    "categorieId": "histoire",
    "question": "Pourquoi le « non » de 1958 est-il souvent présenté comme un acte fondateur ?",
    "choix": ["Parce qu’il entraîne l’indépendance immédiate", "Parce qu’il crée l’Empire du Mali", "Parce qu’il invente la bauxite", "Parce qu’il supprime l’école"],
    "bonnes": [0],
    "explication": "Le « non » ouvre la voie à l’indépendance et marque une rupture politique forte."
  },
  {
    "id": "H043",
    "categorieId": "histoire",
    "question": "Le terme « coup d’État » désigne :",
    "choix": ["Une prise de pouvoir par la force, souvent militaire", "Une élection normale", "Une fête nationale", "Une réforme scolaire"],
    "bonnes": [0],
    "explication": "Un coup d’État correspond à une prise de pouvoir par la force."
  },
  {
    "id": "H044",
    "categorieId": "histoire",
    "question": "Quelle relation est correcte entre le Fouta-Djalon et la période coloniale ?",
    "choix": ["L’Imamat finit par être intégré au système colonial français", "Le Fouta-Djalon devient une colonie japonaise", "Le Fouta-Djalon n’a jamais existé", "Le Fouta-Djalon est fondé en 2021"],
    "bonnes": [0],
    "explication": "Les repères historiques indiquent la fin de l’Imamat et son intégration progressive dans l’ordre colonial."
  },
  {
    "id": "H045",
    "categorieId": "histoire",
    "question": "Parmi ces termes, lesquels appartiennent directement à l’histoire de la Guinée ?",
    "choix": ["Fouta-Djalon", "CRND", "Pax Romana", "Vikings"],
    "bonnes": [0, 1],
    "explication": "Fouta-Djalon et CRND sont liés à l’histoire guinéenne."
  },
  {
    "id": "H046",
    "categorieId": "histoire",
    "question": "Quel couple (date + événement) est correct pour la Guinée ?",
    "choix": ["1958 + référendum menant à l’indépendance", "1912 + coup d’État", "1725 + référendum constitutionnel", "2021 + fondation de l’Imamat"],
    "bonnes": [0],
    "explication": "1958 correspond au référendum ; 1725 à l’origine de l’Imamat ; 2021 au coup d’État."
  },
  {
    "id": "H047",
    "categorieId": "histoire",
    "question": "Quel est le meilleur résumé du rôle de Conakry dans l’histoire politique récente ?",
    "choix": ["Centre du pouvoir, capitale où se déroulent des événements politiques majeurs", "Village isolé sans administration", "Capitale du Fouta-Djalon en 1725", "Ville créée en 2021"],
    "bonnes": [0],
    "explication": "Conakry est la capitale et un lieu central d’événements politiques, notamment en 2021."
  },
  {
    "id": "H048",
    "categorieId": "histoire",
    "question": "Dans les repères historiques, quel est le lien entre 1896 et le Fouta-Djalon (selon certaines chronologies) ?",
    "choix": ["Établissement d’un protectorat français dans la région", "Indépendance de la Guinée", "Coup d’État", "Création du CRND"],
    "bonnes": [0],
    "explication": "Certaines chronologies mentionnent un protectorat français à la fin du XIXe siècle avant la fin de l’Imamat."
  },
  {
    "id": "H049",
    "categorieId": "histoire",
    "question": "Quel élément distingue particulièrement la Guinée dans la séquence de 1958 ?",
    "choix": ["Elle rejette le projet constitutionnel et choisit l’indépendance", "Elle devient un département français", "Elle rejoint immédiatement l’Union européenne", "Elle annexe le Sénégal"],
    "bonnes": [0],
    "explication": "La Guinée se démarque en rejetant la Constitution au référendum, conduisant à l’indépendance."
  },
  {
    "id": "H050",
    "categorieId": "histoire",
    "question": "Quel élément est explicitement mentionné dans les descriptions du coup de 2021 ?",
    "choix": ["Annonce de dissolution des institutions", "Couronnement d’un empereur", "Vote pour rejoindre la France", "Création d’un royaume du Fouta-Djalon"],
    "bonnes": [0],
    "explication": "Les annonces incluent la dissolution des institutions (constitution, gouvernement)."
  },
  {
    "id": "H051",
    "categorieId": "histoire",
    "question": "Quel repère est associé à la fin conventionnelle de l’Imamat du Fouta-Djalon ?",
    "choix": ["1912", "1958", "2021", "1725"],
    "bonnes": [0],
    "explication": "Les repères historiques indiquent 1912 comme fin conventionnelle."
  },
  {
    "id": "H052",
    "categorieId": "histoire",
    "question": "Quel repère est associé au début conventionnel de l’Imamat du Fouta-Djalon ?",
    "choix": ["1725", "1912", "1958", "2021"],
    "bonnes": [0],
    "explication": "1725 est le repère de début le plus souvent cité."
  },
  {
    "id": "H053",
    "categorieId": "histoire",
    "question": "Quels événements sont clairement datés et liés à la Guinée dans cette liste ?",
    "choix": ["Référendum du 28 septembre 1958", "Coup du 5 septembre 2021", "Traité de Versailles (1919)", "Chute de Constantinople (1453)"],
    "bonnes": [0, 1],
    "explication": "1958 (référendum) et 2021 (coup) sont des repères guinéens ; les deux autres sont des repères mondiaux."
  },
  {
    "id": "H054",
    "categorieId": "histoire",
    "question": "Quelle description correspond le mieux au rôle du Fouta-Djalon dans l’histoire guinéenne ?",
    "choix": ["Un État historique majeur structurant la région avant la colonisation", "Une invention moderne", "Une ville fondée en 2021", "Un parti politique européen"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon (Imamat) est un repère historique important avant la période coloniale."
  },
  {
    "id": "H055",
    "categorieId": "histoire",
    "question": "Pourquoi Samory Touré est-il souvent étudié en histoire guinéenne et ouest-africaine ?",
    "choix": ["Pour sa résistance et son organisation politico-militaire face à la colonisation", "Pour avoir créé l’ONU", "Pour la découverte de l’Amérique", "Pour avoir inventé le téléphone"],
    "bonnes": [0],
    "explication": "Samory Touré est étudié pour son rôle dans la résistance à la conquête coloniale."
  },
  {
    "id": "H056",
    "categorieId": "histoire",
    "question": "Quel lien est correct entre 1958 et l’histoire constitutionnelle française en Afrique ?",
    "choix": ["La Guinée rejette la Constitution proposée lors du référendum", "La Guinée rédige la Constitution française", "La Guinée rejoint la monarchie britannique", "Le Fouta-Djalon est créé"],
    "bonnes": [0],
    "explication": "Le référendum de 1958 porte sur l’adoption de la Constitution ; la Guinée vote « non »."
  },
  {
    "id": "H057",
    "categorieId": "histoire",
    "question": "Quel lien est correct entre 2021 et l’organisation du pouvoir annoncée ?",
    "choix": ["Mise en place d’une transition (CRND)", "Restauration de l’Imamat du Fouta-Djalon", "Indépendance de 1958", "Fondation de l’Empire du Mali"],
    "bonnes": [0],
    "explication": "En 2021, on parle d’une transition portée par le CRND."
  },
  {
    "id": "H058",
    "categorieId": "histoire",
    "question": "Quel couple (structure + chef) est correct pour l’histoire du Fouta-Djalon ?",
    "choix": ["Imamat + Almamy", "Empire romain + Pharaon", "Royaume viking + Imam", "Dynastie Ming + Président"],
    "bonnes": [0],
    "explication": "L’Imamat est dirigé par un almamy dans les descriptions historiques classiques."
  },
  {
    "id": "H059",
    "categorieId": "histoire",
    "question": "Quelle phrase est la plus correcte sur la chronologie guinéenne ?",
    "choix": ["Fouta-Djalon (XVIIIe–début XXe) précède l’indépendance (1958)", "L’indépendance (1958) précède 1725", "Le coup (2021) précède 1912", "Tout commence en 1958"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon est un repère antérieur ; l’indépendance arrive en 1958, et 2021 est beaucoup plus récent."
  },
  {
    "id": "H060",
    "categorieId": "histoire",
    "question": "Quels éléments suivants sont directement liés au 5 septembre 2021 ?",
    "choix": ["Renversement d’Alpha Condé", "Annonce de dissolution de la constitution", "Capture du président à Conakry", "Création du Fouta-Djalon en 1725"],
    "bonnes": [0, 1, 2],
    "explication": "Le 5 septembre 2021 : renversement, capture du président et annonce de dissolution des institutions ; 1725 concerne l’Imamat, pas 2021."
  },

  // -------------------------
  // Tranche B: H061 -> H120
  // -------------------------
  {
    "id": "H061",
    "categorieId": "histoire",
    "question": "Quelle date correspond à la proclamation de l’indépendance de la Guinée ?",
    "choix": ["2 octobre 1958", "28 septembre 1958", "3 avril 1984", "5 septembre 2021"],
    "bonnes": [0],
    "explication": "Après le référendum du 28 septembre 1958, l’indépendance est proclamée le 2 octobre 1958."
  },
  {
    "id": "H062",
    "categorieId": "histoire",
    "question": "Quel événement précède directement l’indépendance proclamée le 2 octobre 1958 ?",
    "choix": ["Le référendum du 28 septembre 1958", "Le coup d’État du 3 avril 1984", "La grève générale de 2007", "Le coup du 5 septembre 2021"],
    "bonnes": [0],
    "explication": "Le référendum du 28 septembre 1958 est l’étape clé qui précède la proclamation d’indépendance."
  },
  {
    "id": "H063",
    "categorieId": "histoire",
    "question": "Quel président guinéen est en fonction de 1958 à 1984 ?",
    "choix": ["Ahmed Sékou Touré", "Lansana Conté", "Alpha Condé", "Mamady Doumbouya"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré est le premier président et gouverne de 1958 à 1984."
  },
  {
    "id": "H064",
    "categorieId": "histoire",
    "question": "En 1984, quel événement politique majeur a lieu en Guinée ?",
    "choix": ["Un coup d’État militaire", "Une indépendance", "Une union politique avec le Cap-Vert", "La création de la CEDEAO en Guinée"],
    "bonnes": [0],
    "explication": "Le 3 avril 1984, un coup d’État porte Lansana Conté au pouvoir."
  },
  {
    "id": "H065",
    "categorieId": "histoire",
    "question": "Le coup d’État qui installe Lansana Conté au pouvoir se déroule à :",
    "choix": ["Conakry", "Labé", "Kankan", "Nzérékoré"],
    "bonnes": [0],
    "explication": "Le coup d’État de 1984 est centré sur Conakry, capitale politique."
  },
  {
    "id": "H066",
    "categorieId": "histoire",
    "question": "Quel couple (date + événement) est correct ?",
    "choix": ["3 avril 1984 + coup d’État", "2 octobre 1958 + coup d’État", "22 novembre 1970 + référendum", "27 juin 2010 + indépendance"],
    "bonnes": [0],
    "explication": "Le 3 avril 1984 correspond au coup d’État qui suit la mort d’Ahmed Sékou Touré."
  },
  {
    "id": "H067",
    "categorieId": "histoire",
    "question": "L’attaque de Conakry du 22 novembre 1970 est souvent associée à quel nom ?",
    "choix": ["Operation Green Sea (Battle of Conakry)", "Pax Romana", "Plan Marshall", "Accords d’Évian"],
    "bonnes": [0],
    "explication": "L’attaque de novembre 1970 est connue comme Operation Green Sea (aussi appelée “Battle of Conakry”)."
  },
  {
    "id": "H068",
    "categorieId": "histoire",
    "question": "En 1970, l’attaque vise principalement la capitale de la Guinée :",
    "choix": ["Conakry", "Kindia", "Mamou", "Siguiri"],
    "bonnes": [0],
    "explication": "L’opération de 1970 est une attaque dirigée contre Conakry."
  },
  {
    "id": "H069",
    "categorieId": "histoire",
    "question": "Quelle affirmation décrit le mieux l’enchaînement chronologique suivant ?",
    "choix": [
      "Indépendance (1958) → Attaque de Conakry (1970) → Coup d’État (1984)",
      "Coup d’État (1984) → Indépendance (1958) → Attaque (1970)",
      "Attaque (1970) → Indépendance (1958) → Coup (1984)",
      "Tout se passe en 1958"
    ],
    "bonnes": [0],
    "explication": "1958 précède 1970, qui précède 1984."
  },
  {
    "id": "H070",
    "categorieId": "histoire",
    "question": "Quel événement a lieu le 24 décembre 2008 en Guinée ?",
    "choix": ["Un coup d’État militaire", "La proclamation d’indépendance", "L’attaque de 1970", "La première élection de 2010 (2e tour)"],
    "bonnes": [0],
    "explication": "Le 24 décembre 2008, une junte (CNDD) prend le pouvoir après un coup d’État."
  },
  {
    "id": "H071",
    "categorieId": "histoire",
    "question": "Quel nom porte la junte annoncée après le coup du 24 décembre 2008 ?",
    "choix": ["CNDD", "CRND", "PDG", "UFDG"],
    "bonnes": [0],
    "explication": "Après le coup de 2008, la junte se présente comme le CNDD."
  },
  {
    "id": "H072",
    "categorieId": "histoire",
    "question": "Les événements du 28 septembre 2009 sont liés à quel lieu de Conakry ?",
    "choix": ["Le stade du 28-Septembre", "Le port autonome", "L’aéroport de Gbessia", "Le palais de Timbo"],
    "bonnes": [0],
    "explication": "Les violences de 2009 sont associées au stade du 28-Septembre de Conakry."
  },
  {
    "id": "H073",
    "categorieId": "histoire",
    "question": "Le 28 septembre 2009, l’événement déclencheur est principalement :",
    "choix": [
      "Une manifestation de l’opposition réprimée violemment",
      "Un référendum sur l’indépendance",
      "Un coup d’État contre Sékou Touré",
      "Une attaque portugaise de 1970"
    ],
    "bonnes": [0],
    "explication": "Il s’agit d’une manifestation d’opposition à Conakry, réprimée par les forces de sécurité."
  },
  {
    "id": "H074",
    "categorieId": "histoire",
    "question": "Quels événements sont correctement associés aux dates suivantes ?",
    "choix": [
      "24 déc. 2008 : coup d’État / 28 sept. 2009 : violences au stade",
      "24 déc. 2008 : indépendance / 28 sept. 2009 : attaque de 1970",
      "24 déc. 2008 : référendum / 28 sept. 2009 : coup de 1984",
      "24 déc. 2008 : élection 2010 / 28 sept. 2009 : indépendance 1958"
    ],
    "bonnes": [0],
    "explication": "Les repères 2008 (coup) et 2009 (stade) sont liés à la période CNDD."
  },
  {
    "id": "H075",
    "categorieId": "histoire",
    "question": "En 2010, quel fait est souvent mis en avant dans l’histoire politique guinéenne ?",
    "choix": [
      "Organisation d’une présidentielle considérée comme un jalon démocratique majeur",
      "Retour de l’Imamat du Fouta-Djalon",
      "Indépendance proclamée",
      "Attaque portugaise"
    ],
    "bonnes": [0],
    "explication": "Les élections de 2010 sont souvent présentées comme un jalon démocratique majeur."
  },
  {
    "id": "H076",
    "categorieId": "histoire",
    "question": "La présidentielle de 2010 en Guinée se déroule en :",
    "choix": ["Deux tours", "Un seul tour", "Trois tours", "Quatre tours"],
    "bonnes": [0],
    "explication": "L’élection de 2010 se fait au système à deux tours."
  },
  {
    "id": "H077",
    "categorieId": "histoire",
    "question": "Quel président est déclaré vainqueur de l’élection présidentielle de 2010 ?",
    "choix": ["Alpha Condé", "Ahmed Sékou Touré", "Lansana Conté", "Mamady Doumbouya"],
    "bonnes": [0],
    "explication": "Alpha Condé est déclaré vainqueur de la présidentielle de 2010."
  },
  {
    "id": "H078",
    "categorieId": "histoire",
    "question": "Quel enchaînement est correct (du plus ancien au plus récent) ?",
    "choix": [
      "Indépendance 1958 → Attaque 1970 → Coup 1984 → Coup 2008 → Stade 2009 → Élection 2010",
      "Coup 2008 → Indépendance 1958 → Élection 2010 → Attaque 1970",
      "Attaque 1970 → Coup 1984 → Indépendance 1958 → Stade 2009",
      "Élection 2010 → Indépendance 1958 → Coup 2008 → Attaque 1970"
    ],
    "bonnes": [0],
    "explication": "Cet ordre respecte la chronologie des grands jalons guinéens cités."
  },
  {
    "id": "H079",
    "categorieId": "histoire",
    "question": "La grève générale de 2007 est principalement portée par :",
    "choix": ["Les syndicats et des acteurs de la société civile", "Une armée étrangère", "Un imamat religieux", "Un parti colonial portugais"],
    "bonnes": [0],
    "explication": "La grève de 2007 est initiée par des syndicats et soutenue par des forces sociales et politiques."
  },
  {
    "id": "H080",
    "categorieId": "histoire",
    "question": "La grève générale de 2007 commence le :",
    "choix": ["10 janvier 2007", "2 octobre 1958", "3 avril 1984", "22 novembre 1970"],
    "bonnes": [0],
    "explication": "Le mouvement démarre le 10 janvier 2007."
  },
  {
    "id": "H081",
    "categorieId": "histoire",
    "question": "Quel est l’un des résultats politiques marquants de la crise sociale de 2007 ?",
    "choix": [
      "Nomination de Lansana Kouyaté comme Premier ministre",
      "Proclamation de l’indépendance",
      "Création du CNDD",
      "Attaque amphibie de Conakry"
    ],
    "bonnes": [0],
    "explication": "Après la crise et les négociations, Lansana Kouyaté est nommé Premier ministre."
  },
  {
    "id": "H082",
    "categorieId": "histoire",
    "question": "Dans les repères récents, quel organe est associé au coup du 5 septembre 2021 ?",
    "choix": ["CRND", "CNDD", "PDG", "PUP"],
    "bonnes": [0],
    "explication": "Le coup du 5 septembre 2021 est associé au CRND."
  },
  {
    "id": "H083",
    "categorieId": "histoire",
    "question": "Quel couple (année + événement) est correct ?",
    "choix": ["2008 + coup d’État", "2008 + indépendance", "2010 + attaque de Conakry", "1970 + présidentielle en deux tours"],
    "bonnes": [0],
    "explication": "2008 correspond à un coup d’État (CNDD)."
  },
  {
    "id": "H084",
    "categorieId": "histoire",
    "question": "Quel couple (sigle + période) est correct ?",
    "choix": [
      "CNDD + période de junte après 2008",
      "CRND + période de 1958",
      "PDG + junte de 2021",
      "PUP + grève générale de 2007"
    ],
    "bonnes": [0],
    "explication": "Le CNDD est associé à la prise de pouvoir militaire de 2008."
  },
  {
    "id": "H085",
    "categorieId": "histoire",
    "question": "Quel lieu symbolique de Conakry est directement lié aux événements du 28 septembre 2009 ?",
    "choix": ["Stade du 28-Septembre", "Îles de Loos", "Tombo", "Kassa"],
    "bonnes": [0],
    "explication": "L’événement est lié au stade du 28-Septembre, lieu du rassemblement."
  },
  {
    "id": "H086",
    "categorieId": "histoire",
    "question": "Quels jalons appartiennent à la période 2007–2010 en Guinée ?",
    "choix": ["Grève générale 2007", "Coup 2008 (CNDD)", "Événements du stade 2009", "Attaque de Conakry 1970"],
    "bonnes": [0, 1, 2],
    "explication": "2007, 2008 et 2009–2010 sont liés à la séquence crise sociale → junte → violences → transition électorale."
  },
  {
    "id": "H087",
    "categorieId": "histoire",
    "question": "Quel jalon est associé à la fin de la présidence d’Ahmed Sékou Touré ?",
    "choix": ["26 mars 1984", "2 octobre 1958", "27 juin 2010", "5 septembre 2021"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré meurt en mars 1984, fin de sa présidence."
  },
  {
    "id": "H088",
    "categorieId": "histoire",
    "question": "En 1984, qui est chef de l’État après le coup d’État ?",
    "choix": ["Lansana Conté", "Alpha Condé", "Mamady Doumbouya", "Jean-Marie Doré"],
    "bonnes": [0],
    "explication": "Le coup de 1984 installe Lansana Conté."
  },
  {
    "id": "H089",
    "categorieId": "histoire",
    "question": "L’attaque de novembre 1970 contre Conakry est souvent décrite comme :",
    "choix": ["Une opération amphibie menée par des forces portugaises et des combattants alliés", "Un référendum constitutionnel", "Une élection présidentielle", "Une grève syndicale"],
    "bonnes": [0],
    "explication": "L’événement de 1970 est connu comme une attaque amphibie liée à un contexte régional."
  },
  {
    "id": "H090",
    "categorieId": "histoire",
    "question": "Quel événement est directement lié au nom “Stade du 28-Septembre” dans l’histoire guinéenne récente ?",
    "choix": ["Les violences du 28 septembre 2009", "L’indépendance proclamée le 2 octobre 1958", "Le coup d’État de 1984", "L’attaque de 1970"],
    "bonnes": [0],
    "explication": "Le stade est associé aux événements du 28 septembre 2009, lors d’un rassemblement à Conakry."
  },
  {
    "id": "H091",
    "categorieId": "histoire",
    "question": "Quel événement marque le passage de 2008 à 2010 dans une logique “transition politique” ?",
    "choix": ["Du coup de 2008 à l’organisation de la présidentielle 2010", "Du référendum 1958 à l’attaque 1970", "Du coup 1984 à l’indépendance 1958", "De l’imamat à la grève 2007"],
    "bonnes": [0],
    "explication": "La séquence 2008→2010 illustre une transition d’un régime militaire vers un processus électoral."
  },
  {
    "id": "H092",
    "categorieId": "histoire",
    "question": "Quel fait est correct concernant la présidentielle de 2010 ?",
    "choix": ["Elle se déroule en deux tours", "Elle se déroule en 1958", "Elle est une attaque militaire", "Elle est la grève générale de 2007"],
    "bonnes": [0],
    "explication": "L’élection de 2010 suit un système à deux tours."
  },
  {
    "id": "H093",
    "categorieId": "histoire",
    "question": "Quel jalon est le plus ancien parmi ceux-ci ?",
    "choix": ["Indépendance 1958", "Attaque 1970", "Coup 1984", "Grève 2007"],
    "bonnes": [0],
    "explication": "1958 est le jalon le plus ancien dans cette liste."
  },
  {
    "id": "H094",
    "categorieId": "histoire",
    "question": "Quel jalon est le plus récent parmi ceux-ci ?",
    "choix": ["Coup 2021", "Élection 2010", "Coup 2008", "Attaque 1970"],
    "bonnes": [0],
    "explication": "Le coup du 5 septembre 2021 est le plus récent parmi ces repères."
  },
  {
    "id": "H095",
    "categorieId": "histoire",
    "question": "Dans la chronologie politique guinéenne, quelle paire d’événements est correcte ?",
    "choix": ["1984 : coup d’État → 2008 : coup d’État", "1984 : indépendance → 2008 : référendum", "1984 : attaque → 2008 : attaque", "1984 : présidentielle → 2008 : présidentielle"],
    "bonnes": [0],
    "explication": "1984 et 2008 sont deux repères de coups d’État en Guinée."
  },
  {
    "id": "H096",
    "categorieId": "histoire",
    "question": "Quel événement de 2007 est directement lié à une contestation socio-économique et politique ?",
    "choix": ["La grève générale de 2007", "L’indépendance de 1958", "L’attaque de 1970", "Le référendum de 1958"],
    "bonnes": [0],
    "explication": "La grève générale de 2007 est une mobilisation sociale et syndicale majeure."
  },
  {
    "id": "H097",
    "categorieId": "histoire",
    "question": "Quel événement est associé à une junte appelée CNDD ?",
    "choix": ["Le coup d’État de 2008", "Le coup d’État de 1984", "L’indépendance 1958", "L’attaque 1970"],
    "bonnes": [0],
    "explication": "Le CNDD est le nom de la junte issue du coup du 24 décembre 2008."
  },
  {
    "id": "H098",
    "categorieId": "histoire",
    "question": "Quel événement est associé à l’organe CRND ?",
    "choix": ["Le coup d’État de 2021", "Le coup d’État de 2008", "L’attaque de 1970", "L’indépendance de 1958"],
    "bonnes": [0],
    "explication": "Le CRND est associé à la prise de pouvoir du 5 septembre 2021."
  },
  {
    "id": "H099",
    "categorieId": "histoire",
    "question": "Quels repères sont correctement associés à Conakry ?",
    "choix": ["Attaque de 1970", "Coup de 1984", "Événements du stade 2009", "Fondation de Timbo (capitale de l’imamat)"],
    "bonnes": [0, 1, 2],
    "explication": "Conakry est au centre de plusieurs événements politiques et sécuritaires (1970, 1984, 2009)."
  },
  {
    "id": "H100",
    "categorieId": "histoire",
    "question": "Quel est le lien entre la date “28 septembre” et l’histoire guinéenne ?",
    "choix": [
      "Date du référendum de 1958 et date choisie symboliquement pour une manifestation en 2009",
      "Date de l’attaque de 1970",
      "Date du coup de 1984",
      "Date du coup de 2021"
    ],
    "bonnes": [0],
    "explication": "Le 28 septembre renvoie au référendum de 1958 et devient une date symbolique reprise en 2009."
  },
  {
    "id": "H101",
    "categorieId": "histoire",
    "question": "Quel repère correspond à une attaque militaire venue du contexte colonial portugais (région) ?",
    "choix": ["22 novembre 1970", "2 octobre 1958", "3 avril 1984", "27 juin 2010"],
    "bonnes": [0],
    "explication": "Le 22 novembre 1970 correspond à l’attaque contre Conakry (Operation Green Sea)."
  },
  {
    "id": "H102",
    "categorieId": "histoire",
    "question": "Quel repère correspond à l’entrée de la Guinée dans une phase de junte en 2008 ?",
    "choix": ["24 décembre 2008", "10 janvier 2007", "7 novembre 2010", "26 mars 1984"],
    "bonnes": [0],
    "explication": "Le 24 décembre 2008 marque le coup d’État et l’arrivée de la junte."
  },
  {
    "id": "H103",
    "categorieId": "histoire",
    "question": "Quel événement est principalement lié à une crise des droits humains en 2009 ?",
    "choix": ["Les violences du 28 septembre 2009 au stade", "L’indépendance de 1958", "L’attaque de 1970", "Le coup d’État de 1984"],
    "bonnes": [0],
    "explication": "Le 28 septembre 2009 est associé à une répression violente lors d’un rassemblement à Conakry."
  },
  {
    "id": "H104",
    "categorieId": "histoire",
    "question": "Quel événement est associé à une grande mobilisation syndicale en Guinée ?",
    "choix": ["La grève générale de 2007", "Le référendum de 1958", "L’attaque de 1970", "Le coup de 2021"],
    "bonnes": [0],
    "explication": "La grève générale de 2007 est un mouvement syndical majeur."
  },
  {
    "id": "H105",
    "categorieId": "histoire",
    "question": "Quel enchaînement est le plus cohérent pour la période 2008–2010 ?",
    "choix": ["Coup 2008 → crise/violences 2009 → présidentielle 2010", "Présidentielle 2010 → coup 2008 → crise 2009", "Crise 2009 → indépendance 1958 → présidentielle 2010", "Attaque 1970 → coup 1984 → grève 2007"],
    "bonnes": [0],
    "explication": "La séquence 2008→2009→2010 est un fil logique souvent utilisé pour raconter la transition."
  },
  {
    "id": "H106",
    "categorieId": "histoire",
    "question": "En 2010, quel fait est correct ?",
    "choix": ["Alpha Condé est déclaré vainqueur", "Sékou Touré devient président", "Lansana Conté arrive au pouvoir par coup d’État", "Le CNDD est créé"],
    "bonnes": [0],
    "explication": "Alpha Condé est déclaré vainqueur du scrutin présidentiel de 2010."
  },
  {
    "id": "H107",
    "categorieId": "histoire",
    "question": "Quel événement explique le mieux pourquoi 2010 est un jalon important ?",
    "choix": ["Une élection présidentielle marquante après une longue période de régimes autoritaires et de transition", "Une attaque amphibie étrangère", "La création d’un imamat", "Un référendum colonial portugais"],
    "bonnes": [0],
    "explication": "2010 est présenté comme un jalon démocratique après des décennies de gouvernance autoritaire et des crises."
  },
  {
    "id": "H108",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement associé à une décision populaire par vote ?",
    "choix": ["Le référendum de 1958", "Le coup de 1984", "Le coup de 2008", "L’attaque de 1970"],
    "bonnes": [0],
    "explication": "Le référendum de 1958 est une décision par vote, contrairement aux coups d’État ou à l’attaque de 1970."
  },
  {
    "id": "H109",
    "categorieId": "histoire",
    "question": "Quel repère est directement lié à un changement de pouvoir par la force en 1984 ?",
    "choix": ["3 avril 1984", "2 octobre 1958", "22 novembre 1970", "27 février 2007"],
    "bonnes": [0],
    "explication": "Le 3 avril 1984 correspond au coup d’État en Guinée."
  },
  {
    "id": "H110",
    "categorieId": "histoire",
    "question": "Quels événements se déroulent au XXIe siècle (2001–2100) ?",
    "choix": ["Grève 2007", "Coup 2008", "Stade 2009", "Attaque 1970"],
    "bonnes": [0, 1, 2],
    "explication": "2007, 2008 et 2009 sont au XXIe siècle ; 1970 est au XXe."
  },
  {
    "id": "H111",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une mobilisation de travailleurs et de syndicats ?",
    "choix": ["La grève générale de 2007", "Le coup du 24 décembre 2008", "Le coup du 3 avril 1984", "L’attaque du 22 novembre 1970"],
    "bonnes": [0],
    "explication": "La grève de 2007 est principalement portée par les syndicats."
  },
  {
    "id": "H112",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une junte militaire dans les années 2000 ?",
    "choix": ["Le coup d’État de 2008 (CNDD)", "Le référendum de 1958", "L’attaque de 1970", "Le coup de 1984"],
    "bonnes": [0],
    "explication": "2008 marque l’arrivée d’une junte (CNDD) après un coup d’État."
  },
  {
    "id": "H113",
    "categorieId": "histoire",
    "question": "Quel événement a lieu en 1970 et concerne directement Conakry ?",
    "choix": ["Une attaque militaire sur la capitale", "Une présidentielle à deux tours", "Un référendum d’indépendance", "Une grève générale syndicale"],
    "bonnes": [0],
    "explication": "En 1970, Conakry est ciblée par une attaque militaire (Operation Green Sea)."
  },
  {
    "id": "H114",
    "categorieId": "histoire",
    "question": "Quel événement est associé à une décision de changer de Premier ministre en 2007 ?",
    "choix": ["La crise sociale et la nomination de Lansana Kouyaté", "Le référendum de 1958", "L’attaque de 1970", "La proclamation d’indépendance"],
    "bonnes": [0],
    "explication": "En 2007, après la crise sociale, un nouveau Premier ministre est nommé."
  },
  {
    "id": "H115",
    "categorieId": "histoire",
    "question": "Quel événement est lié à une répression lors d’un rassemblement au stade en 2009 ?",
    "choix": ["Les violences du 28 septembre 2009", "Le coup de 2008", "Le coup de 1984", "Le référendum de 1958"],
    "bonnes": [0],
    "explication": "Le 28 septembre 2009 est associé à une répression au stade du 28-Septembre."
  },
  {
    "id": "H116",
    "categorieId": "histoire",
    "question": "Quels repères sont corrects concernant la période 1958–1984 ?",
    "choix": ["Sékou Touré est président", "La Guinée proclame son indépendance", "Le coup d’État de 1984 a lieu", "La présidentielle de 2010 se déroule"],
    "bonnes": [0, 1, 2],
    "explication": "1958: indépendance ; 1958–1984: présidence de Sékou Touré ; 1984: coup d’État. 2010 est hors période."
  },
  {
    "id": "H117",
    "categorieId": "histoire",
    "question": "Quel repère correspond à une alternance par urnes (processus électoral) et non par force ?",
    "choix": ["La présidentielle de 2010", "Le coup de 2008", "Le coup de 1984", "L’attaque de 1970"],
    "bonnes": [0],
    "explication": "2010 correspond à un processus électoral, contrairement aux coups et à l’attaque de 1970."
  },
  {
    "id": "H118",
    "categorieId": "histoire",
    "question": "Quelle affirmation est la plus correcte sur 2008–2009 ?",
    "choix": [
      "2008 marque une prise de pouvoir par une junte, 2009 une crise majeure au stade",
      "2008 est l’indépendance, 2009 est le référendum",
      "2008 est l’attaque de Conakry, 2009 est le coup de 1984",
      "2008 est la présidentielle, 2009 est l’indépendance"
    ],
    "bonnes": [0],
    "explication": "2008 et 2009 renvoient à la période CNDD et à la crise au stade du 28-Septembre."
  },
  {
    "id": "H119",
    "categorieId": "histoire",
    "question": "Quelle paire est correcte ?",
    "choix": ["CNDD : 2008 / CRND : 2021", "CRND : 2008 / CNDD : 2021", "CNDD : 1958 / CRND : 1970", "CNDD : 1970 / CRND : 1984"],
    "bonnes": [0],
    "explication": "CNDD est lié au coup de 2008 ; CRND au coup de 2021."
  },
  {
    "id": "H120",
    "categorieId": "histoire",
    "question": "Quel enchaînement résume le mieux les grands jalons guinéens modernes ?",
    "choix": [
      "Indépendance 1958 → coups/transformations politiques → transitions et élections → coup 2021",
      "Attaque 1970 → indépendance 1958 → coup 1984 → grève 2007",
      "Tout commence en 2010",
      "Imamat 1725 → coup 2021 → indépendance 1958"
    ],
    "bonnes": [0],
    "explication": "L’indépendance est le point de départ moderne, puis viennent des phases politiques successives jusqu’au coup de 2021."
  },

  // -------------------------
  // Tranche C: H121 -> H160
  // -------------------------
  {
    "id": "H121",
    "categorieId": "histoire",
    "question": "Quelle date est la fête nationale correspondant à la proclamation de l’indépendance de la Guinée ?",
    "choix": ["2 octobre 1958", "28 septembre 1958", "23 décembre 1990", "22 novembre 1970"],
    "bonnes": [0],
    "explication": "L’indépendance de la Guinée est proclamée le 2 octobre 1958, date de la fête nationale."
  },
  {
    "id": "H122",
    "categorieId": "histoire",
    "question": "Quel événement du 28 septembre 1958 est directement lié à l’indépendance proclamée ensuite ?",
    "choix": ["Un référendum décisif", "Un coup d’État", "Une attaque amphibie", "Une élection présidentielle à deux tours"],
    "bonnes": [0],
    "explication": "Le référendum du 28 septembre 1958 est l’étape clé qui ouvre la voie à l’indépendance."
  },
  {
    "id": "H123",
    "categorieId": "histoire",
    "question": "Quel président gouverne la Guinée de 1958 jusqu’à sa mort en 1984 ?",
    "choix": ["Ahmed Sékou Touré", "Lansana Conté", "Alpha Condé", "Jean-Marie Doré"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré est président de 1958 à 1984."
  },
  {
    "id": "H124",
    "categorieId": "histoire",
    "question": "Quel repère correspond à la fin de la présidence d’Ahmed Sékou Touré ?",
    "choix": ["26 mars 1984", "2 octobre 1958", "19 décembre 1993", "22 décembre 2008"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré meurt le 26 mars 1984, marquant la fin de sa présidence."
  },
  {
    "id": "H125",
    "categorieId": "histoire",
    "question": "Quel événement majeur survient peu après la mort d’Ahmed Sékou Touré en 1984 ?",
    "choix": ["Un coup d’État militaire", "Le référendum de 1958", "L’attaque de 1970", "La présidentielle multipartite de 1993"],
    "bonnes": [0],
    "explication": "Un coup d’État militaire a lieu le 3 avril 1984."
  },
  {
    "id": "H126",
    "categorieId": "histoire",
    "question": "Quelle date correspond au coup d’État qui porte Lansana Conté au pouvoir ?",
    "choix": ["3 avril 1984", "24 décembre 2008", "5 septembre 2021", "23 décembre 1990"],
    "bonnes": [0],
    "explication": "Le coup d’État du 3 avril 1984 installe Lansana Conté."
  },
  {
    "id": "H127",
    "categorieId": "histoire",
    "question": "Quel repère est associé à l’attaque amphibie contre Conakry ?",
    "choix": ["22 novembre 1970", "22 décembre 2008", "19 décembre 1993", "2 octobre 1958"],
    "bonnes": [0],
    "explication": "L’attaque contre Conakry a lieu le 22 novembre 1970."
  },
  {
    "id": "H128",
    "categorieId": "histoire",
    "question": "L’attaque de Conakry de 1970 est souvent appelée :",
    "choix": ["Operation Green Sea", "Opération Overlord", "Plan Marshall", "Accords d’Évian"],
    "bonnes": [0],
    "explication": "L’attaque de novembre 1970 est connue sous le nom d’Operation Green Sea."
  },
  {
    "id": "H129",
    "categorieId": "histoire",
    "question": "Parmi ces dates, lesquelles correspondent à des coups d’État en Guinée ?",
    "choix": ["3 avril 1984", "24 décembre 2008", "5 septembre 2021", "23 décembre 1990"],
    "bonnes": [0, 1, 2],
    "explication": "1984, 2008 et 2021 sont des repères de coups d’État ; 1990 est un référendum constitutionnel."
  },
  {
    "id": "H130",
    "categorieId": "histoire",
    "question": "Quelle date correspond au décès du président Lansana Conté ?",
    "choix": ["22 décembre 2008", "24 décembre 2008", "19 décembre 1993", "10 janvier 2007"],
    "bonnes": [0],
    "explication": "Lansana Conté décède le 22 décembre 2008."
  },
  {
    "id": "H131",
    "categorieId": "histoire",
    "question": "Quel événement survient deux jours après la mort de Lansana Conté (décembre 2008) ?",
    "choix": ["Un coup d’État", "L’indépendance", "L’attaque de Conakry", "Un référendum constitutionnel"],
    "bonnes": [0],
    "explication": "Le 24 décembre 2008, un coup d’État militaire a lieu."
  },
  {
    "id": "H132",
    "categorieId": "histoire",
    "question": "Quel sigle correspond à la junte issue du coup du 24 décembre 2008 ?",
    "choix": ["CNDD", "CRND", "PDG", "PUP"],
    "bonnes": [0],
    "explication": "Après le coup de 2008, la junte se présente comme le CNDD."
  },
  {
    "id": "H133",
    "categorieId": "histoire",
    "question": "Quel événement est associé au stade du 28-Septembre à Conakry en 2009 ?",
    "choix": ["Une répression violente lors d’un rassemblement", "La proclamation d’indépendance", "Un référendum constitutionnel", "Une attaque amphibie étrangère"],
    "bonnes": [0],
    "explication": "Le 28 septembre 2009, un rassemblement à Conakry est réprimé violemment au stade."
  },
  {
    "id": "H134",
    "categorieId": "histoire",
    "question": "Quel repère correspond au référendum constitutionnel de 1990 en Guinée ?",
    "choix": ["23 décembre 1990", "23 décembre 2008", "23 décembre 1958", "23 décembre 1970"],
    "bonnes": [0],
    "explication": "Le référendum constitutionnel de 1990 se tient le 23 décembre 1990."
  },
  {
    "id": "H135",
    "categorieId": "histoire",
    "question": "Pourquoi 1990 est un jalon important dans l’histoire politique guinéenne ?",
    "choix": ["Adoption d’une nouvelle constitution par référendum", "Proclamation d’indépendance", "Attaque de Conakry", "Coup du 5 septembre 2021"],
    "bonnes": [0],
    "explication": "En 1990, une nouvelle constitution est approuvée par référendum."
  },
  {
    "id": "H136",
    "categorieId": "histoire",
    "question": "Quel repère correspond à la première présidentielle multipartite après l’ouverture de 1990 ?",
    "choix": ["19 décembre 1993", "19 décembre 1958", "19 décembre 2008", "19 décembre 2010"],
    "bonnes": [0],
    "explication": "La présidentielle de 1993 est la première présidentielle multipartite après le retour au multipartisme."
  },
  {
    "id": "H137",
    "categorieId": "histoire",
    "question": "Qui remporte l’élection présidentielle de 1993 en Guinée ?",
    "choix": ["Lansana Conté", "Ahmed Sékou Touré", "Alpha Condé", "Mamady Doumbouya"],
    "bonnes": [0],
    "explication": "Lansana Conté remporte la présidentielle de 1993."
  },
  {
    "id": "H138",
    "categorieId": "histoire",
    "question": "En 1993, quelle proposition décrit correctement le contexte électoral ?",
    "choix": ["Première présidentielle multipartite depuis le retour au multipartisme en 1990", "Référendum d’indépendance", "Coup d’État", "Attaque amphibie sur Conakry"],
    "bonnes": [0],
    "explication": "Le scrutin de 1993 est une présidentielle multipartite après la réforme politique de 1990."
  },
  {
    "id": "H139",
    "categorieId": "histoire",
    "question": "Selon les récits historiques, quel événement se produit le 2 février 1996 en Guinée ?",
    "choix": ["Une mutinerie / tentative de coup liée à l’armée", "L’indépendance", "Le référendum de 1958", "L’élection de 2010"],
    "bonnes": [0],
    "explication": "Le 2 février 1996, une crise grave liée à une mutinerie/tentative de coup est rapportée."
  },
  {
    "id": "H140",
    "categorieId": "histoire",
    "question": "Quels événements appartiennent à la période 1990–1996 ?",
    "choix": ["Référendum constitutionnel 1990", "Présidentielle multipartite 1993", "Mutinerie/tentative de coup 1996", "Attaque de Conakry 1970"],
    "bonnes": [0, 1, 2],
    "explication": "1990, 1993 et 1996 sont dans la même séquence de transition/instabilités des années 1990."
  },
  {
    "id": "H141",
    "categorieId": "histoire",
    "question": "Quel repère correspond au début de la grande épidémie d’Ebola en Afrique de l’Ouest, avec premiers cas détectés en Guinée ?",
    "choix": ["Mars 2014", "Mars 2007", "Mars 1993", "Mars 1958"],
    "bonnes": [0],
    "explication": "Les premiers cas de l’épidémie ouest-africaine sont détectés en Guinée en mars 2014."
  },
  {
    "id": "H142",
    "categorieId": "histoire",
    "question": "Les premières détections d’Ebola en 2014 en Guinée sont associées à quelle zone du pays ?",
    "choix": ["La région forestière (sud-est)", "Uniquement la côte de Conakry", "Le Fouta-Djalon uniquement", "Les îles de Loos uniquement"],
    "bonnes": [0],
    "explication": "Les premiers cas détectés en 2014 sont associés à la région forestière du sud-est."
  },
  {
    "id": "H143",
    "categorieId": "histoire",
    "question": "Quel enchaînement est le plus cohérent (du plus ancien au plus récent) ?",
    "choix": [
      "Indépendance 1958 → Attaque 1970 → Coup 1984 → Référendum 1990 → Présidentielle 1993 → Ebola 2014",
      "Ebola 2014 → Indépendance 1958 → Coup 1984",
      "Coup 2008 → Attaque 1970 → Indépendance 1958",
      "Référendum 1990 → Attaque 1970 → Ebola 2014 → Indépendance 1958"
    ],
    "bonnes": [0],
    "explication": "Cet ordre respecte les repères majeurs de l’histoire guinéenne moderne."
  },
  {
    "id": "H144",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une décision populaire par vote en 1990 ?",
    "choix": ["Le référendum constitutionnel", "Le coup de 1984", "L’attaque de 1970", "Le coup de 2008"],
    "bonnes": [0],
    "explication": "En 1990, la Guinée organise un référendum constitutionnel."
  },
  {
    "id": "H145",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une élection multipartite en 1993 ?",
    "choix": ["La présidentielle de 1993", "Le référendum de 1958", "L’attaque de 1970", "Le coup de 2008"],
    "bonnes": [0],
    "explication": "1993 correspond à une présidentielle multipartite."
  },
  {
    "id": "H146",
    "categorieId": "histoire",
    "question": "Quel repère est associé à une crise politico-sécuritaire au stade à Conakry en 2009 ?",
    "choix": ["28 septembre 2009", "28 septembre 1958", "2 octobre 1958", "22 novembre 1970"],
    "bonnes": [0],
    "explication": "Le 28 septembre 2009 renvoie aux événements du stade du 28-Septembre à Conakry."
  },
  {
    "id": "H147",
    "categorieId": "histoire",
    "question": "Quelle paire (date + événement) est correcte ?",
    "choix": ["23 décembre 1990 : référendum constitutionnel", "23 décembre 1990 : coup d’État", "22 décembre 2008 : référendum constitutionnel", "19 décembre 1993 : attaque de Conakry"],
    "bonnes": [0],
    "explication": "Le 23 décembre 1990 est la date du référendum constitutionnel."
  },
  {
    "id": "H148",
    "categorieId": "histoire",
    "question": "Quelle paire (date + événement) est correcte ?",
    "choix": ["19 décembre 1993 : présidentielle multipartite", "19 décembre 1993 : proclamation d’indépendance", "19 décembre 1993 : attaque amphibie", "19 décembre 1993 : coup d’État de 1984"],
    "bonnes": [0],
    "explication": "Le 19 décembre 1993 correspond à la présidentielle multipartite."
  },
  {
    "id": "H149",
    "categorieId": "histoire",
    "question": "Quel sigle correspond à l’organe associé au coup d’État du 5 septembre 2021 ?",
    "choix": ["CRND", "CNDD", "PUP", "PDG"],
    "bonnes": [0],
    "explication": "Le coup de 2021 est associé au CRND."
  },
  {
    "id": "H150",
    "categorieId": "histoire",
    "question": "Quels événements appartiennent à la période 2008–2009 ?",
    "choix": ["Coup 2008 (CNDD)", "Événements du stade 2009", "Référendum constitutionnel 1990", "Attaque 1970"],
    "bonnes": [0, 1],
    "explication": "2008 et 2009 renvoient à la période de junte et à la crise du stade."
  },
  {
    "id": "H151",
    "categorieId": "histoire",
    "question": "Quels jalons appartiennent à la séquence 1984–1993 ?",
    "choix": ["Coup 1984", "Référendum 1990", "Présidentielle 1993", "Ebola 2014"],
    "bonnes": [0, 1, 2],
    "explication": "De 1984 à 1993 : coup, réforme constitutionnelle, puis présidentielle multipartite."
  },
  {
    "id": "H152",
    "categorieId": "histoire",
    "question": "Quel jalon illustre le mieux le passage à un cadre constitutionnel modernisé au début des années 1990 ?",
    "choix": ["Référendum constitutionnel de 1990", "Attaque de 1970", "Indépendance 1958", "Coup 2008"],
    "bonnes": [0],
    "explication": "Le référendum de 1990 est le repère constitutionnel central de cette période."
  },
  {
    "id": "H153",
    "categorieId": "histoire",
    "question": "Quel jalon illustre le mieux un retour à une compétition électorale multipartite ?",
    "choix": ["Présidentielle de 1993", "Attaque de 1970", "Coup de 1984", "Référendum de 1958"],
    "bonnes": [0],
    "explication": "La présidentielle de 1993 est la première avec plusieurs candidats après le retour au multipartisme."
  },
  {
    "id": "H154",
    "categorieId": "histoire",
    "question": "Quel jalon illustre le mieux une crise sanitaire majeure ayant touché la Guinée et la région ?",
    "choix": ["Ebola 2014", "Référendum 1990", "Attaque 1970", "Coup 1984"],
    "bonnes": [0],
    "explication": "Ebola en 2014 est une crise sanitaire majeure, avec premiers cas détectés en Guinée."
  },
  {
    "id": "H155",
    "categorieId": "histoire",
    "question": "Quels événements sont correctement associés à leurs catégories ?",
    "choix": ["1970 : attaque militaire sur Conakry", "1990 : référendum constitutionnel", "1993 : présidentielle multipartite", "1958 : proclamation d’indépendance"],
    "bonnes": [0, 1, 2, 3],
    "explication": "Ces quatre repères correspondent chacun à un jalon guinéen connu (sécurité, constitution, élections, indépendance)."
  },
  {
    "id": "H156",
    "categorieId": "histoire",
    "question": "Quel enchaînement relie correctement décès présidentiel et coup d’État en 2008 ?",
    "choix": [
      "22 décembre 2008 : décès de Lansana Conté → 24 décembre 2008 : coup d’État",
      "24 décembre 2008 : décès → 22 décembre 2008 : coup",
      "22 décembre 2008 : indépendance → 24 décembre 2008 : référendum",
      "22 décembre 2008 : attaque → 24 décembre 2008 : élection"
    ],
    "bonnes": [0],
    "explication": "Lansana Conté meurt le 22 décembre, puis un coup d’État survient le 24 décembre 2008."
  },
  {
    "id": "H157",
    "categorieId": "histoire",
    "question": "Parmi ces dates, lesquelles correspondent à des événements à Conakry ?",
    "choix": ["22 novembre 1970", "28 septembre 2009", "3 avril 1984", "23 décembre 1990"],
    "bonnes": [0, 1, 2],
    "explication": "1970 (attaque), 2009 (stade) et 1984 (coup) sont centrés sur la capitale ; 1990 est un vote national."
  },
  {
    "id": "H158",
    "categorieId": "histoire",
    "question": "Quelle phrase est la plus correcte sur 1990–1993 en Guinée ?",
    "choix": [
      "Réforme constitutionnelle (1990) puis première présidentielle multipartite (1993)",
      "Attaque amphibie (1990) puis indépendance (1993)",
      "Coup d’État (1990) puis attaque (1993)",
      "Ebola (1990) puis coup d’État (1993)"
    ],
    "bonnes": [0],
    "explication": "La séquence 1990–1993 est racontée comme une ouverture constitutionnelle suivie d’une présidentielle multipartite."
  },
  {
    "id": "H159",
    "categorieId": "histoire",
    "question": "Quel repère correspond à une crise majeure liée à l’armée en 1996 ?",
    "choix": ["2 février 1996", "2 février 1958", "2 février 2008", "2 février 2014"],
    "bonnes": [0],
    "explication": "Le 2 février 1996 est associé à une mutinerie/tentative de coup dans le contexte du régime de Lansana Conté."
  },
  {
    "id": "H160",
    "categorieId": "histoire",
    "question": "Quel résumé est le plus fidèle des jalons 1958–2014 en Guinée ?",
    "choix": [
      "Indépendance → tensions/attaques → coups et réformes → élections et crises → Ebola 2014",
      "Ebola 2014 → indépendance 1958 → attaque 1970",
      "Attaque 1970 → référendum 1990 → indépendance 1958",
      "Tout se résume à un seul événement en 2008"
    ],
    "bonnes": [0],
    "explication": "Entre 1958 et 2014, on observe une succession de jalons : indépendance, crises sécuritaires, transitions politiques, réformes, élections, puis crise sanitaire."
  },

  // -------------------------
  // Tranche D: H161 -> H200
  // -------------------------
  {
    "id": "H161",
    "categorieId": "histoire",
    "question": "Quelle ville est la capitale politique de la République de Guinée ?",
    "choix": ["Conakry", "Kankan", "Labé", "Nzérékoré"],
    "bonnes": [0],
    "explication": "Conakry est la capitale politique et administrative de la Guinée."
  },
  {
    "id": "H162",
    "categorieId": "histoire",
    "question": "Quel couple (date + événement) est correct pour la Guinée ?",
    "choix": ["2 octobre 1958 : proclamation de l’indépendance", "22 novembre 1970 : proclamation de l’indépendance", "23 décembre 1990 : coup d’État", "5 septembre 2021 : référendum d’indépendance"],
    "bonnes": [0],
    "explication": "L’indépendance est proclamée le 2 octobre 1958 ; les autres dates renvoient à d’autres événements."
  },
  {
    "id": "H163",
    "categorieId": "histoire",
    "question": "Quels événements sont des changements de pouvoir par la force (coups d’État) en Guinée ?",
    "choix": ["3 avril 1984", "24 décembre 2008", "5 septembre 2021", "23 décembre 1990"],
    "bonnes": [0, 1, 2],
    "explication": "1984, 2008 et 2021 sont des repères de coups d’État ; 1990 renvoie à un référendum constitutionnel."
  },
  {
    "id": "H164",
    "categorieId": "histoire",
    "question": "Quel sigle est associé à la junte issue du coup d’État du 24 décembre 2008 ?",
    "choix": ["CNDD", "CRND", "CEDEAO", "UEMOA"],
    "bonnes": [0],
    "explication": "Après le coup de 2008, la junte se présente comme le CNDD."
  },
  {
    "id": "H165",
    "categorieId": "histoire",
    "question": "Quel sigle est associé à la prise de pouvoir du 5 septembre 2021 ?",
    "choix": ["CRND", "CNDD", "PUP", "PDG"],
    "bonnes": [0],
    "explication": "Le coup d’État de 2021 est associé au CRND."
  },
  {
    "id": "H166",
    "categorieId": "histoire",
    "question": "Quel président est renversé lors du coup d’État du 5 septembre 2021 ?",
    "choix": ["Alpha Condé", "Ahmed Sékou Touré", "Lansana Conté", "Lansana Kouyaté"],
    "bonnes": [0],
    "explication": "Le 5 septembre 2021, le président Alpha Condé est renversé."
  },
  {
    "id": "H167",
    "categorieId": "histoire",
    "question": "Quel leader est historiquement associé au « non » de 1958 et aux débuts de la Guinée indépendante ?",
    "choix": ["Ahmed Sékou Touré", "Mamady Doumbouya", "Alpha Condé", "Moussa Dadis Camara"],
    "bonnes": [0],
    "explication": "Ahmed Sékou Touré est la figure centrale du « non » de 1958 et du début de l’État guinéen indépendant."
  },
  {
    "id": "H168",
    "categorieId": "histoire",
    "question": "Quel événement est associé au 28 septembre 2009 à Conakry ?",
    "choix": ["Violences lors d’un rassemblement au stade", "Proclamation de l’indépendance", "Attaque amphibie étrangère", "Référendum constitutionnel"],
    "bonnes": [0],
    "explication": "Le 28 septembre 2009 renvoie à des violences liées à un rassemblement au stade du 28-Septembre."
  },
  {
    "id": "H169",
    "categorieId": "histoire",
    "question": "Quel lieu de Conakry est directement lié aux événements du 28 septembre 2009 ?",
    "choix": ["Stade du 28-Septembre", "Port de Conakry", "Îles de Loos", "Université de Sonfonia"],
    "bonnes": [0],
    "explication": "Les événements sont associés au stade du 28-Septembre à Conakry."
  },
  {
    "id": "H170",
    "categorieId": "histoire",
    "question": "Quelle période correspond à l’épidémie d’Ebola qui a fortement touché la Guinée (début repéré en 2014) ?",
    "choix": ["2014–2016", "1958–1960", "1970–1972", "1990–1991"],
    "bonnes": [0],
    "explication": "La grande épidémie d’Ebola en Afrique de l’Ouest débute en 2014 et se prolonge jusqu’en 2016."
  },
  {
    "id": "H171",
    "categorieId": "histoire",
    "question": "Les premiers cas détectés d’Ebola en 2014 en Guinée sont associés à :",
    "choix": ["La région forestière (Guinée forestière)", "La Basse Guinée uniquement", "Le Fouta-Djalon uniquement", "Les îles de Loos uniquement"],
    "bonnes": [0],
    "explication": "Les premiers foyers rapportés en 2014 sont associés à la Guinée forestière."
  },
  {
    "id": "H172",
    "categorieId": "histoire",
    "question": "Quel enchaînement chronologique est correct (du plus ancien au plus récent) ?",
    "choix": [
      "Indépendance 1958 → attaque 1970 → coup 1984 → référendum 1990 → présidentielle 1993 → coup 2008 → stade 2009 → présidentielle 2010 → coup 2021",
      "Coup 2021 → indépendance 1958 → attaque 1970",
      "Présidentielle 2010 → référendum 1990 → indépendance 1958",
      "Stade 2009 → coup 1984 → indépendance 1958"
    ],
    "bonnes": [0],
    "explication": "La proposition 1 respecte l’ordre des jalons guinéens majeurs sur la période moderne."
  },
  {
    "id": "H173",
    "categorieId": "histoire",
    "question": "Quel événement est associé au 23 décembre 1990 en Guinée ?",
    "choix": ["Référendum constitutionnel", "Coup d’État", "Attaque de Conakry", "Proclamation d’indépendance"],
    "bonnes": [0],
    "explication": "Le 23 décembre 1990 correspond au référendum constitutionnel."
  },
  {
    "id": "H174",
    "categorieId": "histoire",
    "question": "Quel événement est associé au 19 décembre 1993 en Guinée ?",
    "choix": ["Élection présidentielle multipartite", "Référendum d’indépendance", "Attaque amphibie sur Conakry", "Coup d’État militaire"],
    "bonnes": [0],
    "explication": "Le 19 décembre 1993 correspond à une présidentielle multipartite."
  },
  {
    "id": "H175",
    "categorieId": "histoire",
    "question": "Qui remporte l’élection présidentielle de 2010 en Guinée ?",
    "choix": ["Alpha Condé", "Lansana Conté", "Ahmed Sékou Touré", "Mamady Doumbouya"],
    "bonnes": [0],
    "explication": "Alpha Condé est déclaré vainqueur de la présidentielle de 2010."
  },
  {
    "id": "H176",
    "categorieId": "histoire",
    "question": "Quel repère correspond à l’attaque contre Conakry souvent appelée “Operation Green Sea” ?",
    "choix": ["22 novembre 1970", "22 décembre 2008", "2 octobre 1958", "5 septembre 2021"],
    "bonnes": [0],
    "explication": "L’attaque de Conakry associée à “Operation Green Sea” est datée du 22 novembre 1970."
  },
  {
    "id": "H177",
    "categorieId": "histoire",
    "question": "Quel événement est lié au 3 avril 1984 en Guinée ?",
    "choix": ["Coup d’État", "Référendum constitutionnel", "Proclamation d’indépendance", "Élection présidentielle de 2010"],
    "bonnes": [0],
    "explication": "Le 3 avril 1984 est un repère de coup d’État en Guinée."
  },
  {
    "id": "H178",
    "categorieId": "histoire",
    "question": "Quelle phrase résume le mieux le rôle de 1958 dans l’histoire de la Guinée ?",
    "choix": ["Rupture politique décisive menant à l’indépendance", "Création de la junte CNDD", "Début de l’épidémie d’Ebola", "Attaque amphibie sur Conakry"],
    "bonnes": [0],
    "explication": "1958 correspond à la rupture politique (référendum) et à la proclamation de l’indépendance."
  },
  {
    "id": "H179",
    "categorieId": "histoire",
    "question": "Quels événements sont associés à Conakry (capitale) ?",
    "choix": ["Attaque de 1970", "Coup de 1984", "Événements du stade 2009", "Fondation de l’Imamat du Fouta-Djalon"],
    "bonnes": [0, 1, 2],
    "explication": "Conakry est au centre de plusieurs événements ; l’Imamat du Fouta-Djalon est un repère d’une autre zone."
  },
  {
    "id": "H180",
    "categorieId": "histoire",
    "question": "Quel couple (date + événement) est correct pour 2008 en Guinée ?",
    "choix": ["24 décembre 2008 : coup d’État", "24 décembre 2008 : indépendance", "22 décembre 2008 : coup d’État", "22 décembre 2008 : référendum"],
    "bonnes": [0],
    "explication": "Le coup d’État survient le 24 décembre 2008."
  },
  {
    "id": "H181",
    "categorieId": "histoire",
    "question": "Quelle date correspond au décès de Lansana Conté ?",
    "choix": ["22 décembre 2008", "24 décembre 2008", "19 décembre 1993", "10 janvier 2007"],
    "bonnes": [0],
    "explication": "Lansana Conté décède le 22 décembre 2008."
  },
  {
    "id": "H182",
    "categorieId": "histoire",
    "question": "Quel enchaînement est correct pour décembre 2008 ?",
    "choix": [
      "22 décembre : décès de Lansana Conté → 24 décembre : coup d’État",
      "24 décembre : décès → 22 décembre : coup d’État",
      "22 décembre : référendum → 24 décembre : indépendance",
      "22 décembre : attaque → 24 décembre : élection"
    ],
    "bonnes": [0],
    "explication": "Décembre 2008 suit la séquence décès du président puis coup d’État."
  },
  {
    "id": "H183",
    "categorieId": "histoire",
    "question": "La grève générale de 2007 en Guinée est principalement :",
    "choix": ["Une mobilisation syndicale et sociale d’ampleur", "Une attaque militaire étrangère", "Un référendum constitutionnel", "Une proclamation d’indépendance"],
    "bonnes": [0],
    "explication": "La grève de 2007 est une mobilisation syndicale et sociale majeure."
  },
  {
    "id": "H184",
    "categorieId": "histoire",
    "question": "Quel résultat politique est souvent associé à la crise sociale de 2007 ?",
    "choix": ["Nomination d’un Premier ministre de consensus (Lansana Kouyaté)", "Création du CRND", "Proclamation de l’indépendance", "Attaque de Conakry"],
    "bonnes": [0],
    "explication": "La crise de 2007 est souvent liée à la nomination de Lansana Kouyaté comme Premier ministre."
  },
  {
    "id": "H185",
    "categorieId": "histoire",
    "question": "Quel choix décrit le mieux 2010 en Guinée ?",
    "choix": ["Une présidentielle à deux tours marquant une transition politique", "Un référendum d’indépendance", "Un coup d’État militaire", "Une attaque amphibie étrangère"],
    "bonnes": [0],
    "explication": "2010 correspond à une présidentielle à deux tours dans un contexte de transition."
  },
  {
    "id": "H186",
    "categorieId": "histoire",
    "question": "Dans une question de chronologie, quelle proposition est correcte ?",
    "choix": ["Référendum constitutionnel (1990) avant présidentielle (1993)", "Présidentielle (1993) avant référendum (1990)", "Coup (2021) avant indépendance (1958)", "Attaque (1970) après coup (2008)"],
    "bonnes": [0],
    "explication": "1990 (référendum constitutionnel) précède 1993 (présidentielle multipartite)."
  },
  {
    "id": "H187",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à la notion de “référendum” en histoire guinéenne moderne ?",
    "choix": ["Le 28 septembre 1958", "Le 3 avril 1984", "Le 24 décembre 2008", "Le 5 septembre 2021"],
    "bonnes": [0],
    "explication": "Le 28 septembre 1958 est le repère du référendum lié à l’indépendance."
  },
  {
    "id": "H188",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une réforme constitutionnelle par vote national ?",
    "choix": ["Le référendum de 1990", "Le coup de 1984", "Le coup de 2008", "L’attaque de 1970"],
    "bonnes": [0],
    "explication": "En 1990, une constitution est adoptée par référendum."
  },
  {
    "id": "H189",
    "categorieId": "histoire",
    "question": "Quels jalons appartiennent à la période 2008–2010 en Guinée ?",
    "choix": ["Coup 2008", "Événements du stade 2009", "Présidentielle 2010", "Attaque 1970"],
    "bonnes": [0, 1, 2],
    "explication": "2008–2010 couvre la junte, la crise de 2009 et le processus électoral de 2010."
  },
  {
    "id": "H190",
    "categorieId": "histoire",
    "question": "Quel jalon est le plus récent parmi ces choix ?",
    "choix": ["5 septembre 2021", "7 novembre 2010", "24 décembre 2008", "22 novembre 1970"],
    "bonnes": [0],
    "explication": "Le 5 septembre 2021 est le jalon le plus récent de cette liste."
  },
  {
    "id": "H191",
    "categorieId": "histoire",
    "question": "Quelle phrase est la plus correcte concernant l’histoire politique récente (2008 et 2021) ?",
    "choix": ["Deux coups d’État distincts à des dates différentes", "Un seul événement identique répété en 1958", "Deux référendums constitutionnels", "Deux attaques amphibies étrangères"],
    "bonnes": [0],
    "explication": "2008 et 2021 renvoient à deux coups d’État distincts, avec des sigles et contextes différents."
  },
  {
    "id": "H192",
    "categorieId": "histoire",
    "question": "Dans l’histoire guinéenne, quel repère représente une crise sécuritaire extérieure majeure ?",
    "choix": ["L’attaque de Conakry en 1970", "Le référendum de 1990", "La présidentielle de 1993", "L’élection de 2010"],
    "bonnes": [0],
    "explication": "1970 renvoie à une attaque militaire contre Conakry, dans un contexte régional."
  },
  {
    "id": "H193",
    "categorieId": "histoire",
    "question": "Quels repères sont associés à des événements politiques nationaux (et non sanitaires) ?",
    "choix": ["Indépendance 1958", "Présidentielle 2010", "Ebola 2014", "Coup 2021"],
    "bonnes": [0, 1, 3],
    "explication": "1958, 2010 et 2021 sont des repères politiques ; Ebola 2014 est un repère sanitaire."
  },
  {
    "id": "H194",
    "categorieId": "histoire",
    "question": "Quel repère est associé à une crise sanitaire majeure ?",
    "choix": ["Ebola 2014", "Référendum 1958", "Attaque 1970", "Coup 1984"],
    "bonnes": [0],
    "explication": "Ebola 2014 est une crise sanitaire majeure dans l’histoire récente."
  },
  {
    "id": "H195",
    "categorieId": "histoire",
    "question": "Quels événements correspondent à des processus électoraux (urnes) plutôt qu’à la force ?",
    "choix": ["Présidentielle 1993", "Présidentielle 2010", "Coup 2008", "Coup 2021"],
    "bonnes": [0, 1],
    "explication": "1993 et 2010 correspondent à des élections ; 2008 et 2021 sont des prises de pouvoir par la force."
  },
  {
    "id": "H196",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à une junte appelée CNDD ?",
    "choix": ["Le coup d’État de 2008", "Le coup d’État de 2021", "Le référendum de 1958", "L’épidémie d’Ebola"],
    "bonnes": [0],
    "explication": "CNDD correspond à la junte issue du coup d’État de 2008."
  },
  {
    "id": "H197",
    "categorieId": "histoire",
    "question": "Quel événement est le plus directement lié à l’organe CRND ?",
    "choix": ["Le coup d’État de 2021", "Le coup d’État de 2008", "L’attaque de 1970", "Le référendum de 1990"],
    "bonnes": [0],
    "explication": "CRND est associé à la prise de pouvoir du 5 septembre 2021."
  },
  {
    "id": "H198",
    "categorieId": "histoire",
    "question": "Quelle proposition est correcte sur la date du 28 septembre en Guinée ?",
    "choix": ["Elle renvoie au référendum de 1958 et devient aussi une date symbolique reprise en 2009", "Elle est la date de l’indépendance proclamée", "Elle est la date du coup de 1984", "Elle est la date de l’attaque de 1970"],
    "bonnes": [0],
    "explication": "Le 28 septembre est le référendum de 1958 et la date retenue symboliquement pour un rassemblement en 2009."
  },
  {
    "id": "H199",
    "categorieId": "histoire",
    "question": "Quel triplet (événement → année) est correct ?",
    "choix": ["Indépendance → 1958 / CNDD → 2008 / CRND → 2021", "Indépendance → 1970 / CNDD → 1990 / CRND → 2010", "Indépendance → 1984 / CNDD → 2014 / CRND → 1958", "Indépendance → 2010 / CNDD → 1958 / CRND → 2008"],
    "bonnes": [0],
    "explication": "1958 correspond à l’indépendance ; CNDD à 2008 ; CRND à 2021."
  },
  {
    "id": "H200",
    "categorieId": "histoire",
    "question": "Quels jalons suivants sont des repères “fondamentaux” qu’un quiz Histoire Guinée doit connaître ?",
    "choix": ["Indépendance (1958)", "Attaque de Conakry (1970)", "Coup d’État (1984)", "Coup d’État (2021)"],
    "bonnes": [0, 1, 2, 3],
    "explication": "Ces jalons structurent une grande partie du récit historique moderne : indépendance, crise sécuritaire, changements de régimes, transition récente."
  },
];


    // =========================================================
    // GEOGRAPHIE (20)
    // =========================================================
      static final List<Map<String, dynamic>> _rawGeographieGuinee = [
  {
    "id": "G001",
    "categorieId": "geographie",
    "question": "Quelle est la capitale de la République de Guinée ?",
    "choix": ["Conakry", "Kankan", "Labé", "Nzérékoré"],
    "bonnes": [0],
    "explication": "Conakry est la capitale politique et administrative de la Guinée."
  },
  {
    "id": "G002",
    "categorieId": "geographie",
    "question": "Quel océan borde la Guinée à l’ouest ?",
    "choix": ["Océan Atlantique", "Océan Indien", "Mer Méditerranée", "Mer Rouge"],
    "bonnes": [0],
    "explication": "La Guinée possède une façade maritime sur l’océan Atlantique."
  },
  {
    "id": "G003",
    "categorieId": "geographie",
    "question": "Combien de régions naturelles compte la Guinée ?",
    "choix": ["4", "3", "5", "6"],
    "bonnes": [0],
    "explication": "On distingue classiquement : Basse Guinée, Moyenne Guinée, Haute Guinée et Guinée forestière."
  },
  {
    "id": "G004",
    "categorieId": "geographie",
    "question": "La Basse Guinée correspond surtout à :",
    "choix": ["La zone littorale et côtière", "Les savanes intérieures", "Les hauts plateaux du Fouta", "Les forêts denses du sud-est"],
    "bonnes": [0],
    "explication": "La Basse Guinée est la région côtière, ouverte sur l’Atlantique."
  },
  {
    "id": "G005",
    "categorieId": "geographie",
    "question": "Quelle région naturelle est aussi appelée Fouta-Djalon ?",
    "choix": ["Moyenne Guinée", "Basse Guinée", "Haute Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon correspond à la Moyenne Guinée, caractérisée par des plateaux et montagnes."
  },
  {
    "id": "G006",
    "categorieId": "geographie",
    "question": "La Haute Guinée est plutôt dominée par :",
    "choix": ["Savanes et plaines intérieures", "Mangroves côtières", "Reliefs très élevés", "Zones glaciaires"],
    "bonnes": [0],
    "explication": "La Haute Guinée est un espace intérieur de savanes et plaines, propice à certaines cultures et à l’élevage."
  },
  {
    "id": "G007",
    "categorieId": "geographie",
    "question": "La Guinée forestière se situe principalement :",
    "choix": ["Au sud-est du pays", "Au nord-ouest", "Sur la côte uniquement", "Au centre-nord"],
    "bonnes": [0],
    "explication": "La Guinée forestière se trouve au sud-est et se caractérise par une végétation dense."
  },
  {
    "id": "G008",
    "categorieId": "geographie",
    "question": "Quel grand fleuve ouest-africain prend sa source en Guinée ?",
    "choix": ["Niger", "Nil", "Congo", "Zambèze"],
    "bonnes": [0],
    "explication": "Le Niger prend sa source dans le massif guinéen (Fouta-Djalon)."
  },
  {
    "id": "G009",
    "categorieId": "geographie",
    "question": "Quel autre fleuve important prend aussi sa source en Guinée ?",
    "choix": ["Sénégal", "Congo", "Orange", "Limpopo"],
    "bonnes": [0],
    "explication": "Le fleuve Sénégal (via ses affluents) a des sources en Guinée."
  },
  {
    "id": "G010",
    "categorieId": "geographie",
    "question": "Pourquoi la Guinée est-elle appelée « château d’eau » de l’Afrique de l’Ouest ?",
    "choix": [
      "Parce que plusieurs grands fleuves y prennent leur source",
      "Parce qu’elle est entourée par des lacs",
      "Parce qu’elle n’a pas de saison sèche",
      "Parce qu’elle est une île"
    ],
    "bonnes": [0],
    "explication": "Les reliefs guinéens alimentent de nombreux fleuves majeurs de la sous-région."
  },

  {
    "id": "G011",
    "categorieId": "geographie",
    "question": "Quelle ville est la plus grande agglomération du pays ?",
    "choix": ["Conakry", "Labé", "Siguiri", "Dalaba"],
    "bonnes": [0],
    "explication": "Conakry est la plus grande agglomération et le principal centre économique."
  },
  {
    "id": "G012",
    "categorieId": "geographie",
    "question": "Quel massif structure le relief de la Moyenne Guinée ?",
    "choix": ["Massif du Fouta-Djalon", "Atlas", "Alpes", "Himalaya"],
    "bonnes": [0],
    "explication": "La Moyenne Guinée est dominée par le massif du Fouta-Djalon."
  },
  {
    "id": "G013",
    "categorieId": "geographie",
    "question": "Quelle ville est un centre majeur de la Haute Guinée ?",
    "choix": ["Kankan", "Conakry", "Boké", "Coyah"],
    "bonnes": [0],
    "explication": "Kankan est une ville majeure de la Haute Guinée."
  },
  {
    "id": "G014",
    "categorieId": "geographie",
    "question": "Quelle ville est un centre important de la Moyenne Guinée ?",
    "choix": ["Labé", "Boké", "Kankan", "Beyla"],
    "bonnes": [0],
    "explication": "Labé est une ville centrale de la Moyenne Guinée (Fouta-Djalon)."
  },
  {
    "id": "G015",
    "categorieId": "geographie",
    "question": "Quelle ville est un centre important de la Guinée forestière ?",
    "choix": ["Nzérékoré", "Kindia", "Fria", "Gaoual"],
    "bonnes": [0],
    "explication": "Nzérékoré est la principale ville de la Guinée forestière."
  },
  {
    "id": "G016",
    "categorieId": "geographie",
    "question": "Quel pays ne partage PAS de frontière avec la Guinée ?",
    "choix": ["Ghana", "Mali", "Sierra Leone", "Côte d’Ivoire"],
    "bonnes": [0],
    "explication": "La Guinée n’a pas de frontière avec le Ghana."
  },
  {
    "id": "G017",
    "categorieId": "geographie",
    "question": "Avec combien de pays la Guinée partage-t-elle une frontière terrestre ?",
    "choix": ["6", "4", "5", "7"],
    "bonnes": [0],
    "explication": "La Guinée partage ses frontières avec 6 pays : Guinée-Bissau, Sénégal, Mali, Côte d’Ivoire, Libéria, Sierra Leone."
  },
  {
    "id": "G018",
    "categorieId": "geographie",
    "question": "Quel pays se situe au nord de la Guinée ?",
    "choix": ["Mali", "Libéria", "Sierra Leone", "Océan Atlantique"],
    "bonnes": [0],
    "explication": "Le Mali est au nord/nord-est de la Guinée."
  },
  {
    "id": "G019",
    "categorieId": "geographie",
    "question": "Quel pays se situe au sud de la Guinée ?",
    "choix": ["Libéria", "Sénégal", "Mali", "Guinée-Bissau"],
    "bonnes": [0],
    "explication": "Le Libéria est au sud de la Guinée."
  },
  {
    "id": "G020",
    "categorieId": "geographie",
    "question": "Quel pays se situe au sud-ouest de la Guinée ?",
    "choix": ["Sierra Leone", "Mali", "Sénégal", "Côte d’Ivoire"],
    "bonnes": [0],
    "explication": "La Sierra Leone se situe au sud-ouest de la Guinée."
  },

  {
    "id": "G021",
    "categorieId": "geographie",
    "question": "Quel pays se situe à l’ouest de la Guinée (en partie) ?",
    "choix": ["Guinée-Bissau", "Burkina Faso", "Ghana", "Togo"],
    "bonnes": [0],
    "explication": "La Guinée-Bissau est voisine à l’ouest/nord-ouest."
  },
  {
    "id": "G022",
    "categorieId": "geographie",
    "question": "Quel pays se situe au nord-ouest de la Guinée ?",
    "choix": ["Sénégal", "Libéria", "Côte d’Ivoire", "Bénin"],
    "bonnes": [0],
    "explication": "Le Sénégal est voisin au nord-ouest."
  },
  {
    "id": "G023",
    "categorieId": "geographie",
    "question": "Quel pays se situe au sud-est de la Guinée ?",
    "choix": ["Côte d’Ivoire", "Guinée-Bissau", "Sénégal", "Mali"],
    "bonnes": [0],
    "explication": "La Côte d’Ivoire est voisine au sud-est."
  },
  {
    "id": "G024",
    "categorieId": "geographie",
    "question": "Quel pays se situe à l’est/nord-est de la Guinée ?",
    "choix": ["Mali", "Sierra Leone", "Guinée-Bissau", "Océan Atlantique"],
    "bonnes": [0],
    "explication": "Le Mali est voisin à l’est/nord-est."
  },
  {
    "id": "G025",
    "categorieId": "geographie",
    "question": "Quel climat domine globalement en Guinée ?",
    "choix": ["Tropical", "Polaire", "Désertique", "Continental froid"],
    "bonnes": [0],
    "explication": "La Guinée se situe en zone tropicale : alternance saison des pluies et saison sèche."
  },
  {
    "id": "G026",
    "categorieId": "geographie",
    "question": "La saison des pluies en Guinée se situe généralement :",
    "choix": ["De mai à octobre", "De novembre à mars", "Toute l’année", "Uniquement en décembre"],
    "bonnes": [0],
    "explication": "La saison des pluies se situe le plus souvent de mai à octobre."
  },
  {
    "id": "G027",
    "categorieId": "geographie",
    "question": "La saison sèche correspond surtout :",
    "choix": ["De novembre à avril", "De juin à septembre", "Toute l’année", "Uniquement en août"],
    "bonnes": [0],
    "explication": "On observe une saison sèche généralement de novembre à avril."
  },
  {
    "id": "G028",
    "categorieId": "geographie",
    "question": "Quel vent sec est connu en Afrique de l’Ouest pendant la saison sèche et peut toucher la Guinée ?",
    "choix": ["Harmattan", "Sirocco", "Mistral", "Bora"],
    "bonnes": [0],
    "explication": "L’harmattan est un vent sec venu du Sahara pendant la saison sèche."
  },
  {
    "id": "G029",
    "categorieId": "geographie",
    "question": "Quelle ressource minière est la plus connue en Guinée ?",
    "choix": ["Bauxite", "Charbon", "Pétrole", "Potasse"],
    "bonnes": [0],
    "explication": "La Guinée est mondialement connue pour ses réserves de bauxite."
  },
  {
    "id": "G030",
    "categorieId": "geographie",
    "question": "Quelle zone est fortement associée à l’exploitation de la bauxite ?",
    "choix": ["Boké", "Nzérékoré", "Labé", "Kérouané"],
    "bonnes": [0],
    "explication": "La région de Boké est un pôle majeur de la bauxite."
  },

  {
    "id": "G031",
    "categorieId": "geographie",
    "question": "Quel fleuve guinéen se jette dans l’océan Atlantique ?",
    "choix": ["Konkouré", "Niger", "Sénégal", "Gambie"],
    "bonnes": [0],
    "explication": "Le Konkouré est un fleuve guinéen qui se jette dans l’Atlantique."
  },
  {
    "id": "G032",
    "categorieId": "geographie",
    "question": "Quel archipel est situé au large de Conakry ?",
    "choix": ["Îles de Loos", "Île de Gorée", "Zanzibar", "Canaries"],
    "bonnes": [0],
    "explication": "Les îles de Loos se situent au large de Conakry."
  },
  {
    "id": "G033",
    "categorieId": "geographie",
    "question": "Quel type de végétation est typique des zones côtières de Basse Guinée ?",
    "choix": ["Mangrove", "Toundra", "Forêt boréale", "Steppe froide"],
    "bonnes": [0],
    "explication": "Les zones côtières abritent des mangroves."
  },
  {
    "id": "G034",
    "categorieId": "geographie",
    "question": "Quel type de végétation domine largement en Haute Guinée ?",
    "choix": ["Savane", "Forêt tropicale dense", "Mangrove", "Taïga"],
    "bonnes": [0],
    "explication": "La Haute Guinée est majoritairement une zone de savanes."
  },
  {
    "id": "G035",
    "categorieId": "geographie",
    "question": "Quel type de relief est typique de la Moyenne Guinée ?",
    "choix": ["Plateaux et montagnes", "Déserts", "Plaines polaires", "Volcans actifs"],
    "bonnes": [0],
    "explication": "La Moyenne Guinée est un ensemble de plateaux et montagnes (Fouta-Djalon)."
  },
  {
    "id": "G036",
    "categorieId": "geographie",
    "question": "Quelle région est la plus éloignée de l’océan Atlantique ?",
    "choix": ["Haute Guinée", "Basse Guinée", "Conakry", "Forécariah"],
    "bonnes": [0],
    "explication": "La Haute Guinée se situe à l’intérieur des terres, loin du littoral."
  },
  {
    "id": "G037",
    "categorieId": "geographie",
    "question": "Quel grand fleuve traverse la Haute Guinée ?",
    "choix": ["Niger", "Nil", "Congo", "Danube"],
    "bonnes": [0],
    "explication": "Le Niger traverse la Haute Guinée avant de poursuivre sa course en Afrique de l’Ouest."
  },
  {
    "id": "G038",
    "categorieId": "geographie",
    "question": "Quel fleuve prend sa source en Guinée et arrose la Gambie et le Sénégal ?",
    "choix": ["Fleuve Gambie", "Fleuve Congo", "Fleuve Volta", "Fleuve Nil"],
    "bonnes": [0],
    "explication": "Le fleuve Gambie prend sa source en Guinée avant de rejoindre la Gambie."
  },
  {
    "id": "G039",
    "categorieId": "geographie",
    "question": "Quel est le principal port maritime du pays ?",
    "choix": ["Port de Conakry", "Port de Labé", "Port de Kankan", "Port de Nzérékoré"],
    "bonnes": [0],
    "explication": "Le port de Conakry est la principale porte maritime de la Guinée."
  },
  {
    "id": "G040",
    "categorieId": "geographie",
    "question": "Quelle région est souvent la plus humide et la plus forestière ?",
    "choix": ["Guinée forestière", "Haute Guinée", "Moyenne Guinée", "Basse Guinée"],
    "bonnes": [0],
    "explication": "La Guinée forestière est caractérisée par une forte humidité et des forêts denses."
  },

  {
    "id": "G041",
    "categorieId": "geographie",
    "question": "Quel facteur naturel explique en partie la fraîcheur relative de certaines zones du Fouta-Djalon ?",
    "choix": ["L’altitude", "La proximité du pôle Nord", "Les glaciers", "Le désert"],
    "bonnes": [0],
    "explication": "L’altitude du Fouta-Djalon rend certaines zones plus fraîches que les plaines."
  },
  {
    "id": "G042",
    "categorieId": "geographie",
    "question": "Quel type d’agriculture domine dans la plupart des zones rurales guinéennes ?",
    "choix": ["Agriculture pluviale", "Agriculture sous neige", "Agriculture désertique", "Agriculture uniquement hors-sol"],
    "bonnes": [0],
    "explication": "L’agriculture dépend fortement des pluies : c’est une agriculture pluviale."
  },
  {
    "id": "G043",
    "categorieId": "geographie",
    "question": "Quelle région est la plus favorable au riz de mangrove ?",
    "choix": ["Basse Guinée", "Haute Guinée", "Moyenne Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Le riz de mangrove est lié aux zones côtières de Basse Guinée."
  },
  {
    "id": "G044",
    "categorieId": "geographie",
    "question": "Quelle région est souvent adaptée à l’élevage extensif (savanes) ?",
    "choix": ["Haute Guinée", "Conakry", "Basse Guinée littorale", "Îles de Loos"],
    "bonnes": [0],
    "explication": "Les savanes de Haute Guinée sont favorables à l’élevage extensif."
  },
  {
    "id": "G045",
    "categorieId": "geographie",
    "question": "Quel est un rôle majeur des mangroves sur la côte guinéenne ?",
    "choix": ["Protéger les côtes contre l’érosion", "Créer des glaciers", "Créer des volcans", "Assécher l’océan"],
    "bonnes": [0],
    "explication": "Les mangroves freinent l’érosion et protègent le littoral."
  },
  {
    "id": "G046",
    "categorieId": "geographie",
    "question": "Quel risque naturel devient plus fréquent en saison des pluies ?",
    "choix": ["Inondations", "Avalanches", "Blizzards", "Tempêtes de neige"],
    "bonnes": [0],
    "explication": "Les fortes pluies peuvent provoquer des inondations, surtout en zones basses."
  },
  {
    "id": "G047",
    "categorieId": "geographie",
    "question": "Quelle région est la plus urbanisée et densément peuplée ?",
    "choix": ["Basse Guinée", "Moyenne Guinée", "Haute Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "La Basse Guinée, avec Conakry, concentre la plus forte densité urbaine."
  },
  {
    "id": "G048",
    "categorieId": "geographie",
    "question": "Pourquoi certaines routes deviennent difficiles en saison des pluies ?",
    "choix": ["Dégradation/érosion et boue", "Gel permanent", "Sable du désert", "Glace et neige"],
    "bonnes": [0],
    "explication": "Les pluies dégradent les pistes et rendent la circulation plus difficile."
  },
  {
    "id": "G049",
    "categorieId": "geographie",
    "question": "Quel type de paysage est typique autour de Conakry ?",
    "choix": ["Paysage côtier", "Paysage désertique", "Paysage glaciaire", "Paysage polaire"],
    "bonnes": [0],
    "explication": "Conakry est située sur la côte atlantique."
  },
  {
    "id": "G050",
    "categorieId": "geographie",
    "question": "Quel type de relief peut limiter l’agriculture mécanisée ?",
    "choix": ["Relief montagneux", "Plaines", "Vallées alluviales", "Bas-fonds"],
    "bonnes": [0],
    "explication": "Les reliefs montagneux compliquent l’accès et la mécanisation."
  },

  {
    "id": "G051",
    "categorieId": "geographie",
    "question": "Quel grand ensemble administratif existe en Guinée ?",
    "choix": ["Régions administratives", "Cantons alpins", "États fédérés", "Provinces impériales"],
    "bonnes": [0],
    "explication": "La Guinée est divisée en régions administratives, elles-mêmes divisées en préfectures."
  },
  {
    "id": "G052",
    "categorieId": "geographie",
    "question": "Le relief du Fouta-Djalon est important car il :",
    "choix": ["Alimente de nombreuses sources fluviales", "Empêche toute rivière", "Est entièrement désertique", "N’a aucun impact"],
    "bonnes": [0],
    "explication": "Les hauteurs du Fouta-Djalon favorisent la naissance de nombreux cours d’eau."
  },
  {
    "id": "G053",
    "categorieId": "geographie",
    "question": "Quel est un effet direct de la déforestation sur les sols ?",
    "choix": ["Érosion accrue", "Augmentation des glaciers", "Baisse de la gravité", "Création de volcans"],
    "bonnes": [0],
    "explication": "Sans couvert végétal, les sols sont davantage emportés par les pluies."
  },
  {
    "id": "G054",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de l’aménagement du territoire en Guinée ?",
    "choix": ["Réduire les inégalités d’accès aux services", "Créer des montagnes", "Assécher les fleuves", "Déplacer l’océan"],
    "bonnes": [0],
    "explication": "L’aménagement vise à améliorer routes, services et équipements sur l’ensemble du territoire."
  },
  {
    "id": "G055",
    "categorieId": "geographie",
    "question": "Quelle activité économique est fortement liée au littoral ?",
    "choix": ["Pêche", "Ski", "Élevage de rennes", "Culture du blé sous neige"],
    "bonnes": [0],
    "explication": "La pêche est une activité importante sur la côte guinéenne."
  },
  {
    "id": "G056",
    "categorieId": "geographie",
    "question": "Quel est un usage fréquent des fleuves en Guinée ?",
    "choix": ["Hydroélectricité", "Navigation transatlantique", "Fonte des glaciers", "Création de tsunamis"],
    "bonnes": [0],
    "explication": "Les fleuves offrent un potentiel hydroélectrique important."
  },
  {
    "id": "G057",
    "categorieId": "geographie",
    "question": "Quel est le principal lien entre relief et hydroélectricité ?",
    "choix": ["Dénivelés favorisant les barrages", "Absence d’eau", "Présence de neige", "Présence de volcanisme"],
    "bonnes": [0],
    "explication": "Les dénivelés et le débit des cours d’eau facilitent la production hydroélectrique."
  },
  {
    "id": "G058",
    "categorieId": "geographie",
    "question": "Quel est un risque environnemental lié à l’activité minière ?",
    "choix": ["Pollution et dégradation des sols", "Création de glaciers", "Baisse du niveau des montagnes", "Apparition d’icebergs"],
    "bonnes": [0],
    "explication": "L’exploitation minière peut affecter l’eau, les sols et les paysages."
  },
  {
    "id": "G059",
    "categorieId": "geographie",
    "question": "Quel élément naturel est essentiel à l’agriculture guinéenne ?",
    "choix": ["La pluie", "La neige", "La glace", "Les tempêtes polaires"],
    "bonnes": [0],
    "explication": "Les pluies conditionnent les saisons agricoles en Guinée."
  },
  {
    "id": "G060",
    "categorieId": "geographie",
    "question": "Quelle zone est la plus exposée aux inondations côtières ?",
    "choix": ["Basse Guinée", "Haute Guinée", "Moyenne Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Le littoral et les zones basses de Basse Guinée peuvent subir des inondations."
  },

  // -------------------------
  // G061 -> G100 (continuité)
  // -------------------------
  {
    "id": "G061",
    "categorieId": "geographie",
    "question": "Quel facteur explique une partie de la diversité climatique entre régions guinéennes ?",
    "choix": ["Relief et altitude", "Présence de glaciers", "Latitude polaire", "Volcanisme actif"],
    "bonnes": [0],
    "explication": "L’altitude et le relief (notamment au Fouta-Djalon) influencent le climat local."
  },
  {
    "id": "G062",
    "categorieId": "geographie",
    "question": "Quel est l’intérêt des vallées fluviales pour l’agriculture ?",
    "choix": ["Sols plus fertiles et irrigation possible", "Sol gelé", "Absence d’eau", "Climat polaire"],
    "bonnes": [0],
    "explication": "Les vallées offrent souvent des sols alluviaux plus riches et une meilleure disponibilité en eau."
  },
  {
    "id": "G063",
    "categorieId": "geographie",
    "question": "Quel type de sol est souvent associé aux dépôts des fleuves ?",
    "choix": ["Sol alluvial", "Sol glaciaire", "Sol désertique", "Sol volcanique récent"],
    "bonnes": [0],
    "explication": "Les fleuves déposent des alluvions qui enrichissent les sols."
  },
  {
    "id": "G064",
    "categorieId": "geographie",
    "question": "Quel paysage est typique de la Guinée forestière ?",
    "choix": ["Forêt dense", "Désert", "Toundra", "Steppe froide"],
    "bonnes": [0],
    "explication": "La Guinée forestière est marquée par une forêt dense et une forte biodiversité."
  },
  {
    "id": "G065",
    "categorieId": "geographie",
    "question": "Quelle grande culture est souvent associée aux zones humides et forestières (selon les zones) ?",
    "choix": ["Café et cacao", "Blé", "Seigle", "Orge"],
    "bonnes": [0],
    "explication": "Les zones humides du sud peuvent être favorables à certaines cultures comme café/cacao."
  },
  {
    "id": "G066",
    "categorieId": "geographie",
    "question": "Quelle activité est importante dans plusieurs zones rurales guinéennes ?",
    "choix": ["Agro-pastoralisme", "Ski", "Chasse au phoque", "Élevage de rennes"],
    "bonnes": [0],
    "explication": "De nombreuses zones combinent agriculture et élevage (agro-pastoralisme)."
  },
  {
    "id": "G067",
    "categorieId": "geographie",
    "question": "Quel est un facteur majeur d’urbanisation en Guinée ?",
    "choix": ["Attraction de Conakry (emplois/services)", "Présence de neige", "Volcans actifs", "Glaciers"],
    "bonnes": [0],
    "explication": "Conakry concentre emplois et services, attirant des populations depuis l’intérieur."
  },
  {
    "id": "G068",
    "categorieId": "geographie",
    "question": "Quel est un avantage de la position côtière de la Guinée ?",
    "choix": ["Accès au commerce maritime", "Climat polaire", "Absence de pluies", "Isolement total"],
    "bonnes": [0],
    "explication": "La façade atlantique facilite échanges maritimes et import/export."
  },
  {
    "id": "G069",
    "categorieId": "geographie",
    "question": "Quelle région est la plus montagneuse ?",
    "choix": ["Moyenne Guinée", "Haute Guinée", "Basse Guinée", "Conakry"],
    "bonnes": [0],
    "explication": "La Moyenne Guinée (Fouta-Djalon) présente des reliefs plus élevés."
  },
  {
    "id": "G070",
    "categorieId": "geographie",
    "question": "Quel grand atout géographique favorise l’hydroélectricité ?",
    "choix": ["Réseau de fleuves et dénivelés", "Présence de banquise", "Sable saharien", "Absence de rivières"],
    "bonnes": [0],
    "explication": "La combinaison fleuves + reliefs crée un fort potentiel hydroélectrique."
  },
  {
    "id": "G071",
    "categorieId": "geographie",
    "question": "Quel impact peut avoir l’érosion sur l’agriculture ?",
    "choix": ["Baisse de fertilité des sols", "Augmentation des récoltes automatiquement", "Création de glaciers", "Aucun impact"],
    "bonnes": [0],
    "explication": "L’érosion emporte la couche fertile et peut réduire les rendements."
  },
  {
    "id": "G072",
    "categorieId": "geographie",
    "question": "Quel élément naturel peut freiner l’érosion côtière ?",
    "choix": ["Mangrove", "Glacier", "Volcan", "Désert"],
    "bonnes": [0],
    "explication": "La mangrove stabilise les sols et réduit l’énergie des vagues."
  },
  {
    "id": "G073",
    "categorieId": "geographie",
    "question": "Pourquoi la Guinée forestière est-elle parfois difficile d’accès ?",
    "choix": ["Relief, pluies et couverture forestière", "Neige", "Désert", "Glaciers"],
    "bonnes": [0],
    "explication": "L’humidité, les pistes et certains reliefs peuvent compliquer l’accès."
  },
  {
    "id": "G074",
    "categorieId": "geographie",
    "question": "Quel est le principal enjeu de l’eau en Guinée malgré l’abondance des fleuves ?",
    "choix": ["Accès et distribution (infrastructures)", "Absence totale d’eau", "Glaciation", "Désertification polaire"],
    "bonnes": [0],
    "explication": "Le défi est souvent l’accès, la qualité et la distribution via les infrastructures."
  },
  {
    "id": "G075",
    "categorieId": "geographie",
    "question": "Quel type de paysage est associé aux savanes de Haute Guinée ?",
    "choix": ["Paysage de savane", "Paysage de fjords", "Paysage glaciaire", "Paysage désertique saharien pur"],
    "bonnes": [0],
    "explication": "La Haute Guinée correspond largement à des savanes et plaines."
  },
  {
    "id": "G076",
    "categorieId": "geographie",
    "question": "Quelle ressource naturelle favorise fortement l’activité minière en Guinée ?",
    "choix": ["Minerais (dont bauxite)", "Glace", "Charbon arctique", "Volcans"],
    "bonnes": [0],
    "explication": "La Guinée est riche en ressources minières, notamment la bauxite."
  },
  {
    "id": "G077",
    "categorieId": "geographie",
    "question": "Quelle région est la plus directement liée à la façade maritime ?",
    "choix": ["Basse Guinée", "Haute Guinée", "Moyenne Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "La Basse Guinée correspond au littoral et aux plaines côtières."
  },
  {
    "id": "G078",
    "categorieId": "geographie",
    "question": "Quel avantage géographique donne le Fouta-Djalon à la Guinée ?",
    "choix": ["Sources fluviales et altitude", "Glaciers permanents", "Désert de sable", "Absence de pluie"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon joue un rôle majeur pour les sources d’eau et le relief."
  },
  {
    "id": "G079",
    "categorieId": "geographie",
    "question": "Quel phénomène est fréquent en saison sèche et peut affecter la visibilité ?",
    "choix": ["Brume/poussières de l’harmattan", "Neige", "Brouillard polaire", "Cendres volcaniques"],
    "bonnes": [0],
    "explication": "L’harmattan transporte des poussières et peut réduire la visibilité."
  },
  {
    "id": "G080",
    "categorieId": "geographie",
    "question": "Quelle zone est la plus susceptible d’avoir des mangroves ?",
    "choix": ["Littoral de Basse Guinée", "Plateaux intérieurs", "Savanes de Haute Guinée", "Montagnes du Fouta loin de la mer"],
    "bonnes": [0],
    "explication": "Les mangroves se développent sur les côtes et estuaires."
  },

  {
    "id": "G081",
    "categorieId": "geographie",
    "question": "Quel est un défi géographique pour les transports en Guinée ?",
    "choix": ["Relief + saison des pluies", "Présence de glaciers", "Tempêtes de neige", "Volcanisme actif généralisé"],
    "bonnes": [0],
    "explication": "Le relief et les fortes pluies rendent certaines routes difficiles."
  },
  {
    "id": "G082",
    "categorieId": "geographie",
    "question": "Pourquoi les sols peuvent être plus fertiles dans certaines plaines fluviales ?",
    "choix": ["Dépôts alluviaux", "Gel permanent", "Cendres volcaniques fréquentes", "Absence d’eau"],
    "bonnes": [0],
    "explication": "Les fleuves déposent des alluvions riches, qui fertilisent les sols."
  },
  {
    "id": "G083",
    "categorieId": "geographie",
    "question": "Quel secteur est un grand pôle urbain et administratif en Guinée ?",
    "choix": ["Grand Conakry", "Sommet du Fouta-Djalon uniquement", "Zones désertiques", "Îles isolées uniquement"],
    "bonnes": [0],
    "explication": "Le Grand Conakry concentre l’administration et une grande partie de l’économie."
  },
  {
    "id": "G084",
    "categorieId": "geographie",
    "question": "Quel type d’économie est directement facilité par l’accès maritime ?",
    "choix": ["Import/export", "Ski", "Pêche polaire", "Élevage arctique"],
    "bonnes": [0],
    "explication": "L’accès à l’Atlantique favorise le commerce maritime."
  },
  {
    "id": "G085",
    "categorieId": "geographie",
    "question": "Quel élément peut protéger les ressources en eau ?",
    "choix": ["Reboisement et protection des bassins versants", "Déforestation", "Pollution", "Assèchement des marais"],
    "bonnes": [0],
    "explication": "Protéger les bassins versants limite l’érosion et sécurise l’eau."
  },
  {
    "id": "G086",
    "categorieId": "geographie",
    "question": "Quel type de climat favorise la riziculture dans plusieurs zones ?",
    "choix": ["Climat humide", "Climat polaire", "Climat désertique", "Climat continental froid"],
    "bonnes": [0],
    "explication": "Le riz nécessite beaucoup d’eau : l’humidité et les pluies sont essentielles."
  },
  {
    "id": "G087",
    "categorieId": "geographie",
    "question": "Quel type de ressource explique l’importance de Boké dans l’économie ?",
    "choix": ["Bauxite", "Pétrole", "Charbon", "Gaz naturel arctique"],
    "bonnes": [0],
    "explication": "Boké est un pôle majeur lié à la bauxite."
  },
  {
    "id": "G088",
    "categorieId": "geographie",
    "question": "Quel facteur rend certaines zones forestières sensibles à la déforestation ?",
    "choix": ["Pression sur le bois et les terres", "Neige", "Glaciers", "Absence totale de végétation"],
    "bonnes": [0],
    "explication": "Les besoins en terres, bois-énergie et agriculture peuvent accentuer la déforestation."
  },
  {
    "id": "G089",
    "categorieId": "geographie",
    "question": "Quel est un effet possible de la déforestation sur les cours d’eau ?",
    "choix": ["Envasement et baisse de qualité de l’eau", "Transformation en glacier", "Disparition de l’océan", "Aucun changement"],
    "bonnes": [0],
    "explication": "L’érosion augmente les sédiments dans les rivières, ce qui peut dégrader la qualité."
  },
  {
    "id": "G090",
    "categorieId": "geographie",
    "question": "Quel est un risque fréquent des zones urbaines en saison des pluies ?",
    "choix": ["Inondations urbaines", "Avalanches", "Tempêtes de neige", "Gel des routes"],
    "bonnes": [0],
    "explication": "Les fortes pluies peuvent provoquer des inondations en ville, surtout avec un drainage insuffisant."
  },

  {
    "id": "G091",
    "categorieId": "geographie",
    "question": "Quel est un élément clé qui structure les activités rurales ?",
    "choix": ["Calendrier des saisons (pluies/sèche)", "Saisons de neige", "Glaciation", "Saison des volcans"],
    "bonnes": [0],
    "explication": "La vie agricole dépend du rythme saison des pluies / saison sèche."
  },
  {
    "id": "G092",
    "categorieId": "geographie",
    "question": "Quel espace est le plus favorable aux activités maritimes ?",
    "choix": ["Basse Guinée", "Moyenne Guinée", "Haute Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Les activités maritimes se développent sur le littoral de Basse Guinée."
  },
  {
    "id": "G093",
    "categorieId": "geographie",
    "question": "Quel est un atout géographique majeur pour l’agriculture en Guinée ?",
    "choix": ["Diversité des climats et des sols", "Climat polaire", "Désert total", "Absence d’eau"],
    "bonnes": [0],
    "explication": "Les 4 régions naturelles offrent une diversité de paysages et possibilités agricoles."
  },
  {
    "id": "G094",
    "categorieId": "geographie",
    "question": "Quel risque naturel est lié à l’érosion sur les pentes ?",
    "choix": ["Glissements de terrain", "Avalanches", "Tsunamis polaires", "Éruptions volcaniques fréquentes"],
    "bonnes": [0],
    "explication": "L’érosion et les pluies peuvent fragiliser les pentes et provoquer des glissements."
  },
  {
    "id": "G095",
    "categorieId": "geographie",
    "question": "Quel phénomène social est lié à l’attraction de Conakry ?",
    "choix": ["Exode rural", "Migration vers les glaciers", "Nomadisme polaire", "Désertification maritime"],
    "bonnes": [0],
    "explication": "De nombreuses personnes migrent vers Conakry pour l’emploi et les services."
  },
  {
    "id": "G096",
    "categorieId": "geographie",
    "question": "Quel est un facteur qui augmente la pression sur les terres agricoles ?",
    "choix": ["Croissance démographique", "Refroidissement polaire", "Glaciation", "Volcanisme"],
    "bonnes": [0],
    "explication": "Une population en croissance augmente la demande en terres et en production."
  },
  {
    "id": "G097",
    "categorieId": "geographie",
    "question": "Quel élément géographique est essentiel pour la pêche ?",
    "choix": ["Le littoral atlantique", "Les glaciers", "Le désert", "Les sommets enneigés"],
    "bonnes": [0],
    "explication": "La pêche dépend de l’accès à l’océan et aux zones estuariennes."
  },
  {
    "id": "G098",
    "categorieId": "geographie",
    "question": "Quel est un avantage des sols alluviaux ?",
    "choix": ["Fertilité plus élevée", "Gel permanent", "Absence d’eau", "Sable saharien pur"],
    "bonnes": [0],
    "explication": "Les alluvions déposées par les fleuves enrichissent les sols."
  },
  {
    "id": "G099",
    "categorieId": "geographie",
    "question": "Quel enjeu est souvent cité pour l’aménagement du territoire ?",
    "choix": ["Connectivité (routes/ponts) entre zones", "Créer des volcans", "Créer des glaciers", "Réduire l’océan"],
    "bonnes": [0],
    "explication": "Relier les zones, surtout rurales, est clé pour économie et services."
  },
  {
    "id": "G100",
    "categorieId": "geographie",
    "question": "Pourquoi la géographie aide-t-elle à comprendre l’économie guinéenne ?",
    "choix": ["Elle explique ressources, reliefs et activités", "Elle ne sert qu’aux cartes", "Elle ignore les ressources", "Elle ne concerne que l’océan"],
    "bonnes": [0],
    "explication": "Relief, climat, fleuves et minerais influencent agriculture, mines, pêche et transports."
  },

  // -------------------------
  // G101 -> G200 (complément)
  // -------------------------
  {
    "id": "G101",
    "categorieId": "geographie",
    "question": "Quelle ville est un important centre minier et industriel en Basse Guinée ?",
    "choix": ["Fria", "Labé", "Nzérékoré", "Kérouané"],
    "bonnes": [0],
    "explication": "Fria est historiquement connue pour son activité industrielle liée à l’alumine/bauxite."
  },
  {
    "id": "G102",
    "categorieId": "geographie",
    "question": "Boké est surtout connue pour :",
    "choix": ["La bauxite", "Le pétrole", "Les glaciers", "Le blé"],
    "bonnes": [0],
    "explication": "Boké est un pôle majeur de l’exploitation de la bauxite."
  },
  {
    "id": "G103",
    "categorieId": "geographie",
    "question": "Quelle région naturelle comprend la capitale Conakry ?",
    "choix": ["Basse Guinée", "Moyenne Guinée", "Haute Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Conakry se situe dans la Basse Guinée (zone littorale)."
  },
  {
    "id": "G104",
    "categorieId": "geographie",
    "question": "Quelle région naturelle est la plus favorable aux activités maritimes ?",
    "choix": ["Basse Guinée", "Haute Guinée", "Moyenne Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Le littoral atlantique se trouve en Basse Guinée."
  },
  {
    "id": "G105",
    "categorieId": "geographie",
    "question": "Quel type d’espace domine en Guinée forestière ?",
    "choix": ["Forêts et collines humides", "Déserts de dunes", "Glaciers", "Steppes froides"],
    "bonnes": [0],
    "explication": "La Guinée forestière est marquée par la forêt, l’humidité et un relief localement vallonné."
  },
  {
    "id": "G106",
    "categorieId": "geographie",
    "question": "Quel rôle joue la Guinée dans l’hydrologie régionale ?",
    "choix": ["Réservoir de sources fluviales pour l’Afrique de l’Ouest", "Pays sans rivières", "Zone polaire", "Archipel isolé"],
    "bonnes": [0],
    "explication": "La Guinée alimente des fleuves majeurs, d’où l’expression « château d’eau »."
  },
  {
    "id": "G107",
    "categorieId": "geographie",
    "question": "Le littoral guinéen est surtout associé à quel type de milieu ?",
    "choix": ["Côtes, estuaires et mangroves", "Glaciers et fjords", "Déserts rocheux", "Prairies alpines enneigées"],
    "bonnes": [0],
    "explication": "Le littoral guinéen présente des estuaires et des mangroves."
  },
  {
    "id": "G108",
    "categorieId": "geographie",
    "question": "Quelle région naturelle est la plus connue pour ses plateaux et sources de fleuves ?",
    "choix": ["Moyenne Guinée", "Basse Guinée", "Haute Guinée", "Conakry"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon (Moyenne Guinée) est un ensemble de plateaux et sources fluviales."
  },
  {
    "id": "G109",
    "categorieId": "geographie",
    "question": "Quel type de climat explique l’alternance nette des saisons en Guinée ?",
    "choix": ["Climat tropical", "Climat polaire", "Climat désertique", "Climat océanique froid"],
    "bonnes": [0],
    "explication": "Le climat tropical explique l’alternance saison des pluies / saison sèche."
  },
  {
    "id": "G110",
    "categorieId": "geographie",
    "question": "Quel effet le relief peut-il avoir sur les précipitations ?",
    "choix": ["Augmenter les pluies sur certains versants", "Supprimer toute pluie", "Créer des glaciers", "Créer un désert total"],
    "bonnes": [0],
    "explication": "Le relief peut favoriser la condensation et des pluies plus abondantes dans certaines zones."
  },

  {
    "id": "G111",
    "categorieId": "geographie",
    "question": "Quelle activité est fortement liée aux cours d’eau ?",
    "choix": ["Irrigation et hydroélectricité", "Ski", "Chasse au phoque", "Exploitation de banquise"],
    "bonnes": [0],
    "explication": "Les cours d’eau servent à l’agriculture (irrigation) et à l’énergie (barrages)."
  },
  {
    "id": "G112",
    "categorieId": "geographie",
    "question": "Quelle zone est la plus favorable à la pêche maritime ?",
    "choix": ["Le littoral de Basse Guinée", "La savane intérieure", "Les plateaux loin de la mer", "Les forêts denses du sud-est uniquement"],
    "bonnes": [0],
    "explication": "La pêche maritime se pratique surtout sur la côte atlantique."
  },
  {
    "id": "G113",
    "categorieId": "geographie",
    "question": "Quel est un rôle écologique majeur de la mangrove ?",
    "choix": ["Nurserie pour poissons et protection du littoral", "Création de neige", "Formation de volcans", "Assèchement des estuaires"],
    "bonnes": [0],
    "explication": "La mangrove protège le littoral et sert d’habitat à de nombreuses espèces."
  },
  {
    "id": "G114",
    "categorieId": "geographie",
    "question": "Quel type d’activité est fréquent dans les savanes de Haute Guinée ?",
    "choix": ["Agriculture et élevage", "Pêche océanique", "Ski alpin", "Culture de blé sous neige"],
    "bonnes": [0],
    "explication": "La Haute Guinée combine agriculture et élevage sur des espaces de savane."
  },
  {
    "id": "G115",
    "categorieId": "geographie",
    "question": "Quelle région naturelle est la plus liée aux forêts denses et à la biodiversité ?",
    "choix": ["Guinée forestière", "Haute Guinée", "Basse Guinée", "Moyenne Guinée"],
    "bonnes": [0],
    "explication": "La Guinée forestière est un grand espace de biodiversité et de forêts."
  },
  {
    "id": "G116",
    "categorieId": "geographie",
    "question": "Quel enjeu géographique est souvent cité pour Conakry ?",
    "choix": ["Pression urbaine et gestion des eaux pluviales", "Glaciation", "Désertification polaire", "Avalanches"],
    "bonnes": [0],
    "explication": "L’urbanisation rapide rend la gestion des eaux et des infrastructures plus complexe."
  },
  {
    "id": "G117",
    "categorieId": "geographie",
    "question": "Pourquoi certains bas-fonds sont importants en agriculture ?",
    "choix": ["Ils retiennent l’eau et favorisent le riz", "Ils sont toujours secs", "Ils sont gelés", "Ils empêchent les cultures"],
    "bonnes": [0],
    "explication": "Les bas-fonds retiennent l’humidité et sont souvent utilisés pour la riziculture."
  },
  {
    "id": "G118",
    "categorieId": "geographie",
    "question": "Quel facteur rend les pistes rurales plus difficiles pendant l’hivernage ?",
    "choix": ["Boue et ruissellement", "Neige", "Sable saharien pur", "Glace"],
    "bonnes": [0],
    "explication": "Les pluies transforment certaines pistes en zones boueuses et ravinées."
  },
  {
    "id": "G119",
    "categorieId": "geographie",
    "question": "Quel type d’économie est renforcé par la bauxite ?",
    "choix": ["Économie minière et exportatrice", "Économie glaciaire", "Économie du ski", "Économie polaire"],
    "bonnes": [0],
    "explication": "L’exploitation de la bauxite alimente une économie minière tournée vers l’export."
  },
  {
    "id": "G120",
    "categorieId": "geographie",
    "question": "Quel est un enjeu environnemental fréquent autour des sites miniers ?",
    "choix": ["Gestion de l’eau et des sols", "Création de glaciers", "Éruptions volcaniques", "Tempêtes de neige"],
    "bonnes": [0],
    "explication": "Les mines peuvent affecter sols, poussières, eaux et paysages."
  },

  {
    "id": "G121",
    "categorieId": "geographie",
    "question": "Quel type de paysage peut être observé en Basse Guinée ?",
    "choix": ["Plaines côtières et estuaires", "Déserts", "Glaciers", "Taïga"],
    "bonnes": [0],
    "explication": "La Basse Guinée regroupe plaines littorales, estuaires et zones humides."
  },
  {
    "id": "G122",
    "categorieId": "geographie",
    "question": "Quel type de paysage est typique en Moyenne Guinée ?",
    "choix": ["Plateaux et montagnes", "Fjords", "Déserts de dunes", "Glaces"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon se caractérise par des plateaux et montagnes."
  },
  {
    "id": "G123",
    "categorieId": "geographie",
    "question": "Quel type de paysage domine en Haute Guinée ?",
    "choix": ["Savanes et plaines", "Mangroves", "Forêts denses côtières uniquement", "Glaciers"],
    "bonnes": [0],
    "explication": "La Haute Guinée est majoritairement une zone de savane."
  },
  {
    "id": "G124",
    "categorieId": "geographie",
    "question": "Quel type de paysage domine en Guinée forestière ?",
    "choix": ["Forêt dense humide", "Désert", "Steppe froide", "Prairie alpine enneigée"],
    "bonnes": [0],
    "explication": "La Guinée forestière est une région de forêt dense et humide."
  },
  {
    "id": "G125",
    "categorieId": "geographie",
    "question": "Quel facteur explique la concentration d’activités maritimes en Basse Guinée ?",
    "choix": ["Accès à l’Atlantique", "Présence de neige", "Présence de glaciers", "Climat polaire"],
    "bonnes": [0],
    "explication": "La Basse Guinée est la façade atlantique du pays."
  },
  {
    "id": "G126",
    "categorieId": "geographie",
    "question": "Quel est un atout du réseau fluvial pour les populations rurales ?",
    "choix": ["Eau pour agriculture et usages domestiques", "Neige pour irrigation", "Glace pour transport", "Absence de pluies"],
    "bonnes": [0],
    "explication": "Les fleuves et rivières fournissent de l’eau pour la vie quotidienne et l’agriculture."
  },
  {
    "id": "G127",
    "categorieId": "geographie",
    "question": "Quelle conséquence peut avoir l’érosion sur les infrastructures ?",
    "choix": ["Dégradation des routes et ponts", "Création de glaciers", "Baisse de l’océan", "Refroidissement polaire"],
    "bonnes": [0],
    "explication": "L’érosion ravine les pistes et fragilise parfois les ouvrages."
  },
  {
    "id": "G128",
    "categorieId": "geographie",
    "question": "Quel est un effet possible de l’urbanisation rapide ?",
    "choix": ["Pression sur logement, eau, déchets", "Disparition immédiate des pluies", "Apparition de glaciers", "Création de volcans"],
    "bonnes": [0],
    "explication": "La croissance urbaine crée des besoins élevés en services et infrastructures."
  },
  {
    "id": "G129",
    "categorieId": "geographie",
    "question": "Quelle région est la plus directement concernée par les îles de Loos ?",
    "choix": ["Basse Guinée", "Haute Guinée", "Moyenne Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "Les îles de Loos se situent au large de Conakry (Basse Guinée)."
  },
  {
    "id": "G130",
    "categorieId": "geographie",
    "question": "Quel est un avantage des zones de plateau (Fouta-Djalon) pour l’eau ?",
    "choix": ["Multiplication des sources", "Absence totale de rivières", "Gel des sols", "Désertification totale"],
    "bonnes": [0],
    "explication": "Les plateaux favorisent la naissance et l’alimentation de cours d’eau."
  },

  {
    "id": "G131",
    "categorieId": "geographie",
    "question": "Quel est un défi de la Guinée forestière pour les transports ?",
    "choix": ["Routes rendues difficiles par pluies et relief", "Neige", "Glace", "Tempêtes polaires"],
    "bonnes": [0],
    "explication": "Les pluies abondantes et l’état des pistes peuvent compliquer l’accès."
  },
  {
    "id": "G132",
    "categorieId": "geographie",
    "question": "Quel élément géographique explique une partie de la diversité agricole guinéenne ?",
    "choix": ["Les 4 régions naturelles", "Les glaciers", "Le climat polaire", "Le désert permanent"],
    "bonnes": [0],
    "explication": "Les régions naturelles offrent des conditions variées de sols, relief et pluies."
  },
  {
    "id": "G133",
    "categorieId": "geographie",
    "question": "Quel est un enjeu prioritaire pour sécuriser les récoltes ?",
    "choix": ["Gestion de l’eau et des sols", "Création de neige", "Baisse de l’océan", "Éruptions volcaniques"],
    "bonnes": [0],
    "explication": "La gestion de l’eau (drainage/irrigation) et des sols (anti-érosion) stabilise les rendements."
  },
  {
    "id": "G134",
    "categorieId": "geographie",
    "question": "Quel type de milieu est le plus adapté à la riziculture de mangrove ?",
    "choix": ["Estuaires et zones côtières", "Sommets montagneux", "Désert", "Zones glaciaires"],
    "bonnes": [0],
    "explication": "La riziculture de mangrove se fait dans les zones estuariennes côtières."
  },
  {
    "id": "G135",
    "categorieId": "geographie",
    "question": "Quel phénomène peut réduire la fertilité des sols en zone de pente ?",
    "choix": ["Ruissellement et érosion", "Neige", "Gel", "Glaciation"],
    "bonnes": [0],
    "explication": "Le ruissellement emporte la terre fertile sur les pentes."
  },
  {
    "id": "G136",
    "categorieId": "geographie",
    "question": "Quel est un effet possible de la protection des forêts sur l’eau ?",
    "choix": ["Stabilisation des bassins versants", "Disparition des rivières", "Création de glace", "Baisse de l’océan"],
    "bonnes": [0],
    "explication": "Les forêts stabilisent les sols et régulent le cycle de l’eau."
  },
  {
    "id": "G137",
    "categorieId": "geographie",
    "question": "Quel est un enjeu du littoral guinéen ?",
    "choix": ["Érosion côtière et protection des mangroves", "Avalanches", "Neige", "Glaciers"],
    "bonnes": [0],
    "explication": "La protection du littoral passe notamment par la conservation des mangroves."
  },
  {
    "id": "G138",
    "categorieId": "geographie",
    "question": "Quel type de ressource influence fortement les exportations guinéennes ?",
    "choix": ["Ressources minières", "Glaciers", "Neige", "Tourisme polaire"],
    "bonnes": [0],
    "explication": "Les minerais, notamment la bauxite, pèsent fortement dans les exportations."
  },
  {
    "id": "G139",
    "categorieId": "geographie",
    "question": "Quel est un impact possible de l’activité minière sur les cours d’eau ?",
    "choix": ["Turbidité/pollution si mal gérée", "Glaciation", "Disparition du relief", "Création de banquise"],
    "bonnes": [0],
    "explication": "Les rejets et les sédiments peuvent augmenter la turbidité et polluer si les mesures manquent."
  },
  {
    "id": "G140",
    "categorieId": "geographie",
    "question": "Quel est un atout de la diversité des reliefs pour le tourisme ?",
    "choix": ["Paysages variés (montagnes, forêts, littoral)", "Uniquement glace", "Uniquement désert", "Absence de paysage"],
    "bonnes": [0],
    "explication": "La Guinée offre des paysages variés entre côte, plateaux, savanes et forêts."
  },

  {
    "id": "G141",
    "categorieId": "geographie",
    "question": "Quel espace est le plus lié à la savane et aux plaines intérieures ?",
    "choix": ["Haute Guinée", "Basse Guinée", "Conakry", "Îles de Loos"],
    "bonnes": [0],
    "explication": "La Haute Guinée est largement une zone intérieure de savane."
  },
  {
    "id": "G142",
    "categorieId": "geographie",
    "question": "Quel espace est le plus lié aux plateaux du Fouta-Djalon ?",
    "choix": ["Moyenne Guinée", "Basse Guinée", "Haute Guinée", "Guinée-Bissau"],
    "bonnes": [0],
    "explication": "Les plateaux du Fouta-Djalon se trouvent en Moyenne Guinée."
  },
  {
    "id": "G143",
    "categorieId": "geographie",
    "question": "Quel espace est le plus lié à la forêt dense et humide du pays ?",
    "choix": ["Guinée forestière", "Haute Guinée", "Basse Guinée", "Moyenne Guinée"],
    "bonnes": [0],
    "explication": "La Guinée forestière est la zone de forêt dense et humide."
  },
  {
    "id": "G144",
    "categorieId": "geographie",
    "question": "Quel espace est le plus lié au littoral atlantique ?",
    "choix": ["Basse Guinée", "Moyenne Guinée", "Haute Guinée", "Guinée forestière"],
    "bonnes": [0],
    "explication": "La Basse Guinée correspond à la façade maritime de la Guinée."
  },
  {
    "id": "G145",
    "categorieId": "geographie",
    "question": "Quel élément explique en partie l’importance des fleuves guinéens pour la sous-région ?",
    "choix": ["Ils alimentent plusieurs pays voisins", "Ils sont gelés toute l’année", "Ils traversent l’Europe", "Ils sont salés comme la mer"],
    "bonnes": [0],
    "explication": "Les fleuves qui naissent en Guinée traversent ou alimentent des pays voisins d’Afrique de l’Ouest."
  },
  {
    "id": "G146",
    "categorieId": "geographie",
    "question": "Quel est un effet possible des fortes pluies sur les pentes ?",
    "choix": ["Ravinement", "Neige", "Glaciation", "Gel des sols"],
    "bonnes": [0],
    "explication": "Les pluies peuvent raviner les pentes et accélérer l’érosion."
  },
  {
    "id": "G147",
    "categorieId": "geographie",
    "question": "Quel élément rend l’agriculture dépendante du climat ?",
    "choix": ["Pluviométrie (quantité de pluie)", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "La pluviométrie conditionne le calendrier de plantation et de récolte."
  },
  {
    "id": "G148",
    "categorieId": "geographie",
    "question": "Quel est un avantage de la côte pour l’économie nationale ?",
    "choix": ["Port et échanges maritimes", "Glaciers et ski", "Culture sous neige", "Désertification"],
    "bonnes": [0],
    "explication": "Les ports facilitent le commerce et les échanges internationaux."
  },
  {
    "id": "G149",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de la croissance urbaine ?",
    "choix": ["Accès à l’eau, assainissement, déchets", "Création de glaciers", "Gel permanent", "Éruptions volcaniques"],
    "bonnes": [0],
    "explication": "La croissance urbaine exige des infrastructures et services (eau, déchets, assainissement)."
  },
  {
    "id": "G150",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de la protection des bassins versants ?",
    "choix": ["Limiter l’érosion et protéger les sources", "Augmenter la neige", "Créer des volcans", "Assécher les fleuves"],
    "bonnes": [0],
    "explication": "Les bassins versants protégés sécurisent l’eau et réduisent l’érosion."
  },

  {
    "id": "G151",
    "categorieId": "geographie",
    "question": "Quelle ville est un grand pôle urbain de Basse Guinée en dehors de Conakry (selon les repères courants) ?",
    "choix": ["Kindia", "Kérouané", "Beyla", "Koundara"],
    "bonnes": [0],
    "explication": "Kindia est une ville majeure de la Basse Guinée, proche de Conakry."
  },
  {
    "id": "G152",
    "categorieId": "geographie",
    "question": "Quel phénomène peut fragiliser les mangroves ?",
    "choix": ["Pollution et coupe excessive", "Neige", "Glaciation", "Volcanisme"],
    "bonnes": [0],
    "explication": "Les mangroves sont sensibles aux coupes, aménagements et pollutions."
  },
  {
    "id": "G153",
    "categorieId": "geographie",
    "question": "Pourquoi les zones côtières sont-elles stratégiques pour l’économie ?",
    "choix": ["Commerce, pêche, ports", "Glace, ski, banquise", "Désert, caravanes", "Volcans actifs"],
    "bonnes": [0],
    "explication": "Les côtes soutiennent commerce maritime et pêche."
  },
  {
    "id": "G154",
    "categorieId": "geographie",
    "question": "Quel est un lien entre relief et réseau fluvial en Guinée ?",
    "choix": ["Les reliefs alimentent et orientent les cours d’eau", "Les reliefs empêchent toute rivière", "Les reliefs créent des glaciers", "Les reliefs rendent l’eau salée"],
    "bonnes": [0],
    "explication": "Le relief conditionne les pentes, sources et directions des rivières."
  },
  {
    "id": "G155",
    "categorieId": "geographie",
    "question": "Quel est un avantage des forêts pour les sols ?",
    "choix": ["Protection contre l’érosion", "Création de neige", "Assèchement", "Glaciation"],
    "bonnes": [0],
    "explication": "Les racines stabilisent les sols et limitent leur emportement par la pluie."
  },
  {
    "id": "G156",
    "categorieId": "geographie",
    "question": "Quel est un facteur de la diversité des cultures agricoles selon les régions ?",
    "choix": ["Climat + sols + relief", "Neige + glace", "Volcans actifs", "Pôle Nord"],
    "bonnes": [0],
    "explication": "Le couple climat/sols/relief varie entre côte, plateaux, savanes et forêts."
  },
  {
    "id": "G157",
    "categorieId": "geographie",
    "question": "Quel est un enjeu majeur des zones de savane pour l’agriculture ?",
    "choix": ["Gestion de l’eau en saison sèche", "Gestion de la neige", "Glaciation", "Volcanisme permanent"],
    "bonnes": [0],
    "explication": "En savane, la saison sèche impose une gestion stricte de l’eau."
  },
  {
    "id": "G158",
    "categorieId": "geographie",
    "question": "Quelle région naturelle est la plus associée à l’altitude et à une relative fraîcheur ?",
    "choix": ["Moyenne Guinée", "Basse Guinée", "Haute Guinée", "Conakry"],
    "bonnes": [0],
    "explication": "La Moyenne Guinée, plus élevée, a souvent des températures plus modérées."
  },
  {
    "id": "G159",
    "categorieId": "geographie",
    "question": "Quel est un risque écologique si les forêts reculent fortement ?",
    "choix": ["Perte de biodiversité", "Création de glaciers", "Neige permanente", "Apparition d’icebergs"],
    "bonnes": [0],
    "explication": "La déforestation peut entraîner une perte importante d’espèces et d’habitats."
  },
  {
    "id": "G160",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de l’accès à l’eau potable en milieu rural ?",
    "choix": ["Infrastructures et points d’eau sécurisés", "Neige", "Glace", "Volcanisme"],
    "bonnes": [0],
    "explication": "Le défi est souvent l’équipement (forages, réseaux, maintenance) et la qualité de l’eau."
  },

  {
    "id": "G161",
    "categorieId": "geographie",
    "question": "Quel est un avantage des bas-fonds pour certaines cultures ?",
    "choix": ["Humidité plus constante", "Gel permanent", "Absence totale d’eau", "Neige toute l’année"],
    "bonnes": [0],
    "explication": "Les bas-fonds retiennent l’eau plus longtemps et favorisent des cultures comme le riz."
  },
  {
    "id": "G162",
    "categorieId": "geographie",
    "question": "Quel facteur explique le développement de marchés urbains autour de Conakry ?",
    "choix": ["Concentration de population et d’échanges", "Glaciation", "Désert", "Volcans"],
    "bonnes": [0],
    "explication": "Une forte population crée une demande et dynamise les échanges."
  },
  {
    "id": "G163",
    "categorieId": "geographie",
    "question": "Quel est un enjeu pour la protection des côtes ?",
    "choix": ["Conserver mangroves et limiter l’érosion", "Créer de la neige", "Créer des glaciers", "Assécher les estuaires"],
    "bonnes": [0],
    "explication": "La protection côtière passe notamment par les mangroves et la gestion des aménagements."
  },
  {
    "id": "G164",
    "categorieId": "geographie",
    "question": "Quel est un enjeu majeur des zones minières ?",
    "choix": ["Gestion environnementale et sociale", "Ski", "Glace", "Avalanches"],
    "bonnes": [0],
    "explication": "Les zones minières nécessitent une gestion des impacts (sols, eau, emplois, déplacements)."
  },
  {
    "id": "G165",
    "categorieId": "geographie",
    "question": "Quel élément explique la diversité des habitats (côte, plateau, savane, forêt) ?",
    "choix": ["Diversité des régions naturelles", "Glaciers", "Neige permanente", "Désert unique"],
    "bonnes": [0],
    "explication": "Les 4 régions naturelles créent des habitats et paysages très différents."
  },
  {
    "id": "G166",
    "categorieId": "geographie",
    "question": "Quel est un atout de la Guinée pour l’eau en Afrique de l’Ouest ?",
    "choix": ["Réseau de sources fluviales", "Absence de rivières", "Banquise", "Climat polaire"],
    "bonnes": [0],
    "explication": "De nombreux fleuves régionaux naissent sur le territoire guinéen."
  },
  {
    "id": "G167",
    "categorieId": "geographie",
    "question": "Quel est un impact possible des fortes pluies sur les rivières ?",
    "choix": ["Crues et débordements", "Gel", "Assèchement immédiat", "Neige"],
    "bonnes": [0],
    "explication": "En saison des pluies, les rivières peuvent gonfler et déborder."
  },
  {
    "id": "G168",
    "categorieId": "geographie",
    "question": "Quel type d’énergie renouvelable est naturellement favorisé par les fleuves ?",
    "choix": ["Hydroélectricité", "Nucléaire", "Pétrole", "Charbon"],
    "bonnes": [0],
    "explication": "Les fleuves permettent de produire de l’électricité via des barrages."
  },
  {
    "id": "G169",
    "categorieId": "geographie",
    "question": "Quelle relation est correcte entre Conakry et l’océan ?",
    "choix": ["Conakry est sur la côte atlantique", "Conakry est au milieu du désert", "Conakry est en zone glaciaire", "Conakry est une île isolée sans côte"],
    "bonnes": [0],
    "explication": "Conakry est une ville littorale sur l’Atlantique."
  },
  {
    "id": "G170",
    "categorieId": "geographie",
    "question": "Quel type de milieu est le plus associé aux estuaires guinéens ?",
    "choix": ["Mangroves", "Glaciers", "Déserts", "Toundra"],
    "bonnes": [0],
    "explication": "Les estuaires côtiers guinéens abritent des mangroves."
  },

  {
    "id": "G171",
    "categorieId": "geographie",
    "question": "Quel est un effet possible de la déforestation sur les pluies locales ?",
    "choix": ["Perturbation du cycle de l’eau", "Neige permanente", "Glaciation immédiate", "Aucun effet possible"],
    "bonnes": [0],
    "explication": "La couverture végétale influence l’humidité et l’évapotranspiration, donc le cycle de l’eau."
  },
  {
    "id": "G172",
    "categorieId": "geographie",
    "question": "Quel est un enjeu pour la production agricole pendant la saison sèche ?",
    "choix": ["Disponibilité en eau", "Tempêtes de neige", "Banquise", "Glaciers"],
    "bonnes": [0],
    "explication": "En saison sèche, l’eau devient un facteur limitant pour certaines cultures."
  },
  {
    "id": "G173",
    "categorieId": "geographie",
    "question": "Quel type de culture est très dépendant de l’eau ?",
    "choix": ["Riz", "Cactus", "Plantes polaires", "Lichen arctique"],
    "bonnes": [0],
    "explication": "La riziculture nécessite une forte disponibilité en eau."
  },
  {
    "id": "G174",
    "categorieId": "geographie",
    "question": "Quel est un avantage des sols protégés par la forêt ?",
    "choix": ["Moins d’érosion", "Plus de neige", "Glaciation", "Plus de désert"],
    "bonnes": [0],
    "explication": "La forêt stabilise les sols et réduit l’érosion."
  },
  {
    "id": "G175",
    "categorieId": "geographie",
    "question": "Quel est un enjeu fréquent pour les zones urbaines en croissance ?",
    "choix": ["Assainissement", "Avalanches", "Tempêtes polaires", "Banquise"],
    "bonnes": [0],
    "explication": "L’assainissement est crucial pour éviter inondations et problèmes sanitaires."
  },
  {
    "id": "G176",
    "categorieId": "geographie",
    "question": "Quel est un usage économique fréquent de la côte en plus du port ?",
    "choix": ["Pêche", "Ski", "Mine de glace", "Élevage polaire"],
    "bonnes": [0],
    "explication": "La pêche est une activité économique majeure sur la côte."
  },
  {
    "id": "G177",
    "categorieId": "geographie",
    "question": "Quel est un avantage de la diversité des régions naturelles pour l’alimentation ?",
    "choix": ["Diversité des productions", "Une seule culture possible", "Absence d’agriculture", "Culture sous glace uniquement"],
    "bonnes": [0],
    "explication": "Chaque région favorise des productions différentes (côte, plateaux, savanes, forêts)."
  },
  {
    "id": "G178",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de la gestion des déchets en ville ?",
    "choix": ["Limiter pollution et risques sanitaires", "Créer de la neige", "Créer des glaciers", "Assécher les fleuves"],
    "bonnes": [0],
    "explication": "Une mauvaise gestion des déchets pollue et augmente les risques sanitaires."
  },
  {
    "id": "G179",
    "categorieId": "geographie",
    "question": "Quel est un lien correct entre relief et agriculture ?",
    "choix": ["Les plaines facilitent la mécanisation", "Les glaciers facilitent le riz", "La neige augmente les récoltes", "Les volcans sont partout"],
    "bonnes": [0],
    "explication": "Les plaines rendent l’accès et parfois la mécanisation plus faciles."
  },
  {
    "id": "G180",
    "categorieId": "geographie",
    "question": "Quel est un effet des mines sur le paysage ?",
    "choix": ["Modification du relief local", "Création de glaciers", "Création d’océans", "Création de banquise"],
    "bonnes": [0],
    "explication": "Les mines modifient les terrains (tranchées, carrières, remblais)."
  },

  {
    "id": "G181",
    "categorieId": "geographie",
    "question": "Quel est un facteur qui peut améliorer l’accès aux zones rurales ?",
    "choix": ["Routes et ponts", "Glaciers", "Neige", "Volcans"],
    "bonnes": [0],
    "explication": "Les infrastructures (routes/ponts) améliorent l’accès aux services et aux marchés."
  },
  {
    "id": "G182",
    "categorieId": "geographie",
    "question": "Quel type d’activité profite directement des routes améliorées ?",
    "choix": ["Commerce et transport", "Ski", "Banquise", "Chasse polaire"],
    "bonnes": [0],
    "explication": "De meilleures routes facilitent l’évacuation des produits et la mobilité."
  },
  {
    "id": "G183",
    "categorieId": "geographie",
    "question": "Quel type d’environnement est le plus sensible à la pollution en zone côtière ?",
    "choix": ["Estuaires et mangroves", "Glaciers", "Déserts de dunes", "Toundra"],
    "bonnes": [0],
    "explication": "Les estuaires et mangroves sont des milieux fragiles."
  },
  {
    "id": "G184",
    "categorieId": "geographie",
    "question": "Quel est un enjeu clé de la gestion de l’eau en ville ?",
    "choix": ["Drainage des eaux pluviales", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "Le drainage évite les inondations et protège la santé publique."
  },
  {
    "id": "G185",
    "categorieId": "geographie",
    "question": "Quel est un lien entre fleuves et agriculture ?",
    "choix": ["Irrigation et sols alluviaux", "Neige et glace", "Volcans", "Absence d’eau"],
    "bonnes": [0],
    "explication": "Les fleuves irriguent et déposent des alluvions qui enrichissent les sols."
  },
  {
    "id": "G186",
    "categorieId": "geographie",
    "question": "Quel type d’activité est le plus lié à la bauxite ?",
    "choix": ["Industrie minière", "Pêche", "Tourisme polaire", "Agriculture sous neige"],
    "bonnes": [0],
    "explication": "La bauxite est une ressource minière exploitée industriellement."
  },
  {
    "id": "G187",
    "categorieId": "geographie",
    "question": "Quel est un effet positif potentiel d’une bonne gestion forestière ?",
    "choix": ["Protection des sols et de l’eau", "Création de neige", "Création de glaciers", "Assèchement des rivières"],
    "bonnes": [0],
    "explication": "La gestion forestière limite l’érosion et stabilise les bassins versants."
  },
  {
    "id": "G188",
    "categorieId": "geographie",
    "question": "Quel est un enjeu majeur pour les zones de pêche artisanale ?",
    "choix": ["Préserver les ressources halieutiques", "Créer de la banquise", "Créer des glaciers", "Désertifier la côte"],
    "bonnes": [0],
    "explication": "Il faut préserver les stocks de poissons et limiter les pollutions."
  },
  {
    "id": "G189",
    "categorieId": "geographie",
    "question": "Quel facteur peut expliquer les différences de températures entre Conakry et le Fouta-Djalon ?",
    "choix": ["Altitude", "Glaciers", "Latitude polaire", "Désert"],
    "bonnes": [0],
    "explication": "Le Fouta-Djalon est plus élevé : l’altitude peut réduire les températures."
  },
  {
    "id": "G190",
    "categorieId": "geographie",
    "question": "Quel est un enjeu pour les cultures en zones de pente ?",
    "choix": ["Anti-érosion et conservation des sols", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "Les pentes demandent des pratiques anti-érosion pour éviter la perte de terre fertile."
  },

  {
    "id": "G191",
    "categorieId": "geographie",
    "question": "Quel est un avantage des zones côtières pour l’emploi ?",
    "choix": ["Activités portuaires et pêche", "Ski et neige", "Banquise", "Glaciers"],
    "bonnes": [0],
    "explication": "Ports et pêche créent des emplois directs et indirects."
  },
  {
    "id": "G192",
    "categorieId": "geographie",
    "question": "Quel est un avantage des plateaux pour le tourisme ?",
    "choix": ["Paysages et sources/cascades", "Volcans actifs partout", "Glaciers", "Désert"],
    "bonnes": [0],
    "explication": "Les plateaux et reliefs offrent des paysages attractifs et des sites naturels."
  },
  {
    "id": "G193",
    "categorieId": "geographie",
    "question": "Quel est un enjeu de la croissance démographique sur l’environnement ?",
    "choix": ["Pression sur terres, bois et eau", "Création de neige", "Création de glaciers", "Réduction automatique de la pollution"],
    "bonnes": [0],
    "explication": "Plus de population peut augmenter la pression sur les ressources naturelles."
  },
  {
    "id": "G194",
    "categorieId": "geographie",
    "question": "Quelle combinaison est correcte (région naturelle → caractéristique) ?",
    "choix": [
      "Basse Guinée → littoral",
      "Moyenne Guinée → glaciers",
      "Haute Guinée → fjords",
      "Guinée forestière → désert"
    ],
    "bonnes": [0],
    "explication": "La Basse Guinée est la région littorale ; les autres associations sont fausses."
  },
  {
    "id": "G195",
    "categorieId": "geographie",
    "question": "Quelle combinaison est correcte (région naturelle → caractéristique) ?",
    "choix": [
      "Moyenne Guinée → plateaux/montagnes",
      "Basse Guinée → désert",
      "Haute Guinée → banquise",
      "Guinée forestière → toundra"
    ],
    "bonnes": [0],
    "explication": "La Moyenne Guinée (Fouta-Djalon) est une zone de plateaux et montagnes."
  },
  {
    "id": "G196",
    "categorieId": "geographie",
    "question": "Quelle combinaison est correcte (région naturelle → caractéristique) ?",
    "choix": [
      "Haute Guinée → savane intérieure",
      "Basse Guinée → banquise",
      "Moyenne Guinée → océan",
      "Guinée forestière → glaciers"
    ],
    "bonnes": [0],
    "explication": "La Haute Guinée est dominée par des savanes intérieures."
  },
  {
    "id": "G197",
    "categorieId": "geographie",
    "question": "Quelle combinaison est correcte (région naturelle → caractéristique) ?",
    "choix": [
      "Guinée forestière → forêt dense humide",
      "Haute Guinée → mangrove",
      "Basse Guinée → steppe froide",
      "Moyenne Guinée → désert"
    ],
    "bonnes": [0],
    "explication": "La Guinée forestière est la région des forêts denses et humides."
  },
  {
    "id": "G198",
    "categorieId": "geographie",
    "question": "Quel résumé est le plus fidèle de la géographie guinéenne ?",
    "choix": [
      "Quatre régions naturelles : littoral, plateaux, savanes, forêts",
      "Un seul désert sur tout le pays",
      "Un pays polaire avec glaciers",
      "Une île sans relief"
    ],
    "bonnes": [0],
    "explication": "La Guinée est classiquement décrite par 4 régions naturelles : côte, plateaux, savanes et forêts."
  },
  {
    "id": "G199",
    "categorieId": "geographie",
    "question": "Pourquoi la Guinée est-elle importante pour l’Afrique de l’Ouest sur le plan de l’eau ?",
    "choix": [
      "Elle alimente des fleuves qui traversent plusieurs pays",
      "Elle n’a aucune rivière",
      "Elle est recouverte de glace",
      "Elle est un désert total"
    ],
    "bonnes": [0],
    "explication": "Des fleuves nés en Guinée traversent et alimentent de nombreux pays voisins."
  },
  {
    "id": "G200",
    "categorieId": "geographie",
    "question": "Quels éléments suivants sont des repères fondamentaux de géographie de la Guinée ?",
    "choix": ["Océan Atlantique", "4 régions naturelles", "Fouta-Djalon (Moyenne Guinée)", "Bauxite (Boké)"],
    "bonnes": [0, 1, 2, 3],
    "explication": "Ces repères couvrent façade maritime, organisation régionale, relief clé et ressource minière majeure."
  },
];
 static final List<Map<String, dynamic>> _rawCultureGuinee = [
  {
    "id": "C001",
    "categorieId": "culture",
    "question": "Quelle langue officielle est utilisée dans l’administration guinéenne ?",
    "choix": ["Le français", "Le soussou", "Le pular", "Le maninka"],
    "bonnes": [0],
    "explication": "Le français est la langue officielle de l’État guinéen et de l’administration."
  },
  {
    "id": "C002",
    "categorieId": "culture",
    "question": "Parmi ces langues, lesquelles sont largement parlées en Guinée ?",
    "choix": ["Soussou", "Pular", "Maninka", "Japonais"],
    "bonnes": [0, 1, 2],
    "explication": "Le soussou, le pular et le maninka sont des langues majeures en Guinée ; le japonais n’en fait pas partie."
  },
  {
    "id": "C003",
    "categorieId": "culture",
    "question": "Quelle ville est considérée comme un grand centre culturel et urbain de la Haute Guinée ?",
    "choix": ["Kankan", "Boké", "Forécariah", "Boffa"],
    "bonnes": [0],
    "explication": "Kankan est un centre majeur de Haute Guinée, connu pour son rôle culturel et économique."
  },
  {
    "id": "C004",
    "categorieId": "culture",
    "question": "Quelle ville est un grand centre culturel de la Moyenne Guinée (Fouta-Djalon) ?",
    "choix": ["Labé", "Siguiri", "Beyla", "Dubréka"],
    "bonnes": [0],
    "explication": "Labé est une ville importante de Moyenne Guinée, au cœur du Fouta-Djalon."
  },
  {
    "id": "C005",
    "categorieId": "culture",
    "question": "Quelle ville est le principal centre urbain de la Guinée forestière ?",
    "choix": ["Nzérékoré", "Kindia", "Fria", "Gaoual"],
    "bonnes": [0],
    "explication": "Nzérékoré est la principale ville de la région forestière."
  },
  {
    "id": "C006",
    "categorieId": "culture",
    "question": "Quel plat est très connu en Guinée, fait de riz et de sauce ?",
    "choix": ["Riz sauce", "Paëlla", "Sushi", "Tacos"],
    "bonnes": [0],
    "explication": "Le riz accompagné de sauces variées est un pilier de l’alimentation guinéenne."
  },
  {
    "id": "C007",
    "categorieId": "culture",
    "question": "Le manioc est souvent consommé en Guinée sous quelle forme ?",
    "choix": ["Attiéké/semoule de manioc", "Fromage", "Pain de seigle", "Pâtes italiennes"],
    "bonnes": [0],
    "explication": "Le manioc peut être transformé et consommé sous forme de semoule (selon les zones et pratiques)."
  },
  {
    "id": "C008",
    "categorieId": "culture",
    "question": "Quelle boisson traditionnelle est très présente dans la vie quotidienne en Guinée ?",
    "choix": ["Thé", "Chocolat chaud européen", "Saké", "Mate argentin"],
    "bonnes": [0],
    "explication": "Le thé est très consommé dans de nombreux contextes sociaux."
  },
  {
    "id": "C009",
    "categorieId": "culture",
    "question": "En Guinée, quel fruit est très courant sur les marchés ?",
    "choix": ["Mangue", "Pomme de terre", "Canneberge", "Kaki japonais"],
    "bonnes": [0],
    "explication": "La mangue est largement consommée et vendue sur les marchés guinéens."
  },
  {
    "id": "C010",
    "categorieId": "culture",
    "question": "Le palmier à huile et son huile sont surtout associés à :",
    "choix": ["Cuisine et sauces", "Ski", "Industrie glaciaire", "Culture sous neige"],
    "bonnes": [0],
    "explication": "L’huile de palme est utilisée dans plusieurs préparations culinaires."
  },

  {
    "id": "C011",
    "categorieId": "culture",
    "question": "Quel est un instrument traditionnel très répandu en Guinée et en Afrique de l’Ouest ?",
    "choix": ["Djembé", "Violon baroque", "Cornemuse", "Clavecin"],
    "bonnes": [0],
    "explication": "Le djembé est un instrument majeur des musiques traditionnelles ouest-africaines, très présent en Guinée."
  },
  {
    "id": "C012",
    "categorieId": "culture",
    "question": "Quel instrument à cordes est souvent associé aux traditions mandingues ?",
    "choix": ["Kora", "Harpe celtique", "Bandonéon", "Balalaïka"],
    "bonnes": [0],
    "explication": "La kora est un instrument à cordes très connu dans l’univers mandingue."
  },
  {
    "id": "C013",
    "categorieId": "culture",
    "question": "Quelle activité est centrale dans les cérémonies (mariages, baptêmes) en Guinée ?",
    "choix": ["Musique et danse", "Patinage sur glace", "Ski", "Course de traîneaux"],
    "bonnes": [0],
    "explication": "La musique et la danse jouent un rôle social et cérémoniel important."
  },
  {
    "id": "C014",
    "categorieId": "culture",
    "question": "Quel élément est souvent mis en avant dans les valeurs communautaires guinéennes ?",
    "choix": ["Solidarité", "Isolement volontaire", "Refus des cérémonies", "Interdiction de la musique"],
    "bonnes": [0],
    "explication": "La solidarité et l’entraide sont des valeurs fortement présentes dans de nombreuses communautés."
  },
  {
    "id": "C015",
    "categorieId": "culture",
    "question": "Les marchés en Guinée sont souvent importants parce qu’ils servent à :",
    "choix": ["Échanger, vendre et se rencontrer", "Ski", "Élever des rennes", "Exporter de la neige"],
    "bonnes": [0],
    "explication": "Les marchés sont des lieux d’économie mais aussi de vie sociale."
  },
  {
    "id": "C016",
    "categorieId": "culture",
    "question": "Quelle tenue traditionnelle est souvent portée lors d’occasions importantes ?",
    "choix": ["Boubou", "Kimono", "Kilt", "Sari indien uniquement"],
    "bonnes": [0],
    "explication": "Le boubou est une tenue courante lors de cérémonies et événements."
  },
  {
    "id": "C017",
    "categorieId": "culture",
    "question": "Quel type d’artisanat est très présent en Guinée ?",
    "choix": ["Tissage", "Fabrication de skis", "Soufflage de verre vénitien", "Horlogerie alpine"],
    "bonnes": [0],
    "explication": "Le tissage et les textiles font partie des savoir-faire artisanaux répandus."
  },
  {
    "id": "C018",
    "categorieId": "culture",
    "question": "Quelle activité traditionnelle est souvent pratiquée dans les villages lors des fêtes ?",
    "choix": ["Danse collective", "Patinage artistique", "Saut à ski", "Curling"],
    "bonnes": [0],
    "explication": "Les danses collectives accompagnent fréquemment fêtes et cérémonies."
  },
  {
    "id": "C019",
    "categorieId": "culture",
    "question": "En Guinée, quelle boisson est souvent partagée pour discuter et socialiser ?",
    "choix": ["Thé", "Saké", "Cidre normand", "Kvas"],
    "bonnes": [0],
    "explication": "Le thé est un marqueur de sociabilité dans de nombreux contextes."
  },
  {
    "id": "C020",
    "categorieId": "culture",
    "question": "Quel aliment est très courant dans les repas guinéens ?",
    "choix": ["Riz", "Pain de seigle", "Choucroute", "Poutine"],
    "bonnes": [0],
    "explication": "Le riz est un aliment central de l’alimentation guinéenne."
  },

  {
    "id": "C021",
    "categorieId": "culture",
    "question": "Quel est un rôle traditionnel des anciens (sages) dans la société ?",
    "choix": ["Conseil et médiation", "Sport olympique", "Pilotage de trains", "Téléportation"],
    "bonnes": [0],
    "explication": "Les anciens jouent souvent un rôle de conseil, d’arbitrage et de transmission."
  },
  {
    "id": "C022",
    "categorieId": "culture",
    "question": "Quel est un objectif des contes et proverbes dans la culture guinéenne ?",
    "choix": ["Transmettre des valeurs et des leçons", "Remplacer l’école", "Interdire la parole", "Supprimer la mémoire"],
    "bonnes": [0],
    "explication": "Les contes/proverbes servent à enseigner et à transmettre l’expérience collective."
  },
  {
    "id": "C023",
    "categorieId": "culture",
    "question": "Quelle pratique est souvent associée aux veillées et rencontres ?",
    "choix": ["Récits et histoires", "Ski nocturne", "Chasse à l’iceberg", "Pêche polaire"],
    "bonnes": [0],
    "explication": "Les veillées sont souvent des moments de récit, musique ou discussion."
  },
  {
    "id": "C024",
    "categorieId": "culture",
    "question": "Quel est un lieu important pour la vie sociale et économique ?",
    "choix": ["Le marché", "La piste de ski", "La banquise", "Le fjord"],
    "bonnes": [0],
    "explication": "Le marché est un lieu majeur d’échanges et de sociabilité."
  },
  {
    "id": "C025",
    "categorieId": "culture",
    "question": "Quel élément est souvent présent lors des fêtes traditionnelles ?",
    "choix": ["Tambours", "Sonneurs de cornemuse écossaise", "Orchestre symphonique classique", "Carillon alpin"],
    "bonnes": [0],
    "explication": "Les percussions (tambours) accompagnent fréquemment les fêtes."
  },
  {
    "id": "C026",
    "categorieId": "culture",
    "question": "Quelle activité est très valorisée dans la transmission culturelle ?",
    "choix": ["Oralité (parole)", "Silence obligatoire", "Interdiction des histoires", "Absence de cérémonies"],
    "bonnes": [0],
    "explication": "L’oralité est un pilier : histoires, proverbes, chants, généalogies."
  },
  {
    "id": "C027",
    "categorieId": "culture",
    "question": "Quel type de musique est très présent lors des cérémonies ?",
    "choix": ["Musique traditionnelle", "Opéra italien uniquement", "Rock nordique uniquement", "Musique de banquise"],
    "bonnes": [0],
    "explication": "Les musiques traditionnelles accompagnent mariages, baptêmes et fêtes."
  },
  {
    "id": "C028",
    "categorieId": "culture",
    "question": "Quel est un usage courant du coton en Guinée (dans certains savoir-faire) ?",
    "choix": ["Textiles", "Construction de skis", "Fabrication de glace", "Carburant spatial"],
    "bonnes": [0],
    "explication": "Le coton peut être utilisé dans des productions textiles selon les zones."
  },
  {
    "id": "C029",
    "categorieId": "culture",
    "question": "Quel est un moment culturel important pour renforcer les liens familiaux ?",
    "choix": ["Mariage", "Course de luge", "Festival de neige", "Chasse au renne"],
    "bonnes": [0],
    "explication": "Le mariage est un moment social majeur de regroupement familial et communautaire."
  },
  {
    "id": "C030",
    "categorieId": "culture",
    "question": "Quel est un principe social souvent valorisé dans les communautés ?",
    "choix": ["Respect", "Mépris systématique", "Isolement", "Refus de la famille"],
    "bonnes": [0],
    "explication": "Le respect (des aînés, des règles communautaires, des autres) est largement valorisé."
  },

  {
    "id": "C031",
    "categorieId": "culture",
    "question": "Dans beaucoup de familles, quel rôle joue le repas partagé ?",
    "choix": ["Renforcer la cohésion", "Interdire la conversation", "Remplacer la musique", "Supprimer la solidarité"],
    "bonnes": [0],
    "explication": "Le repas partagé consolide les liens familiaux et sociaux."
  },
  {
    "id": "C032",
    "categorieId": "culture",
    "question": "Quel est un exemple de plat très connu à base de manioc en Guinée (selon les zones) ?",
    "choix": ["Semoule/attiéké de manioc", "Raclette", "Sushi", "Bretzel"],
    "bonnes": [0],
    "explication": "Le manioc est parfois consommé sous forme de semoule, selon les pratiques locales."
  },
  {
    "id": "C033",
    "categorieId": "culture",
    "question": "Quel aliment est souvent vendu en brochettes dans la rue ?",
    "choix": ["Viande grillée", "Saumon fumé nordique", "Fondue", "Caviar"],
    "bonnes": [0],
    "explication": "Les grillades et brochettes sont très courantes dans la restauration de rue."
  },
  {
    "id": "C034",
    "categorieId": "culture",
    "question": "Quel est un produit très présent dans la cuisine guinéenne ?",
    "choix": ["Poisson", "Bacon fumé", "Hareng de mer froide", "Fromage à raclette"],
    "bonnes": [0],
    "explication": "Le poisson est très consommé, surtout sur la côte et dans les villes."
  },
  {
    "id": "C035",
    "categorieId": "culture",
    "question": "Quel est un usage social fréquent du thé en Guinée ?",
    "choix": ["Discussion et convivialité", "Compétition sportive", "Rituel polaire", "Cuisine de neige"],
    "bonnes": [0],
    "explication": "Le thé accompagne souvent les échanges et la convivialité."
  },
  {
    "id": "C036",
    "categorieId": "culture",
    "question": "Les cérémonies de baptême en Guinée sont souvent associées à :",
    "choix": ["Famille, prières et repas", "Ski", "Course d’icebergs", "Neige obligatoire"],
    "bonnes": [0],
    "explication": "Les baptêmes réunissent généralement la famille, la communauté et un repas partagé."
  },
  {
    "id": "C037",
    "categorieId": "culture",
    "question": "Quel est un objectif principal des cérémonies communautaires ?",
    "choix": ["Renforcer les liens et la solidarité", "Créer des conflits", "Supprimer la tradition", "Interdire la musique"],
    "bonnes": [0],
    "explication": "Les cérémonies renforcent l’unité et la solidarité de la communauté."
  },
  {
    "id": "C038",
    "categorieId": "culture",
    "question": "Quel type de savoir-faire est souvent transmis de génération en génération ?",
    "choix": ["Artisanat (tissage, forge, etc.)", "Fabrication de banquise", "Construction de volcans", "Chasse au phoque"],
    "bonnes": [0],
    "explication": "Plusieurs métiers artisanaux se transmettent par apprentissage au sein des familles."
  },
  {
    "id": "C039",
    "categorieId": "culture",
    "question": "Quelle affirmation est vraie sur la culture guinéenne ?",
    "choix": ["Elle est diverse selon les régions", "Elle est identique partout dans le monde", "Elle n’a pas de musique", "Elle interdit les marchés"],
    "bonnes": [0],
    "explication": "La Guinée est culturellement diverse selon régions et communautés."
  },
  {
    "id": "C040",
    "categorieId": "culture",
    "question": "Quel élément est souvent central dans la transmission des histoires ?",
    "choix": ["La parole", "Le silence obligatoire", "L’interdiction de raconter", "L’absence de mémoire"],
    "bonnes": [0],
    "explication": "L’oralité (parole, récit, chant) est essentielle pour transmettre l’histoire et les valeurs."
  },

  // =========================
  // C041 -> C100
  // =========================
  {
    "id": "C041",
    "categorieId": "culture",
    "question": "Quel est un type d’événement où la musique traditionnelle est souvent très présente ?",
    "choix": ["Mariages", "Compétitions de ski", "Fêtes de neige", "Carnaval polaire"],
    "bonnes": [0],
    "explication": "Les mariages sont généralement accompagnés de musique et de danses."
  },
  {
    "id": "C042",
    "categorieId": "culture",
    "question": "Quel est un élément culturel important dans la vie quotidienne ?",
    "choix": ["Salutations et respect", "Refus de saluer", "Silence imposé", "Interdiction des rencontres"],
    "bonnes": [0],
    "explication": "Les salutations sont un marqueur de respect et un rituel social important."
  },
  {
    "id": "C043",
    "categorieId": "culture",
    "question": "Quel est un symbole courant de fête et de cérémonie ?",
    "choix": ["Habits traditionnels", "Combinaisons de ski", "Parkas polaires", "Patins à glace"],
    "bonnes": [0],
    "explication": "Les habits traditionnels sont souvent portés pendant les cérémonies et fêtes."
  },
  {
    "id": "C044",
    "categorieId": "culture",
    "question": "Quel est un objectif des danses traditionnelles ?",
    "choix": ["Célébrer et raconter", "Interdire les rassemblements", "Éviter la musique", "Supprimer les fêtes"],
    "bonnes": [0],
    "explication": "Les danses servent à célébrer, accompagner des récits et renforcer l’identité."
  },
  {
    "id": "C045",
    "categorieId": "culture",
    "question": "Quel élément est souvent très important dans la cuisine guinéenne ?",
    "choix": ["Sauces", "Neige", "Glace", "Fromages alpins"],
    "bonnes": [0],
    "explication": "Les sauces (légumes, huile, poisson/viande) accompagnent très souvent le riz."
  },
  {
    "id": "C046",
    "categorieId": "culture",
    "question": "Parmi ces éléments, lesquels sont des lieux/temps de rassemblement social ?",
    "choix": ["Marché", "Cérémonies", "Veillées", "Glacier"],
    "bonnes": [0, 1, 2],
    "explication": "Marchés, cérémonies et veillées sont des espaces/temps sociaux ; un glacier n’est pas un repère culturel guinéen."
  },
  {
    "id": "C047",
    "categorieId": "culture",
    "question": "Quel est un rôle du chant dans plusieurs traditions ?",
    "choix": ["Célébration et transmission", "Interdiction de parler", "Absence de message", "Suppression des récits"],
    "bonnes": [0],
    "explication": "Le chant sert à célébrer, transmettre et renforcer la mémoire collective."
  },
  {
    "id": "C048",
    "categorieId": "culture",
    "question": "Quel produit est très utilisé pour accompagner certains plats ?",
    "choix": ["Piment", "Sirop d’érable", "Wasabi", "Raifort nordique"],
    "bonnes": [0],
    "explication": "Le piment est un condiment fréquemment utilisé dans la cuisine guinéenne."
  },
  {
    "id": "C049",
    "categorieId": "culture",
    "question": "Quel est un lieu où l’on peut découvrir l’artisanat local ?",
    "choix": ["Marchés", "Stations de ski", "Banquise", "Fjords"],
    "bonnes": [0],
    "explication": "Les marchés sont des lieux majeurs de vente d’artisanat et de produits locaux."
  },
  {
    "id": "C050",
    "categorieId": "culture",
    "question": "Le mot « solidarité » renvoie souvent à :",
    "choix": ["Entraide communautaire", "Isolement", "Refus de la famille", "Interdiction des cérémonies"],
    "bonnes": [0],
    "explication": "La solidarité signifie s’entraider dans la communauté, surtout en moments difficiles."
  },
  {
    "id": "C051",
    "categorieId": "culture",
    "question": "Quelle est une forme fréquente de restauration populaire en ville ?",
    "choix": ["Street food (grillades, riz sauce)", "Chasse à l’iceberg", "Sushi bar traditionnel japonais", "Boulettes polaires"],
    "bonnes": [0],
    "explication": "La restauration de rue (grillades, riz, sauces) est très présente."
  },
  {
    "id": "C052",
    "categorieId": "culture",
    "question": "Quel élément est souvent présent lors des fêtes :",
    "choix": ["Danse", "Ski", "Luge", "Neige"],
    "bonnes": [0],
    "explication": "La danse fait partie des expressions culturelles les plus visibles lors des fêtes."
  },
  {
    "id": "C053",
    "categorieId": "culture",
    "question": "Quel est un objectif des proverbes ?",
    "choix": ["Conseiller et faire réfléchir", "Interdire la discussion", "Supprimer l’expérience", "Empêcher la transmission"],
    "bonnes": [0],
    "explication": "Les proverbes sont des outils de sagesse pour guider et faire réfléchir."
  },
  {
    "id": "C054",
    "categorieId": "culture",
    "question": "Quel élément renforce l’identité culturelle d’une communauté ?",
    "choix": ["Traditions et cérémonies", "Interdiction de la langue", "Absence de musique", "Refus des histoires"],
    "bonnes": [0],
    "explication": "Les traditions et cérémonies renforcent l’identité et la continuité culturelle."
  },
  {
    "id": "C055",
    "categorieId": "culture",
    "question": "Quelle catégorie de produits est très visible sur les marchés guinéens ?",
    "choix": ["Fruits et légumes", "Matériel de ski", "Glace de banquise", "Fourrure polaire"],
    "bonnes": [0],
    "explication": "Les marchés proposent beaucoup de fruits, légumes et produits agricoles."
  },
  {
    "id": "C056",
    "categorieId": "culture",
    "question": "Quel fruit est très apprécié et souvent vendu ?",
    "choix": ["Banane", "Myrtille arctique", "Canneberge", "Kiwi de montagne enneigée"],
    "bonnes": [0],
    "explication": "La banane fait partie des fruits très répandus et consommés."
  },
  {
    "id": "C057",
    "categorieId": "culture",
    "question": "Quel fruit est très courant en saison sur les marchés ?",
    "choix": ["Orange", "Cassis", "Airelle", "Litchi de neige"],
    "bonnes": [0],
    "explication": "Les agrumes, dont l’orange, sont présents sur les marchés selon les périodes."
  },
  {
    "id": "C058",
    "categorieId": "culture",
    "question": "Quel est un repas très fréquent au quotidien ?",
    "choix": ["Riz avec sauce", "Fondue savoyarde", "Choucroute", "Fish and chips londonien"],
    "bonnes": [0],
    "explication": "Le riz accompagné de sauce est un repas très fréquent en Guinée."
  },
  {
    "id": "C059",
    "categorieId": "culture",
    "question": "Quel est un marqueur culturel important lors des rencontres ?",
    "choix": ["Salutations", "Refus de parler", "Interdiction de s’asseoir", "Interdiction de rire"],
    "bonnes": [0],
    "explication": "Les salutations structurent les relations sociales et expriment le respect."
  },
  {
    "id": "C060",
    "categorieId": "culture",
    "question": "Quelle affirmation est correcte ?",
    "choix": ["La Guinée possède des cultures régionales variées", "La Guinée n’a pas de traditions", "La Guinée interdit la musique", "Les marchés n’existent pas en Guinée"],
    "bonnes": [0],
    "explication": "La Guinée est riche en cultures régionales et en traditions vivantes."
  },

  {
    "id": "C061",
    "categorieId": "culture",
    "question": "Parmi ces valeurs, lesquelles sont souvent mises en avant dans les familles ?",
    "choix": ["Respect des aînés", "Solidarité", "Partage", "Interdiction de saluer"],
    "bonnes": [0, 1, 2],
    "explication": "Respect, solidarité et partage sont fréquemment valorisés ; l’interdiction de saluer n’est pas une valeur."
  },
  {
    "id": "C062",
    "categorieId": "culture",
    "question": "Quel élément est souvent présent dans les récits traditionnels ?",
    "choix": ["Morale/leçon", "Absence totale de message", "Interdiction de réfléchir", "Suppression de la sagesse"],
    "bonnes": [0],
    "explication": "Les récits traditionnels portent souvent une morale et une leçon."
  },
  {
    "id": "C063",
    "categorieId": "culture",
    "question": "Quel est un rôle du rire et de l’humour dans la vie sociale ?",
    "choix": ["Détendre et rapprocher", "Créer la peur", "Interdire la parole", "Supprimer les liens"],
    "bonnes": [0],
    "explication": "L’humour peut renforcer la proximité et apaiser les tensions."
  },
  {
    "id": "C064",
    "categorieId": "culture",
    "question": "Quel est un moment fréquent pour se retrouver autour du thé ?",
    "choix": ["En fin d’après-midi/soirée", "Uniquement à minuit", "Uniquement au lever du soleil", "Uniquement pendant la neige"],
    "bonnes": [0],
    "explication": "Le thé est souvent partagé lors de moments de détente, souvent en fin de journée."
  },
  {
    "id": "C065",
    "categorieId": "culture",
    "question": "Quel est un usage courant des tissus et habits traditionnels ?",
    "choix": ["Cérémonies et fêtes", "Ski", "Luge", "Banquise"],
    "bonnes": [0],
    "explication": "Les tissus et habits traditionnels sont souvent portés pendant les cérémonies."
  },
  {
    "id": "C066",
    "categorieId": "culture",
    "question": "Quel est un élément important de la cuisine de fête ?",
    "choix": ["Repas en famille", "Repas en isolement obligatoire", "Interdiction de cuisiner", "Suppression du partage"],
    "bonnes": [0],
    "explication": "Les fêtes sont souvent marquées par des repas familiaux et communautaires."
  },
  {
    "id": "C067",
    "categorieId": "culture",
    "question": "Quel type de musique accompagne souvent les danses ?",
    "choix": ["Percussions (tambours)", "Harpe classique uniquement", "Orgue d’église uniquement", "Carillon de montagne"],
    "bonnes": [0],
    "explication": "Les percussions jouent un rôle essentiel pour rythmer les danses."
  },
  {
    "id": "C068",
    "categorieId": "culture",
    "question": "Quel est un rôle de l’artisanat dans la culture ?",
    "choix": ["Exprimer l’identité et le savoir-faire", "Créer de la neige", "Fabriquer des glaciers", "Interdire les traditions"],
    "bonnes": [0],
    "explication": "L’artisanat reflète des savoir-faire et des identités culturelles."
  },
  {
    "id": "C069",
    "categorieId": "culture",
    "question": "Quel est un élément fréquent des échanges au marché ?",
    "choix": ["Négociation", "Ski", "Luge", "Neige"],
    "bonnes": [0],
    "explication": "La négociation fait partie des pratiques commerciales courantes au marché."
  },
  {
    "id": "C070",
    "categorieId": "culture",
    "question": "Quel est un élément culturel important lors des funérailles (selon les traditions) ?",
    "choix": ["Soutien communautaire", "Compétition sportive", "Festival de neige", "Patinage artistique"],
    "bonnes": [0],
    "explication": "Les funérailles sont souvent marquées par la solidarité et le soutien de la communauté."
  },

  {
    "id": "C071",
    "categorieId": "culture",
    "question": "Quelle affirmation est vraie sur les cérémonies en Guinée ?",
    "choix": ["Elles rassemblent souvent famille et communauté", "Elles se déroulent toujours en silence total", "Elles interdisent la musique partout", "Elles excluent toujours les proches"],
    "bonnes": [0],
    "explication": "Les cérémonies sont généralement des moments de rassemblement et de soutien."
  },
  {
    "id": "C072",
    "categorieId": "culture",
    "question": "Quel est un objectif du partage des repas ?",
    "choix": ["Renforcer l’unité", "Créer l’isolement", "Supprimer l’entraide", "Interdire la discussion"],
    "bonnes": [0],
    "explication": "Partager un repas renforce la cohésion sociale."
  },
  {
    "id": "C073",
    "categorieId": "culture",
    "question": "Quelle activité met souvent en valeur les jeunes lors des fêtes ?",
    "choix": ["Danse et performance", "Ski", "Luge", "Pêche sur glace"],
    "bonnes": [0],
    "explication": "Dans certaines fêtes, la danse et la performance valorisent les jeunes."
  },
  {
    "id": "C074",
    "categorieId": "culture",
    "question": "Quel est un élément de la culture orale ?",
    "choix": ["Proverbes", "Glaciers", "Neige", "Volcans"],
    "bonnes": [0],
    "explication": "Les proverbes sont un élément majeur de la culture orale."
  },
  {
    "id": "C075",
    "categorieId": "culture",
    "question": "Quel est un lieu où l’on entend souvent plusieurs langues locales ?",
    "choix": ["Le marché", "La banquise", "La station de ski", "Le désert polaire"],
    "bonnes": [0],
    "explication": "Le marché est un lieu de diversité linguistique et d’échanges."
  },
  {
    "id": "C076",
    "categorieId": "culture",
    "question": "Quel est un rôle de la musique dans les cérémonies ?",
    "choix": ["Créer l’ambiance et rythmer", "Supprimer les émotions", "Interdire la joie", "Remplacer la famille"],
    "bonnes": [0],
    "explication": "La musique accompagne et rythme les moments importants."
  },
  {
    "id": "C077",
    "categorieId": "culture",
    "question": "Quel aliment est souvent associé aux sauces en Guinée ?",
    "choix": ["Riz", "Glace", "Neige", "Fromage alpin"],
    "bonnes": [0],
    "explication": "Le riz est généralement servi avec différentes sauces."
  },
  {
    "id": "C078",
    "categorieId": "culture",
    "question": "Quel est un geste courant de politesse ?",
    "choix": ["Dire bonjour et demander des nouvelles", "Ignorer tout le monde", "Interdire de parler", "Refuser les rencontres"],
    "bonnes": [0],
    "explication": "Saluer et prendre des nouvelles est un geste social important."
  },
  {
    "id": "C079",
    "categorieId": "culture",
    "question": "Quel est un contexte où l’entraide est particulièrement visible ?",
    "choix": ["Maladie ou deuil", "Festival de neige", "Compétition de ski", "Croisière polaire"],
    "bonnes": [0],
    "explication": "L’entraide se manifeste fortement lors des difficultés (maladie, deuil)."
  },
  {
    "id": "C080",
    "categorieId": "culture",
    "question": "Quel est un élément souvent associé au rythme en musique traditionnelle ?",
    "choix": ["Tambour", "Orgue", "Clavecin", "Cornemuse"],
    "bonnes": [0],
    "explication": "Le tambour est un instrument rythmique central dans de nombreuses musiques traditionnelles."
  },

  {
    "id": "C081",
    "categorieId": "culture",
    "question": "Dans la culture guinéenne, quel élément est souvent important pour régler un conflit ?",
    "choix": ["Médiation et dialogue", "Violence obligatoire", "Silence imposé", "Interdiction de se parler"],
    "bonnes": [0],
    "explication": "Le dialogue et la médiation communautaire sont souvent privilégiés."
  },
  {
    "id": "C082",
    "categorieId": "culture",
    "question": "Quel est un usage fréquent des histoires racontées aux enfants ?",
    "choix": ["Éduquer et divertir", "Interdire l’apprentissage", "Supprimer les valeurs", "Refuser la tradition"],
    "bonnes": [0],
    "explication": "Les histoires servent à éduquer tout en divertissant."
  },
  {
    "id": "C083",
    "categorieId": "culture",
    "question": "Quel élément est souvent valorisé dans le travail communautaire ?",
    "choix": ["Coopération", "Isolement", "Refus d’aider", "Interdiction de partager"],
    "bonnes": [0],
    "explication": "La coopération et l’entraide rendent les communautés plus fortes."
  },
  {
    "id": "C084",
    "categorieId": "culture",
    "question": "Quel type de produit artisanal peut être vendu sur les marchés ?",
    "choix": ["Tissus et objets artisanaux", "Skis de compétition", "Banquise emballée", "Neige en sachet"],
    "bonnes": [0],
    "explication": "On trouve souvent tissus, objets artisanaux, bijoux ou ustensiles faits localement."
  },
  {
    "id": "C085",
    "categorieId": "culture",
    "question": "Quel élément est très présent dans les sauces guinéennes ?",
    "choix": ["Légumes", "Glace", "Neige", "Fromage alpin"],
    "bonnes": [0],
    "explication": "Beaucoup de sauces incluent des légumes, selon les recettes locales."
  },
  {
    "id": "C086",
    "categorieId": "culture",
    "question": "Quel est un élément important dans la tenue traditionnelle lors des cérémonies ?",
    "choix": ["Propreté et élégance", "Neige", "Glace", "Bottes de ski"],
    "bonnes": [0],
    "explication": "Les tenues de cérémonie sont souvent choisies avec soin (propreté, élégance, symbolique)."
  },
  {
    "id": "C087",
    "categorieId": "culture",
    "question": "Quel est un rôle des fêtes communautaires ?",
    "choix": ["Renforcer l’identité", "Supprimer les liens", "Interdire la musique", "Créer l’isolement"],
    "bonnes": [0],
    "explication": "Les fêtes renforcent l’identité et l’unité communautaires."
  },
  {
    "id": "C088",
    "categorieId": "culture",
    "question": "Dans un marché guinéen, quel produit est très courant ?",
    "choix": ["Poissons", "Poissons sur glace polaire", "Fromages alpins", "Saucissons de neige"],
    "bonnes": [0],
    "explication": "Le poisson est très présent, surtout en zone côtière et dans les grandes villes."
  },
  {
    "id": "C089",
    "categorieId": "culture",
    "question": "Quel est un élément important de la vie religieuse et sociale ?",
    "choix": ["Respect des pratiques", "Interdiction de croire", "Refus des familles", "Interdiction des cérémonies"],
    "bonnes": [0],
    "explication": "Le respect des pratiques religieuses et sociales est important dans la vie quotidienne."
  },
  {
    "id": "C090",
    "categorieId": "culture",
    "question": "Quel est un élément culturel souvent lié à la musique ?",
    "choix": ["Danse", "Banquise", "Neige", "Ski"],
    "bonnes": [0],
    "explication": "La danse accompagne souvent la musique lors des fêtes et cérémonies."
  },

  {
    "id": "C091",
    "categorieId": "culture",
    "question": "Quel est un exemple de boisson partagée dans un cadre social ?",
    "choix": ["Thé", "Vin chaud alpin", "Saké", "Kvas"],
    "bonnes": [0],
    "explication": "Le thé est souvent partagé pour socialiser et discuter."
  },
  {
    "id": "C092",
    "categorieId": "culture",
    "question": "Quel est un élément important du rôle des parents dans la transmission ?",
    "choix": ["Éducation et valeurs", "Interdiction de raconter", "Silence obligatoire", "Refus de transmettre"],
    "bonnes": [0],
    "explication": "Les parents transmettent souvent valeurs, respect, et repères culturels."
  },
  {
    "id": "C093",
    "categorieId": "culture",
    "question": "Quel est un élément souvent présent lors des grandes fêtes ?",
    "choix": ["Invités et repas", "Neige et glace", "Traîneaux", "Skis"],
    "bonnes": [0],
    "explication": "Les grandes fêtes rassemblent souvent des invités autour d’un repas."
  },
  {
    "id": "C094",
    "categorieId": "culture",
    "question": "Quel est un rôle du marché pour les familles ?",
    "choix": ["Approvisionnement", "Patinage", "Ski", "Chasse polaire"],
    "bonnes": [0],
    "explication": "Le marché sert à l’approvisionnement en produits alimentaires et essentiels."
  },
  {
    "id": "C095",
    "categorieId": "culture",
    "question": "Dans les échanges sociaux, quel geste est très valorisé ?",
    "choix": ["Respect et écoute", "Mépris", "Insulte", "Isolement"],
    "bonnes": [0],
    "explication": "Le respect et l’écoute facilitent la vie sociale et réduisent les conflits."
  },
  {
    "id": "C096",
    "categorieId": "culture",
    "question": "Quel élément fait partie de la culture orale ?",
    "choix": ["Contes", "Glaciers", "Neige", "Ski"],
    "bonnes": [0],
    "explication": "Les contes sont des récits transmis oralement."
  },
  {
    "id": "C097",
    "categorieId": "culture",
    "question": "Quel est un rôle des cérémonies de mariage ?",
    "choix": ["Unir deux familles", "Créer la solitude", "Interdire la musique", "Supprimer les liens"],
    "bonnes": [0],
    "explication": "Le mariage unit deux personnes et symboliquement deux familles."
  },
  {
    "id": "C098",
    "categorieId": "culture",
    "question": "Quel est un contexte fréquent pour les danses traditionnelles ?",
    "choix": ["Fêtes et cérémonies", "Banquise", "Neige", "Ski"],
    "bonnes": [0],
    "explication": "Les danses sont souvent exécutées lors des fêtes et cérémonies."
  },
  {
    "id": "C099",
    "categorieId": "culture",
    "question": "Quel est un rôle du partage dans la société ?",
    "choix": ["Renforcer la cohésion", "Créer l’isolement", "Supprimer l’entraide", "Interdire les rencontres"],
    "bonnes": [0],
    "explication": "Le partage renforce la cohésion et la solidarité."
  },
  {
    "id": "C100",
    "categorieId": "culture",
    "question": "Parmi ces éléments, lesquels sont très liés à l’identité culturelle guinéenne ?",
    "choix": ["Musique", "Danse", "Langues locales", "Banquise"],
    "bonnes": [0, 1, 2],
    "explication": "Musique, danse et langues locales font partie de l’identité culturelle ; la banquise n’est pas un repère guinéen."
  },

  // =========================
  // C101 -> C160
  // =========================
  {
    "id": "C101",
    "categorieId": "culture",
    "question": "Quel élément est souvent central lors d’une grande cérémonie ?",
    "choix": ["Communauté réunie", "Isolement", "Silence imposé à tous", "Interdiction de se voir"],
    "bonnes": [0],
    "explication": "Les grandes cérémonies rassemblent généralement la communauté."
  },
  {
    "id": "C102",
    "categorieId": "culture",
    "question": "Quel est un rôle des tenues traditionnelles ?",
    "choix": ["Exprimer l’élégance et l’identité", "Créer de la neige", "Fabriquer des glaciers", "Interdire la musique"],
    "bonnes": [0],
    "explication": "Les tenues traduisent une identité et un respect de l’événement."
  },
  {
    "id": "C103",
    "categorieId": "culture",
    "question": "Quel est un marqueur culturel fréquent de politesse ?",
    "choix": ["Demander des nouvelles", "Ignorer", "Refuser de saluer", "Interdire la parole"],
    "bonnes": [0],
    "explication": "Demander des nouvelles fait partie des salutations et du respect."
  },
  {
    "id": "C104",
    "categorieId": "culture",
    "question": "Dans les récits, quel personnage est fréquent pour enseigner une morale ?",
    "choix": ["Animaux (conte)", "Robots", "Aliens", "Dragons nordiques"],
    "bonnes": [0],
    "explication": "Les contes utilisent souvent des animaux pour transmettre une leçon."
  },
  {
    "id": "C105",
    "categorieId": "culture",
    "question": "Quel est un rôle de la famille élargie dans la société ?",
    "choix": ["Soutien et entraide", "Isolement total", "Interdiction de se parler", "Refus des enfants"],
    "bonnes": [0],
    "explication": "La famille élargie joue souvent un rôle de soutien matériel et moral."
  },
  {
    "id": "C106",
    "categorieId": "culture",
    "question": "Quel élément est souvent associé aux grands événements (selon les pratiques) ?",
    "choix": ["Prières", "Ski", "Neige", "Banquise"],
    "bonnes": [0],
    "explication": "Les prières peuvent accompagner des événements importants selon les traditions."
  },
  {
    "id": "C107",
    "categorieId": "culture",
    "question": "Quel est un rôle des jeunes lors de certaines fêtes ?",
    "choix": ["Participer aux danses et activités", "Interdire les chants", "Créer l’isolement", "Supprimer la fête"],
    "bonnes": [0],
    "explication": "Les jeunes participent souvent aux danses, chants et activités communautaires."
  },
  {
    "id": "C108",
    "categorieId": "culture",
    "question": "Quel est un signe fréquent de convivialité ?",
    "choix": ["Partager un repas", "Manger seul obligatoirement", "Refuser l’invitation", "Interdire de cuisiner"],
    "bonnes": [0],
    "explication": "Partager un repas est une forme de convivialité et de respect."
  },
  {
    "id": "C109",
    "categorieId": "culture",
    "question": "Quel type d’objet artisanal peut être fabriqué localement ?",
    "choix": ["Objets en bois", "Skis", "Patins", "Luges"],
    "bonnes": [0],
    "explication": "L’artisanat local peut inclure des objets en bois, selon les zones et métiers."
  },
  {
    "id": "C110",
    "categorieId": "culture",
    "question": "Quel est un rôle des fêtes dans la culture ?",
    "choix": ["Renforcer les liens", "Interdire la joie", "Supprimer la solidarité", "Créer l’isolement"],
    "bonnes": [0],
    "explication": "Les fêtes sont des moments de rassemblement et de renforcement des liens."
  },

  {
    "id": "C111",
    "categorieId": "culture",
    "question": "Quel est un élément important de l’identité culturelle ?",
    "choix": ["Langue", "Neige", "Banquise", "Glace"],
    "bonnes": [0],
    "explication": "La langue est un marqueur culturel majeur."
  },
  {
    "id": "C112",
    "categorieId": "culture",
    "question": "Quel est un rôle des chants dans les cérémonies ?",
    "choix": ["Célébrer et accompagner", "Interdire la parole", "Créer le silence", "Supprimer les traditions"],
    "bonnes": [0],
    "explication": "Les chants accompagnent et donnent du sens aux cérémonies."
  },
  {
    "id": "C113",
    "categorieId": "culture",
    "question": "Quel type de nourriture est souvent vendu le soir en ville ?",
    "choix": ["Grillades", "Neige grillée", "Glace au renne", "Soupe polaire"],
    "bonnes": [0],
    "explication": "Les grillades sont une forme fréquente de street food, surtout le soir."
  },
  {
    "id": "C114",
    "categorieId": "culture",
    "question": "Quel est un élément important du respect envers les anciens ?",
    "choix": ["Écoute", "Refus de parler", "Insulte", "Mépris"],
    "bonnes": [0],
    "explication": "L’écoute et le respect des paroles des anciens sont valorisés."
  },
  {
    "id": "C115",
    "categorieId": "culture",
    "question": "Quel est un rôle des cérémonies dans l’éducation des jeunes ?",
    "choix": ["Transmission de repères", "Suppression des valeurs", "Interdiction d’apprendre", "Interdiction de parler"],
    "bonnes": [0],
    "explication": "Les cérémonies et traditions transmettent des repères culturels et sociaux."
  },
  {
    "id": "C116",
    "categorieId": "culture",
    "question": "Quel est un lieu fréquent d’apprentissage informel (savoir-faire, échanges) ?",
    "choix": ["Famille et communauté", "Banquise", "Station de ski", "Fjord"],
    "bonnes": [0],
    "explication": "L’apprentissage informel se fait souvent au sein de la famille et de la communauté."
  },
  {
    "id": "C117",
    "categorieId": "culture",
    "question": "Quel élément est souvent important pour accueillir un invité ?",
    "choix": ["Hospitalité", "Refus d’ouvrir la porte", "Silence imposé", "Interdiction de partager"],
    "bonnes": [0],
    "explication": "L’hospitalité est une valeur sociale importante dans de nombreux contextes."
  },
  {
    "id": "C118",
    "categorieId": "culture",
    "question": "Quel est un élément qui peut marquer une grande fête ?",
    "choix": ["Musique", "Neige", "Patins", "Luge"],
    "bonnes": [0],
    "explication": "La musique est un marqueur fréquent des grandes fêtes."
  },
  {
    "id": "C119",
    "categorieId": "culture",
    "question": "Quel élément culinaire est souvent associé aux repas :",
    "choix": ["Sauce", "Glace", "Neige", "Banquise"],
    "bonnes": [0],
    "explication": "La sauce accompagne fréquemment le riz et d’autres plats."
  },
  {
    "id": "C120",
    "categorieId": "culture",
    "question": "Quel est un élément culturel important pour l’unité sociale ?",
    "choix": ["Solidarité", "Isolement", "Refus d’aider", "Interdiction de se voir"],
    "bonnes": [0],
    "explication": "La solidarité renforce l’unité et la résilience de la communauté."
  },

  {
    "id": "C121",
    "categorieId": "culture",
    "question": "Quel est un élément souvent présent dans la musique traditionnelle ?",
    "choix": ["Percussions", "Ski", "Neige", "Banquise"],
    "bonnes": [0],
    "explication": "Les percussions rythment et structurent souvent la musique traditionnelle."
  },
  {
    "id": "C122",
    "categorieId": "culture",
    "question": "Quel est un rôle de la danse dans la culture ?",
    "choix": ["Expression et célébration", "Interdiction de bouger", "Refus de la fête", "Suppression de la musique"],
    "bonnes": [0],
    "explication": "La danse est une forme d’expression culturelle et de célébration."
  },
  {
    "id": "C123",
    "categorieId": "culture",
    "question": "Quel est un lieu où les gens se rencontrent souvent pour parler ?",
    "choix": ["Autour du thé", "Sur une piste de ski", "Sur la banquise", "Dans un glacier"],
    "bonnes": [0],
    "explication": "Le thé est souvent un cadre de discussion et de sociabilité."
  },
  {
    "id": "C124",
    "categorieId": "culture",
    "question": "Quel est un élément important du marché en tant qu’espace culturel ?",
    "choix": ["Rencontres et échanges", "Silence obligatoire", "Interdiction de négocier", "Isolement total"],
    "bonnes": [0],
    "explication": "Le marché sert aussi d’espace de rencontres, de nouvelles et d’échanges sociaux."
  },
  {
    "id": "C125",
    "categorieId": "culture",
    "question": "Quel est un élément important de la culture culinaire ?",
    "choix": ["Recettes transmises", "Recettes interdites", "Cuisine sans repas", "Cuisine sans partage"],
    "bonnes": [0],
    "explication": "Les recettes se transmettent souvent dans les familles et les communautés."
  },
  {
    "id": "C126",
    "categorieId": "culture",
    "question": "Quel est un signe d’unité lors d’événements ?",
    "choix": ["Participation collective", "Refus de venir", "Interdiction de se réunir", "Silence imposé"],
    "bonnes": [0],
    "explication": "La participation collective reflète l’unité et le soutien communautaire."
  },
  {
    "id": "C127",
    "categorieId": "culture",
    "question": "Quel élément est souvent associé au respect dans les discussions ?",
    "choix": ["Parler calmement", "Crier toujours", "Insulter", "Refuser d’écouter"],
    "bonnes": [0],
    "explication": "Le respect passe souvent par un ton calme et l’écoute."
  },
  {
    "id": "C128",
    "categorieId": "culture",
    "question": "Quel est un élément important du rôle des anciens ?",
    "choix": ["Conseiller", "Interdire la transmission", "Supprimer les traditions", "Refuser la médiation"],
    "bonnes": [0],
    "explication": "Les anciens conseillent et participent à la médiation et à la transmission."
  },
  {
    "id": "C129",
    "categorieId": "culture",
    "question": "Quel est un élément important dans la vie quotidienne ?",
    "choix": ["Relations de voisinage", "Banquise", "Neige", "Glace"],
    "bonnes": [0],
    "explication": "Les relations de voisinage peuvent être très importantes dans l’organisation sociale."
  },
  {
    "id": "C130",
    "categorieId": "culture",
    "question": "Quel est un élément culturel commun à plusieurs régions du pays ?",
    "choix": ["Importance des cérémonies", "Neige permanente", "Glaciers", "Sports polaires"],
    "bonnes": [0],
    "explication": "Les cérémonies et rassemblements sont importants dans de nombreuses régions."
  },

  {
    "id": "C131",
    "categorieId": "culture",
    "question": "Quel est un objectif des chants de cérémonie ?",
    "choix": ["Honorer et célébrer", "Interdire la joie", "Créer l’isolement", "Supprimer les invités"],
    "bonnes": [0],
    "explication": "Les chants peuvent honorer, célébrer et donner du sens à l’événement."
  },
  {
    "id": "C132",
    "categorieId": "culture",
    "question": "Quel est un marqueur culturel des fêtes ?",
    "choix": ["Rassemblement", "Isolement", "Interdiction de manger", "Refus de discuter"],
    "bonnes": [0],
    "explication": "Les fêtes sont des moments de rassemblement et d’expression culturelle."
  },
  {
    "id": "C133",
    "categorieId": "culture",
    "question": "Quel est un élément souvent associé à la générosité ?",
    "choix": ["Offrir/partager", "Refuser d’aider", "Interdire la nourriture", "Créer des conflits"],
    "bonnes": [0],
    "explication": "La générosité se manifeste souvent par l’offre et le partage."
  },
  {
    "id": "C134",
    "categorieId": "culture",
    "question": "Quel est un lieu où les produits agricoles sont souvent vendus ?",
    "choix": ["Marché", "Banquise", "Station de ski", "Fjord"],
    "bonnes": [0],
    "explication": "Le marché est le lieu principal de vente des produits agricoles."
  },
  {
    "id": "C135",
    "categorieId": "culture",
    "question": "Quel est un symbole de respect lors d’un événement important ?",
    "choix": ["Tenue soignée", "Tenue de ski", "Bottes de neige", "Patins"],
    "bonnes": [0],
    "explication": "Porter une tenue soignée est souvent un signe de respect de l’événement."
  },
  {
    "id": "C136",
    "categorieId": "culture",
    "question": "Quel est un élément important du rôle de la communauté ?",
    "choix": ["Soutenir les membres", "Les isoler", "Interdire l’entraide", "Refuser de partager"],
    "bonnes": [0],
    "explication": "La communauté apporte soutien et entraide dans les moments importants."
  },
  {
    "id": "C137",
    "categorieId": "culture",
    "question": "Quel est un objectif des traditions ?",
    "choix": ["Conserver une identité", "Supprimer la mémoire", "Interdire les valeurs", "Refuser les liens"],
    "bonnes": [0],
    "explication": "Les traditions contribuent à conserver et transmettre une identité collective."
  },
  {
    "id": "C138",
    "categorieId": "culture",
    "question": "Quel est un exemple de transmission culturelle ?",
    "choix": ["Apprendre une danse traditionnelle", "Construire un igloo", "Chasser sur la banquise", "Ski de fond"],
    "bonnes": [0],
    "explication": "Apprendre une danse traditionnelle est une forme de transmission culturelle."
  },
  {
    "id": "C139",
    "categorieId": "culture",
    "question": "Quel est un élément essentiel de la culture orale ?",
    "choix": ["Mémoire collective", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "La culture orale repose sur la mémoire collective et la transmission par la parole."
  },
  {
    "id": "C140",
    "categorieId": "culture",
    "question": "Quel élément peut accompagner les repas dans un cadre festif ?",
    "choix": ["Musique", "Tempête de neige", "Avalanche", "Glacier"],
    "bonnes": [0],
    "explication": "La musique peut accompagner les repas festifs et renforcer l’ambiance."
  },

  {
    "id": "C141",
    "categorieId": "culture",
    "question": "Quel est un élément important pour vivre ensemble ?",
    "choix": ["Respect mutuel", "Insulte", "Refus de parler", "Isolement"],
    "bonnes": [0],
    "explication": "Le respect mutuel est essentiel pour la cohésion sociale."
  },
  {
    "id": "C142",
    "categorieId": "culture",
    "question": "Quel est un élément important du lien familial ?",
    "choix": ["Visites et échanges", "Interdiction de voir la famille", "Isolement total", "Refus de se parler"],
    "bonnes": [0],
    "explication": "Visites et échanges entretiennent les liens familiaux."
  },
  {
    "id": "C143",
    "categorieId": "culture",
    "question": "Quel est un moment fréquent pour les rassemblements ?",
    "choix": ["Fêtes et cérémonies", "Sports de neige", "Course de luge", "Festival de banquise"],
    "bonnes": [0],
    "explication": "Les fêtes et cérémonies sont des moments majeurs de rassemblement."
  },
  {
    "id": "C144",
    "categorieId": "culture",
    "question": "Quel est un élément souvent associé à l’éducation par les anciens ?",
    "choix": ["Conseils", "Interdiction de transmettre", "Refus d’enseigner", "Silence imposé"],
    "bonnes": [0],
    "explication": "Les anciens transmettent souvent des conseils et des repères."
  },
  {
    "id": "C145",
    "categorieId": "culture",
    "question": "Quel est un élément essentiel des salutations ?",
    "choix": ["Politesse", "Mépris", "Insulte", "Refus de parler"],
    "bonnes": [0],
    "explication": "Les salutations sont une forme de politesse et de respect."
  },
  {
    "id": "C146",
    "categorieId": "culture",
    "question": "Quel est un élément important du rôle du voisinage ?",
    "choix": ["Entraide", "Isolement", "Refus d’aider", "Interdiction de parler"],
    "bonnes": [0],
    "explication": "Le voisinage peut offrir de l’entraide et un soutien quotidien."
  },
  {
    "id": "C147",
    "categorieId": "culture",
    "question": "Quel est un exemple de produit très courant vendu en rue ?",
    "choix": ["Brochettes", "Glace polaire", "Neige en boule", "Fromage alpin"],
    "bonnes": [0],
    "explication": "Les brochettes sont une restauration de rue très répandue."
  },
  {
    "id": "C148",
    "categorieId": "culture",
    "question": "Quel élément est souvent associé aux événements importants ?",
    "choix": ["Invitations", "Isolement", "Interdiction de venir", "Silence imposé"],
    "bonnes": [0],
    "explication": "Inviter la famille et les proches est fréquent lors des événements importants."
  },
  {
    "id": "C149",
    "categorieId": "culture",
    "question": "Quel est un exemple de savoir-faire artisanal ?",
    "choix": ["Tissage", "Ski", "Patinage", "Chasse sur glace"],
    "bonnes": [0],
    "explication": "Le tissage est un savoir-faire artisanal présent dans plusieurs zones."
  },
  {
    "id": "C150",
    "categorieId": "culture",
    "question": "Quel est un objectif du partage du thé ?",
    "choix": ["Créer un moment de discussion", "Interdire la conversation", "Créer des conflits", "Créer l’isolement"],
    "bonnes": [0],
    "explication": "Le thé est un moment social pour discuter et se retrouver."
  },

  {
    "id": "C151",
    "categorieId": "culture",
    "question": "Quelle ville est connue comme capitale et grand centre culturel et économique ?",
    "choix": ["Conakry", "Gaoual", "Koundara", "Kissidougou"],
    "bonnes": [0],
    "explication": "Conakry est la capitale et le principal centre urbain du pays."
  },
  {
    "id": "C152",
    "categorieId": "culture",
    "question": "Quel est un élément important lors des rencontres familiales ?",
    "choix": ["Partage de repas", "Refus de manger", "Interdiction de se parler", "Isolement total"],
    "bonnes": [0],
    "explication": "Le repas partagé renforce les liens familiaux."
  },
  {
    "id": "C153",
    "categorieId": "culture",
    "question": "Quel est un élément clé de la culture guinéenne ?",
    "choix": ["Diversité", "Uniformité mondiale", "Absence de traditions", "Interdiction de langue"],
    "bonnes": [0],
    "explication": "La Guinée est marquée par une grande diversité culturelle et linguistique."
  },
  {
    "id": "C154",
    "categorieId": "culture",
    "question": "Quel est un objectif des rassemblements communautaires ?",
    "choix": ["Soutenir et célébrer ensemble", "Créer la peur", "Interdire la fête", "Supprimer l’entraide"],
    "bonnes": [0],
    "explication": "Les rassemblements servent à soutenir, célébrer et renforcer les liens."
  },
  {
    "id": "C155",
    "categorieId": "culture",
    "question": "Quel est un élément culturel souvent associé à l’hospitalité ?",
    "choix": ["Accueillir et partager", "Refuser et isoler", "Interdire la visite", "Créer le silence"],
    "bonnes": [0],
    "explication": "L’hospitalité implique accueil, partage et attention à l’invité."
  },
  {
    "id": "C156",
    "categorieId": "culture",
    "question": "Quel est un élément important de l’éducation culturelle ?",
    "choix": ["Apprendre les valeurs", "Interdire la parole", "Refuser la tradition", "Supprimer les récits"],
    "bonnes": [0],
    "explication": "L’éducation culturelle transmet des valeurs et repères."
  },
  {
    "id": "C157",
    "categorieId": "culture",
    "question": "Quel est un élément souvent présent lors des fêtes traditionnelles ?",
    "choix": ["Tambours et chants", "Tempêtes de neige", "Avalanches", "Glaciers"],
    "bonnes": [0],
    "explication": "Tambours et chants accompagnent fréquemment les fêtes."
  },
  {
    "id": "C158",
    "categorieId": "culture",
    "question": "Quel est un produit très fréquent dans la street food ?",
    "choix": ["Poisson/viande grillée", "Glace polaire", "Neige en sachet", "Fondue"],
    "bonnes": [0],
    "explication": "Grillades de poisson ou viande sont très courantes dans la restauration de rue."
  },
  {
    "id": "C159",
    "categorieId": "culture",
    "question": "Quel est un élément important de la cohésion sociale ?",
    "choix": ["Entraide", "Mépris", "Insulte", "Refus de saluer"],
    "bonnes": [0],
    "explication": "L’entraide renforce la cohésion sociale."
  },
  {
    "id": "C160",
    "categorieId": "culture",
    "question": "Quel est un élément important des traditions culinaires ?",
    "choix": ["Transmission des recettes", "Interdiction de cuisiner", "Absence de repas", "Refus du partage"],
    "bonnes": [0],
    "explication": "Les recettes se transmettent et participent à l’identité culturelle."
  },

  // =========================
  // C161 -> C200
  // =========================
  {
    "id": "C161",
    "categorieId": "culture",
    "question": "Parmi ces éléments, lesquels peuvent être des occasions de rassemblement ?",
    "choix": ["Mariage", "Baptême", "Marché", "Banquise"],
    "bonnes": [0, 1, 2],
    "explication": "Mariage, baptême et marché sont des occasions/lieux de rassemblement ; la banquise n’est pas concernée."
  },
  {
    "id": "C162",
    "categorieId": "culture",
    "question": "Quel est un rôle des chants et danses dans la société ?",
    "choix": ["Célébrer et unir", "Diviser", "Interdire la joie", "Supprimer les traditions"],
    "bonnes": [0],
    "explication": "Chants et danses rassemblent et renforcent l’unité."
  },
  {
    "id": "C163",
    "categorieId": "culture",
    "question": "Quel est un comportement souvent valorisé lors d’une discussion ?",
    "choix": ["Écoute", "Insulte", "Mépris", "Refus de répondre"],
    "bonnes": [0],
    "explication": "Écouter est une marque de respect et facilite le dialogue."
  },
  {
    "id": "C164",
    "categorieId": "culture",
    "question": "Quel est un objectif du rôle des anciens dans la communauté ?",
    "choix": ["Guider et transmettre", "Supprimer la mémoire", "Interdire les traditions", "Créer l’isolement"],
    "bonnes": [0],
    "explication": "Les anciens guident, conseillent et transmettent des repères."
  },
  {
    "id": "C165",
    "categorieId": "culture",
    "question": "Quel élément culturel est souvent associé aux instruments ?",
    "choix": ["Rythme", "Glace", "Neige", "Banquise"],
    "bonnes": [0],
    "explication": "Les instruments (notamment percussions) structurent le rythme."
  },
  {
    "id": "C166",
    "categorieId": "culture",
    "question": "Quel est un effet du partage dans les relations sociales ?",
    "choix": ["Renforcer la confiance", "Augmenter l’isolement", "Supprimer les liens", "Interdire les rencontres"],
    "bonnes": [0],
    "explication": "Partager renforce la confiance et la cohésion."
  },
  {
    "id": "C167",
    "categorieId": "culture",
    "question": "Quel est un produit agricole très courant sur les marchés ?",
    "choix": ["Arachide", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "L’arachide est un produit agricole courant sur de nombreux marchés."
  },
  {
    "id": "C168",
    "categorieId": "culture",
    "question": "Quel est un élément de la vie sociale en ville ?",
    "choix": ["Marchés et quartiers", "Glaciers et fjords", "Neige permanente", "Banquise"],
    "bonnes": [0],
    "explication": "Marchés et quartiers sont des lieux de sociabilité urbaine."
  },
  {
    "id": "C169",
    "categorieId": "culture",
    "question": "Quel est un élément culturel souvent lié à la cuisine ?",
    "choix": ["Partage", "Isolement", "Refus de manger", "Interdiction de cuisiner"],
    "bonnes": [0],
    "explication": "La cuisine est souvent un espace de partage et de convivialité."
  },
  {
    "id": "C170",
    "categorieId": "culture",
    "question": "Quel est un rôle des fêtes dans la mémoire collective ?",
    "choix": ["Entretenir les traditions", "Supprimer la mémoire", "Interdire les récits", "Créer l’oubli"],
    "bonnes": [0],
    "explication": "Les fêtes entretiennent les traditions et la mémoire collective."
  },

  {
    "id": "C171",
    "categorieId": "culture",
    "question": "Quel est un comportement valorisé envers un invité ?",
    "choix": ["Hospitalité", "Refus d’aider", "Insulte", "Mépris"],
    "bonnes": [0],
    "explication": "L’hospitalité exprime le respect et la générosité envers l’invité."
  },
  {
    "id": "C172",
    "categorieId": "culture",
    "question": "Quel est un élément souvent associé à la vie communautaire ?",
    "choix": ["Entraide", "Isolement", "Refus de partager", "Interdiction de saluer"],
    "bonnes": [0],
    "explication": "La vie communautaire valorise l’entraide."
  },
  {
    "id": "C173",
    "categorieId": "culture",
    "question": "Quel est un rôle des cérémonies dans la société ?",
    "choix": ["Marquer des étapes de vie", "Supprimer les familles", "Interdire les rencontres", "Créer l’isolement"],
    "bonnes": [0],
    "explication": "Les cérémonies marquent des étapes : naissance, mariage, etc."
  },
  {
    "id": "C174",
    "categorieId": "culture",
    "question": "Quel est un rôle des proverbes dans la communication ?",
    "choix": ["Exprimer une sagesse en peu de mots", "Interdire la parole", "Créer le silence", "Supprimer les valeurs"],
    "bonnes": [0],
    "explication": "Les proverbes condensent une sagesse et guident la réflexion."
  },
  {
    "id": "C175",
    "categorieId": "culture",
    "question": "Quel est un exemple de moment où la solidarité s’exprime fortement ?",
    "choix": ["Deuil", "Festival de neige", "Compétition de ski", "Croisière polaire"],
    "bonnes": [0],
    "explication": "En période de deuil, la communauté apporte souvent un soutien important."
  },
  {
    "id": "C176",
    "categorieId": "culture",
    "question": "Quel est un élément souvent associé à la musique en fête ?",
    "choix": ["Danse", "Banquise", "Neige", "Glace"],
    "bonnes": [0],
    "explication": "La danse accompagne souvent la musique pendant les fêtes."
  },
  {
    "id": "C177",
    "categorieId": "culture",
    "question": "Quel est un élément culturel important du marché ?",
    "choix": ["Nouvelles et rencontres", "Isolement obligatoire", "Interdiction de négocier", "Silence permanent"],
    "bonnes": [0],
    "explication": "Le marché est un lieu où l’on échange aussi des nouvelles et où l’on se rencontre."
  },
  {
    "id": "C178",
    "categorieId": "culture",
    "question": "Quel est un objectif des traditions culinaires ?",
    "choix": ["Transmettre une identité", "Supprimer la mémoire", "Interdire les repas", "Refuser la famille"],
    "bonnes": [0],
    "explication": "Les traditions culinaires participent à l’identité et à la transmission."
  },
  {
    "id": "C179",
    "categorieId": "culture",
    "question": "Quel est un aspect important de la diversité culturelle guinéenne ?",
    "choix": ["Diversité des langues", "Une seule langue unique", "Absence de langues locales", "Interdiction de parler"],
    "bonnes": [0],
    "explication": "La Guinée se caractérise par une diversité de langues locales."
  },
  {
    "id": "C180",
    "categorieId": "culture",
    "question": "Quel est un élément central des grandes célébrations ?",
    "choix": ["Repas", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "Le repas est central dans de nombreuses célébrations."
  },

  {
    "id": "C181",
    "categorieId": "culture",
    "question": "Quel est un rôle des chants dans la culture orale ?",
    "choix": ["Conserver et transmettre", "Supprimer la mémoire", "Interdire les récits", "Créer l’oubli"],
    "bonnes": [0],
    "explication": "Les chants peuvent conserver des récits et transmettre des valeurs."
  },
  {
    "id": "C182",
    "categorieId": "culture",
    "question": "Quel est un élément important de la cohésion familiale ?",
    "choix": ["Respect", "Mépris", "Insulte", "Isolement"],
    "bonnes": [0],
    "explication": "Le respect renforce la cohésion familiale."
  },
  {
    "id": "C183",
    "categorieId": "culture",
    "question": "Quel est un exemple d’événement qui rassemble souvent beaucoup de personnes ?",
    "choix": ["Mariage", "Chasse polaire", "Course de luge", "Festival de neige"],
    "bonnes": [0],
    "explication": "Les mariages rassemblent souvent un grand nombre de proches."
  },
  {
    "id": "C184",
    "categorieId": "culture",
    "question": "Quel est un élément important des salutations ?",
    "choix": ["Respect", "Mépris", "Insulte", "Refus de parler"],
    "bonnes": [0],
    "explication": "Saluer est une marque de respect et un code social important."
  },
  {
    "id": "C185",
    "categorieId": "culture",
    "question": "Quel est un exemple d’expression culturelle très visible ?",
    "choix": ["Danse", "Banquise", "Glace", "Neige"],
    "bonnes": [0],
    "explication": "La danse est une expression culturelle visible dans plusieurs événements."
  },
  {
    "id": "C186",
    "categorieId": "culture",
    "question": "Quel est un produit alimentaire couramment consommé ?",
    "choix": ["Riz", "Neige", "Glace", "Banquise"],
    "bonnes": [0],
    "explication": "Le riz est largement consommé en Guinée."
  },
  {
    "id": "C187",
    "categorieId": "culture",
    "question": "Quel est un élément important du marché comme espace culturel ?",
    "choix": ["Rencontre et échange", "Isolement", "Silence", "Interdiction de parler"],
    "bonnes": [0],
    "explication": "Le marché est un espace de rencontre, d’échange et de communication."
  },
  {
    "id": "C188",
    "categorieId": "culture",
    "question": "Quel est un rôle des repas lors des cérémonies ?",
    "choix": ["Partager et rassembler", "Créer l’isolement", "Interdire les invités", "Refuser la famille"],
    "bonnes": [0],
    "explication": "Le repas réunit et renforce les liens."
  },
  {
    "id": "C189",
    "categorieId": "culture",
    "question": "Quels éléments suivants font partie de la culture guinéenne au quotidien ?",
    "choix": ["Salutations", "Marché", "Thé", "Ski"],
    "bonnes": [0, 1, 2],
    "explication": "Salutations, marché et thé sont des éléments quotidiens ; le ski n’est pas un repère guinéen."
  },
  {
    "id": "C190",
    "categorieId": "culture",
    "question": "Quelle phrase résume le mieux la culture guinéenne ?",
    "choix": [
      "Diversité, solidarité et traditions vivantes",
      "Uniformité mondiale et absence de traditions",
      "Silence permanent et interdiction de saluer",
      "Banquise et sports polaires"
    ],
    "bonnes": [0],
    "explication": "La culture guinéenne est diverse, marquée par la solidarité et des traditions vivantes."
  },

  {
    "id": "C191",
    "categorieId": "culture",
    "question": "Quel est un élément culturel important lors d’un baptême ?",
    "choix": ["Réunir la famille", "Interdire de manger", "Interdire de parler", "Rester seul"],
    "bonnes": [0],
    "explication": "Le baptême réunit souvent famille et proches."
  },
  {
    "id": "C192",
    "categorieId": "culture",
    "question": "Quel est un rôle de l’artisanat local ?",
    "choix": ["Créer des objets utiles et identitaires", "Créer de la neige", "Créer des glaciers", "Interdire la culture"],
    "bonnes": [0],
    "explication": "L’artisanat produit des objets et renforce l’identité culturelle."
  },
  {
    "id": "C193",
    "categorieId": "culture",
    "question": "Quel est un élément important lors des funérailles (selon les pratiques) ?",
    "choix": ["Soutien communautaire", "Compétition sportive", "Course de luge", "Festival de neige"],
    "bonnes": [0],
    "explication": "La communauté apporte souvent un soutien moral et matériel."
  },
  {
    "id": "C194",
    "categorieId": "culture",
    "question": "Quel est un rôle des fêtes dans la transmission culturelle ?",
    "choix": ["Faire vivre les traditions", "Supprimer les traditions", "Interdire la musique", "Créer l’oubli"],
    "bonnes": [0],
    "explication": "Les fêtes maintiennent les traditions et les transmettent."
  },
  {
    "id": "C195",
    "categorieId": "culture",
    "question": "Quel est un rôle du respect des aînés ?",
    "choix": ["Maintenir l’ordre social et la transmission", "Supprimer la mémoire", "Créer le chaos", "Interdire l’éducation"],
    "bonnes": [0],
    "explication": "Le respect des aînés soutient la transmission et l’équilibre social."
  },
  {
    "id": "C196",
    "categorieId": "culture",
    "question": "Quel élément est souvent associé aux grands rassemblements ?",
    "choix": ["Musique", "Banquise", "Neige", "Glace"],
    "bonnes": [0],
    "explication": "La musique est fréquemment présente lors des grands rassemblements."
  },
  {
    "id": "C197",
    "categorieId": "culture",
    "question": "Quel est un élément important du vivre-ensemble ?",
    "choix": ["Dialogue", "Insulte", "Mépris", "Refus de parler"],
    "bonnes": [0],
    "explication": "Le dialogue aide à résoudre les tensions et renforcer la cohésion."
  },
  {
    "id": "C198",
    "categorieId": "culture",
    "question": "Quel est un élément important du lien social en Guinée ?",
    "choix": ["Communauté", "Isolement", "Refus d’entraide", "Interdiction de se réunir"],
    "bonnes": [0],
    "explication": "La communauté joue un rôle central dans l’organisation sociale."
  },
  {
    "id": "C199",
    "categorieId": "culture",
    "question": "Quel est un objectif du partage (repas, aide, temps) ?",
    "choix": ["Renforcer la solidarité", "Créer l’isolement", "Supprimer les liens", "Interdire la famille"],
    "bonnes": [0],
    "explication": "Partager renforce la solidarité et l’unité sociale."
  },
  {
    "id": "C200",
    "categorieId": "culture",
    "question": "Quels éléments suivants résument des piliers culturels guinéens ?",
    "choix": ["Langues locales", "Musique et danse", "Cérémonies", "Solidarité"],
    "bonnes": [0, 1, 2, 3],
    "explication": "La culture guinéenne s’appuie sur la diversité linguistique, l’expression artistique, les cérémonies et la solidarité."
  },
];




  /// ✅ Retourne des objets QuestionQuiz (compatibles avec EducationQuizPage)
  /// ⚠️ L’aléatoire est géré dans EducationQuizPage (shuffle), donc ici on renvoie la base.
  static List<QuestionQuiz> questionsParCategorie(String categorieId) {
    final List<Map<String, dynamic>> raw;
    switch (categorieId) {
      case 'histoire':
        raw = _rawHistoireGuinee;
        break;
      case 'geographie':
        raw = _rawGeographieGuinee;
        break;
      case 'culture':
        raw = _rawCultureGuinee;
        break;
      default:
        raw = const <Map<String, dynamic>>[];
        break;
    }

    return raw.map(QuestionQuiz.fromMap).toList(growable: false);
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
