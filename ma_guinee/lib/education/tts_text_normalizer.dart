// lib/education/tts_text_normalizer.dart
//
// Normalisation FR pour améliorer la prononciation TTS.
// Objectifs:
// - chiffres isolés => lecture plus naturelle
// - dates / années / pourcentages / unités => plus clair
// - symboles & ponctuation => pauses naturelles
// - éviter la lecture "1 slash 2" ou "10 000" bizarre

class TtsTextNormalizer {
  static String normalizeFr(String input) {
    var s = input.trim();

    // espaces propres
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    // ponctuation: mettre des pauses
    s = s
        .replaceAll('?', ' ? ')
        .replaceAll('!', ' ! ')
        .replaceAll(':', ' : ')
        .replaceAll(';', ' ; ')
        .replaceAll(',', ' , ')
        .replaceAll('.', ' . ');

    // symboles courants
    s = s
        .replaceAll('%', ' pour cent')
        .replaceAll('€', ' euros')
        .replaceAll('\$', ' dollars')
        .replaceAll('&', ' et ')
        .replaceAll('@', ' arobase ')
        .replaceAll('=', ' égale ')
        .replaceAll('+', ' plus ')
        .replaceAll('–', '-') // tiret long
        .replaceAll('—', '-');

    // fractions simples (1/2, 1/4, 3/4)
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*2\b'), (_) => ' un demi ');
    s = s.replaceAllMapped(RegExp(r'\b1\s*/\s*4\b'), (_) => ' un quart ');
    s = s.replaceAllMapped(RegExp(r'\b3\s*/\s*4\b'), (_) => ' trois quarts ');

    // 2e / 3e / 1er => "deuxième / troisième / premier"
    s = s.replaceAllMapped(
        RegExp(r'\b1er\b', caseSensitive: false), (_) => ' premier ');
    s = s.replaceAllMapped(RegExp(r'\b(\d+)\s*e\b', caseSensitive: false), (m) {
      final n = m.group(1)!;
      return ' $n ème ';
    });

    // Années (ex: 1958) => "dix-neuf cent cinquante-huit" souvent mieux
    // Ici, on force une pause: "année 1958" peut aider.
    // On ne convertit pas en lettres (trop long), mais on ajoute un contexte.
    s = s.replaceAllMapped(RegExp(r'\b(19\d{2}|20\d{2})\b'), (m) {
      return ' année ${m.group(1)} ';
    });

    // Séparateurs de milliers (10 000 / 10,000) => "10 000"
    s = s.replaceAllMapped(RegExp(r'\b(\d{1,3})([ ,]\d{3})+\b'), (m) {
      // normalise en espace
      final txt = m.group(0)!.replaceAll(',', ' ');
      return ' $txt ';
    });

    // Décimales françaises "3,5" => "3 virgule 5"
    s = s.replaceAllMapped(RegExp(r'\b(\d+),(\d+)\b'), (m) {
      return ' ${m.group(1)} virgule ${m.group(2)} ';
    });

    // slash dans expressions (ex: km/h)
    s = s.replaceAllMapped(RegExp(r'\bkm\s*/\s*h\b', caseSensitive: false),
        (_) => ' kilomètres par heure ');

    // Nettoyage final des espaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Rendre la lecture plus "naturelle": finir par un point si pas de ponctuation finale
    if (!s.endsWith('.') && !s.endsWith('?') && !s.endsWith('!')) {
      s = '$s.';
    }

    return s;
  }
}
