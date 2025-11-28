import 'package:flutter/material.dart';

import '../../../models/job_models.dart';
import '../../../services/jobs_service.dart';
import '../../../utils/format.dart'; // <- gnf()
import '../candidatures_page.dart'; // navigation directe
import 'offre_edit_page.dart';
import 'profil_employeur_page.dart';

class MesOffresPage extends StatefulWidget {
  /// ID de l'employeur (servira à l'insertion/édition des offres)
  final String employeurId;
  const MesOffresPage({super.key, required this.employeurId});

  @override
  State<MesOffresPage> createState() => _MesOffresPageState();
}

class _MesOffresPageState extends State<MesOffresPage> {
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);
  static const kRed = Color(0xFFCE1126);
  static const kGreen = Color(0xFF009460);

  final _svc = JobsService();
  List<EmploiModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _svc.mesOffres();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les offres : $e')),
      );
    }
  }

  Future<void> _deleteOffer(EmploiModel job) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l’offre ?'),
        content: Text('« ${job.titre} » sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _svc.supprimerOffre(job.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == job.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offre supprimée')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e')),
      );
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
        title: const Text('Mes offres'),
        actions: [
          IconButton(
            tooltip: 'Profil entreprise',
            icon: const Icon(Icons.business),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilEmployeurPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => OffreEditPage(employeurId: widget.employeurId),
            ),
          );
          if (ok == true) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? _EmptyState(onCreate: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OffreEditPage(employeurId: widget.employeurId),
                    ),
                  );
                  if (ok == true) _load();
                })
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Sur grands écrans, on centre la colonne
                      final list = ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _OfferCard(
                          job: _items[i],
                          onOpenCandidatures: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CandidaturesPage(
                                  jobId: _items[i].id,
                                  jobTitle: _items[i].titre,
                                ),
                              ),
                            );
                          },
                          onEdit: () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OffreEditPage(
                                  existing: _items[i],
                                  employeurId: widget.employeurId,
                                ),
                              ),
                            );
                            if (ok == true) _load();
                          },
                          onDelete: () => _deleteOffer(_items[i]),
                        ),
                      );

                      if (constraints.maxWidth <= 720) {
                        return list;
                      }

                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: list,
                        ),
                      );
                    },
                  ),
                )),
    );
  }
}

/// ---------- Carte d’offre (responsive)
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.job,
    required this.onOpenCandidatures,
    required this.onEdit,
    required this.onDelete,
  });

  final EmploiModel job;
  final VoidCallback onOpenCandidatures;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _salaire() {
    final min = job.salMin;
    final max = job.salMax;
    if (min != null) {
      final base = max != null ? '${gnf(min)} - ${gnf(max)}' : gnf(min);
      return '$base / mois';
    }
    return 'À négocier';
  }

  bool _isActive(EmploiModel j) {
    try {
      final dynamic any = j;
      final v = (any as dynamic).actif;
      if (v is bool) return v;
      if (v is int) return v == 1;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';
    } catch (_) {}
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final statutActif = _isActive(job);
    final statusColor =
        statutActif ? _MesOffresPageState.kGreen : Colors.black54;
    final statusText = statutActif ? 'Active' : 'Inactive';

    final sousTitre =
        '${job.ville}${job.commune != null && job.commune!.isNotEmpty ? ', ${job.commune}' : ''} • ${job.typeContrat.toUpperCase()}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpenCandidatures,
        onLongPress: onEdit,
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
                backgroundColor: _MesOffresPageState.kBlue,
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
                            job.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(text: statusText, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Sous-titre (ville + contrat)
                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),

                    // Ligne responsive salaire + actions
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isVeryNarrow = constraints.maxWidth < 320;

                        if (isVeryNarrow) {
                          // Petits écrans : pill au dessus, actions en dessous
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Pill(text: _salaire()),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: onEdit,
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red.shade700,
                                    onPressed: onDelete,
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ],
                          );
                        }

                        // Écrans "normaux" : tout sur une seule ligne
                        return Row(
                          children: [
                            Expanded(
                              child: _Pill(text: _salaire()),
                            ),
                            IconButton(
                              tooltip: 'Modifier',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: onEdit,
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red.shade700,
                              onPressed: onDelete,
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Colors.black12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

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
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

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
              Icon(Icons.work_outline,
                  size: 56, color: _MesOffresPageState.kBlue),
              SizedBox(height: 12),
              Text(
                'Aucune offre pour le moment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Créez votre première offre pour recevoir des candidatures.',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _MesOffresPageState.kBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Créer une offre'),
          ),
        ),
      ],
    );
  }
}
