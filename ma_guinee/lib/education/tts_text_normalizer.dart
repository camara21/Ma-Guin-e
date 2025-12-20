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

    // espaces propres
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    // Unifier tirets
    s = s.replaceAll('–', '-').replaceAll('—', '-');

    // Remplacer symboles monétaires & divers (en gardant une prosodie naturelle)
    s = s
        .replaceAll('%', ' pour cent')
        .replaceAll('€', ' euros')
        .replaceAll('\$', ' dollars')
        .replaceAll('&', ' et ')
        .replaceAll('@', ' arobase ');

    // Règles "math" plus naturelles
    // (IMPORTANT: on fait avant la ponctuation)
    s = s
        .replaceAll('×', ' fois ')
        .replaceAll('÷', ' divisé par ')
        .replaceAllMapped(RegExp(r'(?<=\d)\s*\+\s*(?=\d)'), (_) => ' plus ')
        .replaceAllMapped(RegExp(r'(?<=\d)\s*-\s*(?=\d)'), (_) => ' moins ')
        .replaceAll('=', ' égale ');

    // Fractions simples (1/2, 1/4, 3/4)
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*2\b'), (_) => ' un demi ');
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*4\b'), (_) => ' un quart ');
    s = s.replaceAllMapped(RegExp(r'\b3\s*/\s*4\b'), (_) => ' trois quarts ');

    // Slash d'unités (km/h, m/s, etc.) => "par"
    s = s.replaceAllMapped(
      RegExp(r'\b([a-zA-Z]+)\s*/\s*([a-zA-Z]+)\b'),
      (m) => ' ${m.group(1)} par ${m.group(2)} ',
    );

    // Décimales françaises "3,5" => "3 virgule 5"
    // (à faire avant la normalisation des milliers)
    s = s.replaceAllMapped(RegExp(r'\b(\d+),(\d+)\b'), (m) {
      return ' ${m.group(1)} virgule ${m.group(2)} ';
    });

    // Séparateurs de milliers (10 000 / 10,000) => garder l'espace
    s = s.replaceAllMapped(RegExp(r'\b(\d{1,3})([ ,]\d{3})+\b'), (m) {
      final txt = m.group(0)!.replaceAll(',', ' ');
      return ' $txt ';
    });

    // Ordinaux 1er / 2e / 3e
    s = s.replaceAllMapped(RegExp(r'\b1er\b', caseSensitive: false), (_) => ' premier ');
    s = s.replaceAllMapped(RegExp(r'\b(\d+)\s*e\b', caseSensitive: false), (m) {
      return ' ${m.group(1)} ème ';
    });

    // Années 19xx / 20xx => ajouter contexte léger (plus naturel)
    s = s.replaceAllMapped(RegExp(r'\b(19\d{2}|20\d{2})\b'), (m) {
      return ' année ${m.group(1)} ';
    });

    // Ponctuation: on évite de la "séparer" en tokens (" . ")
    // On harmonise juste les espaces avant/après, pour que le moteur marque des pauses.
    s = s
        .replaceAllMapped(RegExp(r'\s*([?!:;,])\s*'), (m) => '${m.group(1)} ')
        .replaceAllMapped(RegExp(r'\s*\.\s*'), (_) => '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Finir proprement: si pas de ponctuation finale, ajouter un point + espace
    if (!RegExp(r'[.!?]$').hasMatch(s)) {
      s = '$s. ';
    } else {
      // Ajouter un petit espace final aide certains moteurs à "finir" proprement
      s = '$s ';
    }

    return s.trimRight();
  }
}
