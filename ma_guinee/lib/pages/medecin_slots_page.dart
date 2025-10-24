import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/rdv_service.dart';

const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen  = Color(0xFF009460);

class MedecinSlotsPage extends StatefulWidget {
  final int cliniqueId;
  final String titre;
  const MedecinSlotsPage({
    super.key,
    required this.cliniqueId,
    required this.titre,
  });

  @override
  State<MedecinSlotsPage> createState() => _MedecinSlotsPageState();
}

class _MedecinSlotsPageState extends State<MedecinSlotsPage> {
  final _svc = RdvService();

  // Fenêtre de génération (hebdo)
  DateTime _from = DateTime.now().add(const Duration(days: 1));
  DateTime _to   = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 17, minute: 0);
  int _capacity = 1;
  final Set<int> _days = {1,2,3,4,5}; // lun→ven

  // Données
  List<SlotDispo> _slots = [];
  List<Rdv> _rdv = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    final slots = await _svc.slotsPourClinique(widget.cliniqueId, windowDays: 90);
    final rdv   = await _svc.rdvPourClinique(widget.cliniqueId);
    if (!mounted) return;
    setState(() {
      _slots = slots..sort((a,b)=>a.startAt.compareTo(b.startAt));
      _rdv   = rdv;
      _loading = false;
    });
  }

  // ----- Pickers -----
  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (p != null) setState(() => _from = p);
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (p != null) setState(() => _to = p);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Heure début' : 'Heure fin',
      builder: (context, child) {
        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
        return MediaQuery(data: mq, child: child!);
      },
    );
    if (t != null) {
      setState(() {
        if (isStart) _start = t; else _end = t;
      });
    }
  }

  // ----- Actions -----
  Future<void> _generate() async {
    if (_to.isBefore(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date fin doit être ≥ date début.')),
      );
      return;
    }
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un jour.')),
      );
      return;
    }
    final count = await _svc.creerSlotsRecurrents(
      cliniqueId: widget.cliniqueId,
      fromDate: _from,
      toDate: _to,
      start: _start,
      end: _end,
      daysOfWeek: _days.toList(),
      durationMinutes: 30,
      capacityPerSlot: _capacity,
    );
    await _refreshAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$count créneaux créés.')));
  }

  // Suppression optimiste d’un créneau : retire visuellement, puis API.
  Future<void> _deleteSlot(String id) async {
    final idx = _slots.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final removed = _slots[idx];

    setState(() => _slots.removeAt(idx));

    try {
      await _svc.supprimerSlot(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _slots.insert(idx, removed)); // rollback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression : $e')),
      );
    }
  }

  // Annulation d’un RDV par la clinique (optimiste + confirmation)
  Future<void> _cancelRdvByClinic(Rdv r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text(
          'Le patient sera notifié si vous avez mis en place des notifications. '
          'Ce créneau redevient disponible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final i = _rdv.indexWhere((x) => x.id == r.id);
    if (i == -1) return;

    final old = _rdv[i];
    final newR = Rdv(
      id: old.id,
      patientId: old.patientId,
      cliniqueId: old.cliniqueId,
      slotId: old.slotId,
      startAt: old.startAt,
      endAt: old.endAt,
      statut: 'annule',
      motif: old.motif,
      noteClinique: old.noteClinique,
      patientNom: old.patientNom,
      patientTel: old.patientTel,
      createdAt: old.createdAt,
    );

    setState(() => _rdv[i] = newR); // MAJ immédiate

    try {
      await _svc.annulerRdvParClinique(r.id);
      // pas de refresh global
    } catch (e) {
      if (!mounted) return;
      setState(() => _rdv[i] = old); // rollback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur annulation : $e')),
      );
    }
  }

  // Groupement par jour
  Map<DateTime, List<SlotDispo>> _groupByDay(List<SlotDispo> slots) {
    final map = <DateTime, List<SlotDispo>>{};
    for (final s in slots) {
      final key = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
      (map[key] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a,b)=>a.startAt.compareTo(b.startAt));
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k : map[k]!};
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final c = kHealthGreen;

    return Scaffold(
      // AppBar neutre (pas de bleu)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kHealthGreen),
        actionsIconTheme: const IconThemeData(color: kHealthGreen),
        title: Text(
          'Créneaux • ${widget.titre}',
          style: const TextStyle(
            color: kHealthGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Générer des créneaux (30 min / patient)',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: c, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                // Ligne dates
                Row(children: [
                  Expanded(child: _tile(
                    icon: Icons.today,
                    label: DateFormat('EEE d MMM', 'fr_FR').format(_from),
                    onTap: _pickFrom,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _tile(
                    icon: Icons.event,
                    label: DateFormat('EEE d MMM', 'fr_FR').format(_to),
                    onTap: _pickTo,
                  )),
                ]),
                const SizedBox(height: 8),

                // Ligne heures
                Row(children: [
                  Expanded(child: _tile(
                    icon: Icons.schedule,
                    label: _fmtTod(_start),
                    onTap: () => _pickTime(true),
                  )),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('→'),
                  ),
                  Expanded(child: _tile(
                    icon: Icons.schedule,
                    label: _fmtTod(_end),
                    onTap: () => _pickTime(false),
                  )),
                ]),
                const SizedBox(height: 8),

                // Jours de semaine
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    const labels = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
                    final day = i + 1; // 1..7
                    final selected = _days.contains(day);
                    return FilterChip(
                      selected: selected,
                      label: Text(labels[i]),
                      onSelected: (_) => setState(() {
                        if (selected) _days.remove(day); else _days.add(day);
                      }),
                      selectedColor: kHealthYellow.withOpacity(.25),
                      checkmarkColor: c,
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // Capacité + Générer
                Row(
                  children: [
                    const Text('Capacité par créneau :'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _capacity,
                      onChanged: (v) => setState(() => _capacity = v ?? 1),
                      items: [1,2,3,4]
                          .map((e) => DropdownMenuItem(
                                value: e, child: Text('$e'),
                              ))
                          .toList(),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.add),
                      label: const Text('Générer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                // Créneaux à venir
                Text(
                  'Créneaux à venir',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: c, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (_slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun créneau.'),
                  )
                else
                  ..._groupByDay(_slots).entries.map((entry) {
                    final day = entry.key;
                    final slots = entry.value;
                    final title = DateFormat('EEEE d MMMM y', 'fr_FR').format(day);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: slots.map((s) {
                                final hhmm = DateFormat('HH:mm', 'fr_FR').format(s.startAt);
                                return InputChip(
                                  label: Text(hhmm,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  onDeleted: () => _deleteSlot(s.id), // ❌ petite croix
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  backgroundColor: const Color(0xFFEFF7F3),
                                  side: const BorderSide(color: kHealthGreen),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                const Divider(),

                // RDV de la clinique
                Text(
                  'Rendez-vous de la clinique',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: c, fontWeight: FontWeight.w700),
                ),
                if (_rdv.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun RDV.'),
                  )
                else
                  ..._rdv.map((r) {
                    final start = DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(r.startAt);
                    final end   = DateFormat('HH:mm', 'fr_FR').format(r.endAt);
                    final patientNom = r.patientNom ?? '';
                    final patientTel = r.patientTel ?? '';
                    final info = [
                      if (patientNom.isNotEmpty) patientNom,
                      if (patientTel.isNotEmpty) patientTel,
                      'Statut: ${r.statut}'
                    ].join(' • ');

                    final canCancel = r.statut == 'confirme' || r.statut == 'en_attente';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_available, color: kHealthGreen),
                        title: Text('$start → $end'),
                        subtitle: Text(info),
                        trailing: canCancel
                            ? TextButton.icon(
                                onPressed: () => _cancelRdvByClinic(r),
                                icon: const Icon(Icons.cancel),
                                label: const Text('Annuler'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              Icon(icon, color: kHealthGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(label)),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      );
}
