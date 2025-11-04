import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../hotel_detail_page.dart';

const kHotelsPrimary = Color(0xFF264653);
const kOnPrimary     = Colors.white;

class ReservationsHotelsPage extends StatefulWidget {
  const ReservationsHotelsPage({super.key});

  @override
  State<ReservationsHotelsPage> createState() => _ReservationsHotelsPageState();
}

class _ReservationsHotelsPageState extends State<ReservationsHotelsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Données
  List<Map<String, dynamic>> _items = [];

  // Filtres: avenir | passees | annulees  (par défaut: avenir)
  String _scope = 'avenir';

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      // AAAA-MM-JJ pour comparaisons SQL
      final today = DateTime.now();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      PostgrestFilterBuilder<dynamic> q = _sb
          .from('v_reservations_hotels_admin')
          .select()
          .eq('user_id', uid);

      if (_scope == 'annulees') {
        q = q.eq('status', 'annule');
      } else if (_scope == 'passees') {
        // Séjours terminés (non annulés)
        q = q.neq('status', 'annule').lt('check_out', todayStr);
      } else {
        // _scope == 'avenir' : Séjours à venir ou en cours (non annulés)
        q = q.neq('status', 'annule').gte('check_out', todayStr);
      }

      final bool desc = (_scope == 'passees'); // passées: plus récentes en premier
      final rows = await q
          .order('check_in', ascending: !desc)
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
      await _sb.from('reservations_hotels').update({'status': 'annule'}).eq('id', id);
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
    final id = (r['hotel_id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDetailPage(hotelId: id)));
  }

  // ---------- Helpers affichage ----------
  bool _isCancelled(Map<String, dynamic> r) =>
      (r['status']?.toString() == 'annule');

  bool _isPast(Map<String, dynamic> r) {
    // Si le scope dit déjà "passees", on peut s'y fier, sinon on vérifie en local.
    if (_scope == 'passees') return true;
    try {
      final co = (r['check_out'] ?? '').toString(); // format AAAA-MM-JJ attendu
      if (co.isEmpty) return false;
      final parsed = DateTime.tryParse(co);
      if (parsed == null) return false;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final outDate = DateTime(parsed.year, parsed.month, parsed.day);
      return !_isCancelled(r) && outDate.isBefore(todayDate);
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
        title: const Text('Mes réservations — Hôtels'),
        backgroundColor: kHotelsPrimary,
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
                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: kHotelsPrimary),
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
                  icon: const Icon(Icons.refresh, color: kHotelsPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kHotelsPrimary))
                : RefreshIndicator(
                    color: kHotelsPrimary,
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
                                  final titre = (r['hotel_nom'] ?? 'Hôtel').toString();
                                  final ville = (r['hotel_ville'] ?? '').toString();
                                  final dates =
                                      "${r['check_in'] ?? ''} → ${r['check_out'] ?? ''}"
                                      "${(r['arrival_time'] ?? '').toString().isNotEmpty ? " | ${r['arrival_time']}" : ""}";

                                  final cancelled = _isCancelled(r);
                                  final past = _isPast(r);
                                  final greyOut = cancelled || past;

                                  final String? badgeText = _badgeText(r);

                                  // Popup menu: on masque "Annuler" hors onglet 'avenir'
                                  final bool canCancelHere = (_scope == 'avenir') && !cancelled;

                                  return Opacity(
                                    opacity: greyOut ? 0.55 : 1.0, // griser passées/annulées
                                    child: Card(
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.hotel,
                                          color: greyOut ? Colors.grey : kHotelsPrimary,
                                        ),
                                        title: Text(
                                          titre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: greyOut ? Colors.grey.shade800 : null,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "${ville.isNotEmpty ? '$ville • ' : ''}$dates",
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
                                                    child: Text('Voir l’hôtel'),
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
