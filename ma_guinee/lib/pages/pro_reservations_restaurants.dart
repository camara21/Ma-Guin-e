import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProReservationsRestaurantsPage extends StatefulWidget {
  const ProReservationsRestaurantsPage({super.key});

  @override
  State<ProReservationsRestaurantsPage> createState() =>
      _ProReservationsRestaurantsPageState();
}

class _ProReservationsRestaurantsPageState
    extends State<ProReservationsRestaurantsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // data
  List<Map<String, dynamic>> _reservations = [];

  // ui filters
  String _q = '';
  String _status = 'actives'; // actives | annulees | toutes
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Base query: reservations + join restaurants
      PostgrestFilterBuilder<dynamic> query = _sb
          .from('reservations_restaurants')
          .select('''
            *,
            restaurants:restaurant_id (
              id, nom, ville, tel, telephone
            )
          ''');

      // Filtre date (sur res_date)
      if (_range != null) {
        query = query
            .gte('res_date', DateFormat('yyyy-MM-dd').format(_range!.start))
            .lte('res_date', DateFormat('yyyy-MM-dd').format(_range!.end));
      }

      // Filtre statut
      if (_status == 'actives') {
        query = query.neq('status', 'annule');
      } else if (_status == 'annulees') {
        query = query.eq('status', 'annule');
      }

      // Tri & exécution
      final rows = await query
          .order('res_date', ascending: true)
          .order('res_time', ascending: true);

      final list = List<Map<String, dynamic>>.from(rows as List);

      // Recherche locale (nom / téléphone client)
      final q = _q.trim().toLowerCase();
      final filtered = q.isEmpty
          ? list
          : list.where((r) {
              final n = (r['client_nom'] ?? '').toString().toLowerCase();
              final p = (r['client_phone'] ?? '').toString().toLowerCase();
              return n.contains(q) || p.contains(q);
            }).toList();

      if (!mounted) return;
      setState(() {
        _reservations = filtered;
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 30)),
          ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: const Color(0xFFE76F51)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _range = picked);
      await _loadAll();
    }
  }

  Future<void> _clearRange() async {
    setState(() => _range = null);
    await _loadAll();
  }

  Future<void> _callClient(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _cancelReservation(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text('Cette action marque la réservation comme “annulée”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _sb
          .from('reservations_restaurants')
          .update({'status': 'annule'}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation annulée.')),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  String _dateLabel(Map<String, dynamic> r) {
    final d = DateTime.tryParse(r['res_date']?.toString() ?? '');
    final t = (r['res_time'] ?? '').toString();
    if (d == null) return '—';
    return '${DateFormat('EEE d MMM', 'fr_FR').format(d)} • $t';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations — Restaurants'),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barre filtres
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            color: scheme.surface,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Rechercher (nom ou téléphone client)',
                    filled: true,
                    fillColor: scheme.surfaceVariant.withOpacity(.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) async {
                    setState(() => _q = v);
                    await _loadAll();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'actives', label: Text('Actives')),
                        ButtonSegment(value: 'annulees', label: Text('Annulées')),
                        ButtonSegment(value: 'toutes', label: Text('Toutes')),
                      ],
                      selected: {_status},
                      onSelectionChanged: (s) async {
                        setState(() => _status = s.first);
                        await _loadAll();
                      },
                    ),
                    const Spacer(),
                    if (_range != null)
                      TextButton.icon(
                        onPressed: _clearRange,
                        icon: const Icon(Icons.clear),
                        label: const Text('Dates'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.event),
                      label: Text(_range == null ? 'Dates' : 'Changer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_error!),
                            )
                          ],
                        )
                      : _reservations.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('Aucune réservation.')),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemBuilder: (_, i) {
                                final r = _reservations[i];

                                // données du resto via la jointure
                                final resto =
                                    Map<String, dynamic>.from(r['restaurants'] ?? {});

                                final status = (r['status'] ?? '').toString();
                                final cancelled = status == 'annule';

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: scheme.outlineVariant),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                (resto['nom'] ?? 'Restaurant').toString(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: cancelled
                                                    ? Colors.red.withOpacity(.12)
                                                    : const Color(0xFFF4A261)
                                                        .withOpacity(.18),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                cancelled ? 'Annulée' : 'Confirmée',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: cancelled
                                                      ? Colors.red
                                                      : const Color(0xFFE67E22),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                        if ((resto['ville'] ?? '').toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              (resto['ville']).toString(),
                                              style:
                                                  TextStyle(color: scheme.outline),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _dateLabel(r),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.people_alt, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Adultes ${r['adults']} • '
                                              'Enfants ${r['children']} • '
                                              '${r['seating_pref']}',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.celebration, size: 18),
                                            const SizedBox(width: 6),
                                            Text('Occasion : ${r['occasion']}'),
                                          ],
                                        ),
                                        if ((r['notes'] ?? '').toString().trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              (r['notes'] ?? '').toString(),
                                              style: TextStyle(
                                                color: scheme.onSurface
                                                    .withOpacity(.75),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        Container(height: 1, color: scheme.outlineVariant),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _callClient(
                                                  (r['client_phone'] ?? '').toString(),
                                                ),
                                                icon: const Icon(Icons.phone),
                                                label: Text(
                                                  (r['client_nom'] ?? 'Client')
                                                      .toString(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            FilledButton.icon(
                                              onPressed: cancelled
                                                  ? null
                                                  : () => _cancelReservation(
                                                      (r['id'] ?? '').toString()),
                                              style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.red),
                                              icon: const Icon(Icons.cancel),
                                              label: const Text('Annuler'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemCount: _reservations.length,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
