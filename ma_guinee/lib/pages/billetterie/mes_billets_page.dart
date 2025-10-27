import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/billetterie_service.dart';

class MesBilletsPage extends StatefulWidget {
  const MesBilletsPage({super.key});

  @override
  State<MesBilletsPage> createState() => _MesBilletsPageState();
}

class _MesBilletsPageState extends State<MesBilletsPage> {
  final _svc = BilletterieService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
    try {
      final rows = await _svc.listMesReservations();
      setState(() => _items = rows);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Mes billets'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Aucune réservation.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = _items[i];

                        final ev = (r['evenements'] is Map)
                            ? Map<String, dynamic>.from(r['evenements'] as Map)
                            : null;
                        final bi = (r['billets'] is Map)
                            ? Map<String, dynamic>.from(r['billets'] as Map)
                            : null;

                        DateTime? date;
                        final rawDate = ev?['date_debut']?.toString();
                        if (rawDate != null && rawDate.isNotEmpty) {
                          date = DateTime.tryParse(rawDate);
                        }
                        final dateTxt = (date != null)
                            ? DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(date)
                            : '';

                        final statut = (r['statut'] ?? '').toString();

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.secondary.withOpacity(.12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // QR
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: cs.secondary.withOpacity(.2)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: QrImageView(
                                    data: (r['qr_token'] ?? '').toString(),
                                    size: 86,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Infos
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ev?['titre']?.toString() ?? 'Événement',
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${bi?['titre'] ?? 'Billet'} • x${r['quantite']}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${ev?['lieu'] ?? ''} • ${ev?['ville'] ?? ''}'),
                                      if (dateTxt.isNotEmpty) Text(dateTxt),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statut == 'utilise'
                                              ? Colors.green.withOpacity(.12)
                                              : statut == 'annule'
                                                  ? Colors.red.withOpacity(.12)
                                                  : cs.secondary.withOpacity(.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          statut.toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }
}
