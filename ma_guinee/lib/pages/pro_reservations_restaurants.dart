import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData; // copier numéro

const kRestaurantsPrimary = Color(0xFFE76F51);

class ProReservationsRestaurantsPage extends StatefulWidget {
  const ProReservationsRestaurantsPage({super.key});

  @override
  State<ProReservationsRestaurantsPage> createState() =>
      _ProReservationsRestaurantsPageState();
}

// ======================
// Modèle interne
// ======================
class _RestaurantEvent {
  final Map<String, dynamic> raw;
  final String id;
  final String restaurantName;
  final String clientName;
  final DateTime start;
  final DateTime end;
  final bool cancelled;

  _RestaurantEvent({
    required this.raw,
    required this.id,
    required this.restaurantName,
    required this.clientName,
    required this.start,
    required this.end,
    required this.cancelled,
  });
}

class _ProReservationsRestaurantsPageState
    extends State<ProReservationsRestaurantsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Tous les événements
  List<_RestaurantEvent> _events = [];

  // vue: jour | semaine | mois
  String _view = 'jour';

  // date de référence
  DateTime _current = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // =========================================================
  //          CHARGEMENT SUPABASE
  // =========================================================
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _events = [];
          _loading = false;
        });
        return;
      }

      // reservations + join restaurants
      final rows = await _sb
          .from('reservations_restaurants')
          .select('''
            *,
            restaurants:restaurant_id (
              id, nom, ville, tel, telephone
            )
          ''')
          .eq('user_id', uid)
          .order('res_date', ascending: true)
          .order('res_time', ascending: true);

      final List<_RestaurantEvent> evts = [];

      for (final raw in rows as List) {
        final r = Map<String, dynamic>.from(raw);

        // res_date: 'YYYY-MM-DD'
        final dateStr = (r['res_date'] ?? '').toString();
        if (dateStr.isEmpty) continue;

        DateTime base;
        try {
          base = DateTime.parse(dateStr);
        } catch (_) {
          continue;
        }

        // res_time: 'HH:mm:ss' ou 'HH:mm'
        final timeStr = (r['res_time'] ?? '00:00:00').toString();
        int h = 0, m = 0, s = 0;
        final parts = timeStr.split(':');
        if (parts.isNotEmpty) h = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1) m = int.tryParse(parts[1]) ?? 0;
        if (parts.length > 2) s = int.tryParse(parts[2]) ?? 0;

        final start = DateTime(base.year, base.month, base.day, h, m, s);

        // Durée visuelle = 2h
        final end = start.add(const Duration(hours: 2));

        final resto = Map<String, dynamic>.from(r['restaurants'] ?? {});
        final restaurantName = (resto['nom'] ?? 'Restaurant').toString();
        final clientName = (r['client_nom'] ?? 'Client').toString();
        final cancelled = (r['status'] ?? '').toString() == 'annule';

        evts.add(
          _RestaurantEvent(
            raw: r,
            id: (r['id'] ?? '').toString(),
            restaurantName: restaurantName,
            clientName: clientName,
            start: start,
            end: end,
            cancelled: cancelled,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _events = evts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // =========================================================
  //          OUTILS DATE / PERIODE
  // =========================================================
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

  bool _isPastEvent(_RestaurantEvent e) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(e.end.year, e.end.month, e.end.day);
    return endDate.isBefore(todayDate) ||
        (endDate.isAtSameMomentAs(todayDate) && e.end.isBefore(now));
  }

  Color _eventColor(_RestaurantEvent e) {
    if (e.cancelled) return Colors.red.shade300;
    if (_isPastEvent(e)) return Colors.grey.shade500;
    return kRestaurantsPrimary;
  }

  // =========================================================
  //          CONTACT & ANNULATION
  // =========================================================
  Future<void> _launchCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showContactDialog(String clientName, String phone) async {
    final number = phone.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro indisponible pour ce client.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contacter le client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(clientName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SelectableText(number, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              'Vous pouvez copier le numéro pour appeler depuis un autre téléphone.',
              style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Numéro copié.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _launchCall(number);
            },
            icon: const Icon(Icons.phone),
            label: const Text('Appeler maintenant'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(_RestaurantEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content:
            const Text('Cette action marque la réservation comme “annulée”.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Fermer')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _sb
          .from('reservations_restaurants')
          .update({'status': 'annule'}).eq('id', e.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Réservation annulée.')));
      await _loadAll();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $err')));
    }
  }

  void _showEventSheet(_RestaurantEvent e) {
    final r = e.raw;
    final clientPhone = (r['client_phone'] ?? '').toString();

    final fmtDate = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = '${fmtDate.format(e.start)} → ${fmtDate.format(e.end)}';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.restaurantName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                e.clientName,
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(dateStr,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showContactDialog(e.clientName, clientPhone),
                      icon: const Icon(Icons.phone),
                      label: Text(e.clientName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!e.cancelled && !_isPastEvent(e))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _cancelReservation(e),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Annuler'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom-sheet listant tous les événements d'un jour (vue Mois)
  void _showDayEventsSheet(DateTime day, List<_RestaurantEvent> events) {
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
                      final status = e.cancelled
                          ? 'Annulée'
                          : (_isPastEvent(e) ? 'Passée' : 'Active');

                      return ListTile(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showEventSheet(e);
                        },
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: _eventColor(e),
                          child: const Icon(
                            Icons.restaurant,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          e.clientName,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$start – $end • ${e.restaurantName} • $status',
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
  //          HEADER STYLE "OUTIL PRO" (responsive)
  // =========================================================
  Widget _buildHeader() {
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

              // Période
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

          // Ligne 2 : Aujourd'hui + Jour / Semaine / Mois, en Wrap (mobile friendly)
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
          backgroundColor:
              selected ? kRestaurantsPrimary : Colors.grey.shade300,
          foregroundColor: selected ? Colors.white : Colors.black87,
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
  //          BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservations — Restaurants'),
        backgroundColor: kRestaurantsPrimary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_error!),
                            )
                          ],
                        )
                      : _events.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('Aucune réservation.')),
                              ],
                            )
                          : _view == 'jour'
                              ? _buildDayView()
                              : (_view == 'semaine'
                                  ? _buildWeekView()
                                  : _buildMonthView()),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  //          VUE JOUR (08:00 → 23:00, blocs par heure)
  // =========================================================
  Widget _buildDayView() {
    const startHour = 8;
    const endHour = 24; // affichera 08:00 → 23:00

    final date = DateTime(_current.year, _current.month, _current.day);

    return ListView.builder(
      itemCount: endHour - startHour,
      itemBuilder: (context, index) {
        final hour = startHour + index;

        final slotEvents = _events.where((e) {
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
              // Blocs rendez-vous (horizontaux)
              Expanded(
                child: slotEvents.isEmpty
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in slotEvents)
                              GestureDetector(
                                onTap: () => _showEventSheet(e),
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(right: 6, top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _eventColor(e),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.clientName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.restaurantName,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
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
  //          VUE SEMAINE (08:00 → 23:00, colonnes)
  // =========================================================
  Widget _buildWeekView() {
    const startHour = 8;
    const endHour = 24;

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
                      bottom: BorderSide(color: Colors.grey.shade300),
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
                                left: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
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
                                          color: Colors.grey.shade300),
                                      left: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: _buildWeekCellEvents(days[d], hour),
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

  Widget _buildWeekCellEvents(DateTime day, int hour) {
    final cellEvents = _events.where((e) {
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
              onTap: () => _showEventSheet(e),
              child: Container(
                margin: const EdgeInsets.all(2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _eventColor(e),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  e.clientName,
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
  Widget _buildMonthView() {
    final first = DateTime(_current.year, _current.month, 1);
    final last = DateTime(_current.year, _current.month + 1, 0);
    final days = List.generate(last.day, (i) => first.add(Duration(days: i)));

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final d = days[index];

        final dayEvents = _events.where((e) {
          return e.start.year == d.year &&
              e.start.month == d.month &&
              e.start.day == d.day;
        }).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        final count = dayEvents.length;
        final hasEvents = count > 0;

        final summary = hasEvents
            ? (count == 1 ? '1 réservation' : '$count réservations')
            : '';

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
}
