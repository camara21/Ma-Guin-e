import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes.dart';

class VtcCoursesPlanifieesPage extends StatefulWidget {
  const VtcCoursesPlanifieesPage({super.key});

  @override
  State<VtcCoursesPlanifieesPage> createState() => _VtcCoursesPlanifieesPageState();
}

class _VtcCoursesPlanifieesPageState extends State<VtcCoursesPlanifieesPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  String get _me => _sb.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_me.isEmpty) {
      setState(() {
        _loading = false;
        _items = [];
      });
      return;
    }
    setState(() => _loading = true);

    dynamic rows;

    try {
      // 1) Table `courses` + statut planifié + date "rdv_a" future
      final nowIso = DateTime.now().toUtc().toIso8601String();
      rows = await _sb
          .from('courses')
          .select('id, chauffeur_id, statut, depart_adresse, arrivee_adresse, prix_gnf, rdv_a, demande_a')
          .eq('chauffeur_id', _me)
          .or('statut.eq.planifiee,statut.eq.programmée,statut.eq.scheduled')
          .gte('rdv_a', nowIso)
          .order('rdv_a', ascending: true);
    } catch (_) {
      try {
        // 2) Même chose mais la date s’appelle "date_heure" ou "horaire"
        rows = await _sb
            .from('courses')
            .select('id, chauffeur_id, statut, depart_adresse, arrivee_adresse, prix_gnf, date_heure, horaire, demande_a')
            .eq('chauffeur_id', _me)
          
            .or('statut.eq.planifiee,statut.eq.programmée,statut.eq.scheduled')
            .order('date_heure', ascending: true);
      } catch (_) {
        try {
          // 3) Table dédiée `courses_planifiees`
          rows = await _sb
              .from('courses_planifiees')
              .select('id, chauffeur_id, depart_adresse, arrivee_adresse, prix_gnf, date_heure')
              .eq('chauffeur_id', _me)
              .order('date_heure', ascending: true);
        } catch (_) {
          rows = [];
        }
      }
    }

    final list = (rows as List?) ?? [];
    setState(() {
      _items = list.map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  String _fmtGNF(num? v) {
    if (v == null) return '-';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remain = s.length - i - 1;
      buf.write(s[i]);
      if (remain > 0 && remain % 3 == 0) buf.write(' ');
    }
    return '${buf.toString()} GNF';
  }

  DateTime? _firstDate(Map<String, dynamic> m) {
    for (final k in ['rdv_a', 'date_heure', 'horaire', 'demande_a']) {
      final v = m[k];
      if (v is String && v.isNotEmpty) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt.toLocal();
      }
    }
    return null;
  }

  void _openSuivi(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.pushNamed(context, AppRoutes.vtcSuivi, arguments: {'courseId': id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courses planifiées')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 40),
                      Center(child: Text('Aucune course planifiée.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemBuilder: (_, i) {
                      final m = _items[i];
                      final when = _firstDate(m);
                      final dateStr = when == null
                          ? 'Date à confirmer'
                          : '${_pad(when.day)}/${_pad(when.month)} • ${_pad(when.hour)}:${_pad(when.minute)}';
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1.5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.1),
                            child: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text('${m['depart_adresse'] ?? '-'} → ${m['arrivee_adresse'] ?? '-'}',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('$dateStr • ${_fmtGNF(m['prix_gnf'] as num?)}'),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _openSuivi(m),
                            child: const Text('Détails'),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: _items.length,
                  )),
      ),
    );
  }

  static String _pad(int v) => v < 10 ? '0$v' : '$v';
}
