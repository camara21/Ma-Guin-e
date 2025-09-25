import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/logement_models.dart';
import '../../services/logement_service.dart';
import 'logement_detail_page.dart';

class MesAnnoncesPage extends StatefulWidget {
  const MesAnnoncesPage({super.key});

  @override
  State<MesAnnoncesPage> createState() => _MesAnnoncesPageState();
}

class _MesAnnoncesPageState extends State<MesAnnoncesPage> {
  final _sb = Supabase.instance.client;
  final _svc = LogementService();

  bool _loading = true;
  String? _error;
  List<LogementModel> _items = [];
  StreamSubscription<List<Map<String, dynamic>>>? _stream;

  // palette
  static const _primary = Color(0xFF0D3B66);
  static const _accent  = Color(0xFFE0006D);
  static const _neutral = Color(0xFFF3F4F6);

  String? get _uid => _sb.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid == null) {
      setState(() {
        _loading = false;
        _items = [];
        _error = "Connecte-toi pour voir tes annonces.";
      });
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // 1) récupère mes IDs d'annonces (dans l'ordre le plus récent)
      final rows = await _sb
          .from('logements')
          .select('id, cree_le')
          .eq('user_id', _uid!)
          .order('cree_le', ascending: false);

      final ids = (rows as List)
          .map((e) => (e as Map)['id']?.toString())
          .whereType<String>()
          .toList();

      if (ids.isEmpty) {
        setState(() { _items = []; _loading = false; });
        return;
      }

      // 2) Logements complets via le service (inclut les photos)
      final list = await _svc.getManyByIds(ids);

      // Conserver l’ordre (cree_le desc) de la requête précédente
      final index = { for (var i = 0; i < ids.length; i++) ids[i]: i };
      list.sort((a, b) => (index[a.id] ?? 1<<30).compareTo(index[b.id] ?? 1<<30));

      setState(() { _items = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _subscribe() {
    if (_uid == null) return;

    // stream en temps réel sur mes logements
    _stream = _sb
        .from('logements')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid!)
        .listen((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Mes annonces'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _accent,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null
                ? _errorBox(_error!)
                : (_items.isEmpty
                    ? _empty("Aucune annonce publiée")
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _tile(_items[i]),
                      ))),
      ),
    );
  }

  Widget _tile(LogementModel b) {
    final id     = b.id;
    final titre  = b.titre;
    final mode   = b.mode == LogementMode.achat ? 'Achat' : 'Location';
    final cat    = _labelCat(b.categorie);
    final prix   = b.prixGnf != null
        ? (b.mode == LogementMode.achat
            ? '${b.prixGnf!.toStringAsFixed(0)} GNF'
            : '${b.prixGnf!.toStringAsFixed(0)} GNF / mois')
        : 'Prix à discuter';
    final photo  = b.photos.isEmpty ? '' : b.photos.first;
    final place  = [b.ville, b.commune].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

    return InkWell(
      onTap: () {
        if (id.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LogementDetailPage(logementId: id),
        ));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 110, height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              child: photo.isEmpty
                  ? Container(color: _neutral, child: const Icon(Icons.image, size: 36, color: Colors.black26))
                  : Image.network(photo, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: -6, children: [_miniChip(mode), _miniChip(cat)]),
                    const SizedBox(height: 6),
                    Text(prix, style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(place, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // helpers UI
  Widget _empty(String msg) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Text(msg, style: const TextStyle(color: Colors.black54)),
  ));

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
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text("Réessayer"),
          ),
        ],
      ),
    ),
  );

  Widget _miniChip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _neutral, borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: const TextStyle(fontSize: 12)),
  );

  String _labelCat(LogementCategorie c) {
    switch (c) {
      case LogementCategorie.maison: return 'Maison';
      case LogementCategorie.appartement: return 'Appartement';
      case LogementCategorie.studio: return 'Studio';
      case LogementCategorie.terrain: return 'Terrain';
      case LogementCategorie.autres: return 'Autres';
    }
  }
}
