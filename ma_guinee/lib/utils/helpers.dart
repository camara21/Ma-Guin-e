import 'package:intl/intl.dart';

class Helpers {
  /// Formatage simple de date (ex: 22/10/2025)
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  /// Formatage avec heure (ex: 22/10/2025 à 14:35)
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
  }

  /// Raccourcir un texte trop long
  static String truncate(String text, {int max = 50}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
    // Astuce : si tu veux éviter de couper un mot,
    // cherche le dernier espace avant "max" et coupe là.
  }

  /// Distance lisible (mètres < 1000, sinon km avec 1 décimale)
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      final km = distanceMeters / 1000.0;
      // Utilise la virgule en français (ex: 1,5 km)
      final nf = NumberFormat('#,##0.0', 'fr_FR');
      return '${nf.format(km)} km';
    }
  }
}
