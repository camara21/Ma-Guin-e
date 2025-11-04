import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

class ProReservationsHotelsPage extends StatefulWidget {
  const ProReservationsHotelsPage({super.key});

  @override
  State<ProReservationsHotelsPage> createState() =>
      _ProReservationsHotelsPageState();
}

class _ProReservationsHotelsPageState extends State<ProReservationsHotelsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // data
  List<Map<String, dynamic>> _reservations = []; // rows + join hotels

  // ui filters
  String _q = '';
  String _status = 'avenir'; // ✅ avenir | passees | annulees
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ---------------- Helpers Date/Time & Statuts ----------------
  DateTime _rowStart(Map<String, dynamic> r) =>
      DateTime.tryParse((r['check_in'] ?? '').toString()) ?? DateTime(1970);

  DateTime _rowEnd(Map<String, dynamic> r) =>
      (DateTime.tryParse((r['check_out'] ?? '').toString()) ?? DateTime(1970))
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));

  bool _isCancelled(Map<String, dynamic> r) =>
      (r['status'] ?? '').toString() == 'annule';

  bool _isPast(Map<String, dynamic> r) {
    final now = DateTime.now();
    return !_rowEnd(r).isAfter(now); // passé si check_out < now (fin de journée)
  }

  // ---------------- Data loading ----------------
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      PostgrestFilterBuilder<dynamic> query = _sb
          .from('reservations_hotels')
          .select('''
            *,
            hotels:hotel_id (
              id, nom, ville, tel, telephone
            )
          ''');

      // Filtre de dates (optionnel)
      if (_range != null) {
        query = query
            .gte('check_in', DateFormat('yyyy-MM-dd').format(_range!.start))
            .lte('check_out', DateFormat('yyyy-MM-dd').format(_range!.end));
      }

      // On récupère tout puis on applique les onglets côté client
      final rows = await query
          .order('check_in', ascending: true)
          .order('arrival_time', ascending: true);

      var list = List<Map<String, dynamic>>.from(rows as List);

      // Recherche locale (nom/téléphone client)
      final q = _q.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((r) {
          final n = (r['client_nom'] ?? '').toString().toLowerCase();
          final p = (r['client_phone'] ?? '').toString().toLowerCase();
          return n.contains(q) || p.contains(q);
        }).toList();
      }

      // --------- TRIS & FILTRES PAR ONGLET ----------
      // Avenir = non annulée & _rowEnd > now (inclut séjours en cours)
      // Passées = non annulée & _rowEnd <= now
      // Annulées = status = annule
      final now = DateTime.now();

      if (_status == 'avenir') {
        list = list
            .where((r) => !_isCancelled(r) && _rowEnd(r).isAfter(now))
            .toList()
          ..sort((a, b) => _rowStart(a).compareTo(_rowStart(b))); // ↑ par check_in
      } else if (_status == 'passees') {
        list = list
            .where((r) => !_isCancelled(r) && !_rowEnd(r).isAfter(now))
            .toList()
          ..sort((a, b) => _rowStart(b).compareTo(_rowStart(a))); // ↓ par check_in
      } else if (_status == 'annulees') {
        list = list.where(_isCancelled).toList()
          ..sort((a, b) => _rowStart(b).compareTo(_rowStart(a))); // ↓ par check_in
      }

      if (!mounted) return;
      setState(() {
        _reservations = list;
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

  // ---------------- UI helpers ----------------
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
              Theme.of(ctx).colorScheme.copyWith(primary: const Color(0xFF264653)),
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

  Future<void> _launchCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showContactDialog(String clientName, String phone) async {
    final number = phone.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro indisponible pour ce client.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacter le client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(number, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              'Vous pouvez copier le numéro pour appeler depuis un autre téléphone.',
              style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Numéro copié.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _launchCall(number);
            },
            icon: const Icon(Icons.phone),
            label: const Text('Appeler maintenant'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
              child: const Text('Fermer')),
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
          .from('reservations_hotels')
          .update({'status': 'annule'}).eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  String _dateSpan(Map<String, dynamic> r) {
    final ci = DateTime.tryParse(r['check_in']?.toString() ?? '');
    final co = DateTime.tryParse(r['check_out']?.toString() ?? '');
    final at = (r['arrival_time'] ?? '').toString();
    if (ci == null || co == null) return '—';
    final fmt = DateFormat('dd/MM');
    return '${fmt.format(ci)} → ${fmt.format(co)}  •  Arrivée $at';
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations — Hôtels'),
        backgroundColor: const Color(0xFF264653),
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
                        ButtonSegment(value: 'avenir', label: Text('À venir')),
                        ButtonSegment(value: 'passees', label: Text('Passées')),
                        ButtonSegment(value: 'annulees', label: Text('Annulées')),
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

                                // infos hôtel via jointure
                                final h =
                                    Map<String, dynamic>.from(r['hotels'] ?? {});
                                final hotelName =
                                    (h['nom'] ?? 'Hôtel').toString();
                                final hotelVille =
                                    (h['ville'] ?? '').toString();

                                final cancelled = _isCancelled(r);
                                final isPast = _isPast(r);

                                // Chip (texte + couleurs)
                                final String chipText = cancelled
                                    ? 'Annulée'
                                    : (isPast ? 'Passée' : 'Confirmée');
                                final Color chipFg = cancelled
                                    ? Colors.red
                                    : (isPast
                                        ? Colors.grey.shade700
                                        : const Color(0xFF2A9D8F));
                                final Color chipBg = cancelled
                                    ? Colors.red.withOpacity(.12)
                                    : (isPast
                                        ? Colors.grey.withOpacity(.15)
                                        : const Color(0xFF2A9D8F)
                                            .withOpacity(.12));

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: scheme.outlineVariant),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                hotelName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: chipBg,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                chipText,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: chipFg,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                        if (hotelVille.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(hotelVille,
                                              style: TextStyle(
                                                  color: scheme.outline)),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(_dateSpan(r),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.people_alt,
                                                size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                                'Chambres ${r['rooms']} • Adultes ${r['adults']} • Enfants ${r['children']}'),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.bed, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                                '${r['bed_pref']} • ${r['smoking_pref']}'),
                                          ],
                                        ),
                                        if ((r['notes'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            (r['notes'] ?? '').toString(),
                                            style: TextStyle(
                                                color: scheme.onSurface
                                                    .withOpacity(.75)),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Container(
                                            height: 1,
                                            color: scheme.outlineVariant),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showContactDialog(
                                                  (r['client_nom'] ??
                                                          'Client')
                                                      .toString(),
                                                  (r['client_phone'] ?? '')
                                                      .toString(),
                                                ),
                                                icon: const Icon(Icons.phone),
                                                label: Text(
                                                    (r['client_nom'] ??
                                                            'Client')
                                                        .toString()),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (!cancelled && !isPast) // ✅ caché si passée/annulée
                                              FilledButton.icon(
                                                onPressed: () =>
                                                    _cancelReservation(
                                                        (r['id'] ?? '')
                                                            .toString()),
                                                style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.red),
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemCount: _reservations.length,
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
