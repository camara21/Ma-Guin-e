import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

import '../supabase_client.dart';

class ContentAdvancedPage extends StatefulWidget {
  final String title; // ex : Annonces, Logements…
  final String table; // ex : annonces, logements, lieux, reports…
  const ContentAdvancedPage({super.key, required this.title, required this.table});

  @override
  State<ContentAdvancedPage> createState() => _ContentAdvancedPageState();
}

class _ContentAdvancedPageState extends State<ContentAdvancedPage> {
  // UI
  final _searchC = TextEditingController();
  final _debouncer = _Debouncer(const Duration(milliseconds: 450));
  String? _city;
  DateTimeRange? _range;
  String _sort = 'created_at';
  bool _asc = false;
  int _page = 0;
  int _pageSize = 25;

  // data
  List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  final _selected = <String>{};

  // features
  bool _hasVille = true;
  bool _hasCreated = true;

  // source (vue si dispo, sinon table)
  late String _source;
  Set<String> _cols = {};

  RealtimeChannel? _chan;

  String get _view => 'v_${widget.table}_public';

  @override
  void initState() {
    super.initState();
    _initSource().then((_) async {
      await _detectSchema();
      await _load();
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    _chan?.unsubscribe();
    super.dispose();
  }

  // source = vue si elle existe, sinon table
  Future<void> _initSource() async {
    _source = widget.table;
    try {
      await SB.i.from(_view).select('id').limit(0);
      _source = _view;
    } catch (_) {
      _source = widget.table;
    }
  }

  // détection du schéma
  Future<void> _detectSchema() async {
    try {
      final res = await SB.i.from(_source).select('*').limit(1);
      if (res is List && res.isNotEmpty && res.first is Map) {
        _cols = Map<String, dynamic>.from(res.first as Map).keys.toSet();
      }
    } catch (_) {
      _cols = {};
    }

    _hasVille = _cols.contains('ville');

    if (_cols.contains('created_at')) {
      _hasCreated = true;
      _sort = 'created_at';
    } else if (_cols.contains('date_ajout')) {
      _hasCreated = true;
      _sort = 'date_ajout';
    } else {
      _hasCreated = false;
      _sort = _cols.contains('id') ? 'id' : (_cols.isNotEmpty ? _cols.first : 'id');
      _asc = false;
    }
  }

  // abonnement realtime
  void _subscribeRealtime() {
    _chan?.unsubscribe();
    _chan = SB.i
        .channel('admin:${widget.table}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: widget.table,
          callback: (_) => _load(),
        )
        .subscribe();
  }

  // query builder
  PostgrestFilterBuilder _buildQuery({required bool forCount}) {
    final builder = SB.i.from(_source).select(forCount ? 'id' : '*');
    PostgrestFilterBuilder q = builder;

    // recherche plein-texte en OR sur les colonnes présentes
    final query = _searchC.text.trim();
    if (query.isNotEmpty) {
      final s = '%$query%';
      final searchable = <String>['titre', 'nom', 'description', 'ville']
          .where(_cols.contains)
          .toList();
      if (searchable.isNotEmpty) {
        final orParts = searchable.map((c) => '$c.ilike.$s').join(',');
        try {
          q = q.or(orParts);
        } catch (_) {
          // fallback : au pire, ilike sur la première colonne dispo
          try {
            q = q.ilike(searchable.first, s);
          } catch (_) {}
        }
      }
      if (_cols.contains('id') && query.length >= 3) {
        try {
          // élargit la recherche aux débuts d'UUID
          q = q.or('id.ilike.${query.replaceAll('%', '')}%');
        } catch (_) {}
      }
    }

    // ville
    final city = _city;
    if (_hasVille && city != null && city.isNotEmpty && _cols.contains('ville')) {
      q = q.eq('ville', city);
    }

    // dates
    if (_hasCreated && _range != null && _cols.contains(_sort)) {
      q = q.gte(_sort, _range!.start.toIso8601String());
      q = q.lte(_sort, _range!.end.add(const Duration(days: 1)).toIso8601String());
    }

    // tri
    if (!forCount && _cols.contains(_sort)) {
      try {
        q = (q as dynamic).order(_sort, ascending: _asc) as PostgrestFilterBuilder;
      } catch (_) {
        try {
          // compat ancienne signature
          // ignore: deprecated_member_use
          q = (q as dynamic).order(_sort, _asc) as PostgrestFilterBuilder;
        } catch (_) {}
      }
    }

    return q;
  }

  // chargement
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final start = _page * _pageSize;
      final end = start + _pageSize - 1;

      final data = await _buildQuery(forCount: false).range(start, end);
      _rows = (data as List).cast<Map<String, dynamic>>();

      final countRes = await _buildQuery(forCount: true);
      _total = (countRes as List).length;
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // mapping table -> RPC
  String? _rpcForTable() {
    switch (widget.table) {
      case 'logements':
        return 'admin_delete_logements';
      case 'lieux':
        return 'admin_delete_lieux';
      default:
        return null; // autres tables : fallback delete normal
    }
  }

  // suppression via RPC (centralisée)
  Future<int> _callAdminDelete(List<String> ids) async {
    final fn = _rpcForTable();
    if (fn == null || ids.isEmpty) return 0;
    final res = await SB.i.rpc(fn, params: {'p_ids': ids});
    return (res is int) ? res : 0;
  }

  // suppression DÉFINITIVE (RPC pour logements/lieux, fallback sinon)
  Future<void> _deleteOneDefinitive(String id) async {
    setState(() => _loading = true);
    try {
      final fn = _rpcForTable();
      if (fn != null) {
        final deleted = await _callAdminDelete([id]);
        if (!mounted) return;
        if (deleted > 0) {
          _selected.remove(id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$deleted élément supprimé (admin).')),
          );
          await _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune ligne supprimée (droits/FK ?).')),
          );
        }
      } else {
        // fallback pour les autres tables
        final res = await SB.i.from(widget.table).delete().eq('id', id).select('id');
        final deleted = (res is List) ? res.length : 0;

        if (!mounted) return;
        if (deleted > 0) {
          _selected.remove(id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$deleted élément supprimé.')),
          );
          await _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune ligne supprimée (RLS/FK ?).')),
          );
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : code=${e.code} msg=${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteManyDefinitive() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      final fn = _rpcForTable();
      if (fn != null) {
        final ids = _selected.toList(); // UUID en String
        final deleted = await _callAdminDelete(ids);

        if (!mounted) return;
        if (deleted > 0) {
          _selected.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$deleted éléments supprimés (admin).')),
          );
          await _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune ligne supprimée (droits/FK ?).')),
          );
        }
      } else {
        // fallback pour les autres tables
        final inList = _buildInListTyped(_selected.toList());
        final res = await SB.i
            .from(widget.table)
            .delete()
            .filter('id', 'in', inList)
            .select('id'); // renvoie les lignes supprimées

        final deleted = (res is List) ? res.length : 0;

        if (!mounted) return;
        if (deleted > 0) {
          _selected.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$deleted éléments supprimés.')),
          );
          await _load();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune ligne supprimée (RLS/FK ?).')),
          );
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : code=${e.code} msg=${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur suppression : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // construit la chaîne pour l'opérateur PostgREST in() (fallback)
  String _buildInListTyped(List<String> ids) {
    if (ids.isEmpty) return '()';
    final allInts = ids.every((s) => int.tryParse(s) != null);
    if (allInts) {
      return '(${ids.join(',')})'; // (1,2,3)
    } else {
      final esc = ids.map((s) => '"${s.replaceAll('"', r'\"')}"').join(',');
      return '($esc)'; // ("uuid1","uuid2")
    }
  }

  // helpers UI
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _page = 0;
      });
      _load();
    }
  }

  Future<List<String>> _fetchCities() async {
    if (!_hasVille) return const [];
    try {
      final data = await SB.i.from(_source).select('ville');
      final vals = (data as List)
          .map((e) => (e as Map)['ville'])
          .where((v) => v != null && v.toString().isNotEmpty)
          .map((v) => v.toString())
          .toSet()
          .toList()
        ..sort();
      return vals;
    } catch (_) {
      return const [];
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final pages = (_total / _pageSize).ceil().clamp(1, 9999);
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (hasSelection)
            IconButton(
              tooltip: 'Supprimer définitivement (sélection)',
              icon: const Icon(Icons.delete_forever),
              onPressed: _loading ? null : _onConfirmBulkDelete,
            ),
          IconButton(onPressed: _loading ? null : _exportCsv, icon: const Icon(Icons.download)),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _filtersBar(),
            const SizedBox(height: 8),
            _toolbar(),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _dataTable(),
            ),
            const SizedBox(height: 8),
            _paginator(pages),
          ],
        ),
      ),
    );
  }

  Widget _filtersBar() {
    return Wrap(
      runSpacing: 8,
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _searchC,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher… (nom/titre/ville…)',
            ),
            onChanged: (_) => _debouncer.run(() {
              _page = 0;
              _load();
            }),
            onSubmitted: (_) {
              _page = 0;
              _load();
            },
          ),
        ),
        if (_hasVille)
          FutureBuilder<List<String>>(
            future: _fetchCities(),
            builder: (context, snap) {
              final items = snap.data ?? const <String>[];
              return DropdownButton<String>(
                value: _city?.isNotEmpty == true ? _city : null,
                hint: const Text('Ville'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Toutes')),
                  ...items.map((v) => DropdownMenuItem(value: v, child: Text(v))),
                ],
                onChanged: (v) {
                  setState(() {
                    _city = (v ?? '').isEmpty ? null : v;
                    _page = 0;
                  });
                  _load();
                },
              );
            },
          ),
        if (_hasCreated)
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(
              _range == null ? 'Date (toutes)' : '${_fmtDate(_range!.start)} au ${_fmtDate(_range!.end)}',
            ),
            onPressed: _pickDateRange,
          ),
        if (_range != null)
          IconButton(
            tooltip: 'Réinitialiser les dates',
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() => _range = null);
              _load();
            },
          ),
      ],
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Text('$_total éléments', style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        DropdownButton<String>(
          value: _sort,
          items: <String>['id', 'titre', 'nom', 'ville', 'created_at', 'date_ajout', _sort]
              .toSet()
              .map((c) => DropdownMenuItem(value: c, child: Text('Trier : $c')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _sort = v);
            _load();
          },
        ),
        IconButton(
          tooltip: _asc ? 'Tri ascendant' : 'Tri descendant',
          icon: Icon(_asc ? Icons.south : Icons.north),
          onPressed: () {
            setState(() => _asc = !_asc);
            _load();
          },
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _pageSize,
          items: const [10, 25, 50, 100]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n / page')))
              .toList(),
          onChanged: (n) {
            if (n == null) return;
            setState(() {
              _pageSize = n;
              _page = 0;
            });
            _load();
          },
        ),
      ],
    );
  }

  Widget _dataTable() {
    if (_rows.isEmpty) return const Center(child: Text('Aucune donnée'));
    final cols = _orderedColumns(_rows.first.keys.toList());

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: true,
          columns: [
            for (final c in cols.take(8))
              DataColumn(
                label: InkWell(
                  onTap: () {
                    setState(() {
                      _sort = c;
                      _asc = !_asc;
                    });
                    _load();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c),
                      if (_sort == c) Icon(_asc ? Icons.south : Icons.north, size: 16),
                    ],
                  ),
                ),
              ),
            const DataColumn(label: Text('Actions')),
          ],
          rows: _rows.map((r) {
            final id = (r['id'] ?? '').toString();
            final selected = _selected.contains(id);
            return DataRow(
              selected: selected,
              onSelectChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                });
              },
              cells: [
                for (final c in cols.take(8)) DataCell(SizedBox(width: 220, child: Text('${r[c]}'))),
                DataCell(Row(children: [
                  IconButton(
                    tooltip: 'Supprimer DÉFINITIVEMENT',
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _onConfirmDeleteOne(id),
                  ),
                ])),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _paginator(int pages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Première',
          onPressed: _page > 0
              ? () {
                  setState(() => _page = 0);
                  _load();
                }
              : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          tooltip: 'Précédente',
          onPressed: _page > 0
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page ${_page + 1}/$pages'),
        IconButton(
          tooltip: 'Suivante',
          onPressed: ((_page + 1) < pages)
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Dernière',
          onPressed: ((_page + 1) < pages)
              ? () {
                  setState(() => _page = pages - 1);
                  _load();
                }
              : null,
          icon: const Icon(Icons.last_page),
        ),
        const SizedBox(width: 12),
        if (_selected.isNotEmpty) ...[
          Text('${_selected.length} sél.'),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _onConfirmBulkDelete,
            child: const Text('Supprimer DÉFINITIVEMENT'),
          ),
        ],
      ],
    );
  }

  List<String> _orderedColumns(List<String> cols) {
    final defaultOrder = ['id', 'titre', 'nom', 'ville', 'created_at', 'date_ajout'];
    cols.sort((a, b) {
      final ia = defaultOrder.indexOf(a);
      final ib = defaultOrder.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return cols;
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // confirmations
  Future<void> _onConfirmDeleteOne(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suppression DÉFINITIVE'),
        content: const Text(
            'Cette action va supprimer la ligne dans la base. C’est irréversible. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (ok == true) await _deleteOneDefinitive(id);
  }

  Future<void> _onConfirmBulkDelete() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Suppression DÉFINITIVE (${_selected.length} éléments)'),
        content: const Text('Action irréversible. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (ok == true) await _deleteManyDefinitive();
  }

  // export CSV
  Future<void> _exportCsv() async {
    if (_rows.isEmpty) return;
    final cols = _rows.first.keys.toList();
    final b = StringBuffer();
    b.writeln(cols.map(_csvEscape).join(','));
    for (final r in _rows) {
      b.writeln(cols.map((c) => _csvEscape('${r[c] ?? ''}')).join(','));
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copié (page courante).')),
    );
  }

  String _csvEscape(String v) {
    final needs = v.contains(',') || v.contains('"') || v.contains('\n');
    return needs ? '"${v.replaceAll('"', '""')}"' : v;
  }
}

class _Debouncer {
  _Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void run(VoidCallback f) {
    _t?.cancel();
    _t = Timer(delay, f);
  }
}
