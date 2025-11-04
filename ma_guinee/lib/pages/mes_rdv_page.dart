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

  // Onglets: avenir | passees | annules  (défaut: avenir)
  String _scope = 'avenir';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _svc.mesRdv(); // récupère tous les RDV de l'utilisateur
      if (!mounted) return;

      final now = DateTime.now();

      bool _isCancelled(Rdv r) =>
          r.statut == 'annule' || r.statut == 'annule_clinique';

      // ✅ "Passés" = on commence à compter après l'heure de RDV : now > startAt + 5h
      bool _isPast(Rdv r) =>
          !_isCancelled(r) && r.startAt.add(const Duration(hours: 5)).isBefore(now);

      // ✅ "À venir" = non annulé ET pas "Passés"
      bool _isFuture(Rdv r) => !_isCancelled(r) && !_isPast(r);

      List<Rdv> filtered;
      if (_scope == 'annules') {
        filtered = data.where(_isCancelled).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt)); // chrono
      } else if (_scope == 'passees') {
        filtered = data.where(_isPast).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt)); // récents d'abord
      } else {
        // avenir
        filtered = data.where(_isFuture).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt)); // chrono
      }

      setState(() {
        _rdv = filtered;
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

  // --- Helpers d'affichage pour le statut ---
  bool _isCancelledStatut(String statut) =>
      statut == 'annule' || statut == 'annule_clinique';

  bool _isPastRdv(Rdv r) =>
      !_isCancelledStatut(r.statut) &&
      r.startAt.add(const Duration(hours: 5)).isBefore(DateTime.now());

  /// Texte affiché dans le chip
  String _displayStatus(Rdv r) {
    if (_isCancelledStatut(r.statut)) return 'annulé';
    if (_isPastRdv(r)) return 'passé';
    if (r.statut == 'en_attente') return 'en attente';
    return 'confirmé';
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
      body: Column(
        children: [
          // Onglets filtres (3 onglets)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'avenir',  label: Text('À venir')),
                    ButtonSegment(value: 'passees', label: Text('Passés')),
                    ButtonSegment(value: 'annules', label: Text('Annulés')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) {
                    setState(() => _scope = s.first);
                    _load();
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rafraîchir',
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: kHealthGreen),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
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
                            final end = DateFormat('HH:mm', 'fr_FR').format(r.endAt);

                            final cancelled = _isCancelledStatut(r.statut);
                            final past = _isPastRdv(r);
                            final greyOut = cancelled || past;

                            // 🔹 On ne montre JAMAIS "Annuler" dans les onglets Passés/Annulés.
                            // 🔹 Dans "À venir" seulement si le RDV est encore annulable.
                            final bool annulableDansAvenir =
                                (_scope == 'avenir') &&
                                !greyOut &&
                                (r.statut == 'confirme' || r.statut == 'en_attente');

                            return Opacity(
                              opacity: greyOut ? 0.55 : 1.0, // griser les passés/annulés
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.event_available,
                                    color: greyOut ? Colors.grey : kHealthGreen,
                                  ),
                                  title: Text(
                                    '$start → $end',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: greyOut ? Colors.grey.shade700 : null,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [_statusChip(_displayStatus(r))]),
                                        if ((r.motif?.trim().isNotEmpty ?? false))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Motif : ${r.motif!.trim()}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: greyOut ? Colors.grey.shade700 : null,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: annulableDansAvenir
                                      ? TextButton.icon(
                                          onPressed: () => _cancel(r.id),
                                          icon: const Icon(Icons.cancel_outlined),
                                          label: const Text('Annuler'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red.shade700,
                                          ),
                                        )
                                      : null, // 👈 rien du tout dans Passés/Annulés (et si non annulable)
                                ),
                              ),
                            );
                          },
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String displayStatut) {
    // Couleurs selon le libellé d'affichage
    Color bg, border, txt;
    switch (displayStatut) {
      case 'confirmé':
        bg = kHealthGreen.withOpacity(.12);
        border = kHealthGreen.withOpacity(.3);
        txt = kHealthGreen;
        break;
      case 'annulé':
        bg = Colors.red.withOpacity(.10);
        border = Colors.red.withOpacity(.25);
        txt = Colors.red.shade700;
        break;
      case 'en attente':
        bg = kHealthYellow.withOpacity(.18);
        border = kHealthYellow.withOpacity(.35);
        txt = const Color(0xFF7A6A00);
        break;
      case 'passé': // style "passé"
      default:
        bg = Colors.grey.withOpacity(.15);
        border = Colors.grey.withOpacity(.35);
        txt = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: border),
      ),
      child: Text(
        displayStatut,
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
                'Aucun rendez-vous trouvé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
}
