// lib/pages/sante_rdv_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/rdv_service.dart';

const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen  = Color(0xFF009460);

class SanteRdvPage extends StatefulWidget {
  final int cliniqueId;
  final String cliniqueName;
  final String? phone;
  final String? address;
  final String? coverImage;
  final Color primaryColor;

  const SanteRdvPage({
    super.key,
    required this.cliniqueId,
    required this.cliniqueName,
    this.phone,
    this.address,
    this.coverImage,
    this.primaryColor = kHealthGreen,
  });

  @override
  State<SanteRdvPage> createState() => _SanteRdvPageState();
}

class _SanteRdvPageState extends State<SanteRdvPage> {
  final _svc = RdvService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  List<SlotDispo> _slots = [];
  bool _loading = true;

  /// Empêche une double réservation dans la même clinique
  bool _hasExistingRdvInClinic = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final slotsF = _svc.slotsPourClinique(widget.cliniqueId);
      final rdvF   = _svc.mesRdv();

      final results = await Future.wait([slotsF, rdvF]);

      final slots = results[0] as List<SlotDispo>;
      final rdvs  = results[1] as List<Rdv>;

      // On bloque si l’utilisateur a déjà un RDV futur et actif dans cette clinique.
      // (on ignore 'annule' et 'annule_clinique', et les RDV passés)
      final now = DateTime.now();
      final hasOne = rdvs.any((r) =>
        r.cliniqueId == widget.cliniqueId &&
        (r.statut != 'annule' && r.statut != 'annule_clinique') &&
        r.endAt.isAfter(now)
      );

      if (!mounted) return;
      setState(() {
        _slots = slots;
        _hasExistingRdvInClinic = hasOne;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _book(SlotDispo s) async {
    if (_formKey.currentState?.validate() != true) return;

    // Sécurité anti double-réservation pour cette clinique
    if (_hasExistingRdvInClinic) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous avez déjà pris un rendez-vous avec cette clinique.\n'
            'Vous ne pouvez pas réserver un second rendez-vous.\n'
            'Annulez le rendez-vous existant pour replanifier.',
          ),
        ),
      );
      return;
    }

    // Sécurité : créneau verrouillé par la clinique ?
    if (s is SlotDispo && (s.lockedByClinic)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce créneau a été verrouillé par la clinique.')),
      );
      return;
    }

    try {
      await _svc.prendreRdv(
        cliniqueId: widget.cliniqueId,
        slot: s,
        motif: _motifCtrl.text.trim().isEmpty ? null : _motifCtrl.text.trim(),
        patientNom: _nameCtrl.text.trim(),
        patientTel: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre rendez-vous est confirmé.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Map<String, List<SlotDispo>> _groupByDay(List<SlotDispo> items) {
    final map = <String, List<SlotDispo>>{};
    for (final s in items) {
      final k = DateFormat('EEEE d MMMM y', 'fr_FR').format(s.startAt);
      (map[k] ??= []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.primaryColor;

    return Scaffold(
      // ===== AppBar “santé” (fond blanc, contenu vert) =====
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: kHealthGreen,
        iconTheme: const IconThemeData(color: kHealthGreen),
        actionsIconTheme: const IconThemeData(color: kHealthGreen),
        centerTitle: true,
        title: Text(
          "Rendez-vous • ${widget.cliniqueName}",
          style: const TextStyle(
            color: kHealthGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // Alerte si déjà un RDV dans la clinique
                if (_hasExistingRdvInClinic)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kHealthYellow.withOpacity(.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kHealthYellow.withOpacity(.35)),
                    ),
                    child: const Text(
                      "Vous avez déjà pris un rendez-vous avec cette clinique.\n"
                      "Pour reprendre un rendez-vous, annulez d’abord le rendez-vous existant.",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                // En-tête clinique
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.withOpacity(.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.withOpacity(.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.cliniqueName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      if ((widget.address ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on, size: 18, color: kHealthYellow),
                          const SizedBox(width: 6),
                          Expanded(child: Text(widget.address!)),
                        ]),
                      ],
                      if ((widget.phone ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.call, size: 18, color: kHealthYellow),
                          const SizedBox(width: 6),
                          Text(widget.phone!),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Formulaire patient
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nom et prénom",
                        filled: true,
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2) ? "Votre nom" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Téléphone",
                        filled: true,
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 6) ? "Votre numéro" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _motifCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Motif (envoyé au praticien)",
                        filled: true,
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),

                // Créneaux style Doctolib
                Text("Choisissez la date de consultation",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: c, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                if (_slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Aucun créneau disponible pour le moment.\nRevenez plus tard ou appelez la clinique.",
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ..._groupByDay(_slots).entries.map((e) {
                    final jour = e.key;
                    final slots = e.value..sort((a,b)=>a.startAt.compareTo(b.startAt));
                    final visible = slots.length > 6 ? slots.sublist(0, 6) : slots;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Text(jour, style: const TextStyle(fontWeight: FontWeight.w600)),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            children: [
                              Wrap(
                                spacing: 10, runSpacing: 10,
                                children: visible.map((s) {
                                  final label = DateFormat('HH:mm', 'fr_FR').format(s.startAt);
                                  final restant = s.placesRestantes ?? s.maxPatients;

                                  // Désactivé si complet, verrouillé par clinique, ou si user a déjà un RDV ici
                                  final disabled = (restant <= 0) || (s.lockedByClinic) || _hasExistingRdvInClinic;

                                  return SizedBox(
                                    height: 42,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: s.lockedByClinic
                                            ? Colors.grey.shade200
                                            : const Color(0xFFEFF6FB),
                                        foregroundColor: Colors.black87,
                                        side: BorderSide(
                                          color: s.lockedByClinic
                                              ? Colors.grey.shade400
                                              : kHealthGreen.withOpacity(.25),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: disabled ? null : () => _book(s),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(label),
                                          if (s.lockedByClinic) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.block, size: 16, color: Colors.grey),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (slots.length > 6) ...[
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        showDragHandle: true,
                                        builder: (_) => _AllSlotsSheet(
                                          dayLabel: jour,
                                          slots: slots,
                                          canBook: !_hasExistingRdvInClinic,
                                          onPick: (s) { Navigator.pop(context); _book(s); },
                                        ),
                                      );
                                    },
                                    child: const Text("VOIR PLUS"),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

/// Feuille qui affiche tous les créneaux d’un jour
class _AllSlotsSheet extends StatelessWidget {
  final String dayLabel;
  final List<SlotDispo> slots;
  final bool canBook;
  final ValueChanged<SlotDispo> onPick;

  const _AllSlotsSheet({
    required this.dayLabel,
    required this.slots,
    required this.canBook,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...slots]..sort((a,b)=>a.startAt.compareTo(b.startAt));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, color: kHealthGreen),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: sorted.map((s) {
              final label = DateFormat('HH:mm', 'fr_FR').format(s.startAt);
              final restant = s.placesRestantes ?? s.maxPatients;

              final disabled = (restant <= 0) || s.lockedByClinic || !canBook;

              return SizedBox(
                height: 42,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: s.lockedByClinic
                        ? Colors.grey.shade200
                        : const Color(0xFFEFF6FB),
                    foregroundColor: Colors.black87,
                    side: BorderSide(
                      color: s.lockedByClinic
                          ? Colors.grey.shade400
                          : kHealthGreen.withOpacity(.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: disabled ? null : () => onPick(s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (s.lockedByClinic) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.block, size: 16, color: Colors.grey),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          )
        ],
      ),
    );
  }
}
