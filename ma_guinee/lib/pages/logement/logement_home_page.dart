// lib/pages/logement/logement_home_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

class LogementHomePage extends StatefulWidget {
  const LogementHomePage({super.key});

  @override
  State<LogementHomePage> createState() => _LogementHomePageState();
}

class _LogementHomePageState extends State<LogementHomePage> {
  final _searchCtrl = TextEditingController();
  final _svc = LogementService();

  String _mode = 'location';   // location | achat
  String _categorie = 'tous';  // maison | appartement | studio | terrain | tous

  List<LogementModel> _latest = [];
  List<LogementModel> _near = [];
  bool _loading = true;
  String? _error;

  // Palette (Action Logement)
  static const _primary     = Color(0xFF0D3B66);
  static const _primaryDark = Color(0xFF0A2C4C);
  static const _accent      = Color(0xFFE0006D);
  static const _ctaGreen    = Color(0xFF0E9F6E);
  static const _neutralBg   = Color(0xFFF5F7FB);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final latest = await _svc.latest(limit: 10);
      final near   = await _svc.nearMe(limit: 10);
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _near   = near;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _soon([String what = 'Fonctionnalité']) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).size.width > 600 ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF0F172A) : _neutralBg,

      // AppBar avec icônes (non branchées pour favoris & mes annonces)
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: const Text("Logements en Guinée", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "Notifications",
            onPressed: () => _soon('Notifications'),
            icon: const Icon(Icons.notifications_none, color: Colors.white),
          ),
          IconButton(
            tooltip: "Favoris",
            onPressed: () => _soon('Favoris'),
            icon: const Icon(Icons.favorite_border, color: Colors.white),
          ),
          IconButton(
            tooltip: "Mes annonces",
            onPressed: () => _soon('Mes annonces'),
            icon: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          children: [
            _heroBanner(),
            const SizedBox(height: 18),
            _searchBar(),
            const SizedBox(height: 14),
            _modeSwitch(),
            const SizedBox(height: 10),
            _categoriesGrid(),
            const SizedBox(height: 18),
            _quickActions(),      // Favoris & Mes annonces en boutons, non branchés
            const SizedBox(height: 22),

            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              _errorBox(_error!)
            else ...[
              _sectionTitle("Nouveaux biens"),
              const SizedBox(height: 12),
              _horizontalList(_latest),
              const SizedBox(height: 22),
              _sectionTitle(
                "Près de moi",
                trailing: IconButton(
                  icon: const Icon(Icons.map_outlined, color: _primary),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.logementMap),
                ),
              ),
              const SizedBox(height: 12),
              _horizontalList(_near),
              const SizedBox(height: 100),
            ],
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _ctaGreen,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.logementEdit),
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text("Publier un bien"),
      ),
    );
  }

  // ------------------ Widgets ------------------

  Widget _heroBanner() {
    return Container(
      height: 164,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DotsPainter(color: Colors.white.withOpacity(0.10))))),
          const Positioned(
            left: 20,
            top: 22,
            right: 140,
            child: Text(
              "Trouvez votre logement idéal, simplement.",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
          Positioned(
            right: 14,
            bottom: -8,
            child: Transform.rotate(
              angle: -math.pi / 16,
              child: Icon(Icons.house_rounded, size: 140, color: Colors.white.withOpacity(0.18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      onSubmitted: (_) {
        final q = _searchCtrl.text.trim();
        final args = <String, dynamic>{'q': q, 'mode': _mode};
        if (_categorie != 'tous') args['categorie'] = _categorie;
        Navigator.pushNamed(context, AppRoutes.logementList, arguments: args);
      },
      decoration: InputDecoration(
        hintText: "Rechercher : ville, quartier, mot-clé…",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _modeSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("Location"),
          selected: _mode == "location",
          onSelected: (_) => setState(() => _mode = "location"),
          selectedColor: _accent,
          labelStyle: TextStyle(color: _mode == "location" ? Colors.white : Colors.black87),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: _mode == "location" ? _accent : Colors.black12)),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text("Achat"),
          selected: _mode == "achat",
          onSelected: (_) => setState(() => _mode = "achat"),
          selectedColor: _accent,
          labelStyle: TextStyle(color: _mode == "achat" ? Colors.white : Colors.black87),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: _mode == "achat" ? _accent : Colors.black12)),
        ),
      ],
    );
  }

  Widget _categoriesGrid() {
    final cats = [
      {"icon": Icons.home, "label": "Maison", "id": "maison"},
      {"icon": Icons.apartment, "label": "Appartement", "id": "appartement"},
      {"icon": Icons.meeting_room, "label": "Studio", "id": "studio"},
      {"icon": Icons.park, "label": "Terrain", "id": "terrain"},
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cats.map((c) {
        final selected = _categorie == c["id"];
        return GestureDetector(
          onTap: () => setState(() => _categorie = c["id"] as String),
          child: Column(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: selected ? _accent : Colors.white,
                child: Icon(c["icon"] as IconData, size: 26, color: selected ? Colors.white : _primary),
              ),
              const SizedBox(height: 6),
              Text(c["label"] as String, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _quickActions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ctaGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.logementEdit),
          icon: const Icon(Icons.add),
          label: const Text("Publier"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _soon('Favoris'),
          icon: const Icon(Icons.favorite_border),
          label: const Text("Favoris"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _soon('Mes annonces'),
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: const Text("Mes annonces"),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.logementMap),
          icon: const Icon(Icons.map_outlined),
          label: const Text("Carte"),
        ),
      ],
    );
  }

  Widget _sectionTitle(String txt, {Widget? trailing}) {
    return Row(
      children: [
        Text(txt, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _horizontalList(List<LogementModel> items) {
    if (items.isEmpty) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Text("Aucun bien pour le moment", style: TextStyle(color: Colors.black54)),
      );
    }
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _bienCard(items[i]),
      ),
    );
  }

  Widget _bienCard(LogementModel b) {
    final image = (b.photos.isNotEmpty) ? b.photos.first : null;
    final mode  = b.mode == LogementMode.achat ? 'Achat' : 'Location';
    final cat   = _labelCat(b.categorie);
    final price = (b.prixGnf != null) ? _formatPrice(b.prixGnf!, b.mode) : 'Prix à discuter';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.logementDetail, arguments: b.id),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: image == null ? const Icon(Icons.image, size: 46, color: Colors.black26)
                                   : Image.network(image, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.titre, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [_chip(mode), const SizedBox(width: 6), _chip(cat)]),
                  const SizedBox(height: 6),
                  Text(price, style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text([if (b.ville != null) b.ville!, if (b.commune != null) b.commune!].join(' • '),
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelCat(LogementCategorie c) {
    switch (c) {
      case LogementCategorie.maison:      return 'Maison';
      case LogementCategorie.appartement: return 'Appartement';
      case LogementCategorie.studio:      return 'Studio';
      case LogementCategorie.terrain:     return 'Terrain';
      case LogementCategorie.autres:      return 'Autres';
    }
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: _neutralBg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  String _formatPrice(num value, LogementMode mode) {
    if (value >= 1000000) {
      final m = (value / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return mode == LogementMode.achat ? '$m M GNF' : '$m M GNF / mois';
    }
    final s = value.toStringAsFixed(0);
    return mode == LogementMode.achat ? '$s GNF' : '$s GNF / mois';
  }

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCCD6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
            TextButton(onPressed: _loadAll, child: const Text('Réessayer')),
          ],
        ),
      );
}

// ---- Painter décoratif pour bannière ----
class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    const r = 3.0;
    for (double y = 18; y < size.height; y += 18) {
      for (double x = 18; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => false;
}
