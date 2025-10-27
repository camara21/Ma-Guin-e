// lib/pages/billetterie/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/billetterie_service.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _svc = BilletterieService();
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _billets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ev = await _svc.getEvenement(widget.eventId);
      final bi = await _svc.listBilletsByEvent(widget.eventId);
      setState(() { _event = ev; _billets = bi; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reserver(String billetId) async {
    final cs = Theme.of(context).colorScheme;
    int qty = 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Choisir la quantité',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setSt(() => qty = (qty > 1 ? qty - 1 : 1)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: () => setSt(() => qty += 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx); // fermer le sheet
                      try {
                        final id = await _svc.reserverBillet(billetId: billetId, quantite: qty);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Réservation confirmée (#$id)')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    },
                    child: const Text('Réserver'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Détail de l’événement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _event == null
                  ? const Center(child: Text('Événement introuvable'))
                  : _buildContent(),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    final e = _event!;
    final imageUrl = _svc.publicImageUrl(e['image_url'] as String?);
    final dateDebut = DateTime.parse(e['date_debut'].toString());
    final dateFin  = e['date_fin'] != null ? DateTime.parse(e['date_fin'].toString()) : null;
    final df = DateFormat('EEE d MMM yyyy • HH:mm', 'fr_FR');

    return ListView(
      children: [
        // Cover
        AspectRatio(
          aspectRatio: 16 / 9,
          child: imageUrl != null
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Container(
                  color: cs.secondary.withOpacity(.08),
                  alignment: Alignment.center,
                  child: Icon(Icons.event, size: 64, color: cs.secondary),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e['titre']?.toString() ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 6),
                Text(df.format(dateDebut) +
                    (dateFin != null ? ' → ${DateFormat('HH:mm').format(dateFin)}' : '')),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text('${e['lieu'] ?? ''} • ${e['ville'] ?? ''}')),
              ]),
              const SizedBox(height: 12),
              if ((e['description'] ?? '').toString().isNotEmpty)
                Text(e['description'].toString(), style: const TextStyle(height: 1.35)),
              const SizedBox(height: 16),
              const Text('Billets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._billets.map((b) => _BilletTile(
                    titre: b['titre']?.toString() ?? '',
                    description: b['description']?.toString(),
                    prix: (b['prix_gnf'] ?? 0) as int,
                    restant: ((b['stock_total'] ?? 0) as int) - ((b['stock_vendu'] ?? 0) as int),
                    onBuy: () => _reserver(b['id'].toString()),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _BilletTile extends StatelessWidget {
  final String titre;
  final String? description;
  final int prix;
  final int restant;
  final VoidCallback onBuy;

  const _BilletTile({
    required this.titre,
    required this.description,
    required this.prix,
    required this.restant,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.decimalPattern('fr_FR'); // 150 000

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withOpacity(.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (description != null && description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              const SizedBox(height: 6),
              Text(
                '${nf.format(prix)} GNF • $restant restants',
                style: const TextStyle(color: Colors.black54),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: restant > 0 ? onBuy : null,
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }
}
