import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProReservationsTourismePage extends StatefulWidget {
  const ProReservationsTourismePage({super.key});

  @override
  State<ProReservationsTourismePage> createState() =>
      _ProReservationsTourismePageState();
}

class _ProReservationsTourismePageState
    extends State<ProReservationsTourismePage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // rows + join lieux
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
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) throw 'Non authentifié';

      // Requête unique : reservations_tourisme + infos du lieu
      // ✅ on n'utilise QUE 'contact' (pas de "telephone"/"tel"/"phone")
      PostgrestFilterBuilder<dynamic> query = _sb
          .from('reservations_tourisme')
          .select('''
            *,
            lieux:lieu_id (
              id, nom, ville, contact, user_id
            )
          ''');

      // (Optionnel, recommandé) limiter aux lieux de l'utilisateur pro
      query = query.eq('lieux.user_id', uid);

      // Filtre de dates (visit_date)
      if (_range != null) {
        query = query
            .gte('visit_date', DateFormat('yyyy-MM-dd').format(_range!.start))
            .lte('visit_date', DateFormat('yyyy-MM-dd').format(_range!.end));
      }

      // Filtre de statut
      if (_status == 'actives') {
        query = query.neq('status', 'annule');
      } else if (_status == 'annulees') {
        query = query.eq('status', 'annule');
      }

      // Tri
      final rows = await query
          .order('visit_date', ascending: true)
          .order('arrival_time', ascending: true);

      final list = List<Map<String, dynamic>>.from(rows as List);

      // Recherche locale (nom/téléphone client + NOM LIEU + CONTACT LIEU)
      final q = _q.trim().toLowerCase();
      final filtered = q.isEmpty
          ? list
          : list.where((r) {
              final n = (r['client_nom'] ?? '').toString().toLowerCase();
              final p = (r['client_phone'] ?? '').toString().toLowerCase();
              final lieu = Map<String, dynamic>.from(r['lieux'] ?? {});
              final ln = (lieu['nom'] ?? '').toString().toLowerCase();
              final lc = (lieu['contact'] ?? '').toString().toLowerCase();
              return n.contains(q) || p.contains(q) || ln.contains(q) || lc.contains(q);
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
              Theme.of(ctx).colorScheme.copyWith(primary: const Color(0xFFDAA520)),
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

  Future<void> _call(String phone) async {
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fermer')),
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
      await _sb.from('reservations_tourisme').update({'status': 'annule'}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  String _dateLabel(Map<String, dynamic> r) {
    final d = DateTime.tryParse(r['visit_date']?.toString() ?? '');
    final t = (r['arrival_time'] ?? '').toString();
    if (d == null) return '—';
    return '${DateFormat('EEE d MMM', 'fr_FR').format(d)} • $t';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations — Tourisme'),
        backgroundColor: const Color(0xFFDAA520), // 🎨 couleur conservée
        foregroundColor: Colors.black,
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
                    hintText: 'Rechercher (nom client, téléphone, lieu, contact)',
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
                            ),
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

                                // Infos du lieu via jointure
                                final lieu = Map<String, dynamic>.from(r['lieux'] ?? {});
                                final lieuNom   = (lieu['nom'] ?? 'Lieu').toString();
                                final lieuVille = (lieu['ville'] ?? '').toString();
                                final lieuContact = (lieu['contact'] ?? '').toString();

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
                                                lieuNom,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: cancelled
                                                    ? Colors.red.withOpacity(.12)
                                                    : const Color(0xFFFFD700).withOpacity(.22),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                cancelled ? 'Annulée' : 'Confirmée',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: cancelled ? Colors.red : const Color(0xFFB8860B),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                        if (lieuVille.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(lieuVille, style: TextStyle(color: scheme.outline)),
                                        ],
                                        if (lieuContact.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _call(lieuContact),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.call, size: 18),
                                                const SizedBox(width: 6),
                                                Text(lieuContact),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(_dateLabel(r), style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.people_alt, size: 18),
                                            const SizedBox(width: 6),
                                            Text('Adultes ${r['adults']} • Enfants ${r['children']}'),
                                          ],
                                        ),
                                        if ((r['notes'] ?? '').toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            (r['notes'] ?? '').toString(),
                                            style: TextStyle(color: scheme.onSurface.withOpacity(.75)),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Container(height: 1, color: scheme.outlineVariant),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _call((r['client_phone'] ?? '').toString()),
                                                icon: const Icon(Icons.phone),
                                                label: Text((r['client_nom'] ?? 'Client').toString()),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            FilledButton.icon(
                                              onPressed: cancelled
                                                  ? null
                                                  : () => _cancelReservation((r['id'] ?? '').toString()),
                                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
