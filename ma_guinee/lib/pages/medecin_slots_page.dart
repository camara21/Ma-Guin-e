// lib/pages/sante/medecin_slots_page.dart
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

enum _Tab { avenir, annules, slots }

class _MedecinSlotsPageState extends State<MedecinSlotsPage> {
  final _svc = RdvService();

  // État UI
  _Tab _tab = _Tab.avenir;
  bool _loading = true;
  String? _error;

  // Données
  List<SlotDispo> _slots = [];
  List<Rdv> _rdv = [];

  // ---- Paramètres de génération (dans la feuille modale uniquement) ----
  DateTime _from = DateTime.now().add(const Duration(days: 1));
  DateTime _to   = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 17, minute: 0);
  int _capacity = 1;
  final Set<int> _days = {1,2,3,4,5}; // lun→ven

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await _svc.slotsPourClinique(widget.cliniqueId, windowDays: 120);
      final rdv   = await _svc.rdvPourClinique(widget.cliniqueId);
      if (!mounted) return;
      setState(() {
        _slots = (slots..sort((a,b)=>a.startAt.compareTo(b.startAt)));
        _rdv   = rdv;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ---------- Filtres / vues ----------
  DateTime get _now => DateTime.now();
  DateTime get _cutoffPast => _now.subtract(const Duration(hours: 1)); // RDV passés >1h masqués

  List<Rdv> get _rdvAvenir {
    // Réservations prises (confirmé / en_attente) et pas encore passées +1h
    return _rdv
        .where((r) =>
            (r.statut == 'confirme' || r.statut == 'en_attente') &&
            r.startAt.isAfter(_cutoffPast))
        .toList()
      ..sort((a,b)=>a.startAt.compareTo(b.startAt));
  }

  List<Rdv> get _rdvAnnules {
    return _rdv
        .where((r) => r.statut == 'annule')
        .toList()
      ..sort((a,b)=>b.startAt.compareTo(a.startAt)); // plus récents d’abord
  }

  List<SlotDispo> get _slotsLibres {
    // On n’affiche que les créneaux à venir
    return _slots.where((s) => s.startAt.isAfter(_now)).toList()
      ..sort((a,b)=>a.startAt.compareTo(b.startAt));
  }

  // ---------- Génération ----------
  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _openGenerationSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final insets = MediaQuery.of(context).viewInsets;
        final c = kHealthGreen;
        return Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Générer des créneaux (30 min / patient)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: c, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              // Dates
              Row(children: [
                Expanded(child: _tile(
                  icon: Icons.today,
                  label: DateFormat('EEE d MMM', 'fr_FR').format(_from),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _from,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('fr','FR'),
                    );
                    if (p != null) setState(() => _from = p);
                  },
                )),
                const SizedBox(width: 8),
                Expanded(child: _tile(
                  icon: Icons.event,
                  label: DateFormat('EEE d MMM', 'fr_FR').format(_to),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _to,
                      firstDate: _from,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('fr','FR'),
                    );
                    if (p != null) setState(() => _to = p);
                  },
                )),
              ]),
              const SizedBox(height: 8),

              // Heures
              Row(children: [
                Expanded(child: _tile(
                  icon: Icons.schedule,
                  label: _fmtTod(_start),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _start,
                      helpText: 'Heure début',
                      builder: (context, child) {
                        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
                        return MediaQuery(data: mq, child: child!);
                      },
                    );
                    if (t != null) setState(() => _start = t);
                  },
                )),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('→'),
                ),
                Expanded(child: _tile(
                  icon: Icons.schedule,
                  label: _fmtTod(_end),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _end,
                      helpText: 'Heure fin',
                      builder: (context, child) {
                        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
                        return MediaQuery(data: mq, child: child!);
                      },
                    );
                    if (t != null) setState(() => _end = t);
                  },
                )),
              ]),
              const SizedBox(height: 8),

              // Jours
              Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(7, (i) {
                  const labels = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];
                  final day = i + 1; // 1..7
                  final selected = _days.contains(day);
                  return FilterChip(
                    selected: selected,
                    label: Text(labels[i]),
                    onSelected: (_) => setState(() {
                      if (selected) { _days.remove(day); } else { _days.add(day); }
                    }),
                    selectedColor: kHealthYellow.withOpacity(.25),
                    checkmarkColor: c,
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Capacité + action
              Row(
                children: [
                  const Text('Capacité par créneau :'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _capacity,
                    onChanged: (v) => setState(() => _capacity = v ?? 1),
                    items: [1,2,3,4].map((e) =>
                      DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.add),
                    label: const Text('Générer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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
    if (!mounted) return;
    Navigator.of(context).maybePop(); // fermer la feuille
    await _refreshAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count créneaux créés.')),
    );
  }

  // ---------- Actions ----------
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

  Future<void> _cancelRdvByClinic(Rdv r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text(
          'Le patient sera notifié si vos notifications sont actives. '
          'Le créneau redevient disponible.',
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
    final newR = old.copyWith(statut: 'annule');

    setState(() => _rdv[i] = newR);
    try {
      await _svc.annulerRdvParClinique(r.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _rdv[i] = old);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur annulation : $e')),
      );
    }
  }

  // ---------- Helpers UI ----------
  Map<DateTime, List<T>> _groupByDay<T>(Iterable<T> items, DateTime Function(T) getter) {
    final map = <DateTime, List<T>>{};
    for (final x in items) {
      final dt = getter(x);
      final key = DateTime(dt.year, dt.month, dt.day);
      (map[key] ??= []).add(x);
    }
    final ordered = map.keys.toList()..sort();
    return { for (final k in ordered) k : map[k]! };
  }

  @override
  Widget build(BuildContext context) {
    final c = kHealthGreen;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: kHealthGreen),
        title: Text(
          'Créneaux • ${widget.titre}',
          style: const TextStyle(color: kHealthGreen, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: _openGenerationSheet,
            icon: const Icon(Icons.add, color: kHealthGreen),
            label: const Text('Générer', style: TextStyle(color: kHealthGreen)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<_Tab>(
              segments: const [
                ButtonSegment(value: _Tab.avenir,  icon: Icon(Icons.event_available), label: Text('RDV à venir')),
                ButtonSegment(value: _Tab.annules, icon: Icon(Icons.history_toggle_off), label: Text('Annulés')),
                ButtonSegment(value: _Tab.slots,   icon: Icon(Icons.schedule), label: Text('Créneaux')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: ButtonStyle(
                side: WidgetStatePropertyAll(BorderSide(color: c.withOpacity(.35))),
                foregroundColor: WidgetStatePropertyAll(c),
              ),
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur : $_error'))
              : _buildBodyForTab(c),
    );
  }

  Widget _buildBodyForTab(Color c) {
    switch (_tab) {
      case _Tab.avenir:
        final groups = _groupByDay<Rdv>(_rdvAvenir, (r) => r.startAt);
        if (groups.isEmpty) {
          return const Center(child: Text('Aucun rendez-vous à venir.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: groups.entries.map((e) {
            final title = DateFormat('EEEE d MMMM y', 'fr_FR').format(e.key);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  children: e.value.map((r) {
                    final start = DateFormat('HH:mm', 'fr_FR').format(r.startAt);
                    final end   = DateFormat('HH:mm', 'fr_FR').format(r.endAt);
                    final info = [
                      if ((r.patientNom ?? '').isNotEmpty) r.patientNom!,
                      if ((r.patientTel ?? '').isNotEmpty) r.patientTel!,
                      'Statut: ${r.statut}'
                    ].join(' • ');
                    final canCancel = r.statut == 'confirme' || r.statut == 'en_attente';
                    return ListTile(
                      leading: const Icon(Icons.event_available, color: kHealthGreen),
                      title: Text('$start → $end', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(info),
                      trailing: canCancel
                          ? TextButton.icon(
                              onPressed: () => _cancelRdvByClinic(r),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Annuler'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        );

      case _Tab.annules:
        final groups = _groupByDay<Rdv>(_rdvAnnules, (r) => r.startAt);
        if (groups.isEmpty) {
          return const Center(child: Text('Aucun rendez-vous annulé.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: groups.entries.map((e) {
            final title = DateFormat('EEEE d MMMM y', 'fr_FR').format(e.key);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  children: e.value.map((r) {
                    final start = DateFormat('HH:mm', 'fr_FR').format(r.startAt);
                    final end   = DateFormat('HH:mm', 'fr_FR').format(r.endAt);
                    final who = [
                      if ((r.patientNom ?? '').isNotEmpty) r.patientNom!,
                      if ((r.patientTel ?? '').isNotEmpty) r.patientTel!,
                    ].join(' • ');
                    return ListTile(
                      leading: const Icon(Icons.event_busy, color: Colors.red),
                      title: Text('$start → $end', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(who.isEmpty ? 'Annulé' : '$who • Annulé'),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        );

      case _Tab.slots:
        final groups = _groupByDay<SlotDispo>(_slotsLibres, (s) => s.startAt);
        if (groups.isEmpty) {
          return const Center(child: Text('Aucun créneau disponible.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: groups.entries.map((e) {
            final title = DateFormat('EEEE d MMMM y', 'fr_FR').format(e.key);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  children: [
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: groups[e.key]!.map((s) {
                        final hhmm = DateFormat('HH:mm', 'fr_FR').format(s.startAt);
                        return InputChip(
                          label: Text(hhmm, style: const TextStyle(fontWeight: FontWeight.w600)),
                          onDeleted: () => _deleteSlot(s.id),
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
          }).toList(),
        );
    }
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
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
}

extension on Rdv {
  Rdv copyWith({
    String? id,
    String? patientId,
    int? cliniqueId,
    String? slotId,
    DateTime? startAt,
    DateTime? endAt,
    String? statut,
    String? motif,
    String? noteClinique,
    String? patientNom,
    String? patientTel,
    DateTime? createdAt,
  }) {
    return Rdv(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      cliniqueId: cliniqueId ?? this.cliniqueId,
      slotId: slotId ?? this.slotId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      statut: statut ?? this.statut,
      motif: motif ?? this.motif,
      noteClinique: noteClinique ?? this.noteClinique,
      patientNom: patientNom ?? this.patientNom,
      patientTel: patientTel ?? this.patientTel,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
