import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/rdv_service.dart';

const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen  = Color(0xFF009460);

class MesRdvPage extends StatefulWidget {
  const MesRdvPage({super.key});

  @override
  State<MesRdvPage> createState() => _MesRdvPageState();
}

class _MesRdvPageState extends State<MesRdvPage> {
  final _svc = RdvService();
  List<Rdv> _rdv = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _svc.mesRdv(); // récupère aussi les annulés
      if (!mounted) return;
      setState(() {
        // Masquer les RDV annulés
        _rdv = data.where((r) => r.statut != 'annule' && r.statut != 'annule_clinique').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _cancel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l’annulation'),
        content: const Text('Souhaitez-vous vraiment annuler ce rendez-vous ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Oui')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _svc.annulerRdv(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('RDV annulé')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: kHealthGreen,
        iconTheme: const IconThemeData(color: kHealthGreen),
        actionsIconTheme: const IconThemeData(color: kHealthGreen),
        centerTitle: true,
        title: const Text(
          'Mes rendez-vous',
          style: TextStyle(
            color: kHealthGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_rdv.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  color: kHealthGreen,
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: _rdv.length,
                    itemBuilder: (_, i) {
                      final r = _rdv[i];
                      final start = DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(r.startAt);
                      final end   = DateFormat('HH:mm', 'fr_FR').format(r.endAt);
                      final statut = r.statut;
                      final motif = r.motif?.trim();

                      final cancellable = statut == 'confirme' || statut == 'en_attente';

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.event_available, color: kHealthGreen),
                          title: Text(
                            '$start → $end',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [_statusChip(statut)]),
                                if (motif != null && motif.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Motif : $motif',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: cancellable
                              ? TextButton.icon(
                                  onPressed: () => _cancel(r.id),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Annuler'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                )),
    );
  }

  Widget _statusChip(String statut) {
    Color bg, border, txt;
    if (statut == 'confirme') {
      bg = kHealthGreen.withOpacity(.12);
      border = kHealthGreen.withOpacity(.3);
      txt = kHealthGreen;
    } else if (statut == 'annule' || statut == 'annule_clinique') {
      bg = Colors.red.withOpacity(.10);
      border = Colors.red.withOpacity(.25);
      txt = Colors.red.shade700;
    } else {
      bg = kHealthYellow.withOpacity(.18);
      border = kHealthYellow.withOpacity(.35);
      txt = const Color(0xFF7A6A00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: border),
      ),
      child: Text(
        statut,
        style: TextStyle(
          color: txt,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.event_busy, size: 42, color: kHealthGreen),
              SizedBox(height: 10),
              Text(
                'Aucun rendez-vous actif pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
}
