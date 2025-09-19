import 'package:flutter/material.dart';
import '../../services/jobs_service.dart';
import 'job_detail_page.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  // 🎨 Palette Home Jobs
  static const kBlue   = Color(0xFF1976D2);
  static const kBg     = Color(0xFFF6F7F9);
  static const kRed    = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen  = Color(0xFF009460);

  final _sb = JobsService().sb;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _sb
          .from('candidatures')
          .select('*, emplois(id, titre, ville, commune, type_contrat)')
          .order('cree_le', ascending: false);

      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
      );
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = d is DateTime ? d : DateTime.parse(d.toString());
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final da = dt.day.toString().padLeft(2, '0');
      return '$da/$m/$y';
    } catch (_) {
      final s = d.toString();
      return s.length >= 10 ? s.substring(0, 10) : s;
    }
  }

  (String, Color) _statutLabelColor(String? s) {
    final v = (s ?? '').toLowerCase();
    if (v == 'acceptee' || v == 'acceptée') return ('Acceptée', kGreen);
    if (v == 'refusee'  || v == 'refusée')  return ('Refusée', kRed);
    if (v == 'en_cours' || v == 'en cours' || v == 'en attente') return ('En cours', kYellow);
    return (s == null || s.isEmpty ? 'En cours' : s, Colors.black54);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: const Text('Mes candidatures'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? const _EmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      final j = (c['emplois'] is Map)
                          ? Map<String, dynamic>.from(c['emplois'])
                          : <String, dynamic>{};

                      final titre   = (j['titre'] ?? 'Offre inconnue').toString();
                      final ville   = (j['ville'] ?? '').toString();
                      final commune = (j['commune'] ?? '').toString();
                      final contrat = (j['type_contrat'] ?? '').toString();
                      final contratUp = contrat.isNotEmpty ? contrat.toUpperCase() : '';

                      final statutRaw = (c['statut'] ?? '').toString();
                      final (statutLabel, statutColor) = _statutLabelColor(statutRaw);

                      final dateStr = _formatDate(c['cree_le']);
                      final emploiId = c['emploi_id']?.toString();

                      final sousTitre = [
                        if (ville.isNotEmpty) ville + (commune.isNotEmpty ? ', $commune' : ''),
                        if (contratUp.isNotEmpty) contratUp,
                        if (dateStr.isNotEmpty) dateStr,
                      ].join(' • ');

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: emploiId == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => JobDetailPage(jobId: emploiId),
                                    ),
                                  ),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: kBlue,
                                  child: Icon(Icons.work_outline, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Titre + statut
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              titre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _StatusChip(text: statutLabel, color: statutColor),
                                        ],
                                      ),
                                      if (sousTitre.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          sousTitre,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )),
    );
  }
}

/// ---------- Composants UI

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(.45))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: const [
              Icon(Icons.assignment_turned_in_outlined, size: 56, color: _MyApplicationsPageState.kBlue),
              SizedBox(height: 12),
              Text(
                'Aucune candidature trouvée',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Quand vous postulerez à une offre, elle apparaîtra ici.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
