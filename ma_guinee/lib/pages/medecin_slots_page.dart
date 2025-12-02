// lib/pages/sante/medecin_slots_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/rdv_service.dart';

const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen = Color(0xFF009460);

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

// Événement pour le planning (RDV ou slot)
class _MedPlanningEvent {
  final DateTime start;
  final DateTime end;
  final String title; // Nom patient / "Créneau libre"
  final String subtitle; // Heure ou info courte
  final bool isSlot;
  final bool isCancelled;
  final bool isPast;
  final Rdv? rdv;
  final SlotDispo? slot;

  _MedPlanningEvent({
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.isSlot,
    required this.isCancelled,
    required this.isPast,
    this.rdv,
    this.slot,
  });
}

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
  DateTime _to = DateTime.now().add(const Duration(days: 14));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  int _capacity = 1;
  final Set<int> _days = {1, 2, 3, 4, 5}; // lun→ven

  // ---- Planning (vue moderne) ----
  // vue: jour | semaine | mois
  String _view = 'jour';
  // date de référence planning
  DateTime _current = DateTime.now();

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
      final slots =
          await _svc.slotsPourClinique(widget.cliniqueId, windowDays: 120);
      final rdv = await _svc.rdvPourClinique(widget.cliniqueId);
      if (!mounted) return;
      setState(() {
        _slots = (slots..sort((a, b) => a.startAt.compareTo(b.startAt)));
        _rdv = rdv;
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

  // ---------- Filtres / vues classiques ----------

  DateTime get _now => DateTime.now();

  // RDV passés >1h masqués dans l'onglet "à venir"
  DateTime get _cutoffPast => _now.subtract(const Duration(hours: 1));

  List<Rdv> get _rdvAvenir {
    return _rdv
        .where((r) =>
            (r.statut == 'confirme' || r.statut == 'en_attente') &&
            r.startAt.isAfter(_cutoffPast))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  List<Rdv> get _rdvAnnules {
    return _rdv.where((r) => r.statut == 'annule').toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt)); // plus récents d’abord
  }

  List<SlotDispo> get _slotsLibres {
    // On n’affiche que les créneaux à venir
    return _slots.where((s) => s.startAt.isAfter(_now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  // ---------- Génération ----------

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
                      color: c,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Icons.today,
                      label: DateFormat('EEE d MMM', 'fr_FR').format(_from),
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _from,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (p != null) setState(() => _from = p);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tile(
                      icon: Icons.event,
                      label: DateFormat('EEE d MMM', 'fr_FR').format(_to),
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _to,
                          firstDate: _from,
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                          locale: const Locale('fr', 'FR'),
                        );
                        if (p != null) setState(() => _to = p);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Heures
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Icons.schedule,
                      label: _fmtTod(_start),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _start,
                          helpText: 'Heure début',
                          builder: (context, child) {
                            final mq = MediaQuery.of(context)
                                .copyWith(alwaysUse24HourFormat: true);
                            return MediaQuery(data: mq, child: child!);
                          },
                        );
                        if (t != null) setState(() => _start = t);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('→'),
                  ),
                  Expanded(
                    child: _tile(
                      icon: Icons.schedule,
                      label: _fmtTod(_end),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _end,
                          helpText: 'Heure fin',
                          builder: (context, child) {
                            final mq = MediaQuery.of(context)
                                .copyWith(alwaysUse24HourFormat: true);
                            return MediaQuery(data: mq, child: child!);
                          },
                        );
                        if (t != null) setState(() => _end = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Jours
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(7, (i) {
                  const labels = [
                    'Lun',
                    'Mar',
                    'Mer',
                    'Jeu',
                    'Ven',
                    'Sam',
                    'Dim'
                  ];
                  final day = i + 1; // 1..7
                  final selected = _days.contains(day);
                  return FilterChip(
                    selected: selected,
                    label: Text(labels[i]),
                    onSelected: (_) => setState(() {
                      if (selected) {
                        _days.remove(day);
                      } else {
                        _days.add(day);
                      }
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
                    items: [1, 2, 3, 4]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text('$e')))
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
    } else if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un jour.')),
      );
    } else {
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
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

  // ---------- Helpers UI communs ----------

  Map<DateTime, List<T>> _groupByDay<T>(
    Iterable<T> items,
    DateTime Function(T) getter,
  ) {
    final map = <DateTime, List<T>>{};
    for (final x in items) {
      final dt = getter(x);
      final key = DateTime(dt.year, dt.month, dt.day);
      (map[key] ??= []).add(x);
    }
    final ordered = map.keys.toList()..sort();
    return {for (final k in ordered) k: map[k]!};
  }

  // ---------- Helpers Planning (dates) ----------

  DateTime _mondayOfWeek(DateTime d) {
    final weekday = d.weekday; // 1 = lundi
    return d.subtract(Duration(days: weekday - 1));
  }

  String _fmtDateShort(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _monthNameFr(int month) {
    const names = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return names[month];
  }

  String _weekdayNameFr(DateTime d) {
    const names = [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE'
    ];
    return names[d.weekday - 1];
  }

  String _periodLabel() {
    if (_view == 'jour') {
      final label = _weekdayNameFr(_current);
      final date = _fmtDateShort(_current);
      return '$label $date';
    } else if (_view == 'semaine') {
      final start = _mondayOfWeek(_current);
      final end = start.add(const Duration(days: 6));
      return '${_fmtDateShort(start)} – ${_fmtDateShort(end)}';
    } else {
      return '${_monthNameFr(_current.month)} ${_current.year}';
    }
  }

  void _goPrev() {
    setState(() {
      if (_view == 'jour') {
        _current = _current.subtract(const Duration(days: 1));
      } else if (_view == 'semaine') {
        _current = _current.subtract(const Duration(days: 7));
      } else {
        _current = DateTime(_current.year, _current.month - 1, _current.day);
      }
    });
  }

  void _goNext() {
    setState(() {
      if (_view == 'jour') {
        _current = _current.add(const Duration(days: 1));
      } else if (_view == 'semaine') {
        _current = _current.add(const Duration(days: 7));
      } else {
        _current = DateTime(_current.year, _current.month + 1, _current.day);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _current,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() {
        _current = picked;
      });
    }
  }

  bool _isPastEvent(_MedPlanningEvent e) {
    final now = DateTime.now();
    return e.end.isBefore(now);
  }

  // Construire la liste d’événements pour le planning (RDV + slots)
  List<_MedPlanningEvent> get _planningEvents {
    final now = _now;
    final list = <_MedPlanningEvent>[];

    // RDV
    for (final r in _rdv) {
      final isCancelled = r.statut == 'annule';
      final isPast = r.endAt.isBefore(now);
      final title =
          (r.patientNom ?? 'Patient').isNotEmpty ? r.patientNom! : 'Patient';
      final subtitle =
          '${DateFormat('HH:mm', 'fr_FR').format(r.startAt)} • ${r.statut}';

      list.add(
        _MedPlanningEvent(
          start: r.startAt,
          end: r.endAt,
          title: title,
          subtitle: subtitle,
          isSlot: false,
          isCancelled: isCancelled,
          isPast: isPast,
          rdv: r,
          slot: null,
        ),
      );
    }

    // Slots (seulement à venir)
    for (final s in _slots) {
      if (s.startAt.isBefore(now)) continue;
      final start = s.startAt;
      final end = start.add(const Duration(minutes: 30));
      final subtitle = DateFormat('HH:mm', 'fr_FR').format(start);

      list.add(
        _MedPlanningEvent(
          start: start,
          end: end,
          title: 'Créneau libre',
          subtitle: subtitle,
          isSlot: true,
          isCancelled: false,
          isPast: false,
          rdv: null,
          slot: s,
        ),
      );
    }

    return list;
  }

  Color _planningColor(_MedPlanningEvent e) {
    if (e.isCancelled) return Colors.red.shade400;
    if (e.isSlot) return Colors.blue.shade400;
    if (e.isPast) return Colors.grey.shade500;
    return kHealthGreen;
  }

  // =========================================================
  //          UI GLOBAL
  // =========================================================

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
          style: const TextStyle(
            color: kHealthGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          TextButton.icon(
            onPressed: _openGenerationSheet,
            icon: const Icon(Icons.add, color: kHealthGreen),
            label: const Text(
              'Générer',
              style: TextStyle(color: kHealthGreen),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SegmentedButton<_Tab>(
              segments: const [
                ButtonSegment(
                  value: _Tab.avenir,
                  icon: Icon(Icons.event_available),
                  label: Text('RDV à venir'),
                ),
                ButtonSegment(
                  value: _Tab.annules,
                  icon: Icon(Icons.history_toggle_off),
                  label: Text('Annulés'),
                ),
                ButtonSegment(
                  value: _Tab.slots,
                  icon: Icon(Icons.schedule),
                  label: Text('Créneaux'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
              style: ButtonStyle(
                side: WidgetStatePropertyAll(
                  BorderSide(color: c.withOpacity(.35)),
                ),
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
              : _buildBodyForTab(kHealthGreen),
    );
  }

  Widget _buildBodyForTab(Color c) {
    switch (_tab) {
      case _Tab.avenir:
        // Onglet RDV à venir : PLANNING moderne
        return _buildPlanningTab();

      case _Tab.annules:
        // Onglet RDV annulés (liste par jour)
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: e.value.map((r) {
                    final start =
                        DateFormat('HH:mm', 'fr_FR').format(r.startAt);
                    final end = DateFormat('HH:mm', 'fr_FR').format(r.endAt);
                    final who = [
                      if ((r.patientNom ?? '').isNotEmpty) r.patientNom!,
                      if ((r.patientTel ?? '').isNotEmpty) r.patientTel!,
                    ].join(' • ');
                    return ListTile(
                      leading: const Icon(Icons.event_busy, color: Colors.red),
                      title: Text(
                        '$start → $end',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        who.isEmpty ? 'Annulé' : '$who • Annulé',
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }).toList(),
        );

      case _Tab.slots:
        // Onglet Créneaux (liste par jour avec chips)
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
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
                      children: groups[e.key]!.map((s) {
                        final hhmm =
                            DateFormat('HH:mm', 'fr_FR').format(s.startAt);
                        return InputChip(
                          label: Text(
                            hhmm,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onDeleted: () => _deleteSlot(s.id),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: const Color(0xFFEFF7F3),
                          side: const BorderSide(color: kHealthGreen),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
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

  // =========================================================
  //          PLANNING : HEADER + VUES
  // =========================================================

  Widget _buildPlanningTab() {
    final events = _planningEvents;
    if (events.isEmpty) {
      return Column(
        children: [
          _buildPlanningHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: const [
                Center(
                  child:
                      Text('Aucun rendez-vous ni créneau pour cette période.'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildPlanningHeader(),
        const Divider(height: 1),
        Expanded(
          child: _view == 'jour'
              ? _buildDayView(events)
              : (_view == 'semaine'
                  ? _buildWeekView(events)
                  : _buildMonthView(events)),
        ),
      ],
    );
  }

  // Header responsive (2 lignes, adapté mobile)
  Widget _buildPlanningHeader() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ligne 1 : flèches + période + bouton calendrier
          Row(
            children: [
              // Flèche gauche
              SizedBox(
                width: 36,
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onPressed: _goPrev,
                  child: const Icon(Icons.chevron_left, size: 18),
                ),
              ),
              const SizedBox(width: 4),

              // Période (jour / semaine / mois)
              Expanded(
                child: Container(
                  height: 32,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    _periodLabel(),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Bouton calendrier
              SizedBox(
                width: 36,
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onPressed: _pickDate,
                  child: const Icon(Icons.calendar_today, size: 15),
                ),
              ),
              const SizedBox(width: 4),

              // Flèche droite
              SizedBox(
                width: 36,
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onPressed: _goNext,
                  child: const Icon(Icons.chevron_right, size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Ligne 2 : Aujourd'hui + Jour / Semaine / Mois sous forme de Wrap
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () {
                    setState(() {
                      _current = DateTime.now();
                      _view = 'jour';
                    });
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text(
                    "Aujourd'hui",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              _buildViewButton('Jour', 'jour'),
              _buildViewButton('Semaine', 'semaine'),
              _buildViewButton('Mois', 'mois'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, String value) {
    final bool selected = _view == value;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: selected ? kHealthYellow : Colors.grey.shade300,
          foregroundColor: selected ? Colors.black : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
        ),
        onPressed: () {
          setState(() {
            _view = value;
          });
        },
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // =========================================================
  //          VUE JOUR (08:00 → 20:00)
  // =========================================================

  Widget _buildDayView(List<_MedPlanningEvent> events) {
    const startHour = 8;
    const endHour = 20; // 08:00 → 19:00 inclus

    final date = DateTime(_current.year, _current.month, _current.day);

    return ListView.builder(
      itemCount: endHour - startHour,
      itemBuilder: (context, index) {
        final hour = startHour + index;

        final slotEvents = events.where((e) {
          final d = e.start;
          final sameDay =
              d.year == date.year && d.month == date.month && d.day == date.day;
          if (!sameDay) return false;
          return e.start.hour == hour;
        }).toList();

        return Container(
          height: 60,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heure
              SizedBox(
                width: 60,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Blocs rendez-vous / slots (horizontaux)
              Expanded(
                child: slotEvents.isEmpty
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in slotEvents)
                              GestureDetector(
                                onTap: () => _openEventDetails(e),
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(right: 6, top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _planningColor(e),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.title,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.subtitle,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  //          VUE SEMAINE (08:00 → 20:00, colonnes)
  // =========================================================

  Widget _buildWeekView(List<_MedPlanningEvent> events) {
    const startHour = 8;
    const endHour = 20;

    final weekStart = _mondayOfWeek(_current);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    const labels = [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE'
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minDayWidth = 120;
        final double hoursColWidth = 60;
        final double neededWidth = hoursColWidth + minDayWidth * 7;
        final double contentWidth = constraints.maxWidth < neededWidth
            ? neededWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                // Ligne des jours
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: hoursColWidth),
                      for (int i = 0; i < 7; i++)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  labels[i],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${days[i].day.toString().padLeft(2, "0")}/${days[i].month.toString().padLeft(2, "0")}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Grille horaire
                Expanded(
                  child: ListView.builder(
                    itemCount: endHour - startHour,
                    itemBuilder: (context, index) {
                      final hour = startHour + index;
                      return SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            // Colonne heures
                            SizedBox(
                              width: hoursColWidth,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),

                            // Colonnes jours
                            for (int d = 0; d < 7; d++)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                      left: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: _buildWeekCellEvents(
                                    events,
                                    days[d],
                                    hour,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekCellEvents(
    List<_MedPlanningEvent> events,
    DateTime day,
    int hour,
  ) {
    final cellEvents = events.where((e) {
      final sameDay = e.start.year == day.year &&
          e.start.month == day.month &&
          e.start.day == day.day;
      if (!sameDay) return false;
      return e.start.hour == hour;
    }).toList();

    if (cellEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in cellEvents)
            GestureDetector(
              onTap: () => _openEventDetails(e),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _planningColor(e),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  //          VUE MOIS (résumé par jour, safe mobile)
  // =========================================================

  Widget _buildMonthView(List<_MedPlanningEvent> events) {
    final first = DateTime(_current.year, _current.month, 1);
    final last = DateTime(_current.year, _current.month + 1, 0);
    final days = List.generate(last.day, (i) => first.add(Duration(days: i)));

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9, // un peu de hauteur
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final d = days[index];

        final dayEvents = events.where((e) {
          return e.start.year == d.year &&
              e.start.month == d.month &&
              e.start.day == d.day;
        }).toList();

        final rdvCount = dayEvents.where((e) => !e.isSlot).length;
        final slotsCount = dayEvents.where((e) => e.isSlot).length;

        final hasEvents = dayEvents.isNotEmpty;

        String summary = '';
        if (rdvCount > 0) summary += '$rdvCount RDV';
        if (rdvCount > 0 && slotsCount > 0) summary += ' • ';
        if (slotsCount > 0) summary += '$slotsCount créneaux';

        return InkWell(
          onTap: hasEvents ? () => _showDayEventsSheet(d, dayEvents) : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.day.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasEvents)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Bottom sheet listant tous les événements d'un jour
  void _showDayEventsSheet(
    DateTime day,
    List<_MedPlanningEvent> events,
  ) {
    final title = DateFormat('EEEE d MMMM y', 'fr_FR').format(day);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final e = events[i];
                      final start =
                          DateFormat('HH:mm', 'fr_FR').format(e.start);
                      final end = DateFormat('HH:mm', 'fr_FR').format(e.end);
                      return ListTile(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openEventDetails(e);
                        },
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _planningColor(e),
                          child: const Icon(
                            Icons.event,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          e.title,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$start – $end',
                          style: const TextStyle(fontSize: 12),
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  //          FEUILLES DÉTAILS RDV / SLOT
  // =========================================================

  void _openEventDetails(_MedPlanningEvent e) {
    if (e.isSlot && e.slot != null) {
      _showSlotSheet(e.slot!);
    } else if (e.rdv != null) {
      _showRdvSheet(e.rdv!);
    }
  }

  void _showRdvSheet(Rdv r) {
    final canCancel = r.statut == 'confirme' || r.statut == 'en_attente';
    final start = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(r.startAt);
    final end = DateFormat('HH:mm', 'fr_FR').format(r.endAt);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.patientNom ?? 'Patient',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if ((r.patientTel ?? '').isNotEmpty)
                  Text(
                    r.patientTel!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '$start → $end',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('Statut : ${r.statut}'),
                if ((r.motif ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Motif : ${r.motif}'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Spacer(),
                    if (canCancel)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _cancelRdvByClinic(r);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annuler le RDV'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSlotSheet(SlotDispo s) {
    final start = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(s.startAt);
    final end = DateFormat('HH:mm', 'fr_FR')
        .format(s.startAt.add(const Duration(minutes: 30)));

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Créneau libre',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$start → $end',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _deleteSlot(s.id);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.delete),
                      label: const Text('Supprimer ce créneau'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Tuile générique (génération) ----------

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

// ---------- copyWith RDV ----------

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
