// lib/pages/logement/logement_detail_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

class LogementDetailPage extends StatefulWidget {
  const LogementDetailPage({super.key, required this.logementId});
  final String logementId;

  @override
  State<LogementDetailPage> createState() => _LogementDetailPageState();
}

class _LogementDetailPageState extends State<LogementDetailPage> {
  final _svc = LogementService();
  final _page = PageController();

  LogementModel? _bien;
  bool _loading = true;
  String? _error;
  int _pageIndex = 0;

  // ---------- Palette "Action Logement" ----------
  Color get _primary => const Color(0xFF0B3A6A); // bleu profond (AppBar)
  Color get _accent  => const Color(0xFFE1005A); // fuchsia (CTA/price)
  bool  get _isDark  => Theme.of(context).brightness == Brightness.dark;
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _chipBg  => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getById(widget.logementId);
      if (!mounted) return;
      setState(() {
        _bien = data;
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

  // -------- actions navigation / contact --------

  void _openMap() {
    final b = _bien;
    if (b == null) return;
    if (b.lat == null || b.lng == null) {
      _snack("Coordonnées indisponibles pour ce bien.");
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.logementMap,
      arguments: {
        'id': b.id,
        'lat': b.lat,
        'lng': b.lng,
        'titre': b.titre,
        'ville': b.ville,
        'commune': b.commune,
      },
    );
  }

  void _edit() {
    final b = _bien;
    if (b == null) return;
    Navigator.pushNamed(context, AppRoutes.logementEdit, arguments: b).then((_) => _load());
  }

  void _openMessages() {
    final b = _bien;
    if (b == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.messages,
      arguments: {
        'peerUserId': b.userId,
        'logementId': b.id,
        'title': b.titre,
        'source': 'logement_detail',
      },
    );
  }

  Future<void> _callOwner() async {
    // ✅ priorité au champ du modèle, sinon fallback via arguments de route
    String? tel = _bien?.contactTelephone?.trim();
    if (tel == null || tel.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['phone'] is String) {
        tel = (args['phone'] as String).trim();
      }
    }
    if (tel == null || tel.isEmpty) {
      _snack("Numéro de téléphone non renseigné pour cette annonce.");
      return;
    }

    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack("Impossible d’ouvrir l’app Téléphone.");
    }
  }

  String _formatPrice(num? value, LogementMode mode) {
    if (value == null) return 'Prix à discuter';
    if (value >= 1000000) {
      final m = (value / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return mode == LogementMode.achat ? '$m M GNF' : '$m M GNF / mois';
    }
    final s = value.toStringAsFixed(0);
    return mode == LogementMode.achat ? '$s GNF' : '$s GNF / mois';
  }

  // -------- UI --------

  @override
  Widget build(BuildContext context) {
    final b = _bien;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text("Détail du bien"),
        actions: [
          IconButton(
            tooltip: "Rafraîchir",
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _edit();
                  break;
                case 'share':
                  _snack("Partage à venir");
                  break;
                case 'report':
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Signaler"),
                      content: const Text("La fonctionnalité de signalement arrive bientôt."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                      ],
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'share', child: Text('Partager')),
              PopupMenuItem(value: 'report', child: Text('Signaler')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBox(_error!)
              : b == null
                  ? const Center(child: Text("Bien introuvable"))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _imagesHeader(b),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Titre
                                      Text(
                                        b.titre,
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 8),

                                      // Prix
                                      Text(
                                        _formatPrice(b.prixGnf, b.mode),
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _accent),
                                      ),
                                      const SizedBox(height: 12),

                                      // Badges
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: -6,
                                        children: [
                                          _chip(b.mode == LogementMode.achat ? 'Achat' : 'Location'),
                                          _chip(logementCategorieToString(b.categorie)),
                                          if (b.chambres != null) _chip('${b.chambres} ch'),
                                          if (b.superficieM2 != null) _chip('${b.superficieM2!.toStringAsFixed(0)} m²'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Localisation
                                      Row(
                                        children: [
                                          const Icon(Icons.place, size: 18, color: Colors.black54),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              [
                                                if (b.adresse?.isNotEmpty == true) b.adresse!,
                                                if (b.commune?.isNotEmpty == true) b.commune!,
                                                if (b.ville?.isNotEmpty == true) b.ville!,
                                              ].join(' • '),
                                              style: const TextStyle(color: Colors.black54),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _accent,
                                              side: BorderSide(color: _accent),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: _openMap,
                                            icon: const Icon(Icons.map_outlined),
                                            label: const Text("Carte"),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 18),
                                      const Divider(height: 1),
                                      const SizedBox(height: 18),

                                      // Description
                                      const Text(
                                        "Description",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        (b.description ?? '—').trim().isEmpty ? '—' : b.description!.trim(),
                                        style: const TextStyle(fontSize: 14, height: 1.4),
                                      ),

                                      const SizedBox(height: 16),

                                      // Contact (affichage du numéro si dispo)
                                      if ((b.contactTelephone ?? '').trim().isNotEmpty) ...[
                                        const Divider(height: 24),
                                        Row(
                                          children: [
                                            const Icon(Icons.call, size: 18, color: Colors.black54),
                                            const SizedBox(width: 6),
                                            Text(
                                              b.contactTelephone!.trim(),
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --------- Barre d’actions Contact ---------
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                            decoration: BoxDecoration(
                              color: _bg,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: _accent),
                                      foregroundColor: _accent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _openMessages,
                                    icon: const Icon(Icons.forum_outlined),
                                    label: const Text("Écrire"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _callOwner,
                                    icon: const Icon(Icons.call),
                                    label: const Text("Appeler"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
      // FAB Modifier
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text("Modifier"),
            ),
    );
  }

  // ---------- helpers visuels ----------

  Widget _imagesHeader(LogementModel b) {
    final photos = b.photos.where((e) => e.trim().isNotEmpty).toList();
    final hasPhotos = photos.isNotEmpty;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: hasPhotos
              ? PageView.builder(
                  controller: _page,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (_, i) => Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.black26),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.image, size: 64, color: Colors.black26)),
                ),
        ),
        if (hasPhotos) _pagerDots(photos.length),
        Positioned(
          top: 10,
          right: 10,
          child: _glass(
            child: IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: () => _snack("Visionneuse à venir"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pagerDots(int count) {
    return Positioned(
      bottom: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(
            count,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _pageIndex == i ? 9 : 7,
              height: _pageIndex == i ? 9 : 7,
              decoration: BoxDecoration(
                color: _pageIndex == i ? Colors.white : Colors.white54,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glass({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _errorBox(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 10),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
