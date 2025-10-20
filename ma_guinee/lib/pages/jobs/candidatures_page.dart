// lib/pages/jobs/employer/candidatures_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'candidature_detail_page.dart';

class CandidaturesPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  const CandidaturesPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<CandidaturesPage> createState() => _CandidaturesPageState();
}

class _CandidaturesPageState extends State<CandidaturesPage> {
  // Thème app
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kYellow = Color(0xFFFCD116);
  static const kGreen = Color(0xFF009460);

  final _sb = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('candidatures')
          .select(
            'id, prenom, nom, telephone, email, lettre, cv_url, cv_is_public, cree_le, statut',
          )
          .eq('emploi_id', widget.jobId)
          .order('cree_le', ascending: false);

      _items = (rows as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _toast('Chargement impossible : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Met à jour le statut
  Future<void> _changeStatus(String id, String newStatut) async {
    try {
      await _sb.from('candidatures').update({'statut': newStatut}).eq('id', id);
      final i = _items.indexWhere((e) => (e['id']?.toString() ?? '') == id);
      if (i != -1) setState(() => _items[i]['statut'] = newStatut);
      _toast('Statut mis à jour : ${_label(newStatut)}');
    } catch (e) {
      _toast('Mise à jour du statut impossible : $e');
    }
  }

  String _displayName(Map<String, dynamic> c) {
    final prenom = (c['prenom'] ?? '').toString().trim();
    final nom = (c['nom'] ?? '').toString().trim();
    final t = ([prenom, nom]..removeWhere((s) => s.isEmpty)).join(' ');
    if (t.isNotEmpty) return t;
    final tel = (c['telephone'] ?? '').toString().trim();
    return tel.isNotEmpty ? tel : 'Candidat';
  }

  String _dateStr(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '';
    }
  }

  // Couleur & libellé pour la pastille de statut
  Color _color(String s) {
    switch (s.toLowerCase()) {
      case 'refusee':
        return kRed;
      case 'acceptee':
        return kGreen;
      case 'en_cours':
      case 'en cours':
        return kYellow;
      case 'envoyee':
      default:
        return kBlue;
    }
  }

  String _label(String s) {
    switch (s.toLowerCase()) {
      case 'refusee':
        return 'Refusée';
      case 'acceptee':
        return 'Acceptée';
      case 'en_cours':
      case 'en cours':
        return 'En cours';
      case 'envoyee':
      default:
        return 'Envoyée';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: Text(
          'Candidatures – ${widget.jobTitle}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final c = _items[i];
                  final id = (c['id'] ?? '').toString();
                  final name = _displayName(c);
                  final tel = (c['telephone'] ?? '').toString();
                  final email = (c['email'] ?? '').toString();
                  final date = _dateStr((c['cree_le'] ?? '').toString());
                  final statut = (c['statut'] ?? '').toString();

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CandidatureDetailPage(
                              candidature: Map<String, dynamic>.from(c),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: kBlue,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _StatutPill(
                                        color: _color(statut),
                                        label: _label(statut),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  if (date.isNotEmpty)
                                    Text(
                                      date,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (tel.isNotEmpty)
                                        _MiniChip(icon: Icons.phone, text: tel),
                                      if (email.isNotEmpty)
                                        _MiniChip(
                                          icon: Icons.email_outlined,
                                          text: email,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // actions
                            PopupMenuButton<String>(
                              tooltip: 'Actions',
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black45),
                              onSelected: (v) => _changeStatus(id, v),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'acceptee',
                                  child: _MenuRow(
                                    icon: Icons.check_circle_outline,
                                    color: kGreen,
                                    text: 'Marquer "Acceptée"',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'en_cours',
                                  child: _MenuRow(
                                    icon: Icons.timelapse,
                                    color: kYellow,
                                    text: 'Marquer "En cours"',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'refusee',
                                  child: _MenuRow(
                                    icon: Icons.cancel_outlined,
                                    color: kRed,
                                    text: 'Marquer "Refusée"',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color),
      const SizedBox(width: 8),
      Text(text),
    ]);
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatutPill extends StatelessWidget {
  const _StatutPill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
