import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProVentesPage extends StatefulWidget {
  const ProVentesPage({super.key});

  @override
  State<ProVentesPage> createState() => _ProVentesPageState();
}

class _ProVentesPageState extends State<ProVentesPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
      final user = _sb.auth.currentUser;
      if (user == null) throw 'Veuillez vous connecter.';
      final orgRaw = await _sb
          .from('organisateurs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) throw 'Profil organisateur manquant.';
      final String orgId = orgList.first['id'].toString();

      final rowsRaw = await _sb
          .from('evenements_stats')
          .select('*')
          .eq('organisateur_id', orgId)
          .order('date_debut', ascending: false);

      _rows = (rowsRaw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.decimalPattern('fr_FR');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Ventes & Statistiques'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _rows.isEmpty
                  ? const Center(child: Text('Aucune donnée de vente disponible.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final e = _rows[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.secondary.withOpacity(.12)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (e['titre'] ?? '').toString(),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text('${e['ville'] ?? ''} • ${e['lieu'] ?? ''}'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _chip(context, 'Réservés',
                                      nf.format(e['billets_reserves'] ?? 0)),
                                  _chip(context, 'Utilisés',
                                      nf.format(e['billets_utilises'] ?? 0)),
                                  _chip(context, 'Ventes (GNF)',
                                      nf.format(e['total_ventes_gnf'] ?? 0)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text('$label : $value'),
      backgroundColor: cs.secondary.withOpacity(.12),
      labelStyle: TextStyle(color: cs.onSecondaryContainer),
      side: BorderSide(color: cs.secondary.withOpacity(.2)),
    );
  }
}
