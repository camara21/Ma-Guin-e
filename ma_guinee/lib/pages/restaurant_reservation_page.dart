// lib/pages/restaurant_reservation_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ insertion DB

class RestaurantReservationPage extends StatefulWidget {
  final String restaurantId;           // ✅ FK -> public.restaurants.id
  final String restoName;
  final String? phone;                 // affiché, pas prérempli
  final String? address;               // optionnel
  final String? coverImage;            // optionnel (URL)
  final Color primaryColor;

  const RestaurantReservationPage({
    super.key,
    required this.restaurantId,        // ✅ nouveau requis
    required this.restoName,
    this.phone,
    this.address,
    this.coverImage,
    this.primaryColor = const Color(0xFFE76F51),
  });

  @override
  State<RestaurantReservationPage> createState() =>
      _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends State<RestaurantReservationPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  int _adults = 2;
  int _children = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // tel CLIENT (jamais prérempli)
  final _notesCtrl = TextEditingController();

  String _seating = 'Peu importe';
  final List<String> _occasions = ['Aucune','Anniversaire','RDV pro','Rendez-vous','Famille'];
  String _occasion = 'Aucune';
  bool _accept = true;

  bool _loading = false; // ✅ état envoi

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _phoneCtrl.text = '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Helpers
  String get _dateLabel {
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    return DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(dt);
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _call(String? number) async {
    final raw = (number ?? '').trim();
    final num = _digitsOnly(raw);
    if (num.isEmpty) return;
    final uri = Uri.parse('tel:$num');
    await launchUrl(uri);
  }

  Future<void> _showSuccessSheet(Map<String, dynamic> row) async {
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final resume = StringBuffer()
      ..writeln('Réservation confirmée ✅')
      ..writeln('Restaurant : ${widget.restoName}')
      ..writeln('Date & heure : ${DateFormat('EEEE d MMMM y, HH:mm', 'fr_FR').format(dt)}')
      ..writeln('Convives : $_adults adulte(s)${_children > 0 ? " + $_children enfant(s)" : ""}')
      ..writeln('Placement : $_seating')
      ..writeln('Occasion : $_occasion')
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

    final phone = (widget.phone ?? '').trim();
    final scheme = Theme.of(context).colorScheme;

    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: widget.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text("Votre demande a été enregistrée et est confirmée."),
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
              const SizedBox(height: 12),
              if (phone.isNotEmpty)
                _CallCard(
                  phoneNumber: phone,
                  onCall: () => _call(phone),
                  primaryColor: widget.primaryColor,
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
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

  Future<void> _submitReservation() async {
    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;

      final payload = {
        'restaurant_id': widget.restaurantId,                 // ✅ FK
        'user_id': uid,                                       // peut être null si tu autorises anonyme
        'client_nom': _nameCtrl.text.trim(),
        'client_phone': _phoneCtrl.text.trim(),
        'res_date': DateFormat('yyyy-MM-dd').format(_date),
        'res_time': _hhmm(_time),
        'adults': _adults,
        'children': _children,
        'seating_pref': _seating,
        'occasion': _occasion,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'consent_contact': _accept,
        // 'status': 'confirme',   // inutile: défaut DB
      };

      final inserted = await supa
          .from('reservations_restaurants')
          .insert(payload)
          .select()
          .single();

      if (!mounted) return;
      _showSuccessSheet(inserted);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      String human = "Impossible d'enregistrer la réservation.";
      if (msg.contains('unique') || msg.contains('duplicate')) {
        human = "Vous avez déjà une réservation active à cette date/heure pour ce restaurant.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(human)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Une erreur est survenue.")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onReservePressed() {
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez accepter les conditions de contact."),
      ));
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    _submitReservation(); // ✅ insert DB + feuille succès
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        title: Text("Réserver — ${widget.restoName}"),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              title: widget.restoName,
              subtitle: (widget.phone?.trim().isNotEmpty ?? false)
                  ? widget.phone!.trim()
                  : (widget.address ?? "Sélectionnez la date, l’heure et vos préférences"),
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
                    _Section(
                      title: "Quand souhaitez-vous venir ?",
                      primaryColor: widget.primaryColor,
                      child: Row(
                        children: [
                          Expanded(
                            child: _TileButton(
                              icon: Icons.event_rounded,
                              label: DateFormat('EEE d MMM', 'fr_FR').format(_date),
                              onTap: _pickDate,
                              primaryColor: widget.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TileButton(
                              icon: Icons.schedule_rounded,
                              label: _time.format(context),
                              onTap: _pickTime,
                              primaryColor: widget.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        _dateLabel,
                        style: theme.textTheme.labelMedium?.copyWith(color: widget.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ======= Compteurs empilés (Adultes / Enfants) =======
                    _Section(
                      title: "Combien de personnes ?",
                      primaryColor: widget.primaryColor,
                      child: Column(
                        children: [
                          _CounterCard(
                            title: "Adultes",
                            value: _adults,
                            onChanged: (v) => setState(() => _adults = v.clamp(1, 20)),
                            primaryColor: widget.primaryColor,
                          ),
                          const SizedBox(height: 10),
                          _CounterCard(
                            title: "Enfants",
                            value: _children,
                            onChanged: (v) => setState(() => _children = v.clamp(0, 20)),
                            primaryColor: widget.primaryColor,
                          ),
                        ],
                      ),
                    ),
                    // ======================================================

                    const SizedBox(height: 12),
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
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "Téléphone",
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6) ? "Votre numéro" : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: "Préférences",
                      primaryColor: widget.primaryColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _seating,
                            items: const [
                              DropdownMenuItem(value: 'Peu importe', child: Text('Placement : Peu importe')),
                              DropdownMenuItem(value: 'Intérieur', child: Text('Placement : Intérieur')),
                              DropdownMenuItem(value: 'Terrasse', child: Text('Placement : Terrasse')),
                              DropdownMenuItem(value: 'Près d’une fenêtre', child: Text('Placement : Près d’une fenêtre')),
                              DropdownMenuItem(value: 'Zone non-fumeur', child: Text('Placement : Zone non-fumeur')),
                            ],
                            onChanged: (v) => setState(() => _seating = v ?? 'Peu importe'),
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.chair_alt_rounded)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _occasions.map((o) {
                              final selected = _occasion == o;
                              return ChoiceChip(
                                label: Text(o),
                                selected: selected,
                                selectedColor: widget.primaryColor.withOpacity(.2),
                                onSelected: (_) => setState(() => _occasion = o),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: "Notes (allergies, haute-chaise, message au chef…)",
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
                        title: const Text("J’accepte d’être contacté(e) par le restaurant pour finaliser ma demande."),
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
          color: theme.colorScheme.surface,
          boxShadow: [BoxShadow(blurRadius: 16, color: Colors.black.withOpacity(.08), offset: const Offset(0, -4))],
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: widget.primaryColor, secondary: widget.primaryColor, onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: "Heure d’arrivée",
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
        final themed = Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: widget.primaryColor, secondary: widget.primaryColor, onPrimary: Colors.white,
              ),
        );
        return MediaQuery(data: mq, child: Theme(data: themed, child: child!));
      },
    );
    if (picked != null) setState(() => _time = picked);
  }
}

// ======== Widgets réutilisables ========

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color primaryColor;

  const _Section({required this.title, required this.child, this.trailing, required this.primaryColor});

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
  const _HeroBanner({required this.title, required this.subtitle, this.imageUrl, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover) : null,
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
            left: 16, right: 16, bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70)),
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

  const _TileButton({required this.icon, required this.label, required this.onTap, required this.primaryColor});

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

// ===== CounterCard version responsive =====
class _CounterCard extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final Color primaryColor;
  const _CounterCard({required this.title, required this.value, required this.onChanged, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final int minVal = title.toLowerCase().contains('adulte') ? 1 : 0;
    final int maxVal = 20;

    final bool canMinus = value > minVal;
    final bool canPlus  = value < maxVal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface.withOpacity(.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: scheme.surface),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canMinus ? () => onChanged(value - 1) : null,
                  icon: Icon(Icons.remove_circle_outline, color: canMinus ? primaryColor : scheme.outline.withOpacity(.6)),
                ),
                Expanded(
                  child: Center(
                    child: Text('$value',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canPlus ? () => onChanged(value + 1) : null,
                  icon: Icon(Icons.add_circle_outline, color: canPlus ? primaryColor : scheme.outline.withOpacity(.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  final String phoneNumber;
  final VoidCallback onCall;
  final Color primaryColor;
  const _CallCard({required this.phoneNumber, required this.onCall, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceVariant.withOpacity(.35),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Téléphone"),
              const SizedBox(height: 6),
              SelectableText(phoneNumber, style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.phone_rounded),
            label: const Text("Appeler"),
            style: FilledButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
