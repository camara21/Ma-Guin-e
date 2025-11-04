import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

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
  String _status = 'avenir'; // ✅ avenir | passees | annulees
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ------- Helpers datetime & status
  DateTime _rowDateTime(Map<String, dynamic> r) {
    // visit_date 'YYYY-MM-DD', arrival_time 'HH:mm' | 'HH:mm:ss'
    final dStr = (r['visit_date'] ?? '').toString();
    final tStr = (r['arrival_time'] ?? '00:00:00').toString();
    DateTime d;
    try {
      d = DateTime.parse(dStr);
    } catch (_) {
      d = DateTime.now();
    }
    final parts = tStr.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(d.year, d.month, d.day, h, m, s);
  }

  bool _isCancelled(Map<String, dynamic> r) =>
      (r['status'] ?? '').toString() == 'annule';

  bool _isPast(Map<String, dynamic> r) {
    final now = DateTime.now();
    // Pour le tourisme, la résa est "passée" si l'horaire de visite est écoulé
    return !_rowDateTime(r).isAfter(now);
  }

  // ------- Data
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) throw 'Non authentifié';

      PostgrestFilterBuilder<dynamic> query = _sb
          .from('reservations_tourisme')
          .select('''
            *,
            lieux:lieu_id (
              id, nom, ville, contact, user_id
            )
          ''');

      // limiter aux lieux de l'utilisateur pro (RLS recommandé)
      query = query.eq('lieux.user_id', uid);

      // Filtre dates (sur visit_date)
      if (_range != null) {
        query = query
            .gte('visit_date', DateFormat('yyyy-MM-dd').format(_range!.start))
            .lte('visit_date', DateFormat('yyyy-MM-dd').format(_range!.end));
      }

      // Récup brute (on filtre avenir/passees côté client)
      final rows = await query
          .order('visit_date', ascending: true)
          .order('arrival_time', ascending: true);

      var list = List<Map<String, dynamic>>.from(rows as List);

      // Recherche locale (client + lieu)
      final q = _q.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((r) {
          final n = (r['client_nom'] ?? '').toString().toLowerCase();
          final p = (r['client_phone'] ?? '').toString().toLowerCase();
          final lieu = Map<String, dynamic>.from(r['lieux'] ?? {});
          final ln = (lieu['nom'] ?? '').toString().toLowerCase();
          final lc = (lieu['contact'] ?? '').toString().toLowerCase();
          return n.contains(q) || p.contains(q) || ln.contains(q) || lc.contains(q);
        }).toList();
      }

      // Avenir / Passées / Annulées + tri
      final now = DateTime.now();
      if (_status == 'avenir') {
        list = list
            .where((r) => !_isCancelled(r) && _rowDateTime(r).isAfter(now))
            .toList()
          ..sort((a, b) => _rowDateTime(a).compareTo(_rowDateTime(b))); // ↑
      } else if (_status == 'passees') {
        list = list
            .where((r) => !_isCancelled(r) && !_rowDateTime(r).isAfter(now))
            .toList()
          ..sort((a, b) => _rowDateTime(b).compareTo(_rowDateTime(a))); // ↓
      } else if (_status == 'annulees') {
        list = list.where(_isCancelled).toList()
          ..sort((a, b) => _rowDateTime(b).compareTo(_rowDateTime(a))); // ↓
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

  // ------- UI helpers
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

  Future<void> _launchCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showContactDialog(String title, String phone) async {
    final number = phone.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro indisponible.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title.isEmpty ? 'Contacter' : 'Contacter — $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
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
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Numéro copié.')));
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

  // ------- UI
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations — Tourisme'),
        backgroundColor: const Color(0xFFDAA520),
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
                        ButtonSegment(value: 'avenir', label: Text('À venir')),   // ✅
                        ButtonSegment(value: 'passees', label: Text('Passées')),   // ✅
                        ButtonSegment(value: 'annulees', label: Text('Annulées')), // ✅
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
                                final lieuNom     = (lieu['nom'] ?? 'Lieu').toString();
                                final lieuVille   = (lieu['ville'] ?? '').toString();
                                final lieuContact = (lieu['contact'] ?? '').toString();

                                final cancelled = _isCancelled(r);
                                final isPast = _isPast(r);

                                // Chip (texte + couleurs)
                                final String chipText = cancelled
                                    ? 'Annulée'
                                    : (isPast ? 'Passée' : 'Confirmée');
                                final Color chipFg = cancelled
                                    ? Colors.red
                                    : (isPast ? Colors.grey.shade700 : const Color(0xFFB8860B));
                                final Color chipBg = cancelled
                                    ? Colors.red.withOpacity(.12)
                                    : (isPast
                                        ? Colors.grey.withOpacity(.15)
                                        : const Color(0xFFFFD700).withOpacity(.22));

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
                                                color: chipBg,
                                                borderRadius: BorderRadius.circular(999),
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
                                        if (lieuVille.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(lieuVille, style: TextStyle(color: scheme.outline)),
                                        ],
                                        if (lieuContact.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _showContactDialog(lieuNom, lieuContact),
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
                                                onPressed: () => _showContactDialog(
                                                  (r['client_nom'] ?? 'Client').toString(),
                                                  (r['client_phone'] ?? '').toString(),
                                                ),
                                                icon: const Icon(Icons.phone),
                                                label: Text((r['client_nom'] ?? 'Client').toString()),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (!cancelled && !isPast) // ✅ caché si passée/annulée
                                              FilledButton.icon(
                                                onPressed: () => _cancelReservation((r['id'] ?? '').toString()),
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
