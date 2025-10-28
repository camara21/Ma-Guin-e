// lib/pages/billetterie/pro_ventes_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Palette Billetterie
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

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

      // Récupère l’ID organisateur
      final orgRaw = await _sb
          .from('organisateurs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) throw 'Profil organisateur manquant.';
      final String orgId = orgList.first['id'].toString();

      // Stats par événement (vue ou table agrégée evenements_stats)
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
    final nf = NumberFormat.decimalPattern('fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Ventes & Statistiques'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _rows.isEmpty
                  ? const Center(child: Text('Aucune donnée de vente disponible.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final e = _rows[i];

                          final titre = (e['titre'] ?? '').toString();
                          final ville = (e['ville'] ?? '').toString();
                          final lieu  = (e['lieu'] ?? '').toString();

                          final rawDeb = e['date_debut']?.toString();
                          final DateTime? dDeb = rawDeb != null ? DateTime.tryParse(rawDeb) : null;
                          final rawFin = e['date_fin']?.toString();
                          final DateTime? dFin = rawFin != null ? DateTime.tryParse(rawFin) : null;
                          final dfShort = DateFormat('EEE d MMM • HH:mm', 'fr_FR');
                          final dateTxt = dDeb != null
                              ? dfShort.format(dDeb) +
                                  (dFin != null ? ' → ${DateFormat('HH:mm').format(dFin)}' : '')
                              : '';

                          final reserves = (e['billets_reserves'] as num?)?.toInt() ?? 0;
                          final utilises = (e['billets_utilises'] as num?)?.toInt() ?? 0;
                          final ventes   = (e['total_ventes_gnf'] as num?)?.toInt() ?? 0;
                          final capacity = (e['capacité'] as num?)?.toInt() ?? (reserves + utilises);
                          final pct = capacity > 0 ? (reserves / capacity) : 0.0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0x1F000000)),
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
                                // Titre
                                Text(
                                  titre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Métadonnées
                                Row(
                                  children: [
                                    const Icon(Icons.place, size: 16, color: _kEventPrimary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$lieu • $ville',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (dateTxt.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 16, color: _kEventPrimary),
                                      const SizedBox(width: 6),
                                      Text(dateTxt),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),

                                // Barre de progression (remplissage des réservations vs capacité)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0, 1),
                                    minHeight: 8,
                                    backgroundColor: _kEventPrimary.withOpacity(.12),
                                    valueColor: const AlwaysStoppedAnimation(_kEventPrimary),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Remplissage: ${(pct * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.black54),
                                ),

                                const SizedBox(height: 12),

                                // Chips stats
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _statChip('Réservés', nf.format(reserves),
                                        bg: _kEventPrimary.withOpacity(.10),
                                        fg: _kEventPrimary),
                                    _statChip('Utilisés', nf.format(utilises),
                                        bg: const Color(0xFF2E7D32).withOpacity(.10),
                                        fg: const Color(0xFF2E7D32)),
                                    _statChip('Ventes (GNF)', nf.format(ventes),
                                        bg: const Color(0xFF1E88E5).withOpacity(.10),
                                        fg: const Color(0xFF1E88E5)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _statChip(
    String label,
    String value, {
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.2)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: fg, fontSize: 13),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
