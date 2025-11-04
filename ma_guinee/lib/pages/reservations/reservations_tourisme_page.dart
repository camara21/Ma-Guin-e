import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tourisme_detail_page.dart';

const kTourismePrimary = Color(0xFFDAA520);
const kOnPrimaryDark   = Colors.black;

class ReservationsTourismePage extends StatefulWidget {
  const ReservationsTourismePage({super.key});

  @override
  State<ReservationsTourismePage> createState() => _ReservationsTourismePageState();
}

class _ReservationsTourismePageState extends State<ReservationsTourismePage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Données
  List<Map<String, dynamic>> _items = [];

  // Filtres: avenir | passees | annulees (défaut: avenir)
  String _scope = 'avenir';

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _yMd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _hms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    try {
      // Cutoff = maintenant - 4h
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 4));
      final cutDateStr = _yMd(cutoff);
      final cutTimeStr = _hms(TimeOfDay(hour: cutoff.hour, minute: cutoff.minute));

      PostgrestFilterBuilder<dynamic> q = _sb
          .from('v_reservations_tourisme_admin')
          .select()
          .eq('user_id', uid);

      if (_scope == 'annulees') {
        q = q.eq('status', 'annule');
      } else if (_scope == 'passees') {
        // Non annulées ET avant cutoff
        q = q
            .neq('status', 'annule')
            .or('visit_date.lt.$cutDateStr,and(visit_date.eq.$cutDateStr,arrival_time.lt.$cutTimeStr)');
      } else {
        // À venir : Non annulées ET après/égal cutoff
        q = q
            .neq('status', 'annule')
            .or('visit_date.gt.$cutDateStr,and(visit_date.eq.$cutDateStr,arrival_time.gte.$cutTimeStr)');
      }

      final bool desc = (_scope == 'passees'); // Passées : plus récentes d’abord
      final rows = await q
          .order('visit_date', ascending: !desc)
          .order('arrival_time', ascending: !desc);

      setState(() {
        _items = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _annuler(String id) async {
    final ok = await _confirm();
    if (!ok) return;
    try {
      await _sb.from('reservations_tourisme').update({'status': 'annule'}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation annulée.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<bool> _confirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Annuler la réservation ?'),
            content: const Text('Cette action met le statut à "annule".'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
            ],
          ),
        ) ??
        false;
  }

  void _openLieu(Map<String, dynamic> r) {
    final lieu = {
      'id': r['lieu_id'],
      'nom': r['lieu_nom'],
      'ville': r['lieu_ville'],
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => TourismeDetailPage(lieu: lieu)));
  }

  // ---------- Helpers affichage ----------
  bool _isCancelled(Map<String, dynamic> r) =>
      (r['status']?.toString() == 'annule');

  bool _isPast(Map<String, dynamic> r) {
    if (_scope == 'passees') return true;       // déjà filtré SQL
    if (_scope == 'avenir') return false;       // déjà filtré SQL
    try {
      final vd = (r['visit_date'] ?? '').toString();
      final at = (r['arrival_time'] ?? '').toString(); // "HH:MM:SS" ou "HH:MM"
      if (vd.isEmpty || at.isEmpty) return false;
      final parts = at.split(':');
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      final date = DateTime.tryParse(vd);
      if (date == null) return false;
      final dt = DateTime(date.year, date.month, date.day, hh, mm);
      final cutoff = DateTime.now().subtract(const Duration(hours: 4));
      return !_isCancelled(r) && dt.isBefore(cutoff);
    } catch (_) {
      return false;
    }
  }

  String? _badgeText(Map<String, dynamic> r) {
    if (_isCancelled(r)) return 'Annulée';
    if (_isPast(r)) return 'Passée';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations — Tourisme'),
        backgroundColor: kTourismePrimary,
        foregroundColor: kOnPrimaryDark,
        iconTheme: const IconThemeData(color: kOnPrimaryDark),
        actionsIconTheme: const IconThemeData(color: kOnPrimaryDark),
      ),
      body: Column(
        children: [
          // Onglets filtres (3 onglets)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: kTourismePrimary),
                  ),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'avenir',   label: Text('À venir')),
                      ButtonSegment(value: 'passees',  label: Text('Passées')),
                      ButtonSegment(value: 'annulees', label: Text('Annulées')),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) {
                      setState(() => _scope = s.first);
                      _load();
                    },
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: kTourismePrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kTourismePrimary))
                : RefreshIndicator(
                    color: kTourismePrimary,
                    onRefresh: _load,
                    child: _error != null
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_error!, style: TextStyle(color: scheme.error)),
                              ),
                            ],
                          )
                        : _items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('Aucune réservation.')),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final r = _items[i];
                                  final titre = (r['lieu_nom'] ?? 'Lieu').toString();
                                  final ville = (r['lieu_ville'] ?? '').toString();
                                  final dt = "${r['visit_date'] ?? ''} • ${r['arrival_time'] ?? ''}";

                                  final cancelled = _isCancelled(r);
                                  final past = _isPast(r);
                                  final greyOut = cancelled || past;

                                  final String? badgeText = _badgeText(r);

                                  // Menu: masquer "Annuler" hors onglet 'avenir'
                                  final bool canCancelHere = (_scope == 'avenir') && !cancelled;

                                  return Opacity(
                                    opacity: greyOut ? 0.55 : 1.0, // griser passées/annulées
                                    child: Card(
                                      child: ListTile(
                                        onTap: () => _openLieu(r),
                                        leading: Icon(
                                          Icons.place,
                                          color: greyOut ? Colors.grey : kTourismePrimary,
                                        ),
                                        title: Text(
                                          titre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: greyOut ? Colors.grey.shade800 : null,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "${ville.isNotEmpty ? '$ville • ' : ''}$dt",
                                          style: TextStyle(
                                            color: greyOut ? Colors.grey.shade700 : null,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (badgeText != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: cancelled
                                                      ? Colors.red.withOpacity(.12)
                                                      : Colors.black12,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    color: cancelled ? Colors.red.shade700 : Colors.black87,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 6),
                                            PopupMenuButton<String>(
                                              onSelected: (v) {
                                                if (v == 'open') _openLieu(r);
                                                if (v == 'cancel' && canCancelHere) {
                                                  final id = (r['id'] ?? '').toString();
                                                  if (id.isNotEmpty) _annuler(id);
                                                }
                                              },
                                              itemBuilder: (_) {
                                                final items = <PopupMenuEntry<String>>[
                                                  const PopupMenuItem(
                                                    value: 'open',
                                                    child: Text('Voir le lieu'),
                                                  ),
                                                ];
                                                if (canCancelHere) {
                                                  items.add(
                                                    const PopupMenuItem(
                                                      value: 'cancel',
                                                      child: Text('Annuler'),
                                                    ),
                                                  );
                                                }
                                                return items;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
          ),
        ],
      ),
    );
  }
}
