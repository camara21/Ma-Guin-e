import 'package:intl/intl.dart';

/// --------- Nombre / monnaie (GNF) ---------

final NumberFormat _fmt     = NumberFormat.decimalPattern('fr_FR');
final NumberFormat _compact = NumberFormat.compact(locale: 'fr_FR');

/// 1 234 567 GNF (retourne '—' si null)
String gnf(num? v) => v == null ? '—' : '${_fmt.format(v)} GNF';

/// 1,2 M GNF (retourne '—' si null)
String gnfCompact(num? v) => v == null ? '—' : '${_compact.format(v)} GNF';

/// --------- Dates ---------

/// yyyy-MM-dd (retourne '—' si null)
String dateYMD(DateTime? d) =>
    d == null ? '—' : DateFormat('yyyy-MM-dd', 'fr_FR').format(d);

/// dd/MM/yyyy (retourne '—' si null)
String dateDMY(DateTime? d) =>
    d == null ? '—' : DateFormat('dd/MM/yyyy', 'fr_FR').format(d);

/// Convertit une valeur BDD (String ISO, Date, DateTime…) en DateTime local.
/// Renvoie null si non parseable.
DateTime? parseDbDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  if (v is String && v.isNotEmpty) {
    try {
      return DateTime.parse(v).toLocal(); // gère '2025-09-30' ou ISO '2025-09-30T12:00:00Z'
    } catch (_) {}
  }
  return null;
}

/// Formatte une valeur BDD (String/DateTime) en yyyy-MM-dd.
String dateYMDfromDb(dynamic v) => dateYMD(parseDbDate(v));

/// “il y a 5 min / 3 h / 2 j / 12/03/2024”
String relativeTime(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours   < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays    < 7)  return 'il y a ${diff.inDays} j';
  return dateDMY(d);
}
