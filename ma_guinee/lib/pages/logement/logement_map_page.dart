// lib/pages/logement/logement_map_page.dart
import 'package:flutter/material.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart'; // ✅ pour ouvrir le détail

class LogementMapPage extends StatefulWidget {
  const LogementMapPage({super.key, this.ville, this.commune});

  final String? ville;
  final String? commune;

  @override
  State<LogementMapPage> createState() => _LogementMapPageState();
}

class _LogementMapPageState extends State<LogementMapPage> {
  final _svc = LogementService();
  List<LogementModel> _items = [];
  bool _loading = true;
  String? _error;

  // ---------- Thème "Action Logement" ----------
  Color get _primary => const Color(0xFF0B3A6A); // bleu profond (header)
  Color get _accent  => const Color(0xFFE1005A); // fuchsia (prix/boutons)
  bool  get _isDark  => Theme.of(context).brightness == Brightness.dark;
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _chipBg  => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

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
      final list = await _svc.nearMe(
        ville: widget.ville,
        commune: widget.commune,
        limit: 30,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
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

  @override
  Widget build(BuildContext context) {
    final subtitle = [widget.ville, widget.commune].whereType<String>().join(' • ');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Text("Carte des logements", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: "Rafraîchir",
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              subtitle.isEmpty ? "Guinée" : subtitle,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _accent,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorBox(_error!)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    children: [
                      _mapHeader(),
                      const SizedBox(height: 12),
                      ..._items.map(_tile).toList(),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text(
                              "Aucun bien trouvé ${subtitle.isEmpty ? '' : 'autour de $subtitle'}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _mapHeader() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3A6A), Color(0xFF1E5AA8)], // bleu → bleu clair
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          "🗺️ Carte interactive — bientôt",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _tile(LogementModel b) {
    final price = (b.prixGnf != null)
        ? (b.mode == LogementMode.achat
            ? '${b.prixGnf!.toStringAsFixed(0)} GNF'
            : '${b.prixGnf!.toStringAsFixed(0)} GNF / mois')
        : 'Prix à discuter';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.logementDetail, arguments: b.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: (b.photos.isEmpty)
                      ? Container(
                          color: _chipBg,
                          child: const Icon(Icons.image, color: Colors.black26),
                        )
                      : Image.network(b.photos.first, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _miniChip(b.mode == LogementMode.achat ? 'Achat' : 'Location'),
                        _miniChip(_labelCat(b.categorie)),
                        if (b.chambres != null) _miniChip('${b.chambres} ch'),
                        if (b.superficieM2 != null) _miniChip('${b.superficieM2!.toStringAsFixed(0)} m²'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [b.ville, b.commune].whereType<String>().join(' • '),
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                price,
                textAlign: TextAlign.right,
                style: TextStyle(color: _accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: const TextStyle(fontSize: 12)),
      );

  String _labelCat(LogementCategorie c) {
    switch (c) {
      case LogementCategorie.maison:
        return 'Maison';
      case LogementCategorie.appartement:
        return 'Appartement';
      case LogementCategorie.studio:
        return 'Studio';
      case LogementCategorie.terrain:
        return 'Terrain';
      case LogementCategorie.autres:
        return 'Autres';
    }
  }

  Widget _errorBox(String msg) => Center(
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
}
