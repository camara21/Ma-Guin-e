// lib/pages/logement/logement_list_page.dart
import 'package:flutter/material.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../../routes.dart';

class LogementListPage extends StatefulWidget {
  const LogementListPage({
    super.key,
    this.initialQuery,
    this.initialMode = LogementMode.location,
    this.initialCategorie = LogementCategorie.autres,
  });

  final String? initialQuery;
  final LogementMode initialMode;
  final LogementCategorie initialCategorie;

  @override
  State<LogementListPage> createState() => _LogementListPageState();
}

class _LogementListPageState extends State<LogementListPage> {
  final _svc = LogementService();
  final _qCtrl = TextEditingController();
  final _scroll = ScrollController();

  // État / filtres
  late LogementSearchParams _params;
  List<LogementModel> _items = [];
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;

  // Thème "Action Logement"
  Color get _primary => const Color(0xFF0B3A6A); // bleu profond (header)
  Color get _accent => const Color(0xFFE1005A); // fuchsia (actions/prix/FAB)
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _fill =>
      _isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6);
  Color get _chipBg =>
      _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _params = LogementSearchParams(
      q: widget.initialQuery,
      mode: widget.initialMode,
      categorie: widget.initialCategorie,
      orderBy: 'cree_le',
      ascending: false,
      limit: 20,
      offset: 0,
    );
    _qCtrl.text = widget.initialQuery ?? '';
    _fetch(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 220 &&
        !_loading &&
        _hasMore) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _hasMore = true;
        _params = _params.copyWith(offset: 0);
        if (!_refreshing) _items = [];
      }
    });

    try {
      final list = await _svc.search(_params);
      setState(() {
        if (reset) {
          _items = list;
        } else {
          _items.addAll(list);
        }
        _hasMore = list.length == _params.limit;
        _params = _params.copyWith(offset: _params.offset + list.length);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _fetch(reset: true);
    if (mounted) setState(() => _refreshing = false);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text("Résultats logement"),
        actions: [
          IconButton(
            tooltip: "Filtres",
            onPressed: _openFilters,
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (v) {
              switch (v) {
                case 'recent':
                  _params =
                      _params.copyWith(orderBy: 'cree_le', ascending: false);
                  break;
                case 'prix_asc':
                  _params =
                      _params.copyWith(orderBy: 'prix_gnf', ascending: true);
                  break;
                case 'prix_desc':
                  _params =
                      _params.copyWith(orderBy: 'prix_gnf', ascending: false);
                  break;
                case 'surface_desc':
                  _params = _params.copyWith(
                      orderBy: 'superficie_m2', ascending: false);
                  break;
              }
              _fetch(reset: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recent', child: Text('Plus récents')),
              PopupMenuItem(value: 'prix_asc', child: Text('Prix croissant')),
              PopupMenuItem(
                  value: 'prix_desc', child: Text('Prix décroissant')),
              PopupMenuItem(
                  value: 'surface_desc', child: Text('Grande superficie')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _accent,
        child: Column(
          children: [
            _searchBar(),
            _activeFiltersBar(),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? _errorBox(_error!)
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        if (i >= _items.length) {
                          return _loadMoreTile();
                        }
                        return _bienTile(_items[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.logementEdit),
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text("Publier un bien"),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _qCtrl,
              onSubmitted: (_) {
                _params = _params.copyWith(q: _qCtrl.text, offset: 0);
                _fetch(reset: true);
              },
              decoration: InputDecoration(
                hintText: "Rechercher : ville, quartier, mot-clé…",
                prefixIcon: Icon(Icons.search, color: _primary),
                filled: true,
                fillColor: _fill,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _softBtn(
            icon: Icons.tune_rounded,
            label: "Filtres",
            onTap: _openFilters,
          ),
        ],
      ),
    );
  }

  Widget _activeFiltersBar() {
    final chips = <Widget>[];

    if (_params.mode != null) {
      chips.add(_tag(
        _params.mode == LogementMode.achat ? "Achat" : "Location",
        onClear: () {
          _params = _params.copyWith(mode: null, offset: 0);
          _fetch(reset: true);
        },
      ));
    }
    if (_params.categorie != null) {
      chips.add(_tag(_labelCat(_params.categorie!), onClear: () {
        _params = _params.copyWith(categorie: null, offset: 0);
        _fetch(reset: true);
      }));
    }
    if ((_params.ville ?? '').isNotEmpty) {
      chips.add(_tag(_params.ville!, onClear: () {
        _params = _params.copyWith(ville: null, offset: 0);
        _fetch(reset: true);
      }));
    }
    if ((_params.commune ?? '').isNotEmpty) {
      chips.add(_tag(_params.commune!, onClear: () {
        _params = _params.copyWith(commune: null, offset: 0);
        _fetch(reset: true);
      }));
    }
    if (_params.prixMin != null || _params.prixMax != null) {
      final min = _params.prixMin?.toStringAsFixed(0) ?? '0';
      final max = _params.prixMax?.toStringAsFixed(0) ?? '∞';
      chips.add(_tag('Prix : $min–$max GNF', onClear: () {
        _params = _params.copyWith(prixMin: null, prixMax: null, offset: 0);
        _fetch(reset: true);
      }));
    }
    if (_params.surfaceMin != null || _params.surfaceMax != null) {
      final min = _params.surfaceMin?.toStringAsFixed(0) ?? '0';
      final max = _params.surfaceMax?.toStringAsFixed(0) ?? '∞';
      chips.add(_tag('Surface : $min–$max m²', onClear: () {
        _params =
            _params.copyWith(surfaceMin: null, surfaceMax: null, offset: 0);
        _fetch(reset: true);
      }));
    }
    if (_params.chambres != null && _params.chambres! > 0) {
      chips.add(_tag('${_params.chambres} ch', onClear: () {
        _params = _params.copyWith(chambres: null, offset: 0);
        _fetch(reset: true);
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map((w) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: w,
                ))
            .toList(),
      ),
    );
  }

  Widget _bienTile(LogementModel b) {
    final price = (b.prixGnf != null)
        ? (b.mode == LogementMode.achat
            ? '${b.prixGnf!.toStringAsFixed(0)} GNF'
            : '${b.prixGnf!.toStringAsFixed(0)} GNF / mois')
        : 'Prix à discuter';

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.logementDetail, arguments: b.id);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            // image
            Container(
              width: 110,
              height: 92,
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              clipBehavior: Clip.antiAlias,
              child: (b.photos.isEmpty)
                  ? Container(
                      color: _chipBg,
                      child: const Icon(Icons.image,
                          size: 36, color: Colors.black26),
                    )
                  : Image.network(b.photos.first, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: -6,
                      children: [
                        _miniChip(
                            b.mode == LogementMode.achat ? 'Achat' : 'Location'),
                        _miniChip(_labelCat(b.categorie)),
                        if (b.chambres != null) _miniChip('${b.chambres} ch'),
                        if (b.superficieM2 != null)
                          _miniChip('${b.superficieM2!.toStringAsFixed(0)} m²'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(price,
                        style: TextStyle(
                            color: _accent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      [b.ville, b.commune].whereType<String>().join(' • '),
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadMoreTile() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: Text("Fin des résultats")),
      );
    }
    return const SizedBox.shrink();
  }

  // --------------- Filtres ---------------

  void _openFilters() async {
    final res = await showModalBottomSheet<LogementSearchParams>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _FiltersSheet(
        initial: _params,
        primary: _primary,
        accent: _accent,
        chipBg: _chipBg,
      ),
    );
    if (res != null) {
      _params = res.copyWith(offset: 0);
      _fetch(reset: true);
    }
  }

  // --------------- Helpers UI ---------------

  Widget _softBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 6),
          Text(label)
        ]),
      ),
    );
  }

  Widget _tag(String text, {VoidCallback? onClear}) {
    return Chip(
      label: Text(text),
      deleteIcon: onClear == null ? null : const Icon(Icons.close, size: 18),
      onDeleted: onClear,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: _chipBg,
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
                    backgroundColor: _accent, foregroundColor: Colors.white),
                onPressed: () => _fetch(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );

  void _showSnack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }
}

// ------------------- BottomSheet Filtres -------------------

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet(
      {required this.initial,
      required this.primary,
      required this.accent,
      required this.chipBg});
  final LogementSearchParams initial;
  final Color primary;
  final Color accent;
  final Color chipBg;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late LogementMode? _mode;
  late LogementCategorie? _cat;
  late TextEditingController _ville;
  late TextEditingController _commune;
  double _prixMin = 0;
  double _prixMax = 0;
  double _surfMin = 0;
  double _surfMax = 0;
  int _chambres = 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _cat = widget.initial.categorie;
    _ville = TextEditingController(text: widget.initial.ville ?? '');
    _commune = TextEditingController(text: widget.initial.commune ?? '');
    _prixMin = (widget.initial.prixMin ?? 0).toDouble();
    _prixMax = (widget.initial.prixMax ?? 0).toDouble();
    _surfMin = (widget.initial.surfaceMin ?? 0).toDouble();
    _surfMax = (widget.initial.surfaceMax ?? 0).toDouble();
    _chambres = widget.initial.chambres ?? 0;
  }

  @override
  void dispose() {
    _ville.dispose();
    _commune.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom + 16;
    return Padding(
      padding: EdgeInsets.only(bottom: padding, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 12),
            const Text("Filtres",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Mode
            const Text("Type d’opération"),
            const SizedBox(height: 8),
            Wrap(spacing: 10, children: [
              ChoiceChip(
                label: const Text('Location'),
                selected: _mode == LogementMode.location,
                selectedColor: widget.accent,
                labelStyle: TextStyle(
                    color:
                        _mode == LogementMode.location ? Colors.white : null),
                onSelected: (_) =>
                    setState(() => _mode = LogementMode.location),
              ),
              ChoiceChip(
                label: const Text('Achat'),
                selected: _mode == LogementMode.achat,
                selectedColor: widget.accent,
                labelStyle: TextStyle(
                    color: _mode == LogementMode.achat ? Colors.white : null),
                onSelected: (_) => setState(() => _mode = LogementMode.achat),
              ),
              ChoiceChip(
                label: const Text('Peu importe'),
                selected: _mode == null,
                selectedColor: widget.accent,
                labelStyle:
                    TextStyle(color: _mode == null ? Colors.white : null),
                onSelected: (_) => setState(() => _mode = null),
              ),
            ]),
            const SizedBox(height: 16),

            // Catégorie
            const Text("Catégorie"),
            const SizedBox(height: 8),
            Wrap(spacing: 10, children: [
              for (final c in LogementCategorie.values)
                ChoiceChip(
                  label: Text(_labelCat(c)),
                  selected: _cat == c,
                  selectedColor: widget.accent,
                  labelStyle: TextStyle(color: _cat == c ? Colors.white : null),
                  onSelected: (_) => setState(() => _cat = c),
                ),
              ChoiceChip(
                label: const Text('Aucune'),
                selected: _cat == null,
                selectedColor: widget.accent,
                labelStyle:
                    TextStyle(color: _cat == null ? Colors.white : null),
                onSelected: (_) => setState(() => _cat = null),
              ),
            ]),
            const SizedBox(height: 16),

            // Ville/commune
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ville,
                    decoration:
                        const InputDecoration(labelText: 'Ville', filled: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commune,
                    decoration: const InputDecoration(
                        labelText: 'Commune / Quartier', filled: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prix
            const Text("Prix (GNF)"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Min', filled: true),
                    onChanged: (v) => _prixMin = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Max', filled: true),
                    onChanged: (v) => _prixMax = double.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Surface
            const Text("Superficie (m²)"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Min', filled: true),
                    onChanged: (v) => _surfMin = double.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Max', filled: true),
                    onChanged: (v) => _surfMax = double.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chambres
            const Text("Chambres"),
            const SizedBox(height: 8),
            DropdownButton<int>(
              isExpanded: true,
              value: _chambres,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Peu importe')),
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 5, child: Text('5+')),
              ],
              onChanged: (v) => setState(() => _chambres = v ?? 0),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: widget.primary),
                      foregroundColor: widget.primary,
                    ),
                    onPressed: () => Navigator.pop(context, widget.initial),
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Appliquer'),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        widget.initial.copyWith(
                          mode: _mode,
                          categorie: _cat,
                          ville: _ville.text.trim().isEmpty
                              ? null
                              : _ville.text.trim(),
                          commune: _commune.text.trim().isEmpty
                              ? null
                              : _commune.text.trim(),
                          prixMin: _prixMin > 0 ? _prixMin : null,
                          prixMax: _prixMax > 0 ? _prixMax : null,
                          surfaceMin: _surfMin > 0 ? _surfMin : null,
                          surfaceMax: _surfMax > 0 ? _surfMax : null,
                          chambres: _chambres > 0 ? _chambres : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

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
}
