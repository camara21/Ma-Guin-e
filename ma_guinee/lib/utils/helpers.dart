import 'package:intl/intl.dart';

class Helpers {
  /// 🗓 Formattage simple de date
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// ⏱ Formattage avec heure
  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  /// ✂️ Raccourcir un texte trop long
  static String truncate(String text, {int max = 50}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  /// 📍 Distance lisible
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }
}
