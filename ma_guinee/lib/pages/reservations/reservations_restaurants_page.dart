import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../resto_detail_page.dart';

const kRestoPrimary = Color(0xFFE76F51);
const kOnPrimary    = Colors.white;

class ReservationsRestaurantsPage extends StatefulWidget {
  const ReservationsRestaurantsPage({super.key});

  @override
  State<ReservationsRestaurantsPage> createState() => _ReservationsRestaurantsPageState();
}

class _ReservationsRestaurantsPageState extends State<ReservationsRestaurantsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Données
  List<Map<String, dynamic>> _items = [];

  // Filtres UI (par défaut: À venir) -> avenir | passees | annulees
  String _scope = 'avenir';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Strings AAAA-MM-JJ et HH:MM:SS
  String _yMd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _hms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

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
      // Cutoff = maintenant - 3h
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 3));
      final cutDateStr = _yMd(cutoff);
      final cutTimeStr = _hms(TimeOfDay(hour: cutoff.hour, minute: cutoff.minute));

      PostgrestFilterBuilder<dynamic> q = _sb
          .from('v_reservations_restaurants_admin')
          .select()
          .eq('user_id', uid);

      if (_scope == 'annulees') {
        q = q.eq('status', 'annule');
      } else if (_scope == 'passees') {
        // Non annulées ET avant cutoff (date < cutDate OU (date = cutDate ET time < cutTime))
        q = q
            .neq('status', 'annule')
            .or('res_date.lt.$cutDateStr,and(res_date.eq.$cutDateStr,res_time.lt.$cutTimeStr)');
      } else {
        // avenir : Non annulées ET après/égal cutoff
        q = q
            .neq('status', 'annule')
            .or('res_date.gt.$cutDateStr,and(res_date.eq.$cutDateStr,res_time.gte.$cutTimeStr)');
      }

      // Tri : Passées -> décroissant (plus récentes d’abord), sinon croissant
      final bool desc = (_scope == 'passees');
      final rows = await q
          .order('res_date', ascending: !desc)
          .order('res_time', ascending: !desc);

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
      await _sb.from('reservations_restaurants').update({'status': 'annule'}).eq('id', id);
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
    final id = (r['restaurant_id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => RestoDetailPage(restoId: id)));
  }

  String _dateTimeLabel(Map<String, dynamic> r) {
    final dStr = (r['res_date'] ?? '').toString();
    final tStr = (r['res_time'] ?? '').toString();
    return '$dStr • $tStr';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations — Restaurants'),
        backgroundColor: kRestoPrimary,
        foregroundColor: kOnPrimary,
        iconTheme: const IconThemeData(color: kOnPrimary),
        actionsIconTheme: const IconThemeData(color: kOnPrimary),
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
                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: kRestoPrimary),
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
                  icon: const Icon(Icons.refresh, color: kRestoPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kRestoPrimary))
                : RefreshIndicator(
                    color: kRestoPrimary,
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
                                  final titre = (r['restaurant_nom'] ?? 'Restaurant').toString();
                                  final ville = (r['restaurant_ville'] ?? '').toString();
                                  final dt = _dateTimeLabel(r);
                                  final cancelled = (r['status']?.toString() == 'annule');

                                  final String? badgeText = cancelled
                                      ? 'Annulée'
                                      : (_scope == 'passees' ? 'Passée' : null);

                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.restaurant, color: kRestoPrimary),
                                      title: Text(titre),
                                      subtitle: Text("${ville.isNotEmpty ? '$ville • ' : ''}$dt"),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (badgeText != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: cancelled ? Colors.red.withOpacity(.12) : Colors.black12,
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
                                              if (v == 'cancel' && !cancelled) {
                                                final id = (r['id'] ?? '').toString();
                                                if (id.isNotEmpty) _annuler(id);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'open',
                                                child: Text('Voir le restaurant'),
                                              ),
                                              PopupMenuItem(
                                                value: 'cancel',
                                                enabled: !cancelled,
                                                child: const Text('Annuler'),
                                              ),
                                            ],
                                          ),
                                        ],
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
