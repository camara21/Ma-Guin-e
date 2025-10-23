import 'package:intl/intl.dart';

/// --------- Nombre / monnaie (GNF) ---------

final NumberFormat _fmt = NumberFormat.decimalPattern('fr_FR');
final NumberFormat _compact = NumberFormat.compact(locale: 'fr_FR');

const String _placeholder = '—';

/// Ex.: 1 234 567 GNF (retourne '—' si null)
String gnf(num? v) => v == null ? _placeholder : '${_fmt.format(v)} GNF';

/// Ex.: 1,2 M GNF (retourne '—' si null)
String gnfCompact(num? v) =>
    v == null ? _placeholder : '${_compact.format(v)} GNF';

/// --------- Dates ---------

/// Ex.: 2024-10-05 (retourne '—' si null)
String dateYMD(DateTime? d) =>
    d == null ? _placeholder : DateFormat('yyyy-MM-dd', 'fr_FR').format(d);

/// Ex.: 05/10/2024 (retourne '—' si null)
String dateDMY(DateTime? d) =>
    d == null ? _placeholder : DateFormat('dd/MM/yyyy', 'fr_FR').format(d);

/// Convertit une valeur BDD (String ISO, Date, DateTime…) en DateTime local.
/// Renvoie null si non analysable.
DateTime? parseDbDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is String && v.isNotEmpty) {
    try {
      // Gère '2025-09-30' ou ISO '2025-09-30T12:00:00Z'
      return DateTime.parse(v).toLocal();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Formatte une valeur BDD (String/DateTime) en yyyy-MM-dd.
String dateYMDfromDb(dynamic v) => dateYMD(parseDbDate(v));

/// Ex.: "il y a 5 min" / "il y a 3 h" / "il y a 2 j" / "12/03/2024"
String relativeTime(DateTime? d) {
  if (d == null) return _placeholder;
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return dateDMY(d);
}
