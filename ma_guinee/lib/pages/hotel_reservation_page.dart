// lib/pages/hotel_reservation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HotelReservationPage extends StatefulWidget {
  final String hotelId;     // FK -> public.hotels.id
  final String hotelName;
  final String? phone;      // (non affiché dans la confirmation)
  final String? address;    // optionnel
  final String? coverImage; // optionnel (URL)
  final Color primaryColor;

  const HotelReservationPage({
    super.key,
    required this.hotelId,
    required this.hotelName,
    this.phone,
    this.address,
    this.coverImage,
    this.primaryColor = const Color(0xFF264653),
  });

  @override
  State<HotelReservationPage> createState() => _HotelReservationPageState();
}

class _HotelReservationPageState extends State<HotelReservationPage> {
  final _formKey = GlobalKey<FormState>();

  // Séjour
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 15, minute: 0);

  // Occupants
  int _rooms = 1;
  int _adults = 2;
  int _children = 0;

  // Coordonnées client
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Préférences
  String _bed = 'Peu importe';
  String _smoking = 'Non-fumeur';
  final _bedOptions = const ['Peu importe', 'Lit double', 'Lits jumeaux', 'King', 'Queen'];

  bool _accept = true;
  bool _loading = false;

  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ================= Helpers =================

  String _formatDate(DateTime d) => DateFormat('EEE d MMM', 'fr_FR').format(d);
  String _sqlDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  DateTime _composeDateTime(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  // ================== RÈGLES ==================
  // - 1 seule réservation exactement à la même heure (même jour)
  // - 3 max par jour (tous établissements)
  // - 2 max dans le même établissement / jour et >= 2h d’écart entre elles
  // - Ignore 'annule' / 'annule_hotel'

  Future<String?> _validateBusinessRules() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return "Connectez-vous pour réserver.";

    // On raisonne sur le JOUR d'arrivée (checkIn) et l'heure d'arrivée
    final dayStr = _sqlDate(_checkIn);
    final selectedArrival = _composeDateTime(_checkIn, _arrivalTime);

    // Récupère toutes les réservations de l’utilisateur ce jour-là
    final list = await _sb
        .from('reservations_hotels')
        .select('hotel_id, check_in, arrival_time, status')
        .eq('user_id', userId)
        .eq('check_in', dayStr);

    // Filtre actifs (non annulés)
    final active = (list as List)
        .where((r) {
          final st = (r['status'] ?? '').toString();
          return st != 'annule' && st != 'annule_hotel';
        })
        .toList();

    // 3 max par jour
    if (active.length >= 3) {
      return "Vous avez déjà atteint la limite de 3 réservations pour cette journée.";
    }

    // Règles par établissement (même jour)
    final sameHotel = active.where((r) => (r['hotel_id'] ?? '').toString() == widget.hotelId).toList();

    // 2 max dans le même hôtel
    if (sameHotel.length >= 2) {
      return "Vous avez déjà 2 réservations actives dans cet établissement pour ce jour.";
    }

    // Même heure exactement ET intervalle >= 2h
    for (final r in sameHotel) {
      final String at = (r['arrival_time'] ?? '00:00').toString();
      final parts = at.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final existing = DateTime(_checkIn.year, _checkIn.month, _checkIn.day, h, m);

      // Même heure exacte
      if (existing.hour == selectedArrival.hour && existing.minute == selectedArrival.minute) {
        return "Vous avez déjà une réservation à cette heure dans cet établissement.";
      }

      // Espace de 2h minimum
      final diff = selectedArrival.difference(existing).inMinutes.abs();
      if (diff < 120) {
        return "Un intervalle de 2h est requis entre vos réservations dans cet établissement.";
      }
    }

    return null; // ok
  }

  // ============= UI: pickers =============

  Future<void> _pickCheckIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => _themePicker(child),
    );
    if (picked != null) {
      setState(() {
        _checkIn = picked;
        if (!_checkOut.isAfter(_checkIn)) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickCheckOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => _themePicker(child),
    );
    if (picked != null) setState(() => _checkOut = picked);
  }

  Future<void> _pickArrivalTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
      helpText: "Heure d'arrivée",
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
        return MediaQuery(data: mq, child: _themePicker(child));
      },
    );
    if (picked != null) setState(() => _arrivalTime = picked);
  }

  Theme _themePicker(Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: widget.primaryColor,
          secondary: widget.primaryColor,
          onPrimary: Colors.white,
        ),
      ),
      child: child!,
    );
  }

  // ============= Flux Réservation =============

  Future<void> _onReservePressed() async {
    if (_loading) return;

    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez accepter les conditions de contact.")),
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    // Vérifie les règles métier côté client (lecture DB)
    final ruleError = await _validateBusinessRules();
    if (ruleError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ruleError)));
      return;
    }

    // Fenêtre de confirmation AVANT insertion
    final confirmed = await _showPreConfirmDialog();
    if (confirmed != true) return;

    // Insertion
    await _submitReservation();
  }

  Future<bool?> _showPreConfirmDialog() {
    final nights = _checkOut.difference(_checkIn).inDays;
    final resume = StringBuffer()
      ..writeln("Souhaitez-vous confirmer cette réservation ?")
      ..writeln("")
      ..writeln("Hôtel : ${widget.hotelName}")
      ..writeln("Arrivée : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkIn)} à ${_arrivalTime.format(context)}")
      ..writeln("Départ : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkOut)} (${nights} nuit${nights > 1 ? 's' : ''})")
      ..writeln("Chambres : $_rooms  |  Occupants : $_adults adulte(s)${_children > 0 ? ' + $_children enfant(s)' : ''}")
      ..writeln("Lit : $_bed  |  $_smoking")
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la réservation"),
        content: Text(resume.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReservation() async {
    setState(() => _loading = true);
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connectez-vous pour réserver.")),
        );
        return;
      }

      final payload = {
        'hotel_id': widget.hotelId,
        'user_id': uid,
        'client_nom': _nameCtrl.text.trim(),
        'client_phone': _phoneCtrl.text.trim(),
        'check_in': _sqlDate(_checkIn),
        'check_out': _sqlDate(_checkOut),
        'arrival_time': _hhmm(_arrivalTime),
        'rooms': _rooms,
        'adults': _adults,
        'children': _children,
        'bed_pref': _bed,
        'smoking_pref': _smoking,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'consent_contact': _accept,
        // status par défaut côté DB: 'confirme'
      };

      final inserted = await _sb
          .from('reservations_hotels')
          .insert(payload)
          .select()
          .single();

      if (!mounted) return;
      await _showSuccessSheet(inserted);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      String human = "Impossible d'enregistrer la réservation.";
      if (msg.contains('unique') || msg.contains('duplicate')) {
        human = "Vous avez déjà une réservation active à ces dates dans cet hôtel.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(human)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Une erreur est survenue.")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessSheet(Map<String, dynamic> row) async {
    final nights = _checkOut.difference(_checkIn).inDays;
    final resume = StringBuffer()
      ..writeln('Réservation confirmée ✅')
      ..writeln('Hôtel : ${widget.hotelName}')
      ..writeln('Arrivée : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkIn)} à ${_arrivalTime.format(context)}')
      ..writeln('Départ : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkOut)} (${nights} nuit${nights > 1 ? 's' : ''})')
      ..writeln('Chambres : $_rooms  |  Occupants : $_adults adulte(s)${_children > 0 ? ' + $_children enfant(s)' : ''}')
      ..writeln('Lit : $_bed  |  $_smoking')
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

    // Pas d’affichage du numéro de l’hôtel, pas de bouton “Appeler”
    // ignore: use_build_context_synchronously
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: widget.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Votre réservation est confirmée.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.surfaceVariant.withOpacity(.6),
                ),
                child: Text(resume.toString(), style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 8),
              Text(
                "Vous pouvez consulter vos réservations dans votre profil (Mes réservations).",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);        // ferme la bottom sheet
                  Navigator.pop(context, true);  // retourne à la page détail
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("OK"),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        title: Text("Réserver – ${widget.hotelName}"),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              title: widget.hotelName,
              // On n'affiche pas le téléphone ici pour éviter les confusions.
              subtitle: (widget.address?.trim().isNotEmpty ?? false)
                  ? widget.address!.trim()
                  : "Sélectionnez vos dates et préférences",
              imageUrl: widget.coverImage,
              primaryColor: widget.primaryColor,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Dates & heure d'arrivée
                    _Section(
                      title: "Vos dates",
                      primaryColor: widget.primaryColor,
                      trailing: Text(
                        "${_formatDate(_checkIn)} → ${_formatDate(_checkOut)} • ${_arrivalTime.format(context)}",
                        style: theme.textTheme.labelMedium?.copyWith(color: widget.primaryColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _TileButton(
                                  icon: Icons.login_rounded,
                                  label: "Arrivée : ${_formatDate(_checkIn)}",
                                  onTap: _pickCheckIn,
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TileButton(
                                  icon: Icons.logout_rounded,
                                  label: "Départ : ${_formatDate(_checkOut)}",
                                  onTap: _pickCheckOut,
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _TileButton(
                            icon: Icons.schedule_rounded,
                            label: "Heure d'arrivée : ${_arrivalTime.format(context)}",
                            onTap: _pickArrivalTime,
                            primaryColor: widget.primaryColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Occupants
                    _Section(
                      title: "Occupants",
                      primaryColor: widget.primaryColor,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final cols = w >= 680 ? 3 : (w >= 420 ? 2 : 1);
                          const spacing = 12.0;
                          final itemW = (w - (cols - 1) * spacing) / cols;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(
                                width: itemW,
                                child: _CounterCard(
                                  title: "Chambres",
                                  value: _rooms,
                                  onChanged: (v) => setState(() => _rooms = v.clamp(1, 10)),
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                              SizedBox(
                                width: itemW,
                                child: _CounterCard(
                                  title: "Adultes",
                                  value: _adults,
                                  onChanged: (v) => setState(() => _adults = v.clamp(1, 10)),
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                              SizedBox(
                                width: itemW,
                                child: _CounterCard(
                                  title: "Enfants",
                                  value: _children,
                                  onChanged: (v) => setState(() => _children = v.clamp(0, 10)),
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Coordonnées
                    _Section(
                      title: "Vos informations",
                      primaryColor: widget.primaryColor,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Nom et prénom",
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().length < 2) ? "Votre nom" : null,
                          ),
                          const SizedBox(height: 10),
                          // Téléphone : chiffres uniquement + blocage du collage/menu
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Téléphone (chiffres uniquement)",
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(20),
                            ],
                            enableInteractiveSelection: false, // désactive sélection
                            // supprime totalement le menu contextuel (pas de coller/copier)
                            contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
                            validator: (v) {
                              final val = (v ?? '').trim();
                              if (val.length < 6) return "Votre numéro";
                              if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                                return "Chiffres uniquement";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Préférences
                    _Section(
                      title: "Préférences",
                      primaryColor: widget.primaryColor,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _bed,
                            items: _bedOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _bed = v ?? 'Peu importe'),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.bed)),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _smoking,
                            items: const [
                              DropdownMenuItem(value: 'Non-fumeur', child: Text('Non-fumeur')),
                              DropdownMenuItem(value: 'Fumeur', child: Text('Fumeur')),
                            ],
                            onChanged: (v) => setState(() => _smoking = v ?? 'Non-fumeur'),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.smoke_free)),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: "Notes (arrivée tardive, préférences, etc.)",
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _Section(
                      title: "Confirmation",
                      primaryColor: widget.primaryColor,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _accept,
                        onChanged: (v) => setState(() => _accept = v ?? false),
                        title: const Text(
                          "J’accepte d’être contacté(e) par l’hôtel pour finaliser ma demande.",
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Barre collée en bas
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              color: Colors.black.withOpacity(.08),
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _onReservePressed,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.event_available_rounded),
                  label: Text(_loading ? "Enregistrement..." : "Réserver"),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============= Widgets réutilisables =============

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color primaryColor;

  const _Section({
    required this.title,
    required this.child,
    this.trailing,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceVariant.withOpacity(.25),
        border: Border.all(color: primaryColor.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: primaryColor)),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color primaryColor;

  const _HeroBanner({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
        color: primaryColor.withOpacity(.12),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(.45), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color primaryColor;

  const _TileButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final Color primaryColor;

  const _CounterCard({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              softWrap: false,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => onChanged((value - 1).clamp(0, 999999)),
                icon: Icon(Icons.remove_circle_outline, color: primaryColor),
                tooltip: 'Diminuer',
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => onChanged((value + 1).clamp(0, 999999)),
                icon: Icon(Icons.add_circle_outline, color: primaryColor),
                tooltip: 'Augmenter',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
