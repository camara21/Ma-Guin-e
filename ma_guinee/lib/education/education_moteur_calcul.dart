import 'dart:math';

enum TypeCalcul {
  addition,
  soustraction,
  multiplication,
  division,
}

enum NiveauCalcul {
  facile,
  moyen,
  avance,
}

class QuestionCalcul {
  final String enonce; // affiché + lu (question uniquement)
  final List<int> propositions; // affichées seulement
  final int indexBonneReponse;
  final String explication; // lue seulement si faux

  const QuestionCalcul({
    required this.enonce,
    required this.propositions,
    required this.indexBonneReponse,
    required this.explication,
  });

  int get bonneReponse => propositions[indexBonneReponse];
}

class EducationMoteurCalcul {
  final Random _rnd = Random();

  QuestionCalcul generer({
    required TypeCalcul type,
    required NiveauCalcul niveau,
  }) {
    switch (type) {
      case TypeCalcul.addition:
        return _genererAddition(niveau);
      case TypeCalcul.soustraction:
        return _genererSoustraction(niveau);
      case TypeCalcul.multiplication:
        return _genererMultiplication(niveau);
      case TypeCalcul.division:
        return _genererDivisionExacte(niveau);
    }
  }

  // ---------- ADDITION ----------
  QuestionCalcul _genererAddition(NiveauCalcul niveau) {
    final (min, max) =
        _plage(niveau, facileMax: 10, moyenMax: 50, avanceMax: 200);
    final a = _entre(min, max);
    final b = _entre(min, max);
    final resultat = a + b;

    final propositions = _propositionsQcm(resultat);
    return QuestionCalcul(
      enonce: '$a + $b = ?',
      propositions: propositions,
      indexBonneReponse: propositions.indexOf(resultat),
      explication: 'La bonne réponse est $resultat car $a + $b = $resultat.',
    );
  }

  // ---------- SOUSTRACTION ----------
  QuestionCalcul _genererSoustraction(NiveauCalcul niveau) {
    final (min, max) =
        _plage(niveau, facileMax: 10, moyenMax: 100, avanceMax: 500);
    int a = _entre(min, max);
    int b = _entre(min, max);
    if (b > a) {
      final tmp = a;
      a = b;
      b = tmp;
    }
    final resultat = a - b;

    final propositions = _propositionsQcm(resultat);
    return QuestionCalcul(
      enonce: '$a - $b = ?',
      propositions: propositions,
      indexBonneReponse: propositions.indexOf(resultat),
      explication: 'La bonne réponse est $resultat car $a - $b = $resultat.',
    );
  }

  // ---------- MULTIPLICATION ----------
  QuestionCalcul _genererMultiplication(NiveauCalcul niveau) {
    if (niveau == NiveauCalcul.facile) {
      final a = _entre(0, 10);
      final b = _entre(0, 10);
      final resultat = a * b;
      final propositions = _propositionsQcm(resultat);

      return QuestionCalcul(
        enonce: '$a × $b = ?',
        propositions: propositions,
        indexBonneReponse: propositions.indexOf(resultat),
        explication:
            'La bonne réponse est $resultat car $a multiplié par $b = $resultat.',
      );
    }

    if (niveau == NiveauCalcul.moyen) {
      final a = _entre(0, 20);
      final b = _entre(0, 20);
      final resultat = a * b;
      final propositions = _propositionsQcm(resultat);

      return QuestionCalcul(
        enonce: '$a × $b = ?',
        propositions: propositions,
        indexBonneReponse: propositions.indexOf(resultat),
        explication: 'La bonne réponse est $resultat car $a × $b = $resultat.',
      );
    }

    // Avancé : 2 chiffres × 2 chiffres (raisonnable)
    final a = _entre(0, 99);
    final b = _entre(0, 99);
    final resultat = a * b;
    final propositions = _propositionsQcm(resultat);

    return QuestionCalcul(
      enonce: '$a × $b = ?',
      propositions: propositions,
      indexBonneReponse: propositions.indexOf(resultat),
      explication: 'La bonne réponse est $resultat car $a × $b = $resultat.',
    );
  }

  // ---------- DIVISION (exacte, résultat entier) ----------
  QuestionCalcul _genererDivisionExacte(NiveauCalcul niveau) {
    // Génération contrôlée : n = r × d
    final (rMin, rMax, dMin, dMax) = switch (niveau) {
      NiveauCalcul.facile => (1, 10, 2, 10),
      NiveauCalcul.moyen => (1, 20, 2, 12),
      NiveauCalcul.avance => (2, 50, 2, 25),
    };

    final resultat = _entre(rMin, rMax);
    final diviseur = _entre(dMin, dMax);
    final dividende = resultat * diviseur;

    final propositions = _propositionsQcm(resultat);

    return QuestionCalcul(
      enonce: '$dividende ÷ $diviseur = ?',
      propositions: propositions,
      indexBonneReponse: propositions.indexOf(resultat),
      explication:
          'La bonne réponse est $resultat car $diviseur × $resultat = $dividende.',
    );
  }

  // ---------- OUTILS ----------
  (int, int) _plage(
    NiveauCalcul niveau, {
    required int facileMax,
    required int moyenMax,
    required int avanceMax,
  }) {
    switch (niveau) {
      case NiveauCalcul.facile:
        return (0, facileMax);
      case NiveauCalcul.moyen:
        return (0, moyenMax);
      case NiveauCalcul.avance:
        return (0, avanceMax);
    }
  }

  int _entre(int min, int maxInclus) {
    if (maxInclus <= min) return min;
    return min + _rnd.nextInt(maxInclus - min + 1);
  }

  List<int> _propositionsQcm(int resultat) {
    // 1 bonne + 3 fausses proches, sans doublons, jamais négatives
    final set = <int>{resultat};

    // offsets plausibles
    final offsets = <int>[1, 2, 3, 4, 5, 7, 10, 12];
    offsets.shuffle(_rnd);

    int i = 0;
    while (set.length < 4 && i < offsets.length) {
      final off = offsets[i++];
      final candidats = <int>[
        resultat + off,
        resultat - off,
      ];
      candidats.shuffle(_rnd);
      for (final c in candidats) {
        if (set.length >= 4) break;
        if (c >= 0) set.add(c);
      }
    }

    // fallback au cas rare
    while (set.length < 4) {
      final c = resultat + _entre(6, 25);
      set.add(c);
    }

    final list = set.toList()..shuffle(_rnd);
    return list;
  }
}
