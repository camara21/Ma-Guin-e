import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'job_detail_page.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  static const kBlue = Color(0xFF1976D2);
  static const kBg   = Color(0xFFF6F7F9);

  late Future<List<Map<String, dynamic>>> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  // ---------------- DATA ----------------
  Future<List<Map<String, dynamic>>> _load() async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return [];

    // 1) candidatures de l'utilisateur
    final cands = await sb
        .from('candidatures')
        .select('id, emploi_id, statut, cree_le')
        .eq('candidat_id', uid)
        .order('cree_le', ascending: false) as List;

    if (cands.isEmpty) return [];

    final emploiIds = cands
        .map((e) => (e['emploi_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    // 2) emplois liés
    List emplois = [];
    if (emploiIds.isNotEmpty) {
      final inList = '(${emploiIds.map((e) => '"$e"').join(',')})';
      emplois = await sb
          .from('emplois')
          .select('id, titre, ville, type_contrat, employeur_id, cree_le')
          .filter('id', 'in', inList) as List;
    }

    final emploiById = <String, Map<String, dynamic>>{};
    for (final e in emplois) {
      final m = Map<String, dynamic>.from(e);
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty) emploiById[id] = m;
    }

    // 3) employeurs liés
    final empIds = emploiById.values
        .map((m) => (m['employeur_id'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final empById = <String, Map<String, dynamic>>{};
    if (empIds.isNotEmpty) {
      final inList = '(${empIds.map((e) => '"$e"').join(',')})';
      final emps = await sb
          .from('employeurs')
          .select('id, nom, logo_url')
          .filter('id', 'in', inList) as List?;
      for (final e in (emps ?? const [])) {
        final m = Map<String, dynamic>.from(e);
        final id = (m['id'] ?? '').toString();
        if (id.isNotEmpty) empById[id] = m;
      }
    }

    // 4) merge final
    final out = <Map<String, dynamic>>[];
    for (final c in cands) {
      final cand = Map<String, dynamic>.from(c as Map);
      final job  = emploiById[(cand['emploi_id'] ?? '').toString()];
      if (job == null) continue;
      final emp  = empById[(job['employeur_id'] ?? '').toString()];

      out.add({
        'candidature_id': cand['id'],
        'statut': (cand['statut'] ?? '').toString(),
        'date_cand': cand['cree_le'],
        'emploi_id': job['id'],
        'titre': job['titre'] ?? '',
        'ville': job['ville'] ?? '',
        'type_contrat': job['type_contrat'] ?? '',
        'employeur_nom': emp?['nom'] ?? '',
        'logo_url': emp?['logo_url'] ?? '',
        'cree_le': job['cree_le'], // si besoin d'afficher la date de l'offre
      });
    }

    return out;
  }

  // ---------------- UI HELPERS ----------------
  String _subtitle(Map<String, dynamic> m) {
    final v = (m['ville'] ?? '').toString();
    final t = (m['type_contrat'] ?? '').toString().toUpperCase();
    if (v.isEmpty && t.isEmpty) return '';
    if (v.isEmpty) return t;
    if (t.isEmpty) return v;
    return '$v • $t';
  }

  // relative time: min / h / j — pour la date de candidature
  String _formatRelative(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      final diff = DateTime.now().toLocal().difference(d);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours   < 24) return 'il y a ${diff.inHours} h';
      if (diff.inDays    < 7)  return 'il y a ${diff.inDays} j';
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  // normalisation simple (sans package supplémentaire) pour matcher les statuts FR
  String _norm(String s) {
    final lower = s.trim().toLowerCase();
    return lower
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ûùü]'), 'u');
  }

  // Renvoie (label, bg, fg) selon le statut
  ({String label, Color bg, Color fg}) _statusStyle(String? raw) {
    final s = _norm(raw ?? '');
    // accepté
    if (s.contains('accep')) {
      return (label: 'Acceptée', bg: const Color(0xFFE8F5E9), fg: const Color(0xFF2E7D32));
    }
    // refusé
    if (s.contains('refus') || s.contains('rejet')) {
      return (label: 'Refusée', bg: const Color(0xFFFFEBEE), fg: const Color(0xFFC62828));
    }
    // en cours / pending (par défaut)
    if (s.contains('cours') || s.contains('pend') || s.isEmpty) {
      return (label: 'En cours', bg: const Color(0xFFFFF8E1), fg: const Color(0xFFF9A825));
    }
    // fallback neutre
    return (label: raw?.isNotEmpty == true ? raw! : 'En cours',
            bg: Colors.black.withOpacity(.05),
            fg: Colors.black87);
  }

  Widget _statusChip(String? raw) {
    final st = _statusStyle(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(st.label, style: TextStyle(fontSize: 12, color: st.fg, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text('Mes candidatures'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Erreur de chargement : ${snap.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fact_check_rounded, color: kBlue, size: 52),
                      SizedBox(height: 10),
                      Text('Aucune candidature trouvée',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text(
                        'Quand vous postulerez à une offre, elle apparaîtra ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final m = items[i];
              final jobId   = (m['emploi_id'] ?? '').toString();
              final hasLogo = (m['logo_url'] ?? '').toString().trim().isNotEmpty;
              final subtitle = _subtitle(m);
              final relDate  = _formatRelative(m['date_cand']);

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: jobId.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)),
                          ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if (hasLogo)
                          CircleAvatar(radius: 20, backgroundImage: NetworkImage(m['logo_url']))
                        else
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: kBlue,
                            child: Icon(Icons.work_outline, color: Colors.white),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['titre'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              if ((m['employeur_nom'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(m['employeur_nom'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black54)),
                              ],
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black54)),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _statusChip(m['statut']),
                                  const SizedBox(width: 10),
                                  if (relDate.isNotEmpty)
                                    Text(
                                      relDate,
                                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                                    ),
                                ],
                              ),
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
          );
        },
      ),
    );
  }
}
