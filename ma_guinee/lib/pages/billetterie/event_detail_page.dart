// lib/pages/billetterie/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/billetterie_service.dart';

// Palette Billetterie
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ev = await _svc.getEvenement(widget.eventId);
      final bi = await _svc.listBilletsByEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = ev;
        _billets = bi;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reserver(String billetId) async {
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
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choisir la quantité',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () =>
                          setSt(() => qty = (qty > 1 ? qty - 1 : 1)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$qty',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
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
                      backgroundColor: _kEventPrimary,
                      foregroundColor: _kOnPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx); // fermer le sheet
                      try {
                        final id = await _svc.reserverBillet(
                          billetId: billetId,
                          quantite: qty,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Réservation confirmée (#$id)'),
                          ),
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

  void _openFullscreen(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenImagePage(
          tag: 'event_image_${widget.eventId}',
          imageUrl: imageUrl,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Détail de l’événement'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _event == null
                  ? const Center(child: Text('Événement introuvable'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final e = _event!;
    final imageUrl = _svc.publicImageUrl(e['image_url'] as String?);
    final dateDebut = DateTime.parse(e['date_debut'].toString());
    final dateFin =
        e['date_fin'] != null ? DateTime.parse(e['date_fin'].toString()) : null;
    final df = DateFormat('EEE d MMM yyyy • HH:mm', 'fr_FR');

    return ListView(
      children: [
        // Cover cliquable + voile
        GestureDetector(
          onTap: imageUrl == null ? null : () => _openFullscreen(imageUrl),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null
                    ? Hero(
                        tag: 'event_image_${widget.eventId}',
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      )
                    : Container(
                        color: const Color(0xFFEFE7FF),
                        alignment: Alignment.center,
                        child: const Icon(Icons.event,
                            size: 64, color: _kEventPrimary),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(.5),
                      ],
                    ),
                  ),
                ),
              ),
              if ((e['categorie'] ?? '').toString().isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kEventPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (e['categorie'] ?? '').toString(),
                      style: const TextStyle(
                        color: _kOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (imageUrl != null)
                // Indice "tap to zoom"
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.zoom_out_map, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Agrandir',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e['titre']?.toString() ?? '',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: _kEventPrimary),
                  const SizedBox(width: 6),
                  Text(
                    df.format(dateDebut) +
                        (dateFin != null
                            ? ' → ${DateFormat('HH:mm').format(dateFin)}'
                            : ''),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place, size: 18, color: _kEventPrimary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${e['lieu'] ?? ''} • ${e['ville'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if ((e['description'] ?? '').toString().isNotEmpty)
                Text(
                  e['description'].toString(),
                  style: const TextStyle(height: 1.35),
                ),
              const SizedBox(height: 16),
              const Text(
                'Billets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              // Liste billets
              ..._billets.map(
                (b) => _BilletTile(
                  titre: b['titre']?.toString() ?? '',
                  description: b['description']?.toString(),
                  prix: (b['prix_gnf'] ?? 0) as int,
                  restant: ((b['stock_total'] ?? 0) as int) -
                      ((b['stock_vendu'] ?? 0) as int),
                  onBuy: () => _reserver(b['id'].toString()),
                ),
              ),

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

  // Couleur des billets selon le titre (VIP/Gold/Silver/Standard…)
  Color _badgeColor() {
    final t = titre.toLowerCase();
    if (t.contains('vvip')) return const Color(0xFFB00020); // rouge premium
    if (t.contains('vip')) return const Color(0xFFDAA520); // or
    if (t.contains('gold')) return const Color(0xFFFFB300); // gold
    if (t.contains('silver')) return const Color(0xFFB0BEC5); // silver
    if (t.contains('student') || t.contains('etudiant')) {
      return const Color(0xFF2E7D32); // vert
    }
    return _kEventPrimary; // défaut
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.decimalPattern('fr_FR'); // 150 000
    final c = _badgeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22000000)),
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
          // Badge à gauche
          Container(
            width: 6,
            height: 56,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        titre,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${nf.format(prix)} GNF',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                if (description != null && description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '$restant restants',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kEventPrimary,
              foregroundColor: _kOnPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: restant > 0 ? onBuy : null,
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// Page plein écran avec zoom
/// ===============================
class _FullscreenImagePage extends StatefulWidget {
  final String tag;
  final String imageUrl;

  const _FullscreenImagePage({
    required this.tag,
    required this.imageUrl,
  });

  @override
  State<_FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<_FullscreenImagePage> {
  final TransformationController _tc = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_tc.value != Matrix4.identity()) {
      _tc.value = Matrix4.identity();
      return;
    }
    final pos = _doubleTapDetails!.localPosition;
    // zoom x2 centré sur le tap
    _tc.value = Matrix4.identity()
      ..translate(-pos.dx, -pos.dy)
      ..scale(2.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onTapDown: (d) => _doubleTapDetails = d,
                onDoubleTap: _onDoubleTap,
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Hero(
                    tag: widget.tag,
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
