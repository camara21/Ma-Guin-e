// lib/education/tts_text_normalizer.dart
//
// Normalisation FR pour améliorer la prononciation TTS.
// Objectifs:
// - prosodie naturelle (pauses), sans "hachurer" le texte
// - gestion symboles math (×, ÷, /, +, -) => lecture humaine
// - décimales FR, milliers
// - finir proprement les phrases

class TtsTextNormalizer {
  static String normalizeFr(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    // Nettoyage espaces
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    // Tirets
    s = s.replaceAll('–', '-').replaceAll('—', '-');

    // Symboles divers / monnaies
    s = s
        .replaceAll('&', ' et ')
        .replaceAll('@', ' arobase ')
        .replaceAll('€', ' euros ')
        .replaceAll('\$', ' dollars ');

    // Pourcent : 50% => "50 pour cent"
    s = s.replaceAllMapped(RegExp(r'(\d)\s*%'), (m) => '${m.group(1)} pour cent');
    s = s.replaceAll('%', ' pour cent ');

    // Opérateurs math
    s = s
        .replaceAll('×', ' fois ')
        .replaceAll('÷', ' divisé par ')
        .replaceAllMapped(RegExp(r'\s*=\s*'), (_) => ' égale ')
        .replaceAllMapped(RegExp(r'(?<=\d)\s*\+\s*(?=\d)'), (_) => ' plus ')
        .replaceAllMapped(RegExp(r'(?<=\d)\s*-\s*(?=\d)'), (_) => ' moins ');

    // Fractions "connues"
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*2\b'), (_) => ' un demi ');
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*4\b'), (_) => ' un quart ');
    s = s.replaceAllMapped(RegExp(r'\b3\s*/\s*4\b'), (_) => ' trois quarts ');

    // Fractions générales (évite "slash"), mais évite les dates (12/05/2024)
    // - pas de 2e slash derrière
    // - num/den <= 3 chiffres, pour les fractions scolaires
    s = s.replaceAllMapped(
      RegExp(r'\b(\d{1,3})\s*/\s*(\d{1,3})\b(?!\s*/)'),
      (m) {
        final a = m.group(1)!;
        final b = m.group(2)!;
        return ' $a sur $b ';
      },
    );

    // Slash unités (km/h, m/s) => "par" (uniquement lettres/lettres)
    s = s.replaceAllMapped(
      RegExp(r'\b([a-zA-Z]{1,6})\s*/\s*([a-zA-Z]{1,6})\b'),
      (m) => ' ${m.group(1)} par ${m.group(2)} ',
    );

    // Unités : uniquement lorsqu'elles suivent un nombre (évite de casser du texte)
    s = _replaceUnitsAfterNumbers(s);

    // Décimales FR: 3,5 / 3,05 => "3 virgule cinq" / "3 virgule zéro cinq"
    s = s.replaceAllMapped(RegExp(r'\b(\d+),(\d+)\b'), (m) {
      final intPart = m.group(1)!;
      final decPart = m.group(2)!;

      final hasLeadingZeros = decPart.startsWith('0');
      final decSpoken = hasLeadingZeros ? _digitsToWords(decPart) : _compactNumberDec(decPart);

      return ' $intPart virgule $decSpoken ';
    });

    // Milliers: 10 000 / 10,000 / 1 000 000
    s = s.replaceAllMapped(RegExp(r'\b(\d{1,3})([ ,]\d{3})+\b'), (m) {
      final txt = m.group(0)!.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return ' $txt ';
    });

    // Ordinaux
    s = s.replaceAllMapped(RegExp(r'\b1er\b', caseSensitive: false), (_) => ' premier ');
    s = s.replaceAllMapped(RegExp(r'\b(\d+)\s*e\b', caseSensitive: false), (m) {
      return ' ${m.group(1)} ème ';
    });

    // Ponctuation: on ne "tokenise" pas, on normalise les espaces pour la pause
    s = s
        .replaceAllMapped(RegExp(r'\s*([?!])\s*'), (m) => '${m.group(1)} ')
        .replaceAllMapped(RegExp(r'\s*([:;])\s*'), (m) => '${m.group(1)} ')
        .replaceAllMapped(RegExp(r'\s*,\s*'), (_) => ', ')
        .replaceAllMapped(RegExp(r'\s*\.\s*'), (_) => '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Finir proprement:
    // - si finit par ":" ";" "," => on termine par un point
    if (RegExp(r'[:;,]$').hasMatch(s)) {
      s = s.substring(0, s.length - 1).trimRight();
      s = '$s.';
    }

    // - si pas de ponctuation finale => ajouter un point (meilleure intonation finale)
    if (!RegExp(r'[.!?]$').hasMatch(s)) {
      s = '$s.';
    }

    // Petit espace final: aide certains moteurs à ne pas "manger" la fin
    return '$s '.trimRight();
  }

  static String _replaceUnitsAfterNumbers(String s) {
    // Remplacements ciblés: "10 km" => "10 kilomètres"
    // On garde des bornes et on exige un nombre avant, pour éviter les faux positifs.
    final rules = <RegExp, String>{
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*km/h\b', caseSensitive: false): r'\1 kilomètres par heure',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*m/s\b', caseSensitive: false): r'\1 mètres par seconde',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*km\b', caseSensitive: false): r'\1 kilomètres',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*m\b', caseSensitive: false): r'\1 mètres',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*cm\b', caseSensitive: false): r'\1 centimètres',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*mm\b', caseSensitive: false): r'\1 millimètres',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*kg\b', caseSensitive: false): r'\1 kilogrammes',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*g\b', caseSensitive: false): r'\1 grammes',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*L\b', caseSensitive: false): r'\1 litres',
      RegExp(r'\b(\d+(?:[.,]\d+)?)\s*ml\b', caseSensitive: false): r'\1 millilitres',
      RegExp(r'\b(\d+)\s*h\b', caseSensitive: false): r'\1 heures',
      RegExp(r'\b(\d+)\s*min\b', caseSensitive: false): r'\1 minutes',
      RegExp(r'\b(\d+)\s*s\b', caseSensitive: false): r'\1 secondes',
    };

    var out = s;
    rules.forEach((re, rep) {
      out = out.replaceAllMapped(re, (m) => ' ${m.group(0)!.replaceAll(re, rep)} ');
    });

    // Correction si replaceAllMapped a doublé: on repasse proprement
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*km/h\b', caseSensitive: false),
        (m) => '${m.group(1)} kilomètres par heure');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*m/s\b', caseSensitive: false),
        (m) => '${m.group(1)} mètres par seconde');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*km\b', caseSensitive: false),
        (m) => '${m.group(1)} kilomètres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*m\b', caseSensitive: false),
        (m) => '${m.group(1)} mètres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*cm\b', caseSensitive: false),
        (m) => '${m.group(1)} centimètres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*mm\b', caseSensitive: false),
        (m) => '${m.group(1)} millimètres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*kg\b', caseSensitive: false),
        (m) => '${m.group(1)} kilogrammes');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*g\b', caseSensitive: false),
        (m) => '${m.group(1)} grammes');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*L\b', caseSensitive: false),
        (m) => '${m.group(1)} litres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*ml\b', caseSensitive: false),
        (m) => '${m.group(1)} millilitres');
    out = out.replaceAllMapped(RegExp(r'\b(\d+)\s*h\b', caseSensitive: false),
        (m) => '${m.group(1)} heures');
    out = out.replaceAllMapped(RegExp(r'\b(\d+)\s*min\b', caseSensitive: false),
        (m) => '${m.group(1)} minutes');
    out = out.replaceAllMapped(RegExp(r'\b(\d+)\s*s\b', caseSensitive: false),
        (m) => '${m.group(1)} secondes');

    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _digitsToWords(String digits) {
    // "05" => "zéro cinq"
    return digits.split('').map(_digitWord).join(' ');
  }

  static String _compactNumberDec(String dec) {
    // Pour "5" => "cinq", pour "12" => "douze" (mais on reste simple)
    // La plupart des TTS FR gèrent correctement les petits nombres.
    // Si ce n’est pas votre cas, remplacez par _digitsToWords(dec).
    return dec;
  }

  static String _digitWord(String c) {
    switch (c) {
      case '0':
        return 'zéro';
      case '1':
        return 'un';
      case '2':
        return 'deux';
      case '3':
        return 'trois';
      case '4':
        return 'quatre';
      case '5':
        return 'cinq';
      case '6':
        return 'six';
      case '7':
        return 'sept';
      case '8':
        return 'huit';
      case '9':
        return 'neuf';
      default:
        return c;
    }
  }
}
