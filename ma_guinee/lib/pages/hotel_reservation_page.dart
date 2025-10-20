// lib/pages/hotel_reservation_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class HotelReservationPage extends StatefulWidget {
  final String hotelName;
  final String? phone;      // téléphone (affiché, jamais prérempli)
  final String? address;    // optionnel
  final String? coverImage; // optionnel (URL)
  final Color primaryColor; // couleur de thème côté Hôtel

  const HotelReservationPage({
    super.key,
    required this.hotelName,
    this.phone,
    this.address,
    this.coverImage,
    // Couleur service Hôtels
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

  // Coordonnées client (jamais préremplies)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Préférences
  String _bed = 'Peu importe';
  String _smoking = 'Non-fumeur';
  final _bedOptions = const ['Peu importe', 'Lit double', 'Lits jumeaux', 'King', 'Queen'];

  bool _accept = true;

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

  // Helpers
  String _formatDate(DateTime d) => DateFormat('EEE d MMM', 'fr_FR').format(d);
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _call(String? number) async {
    final raw = (number ?? '').trim();
    final num = _digitsOnly(raw);
    if (num.isEmpty) return;
    final uri = Uri.parse('tel:$num');
    await launchUrl(uri);
  }

  void _showNotAvailableSheet() {
    final nights = _checkOut.difference(_checkIn).inDays;
    final resume = StringBuffer()
      ..writeln('Demande de réservation')
      ..writeln('Hôtel : ${widget.hotelName}')
      ..writeln('Arrivée : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkIn)} à ${_arrivalTime.format(context)}')
      ..writeln('Départ : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_checkOut)}  (${nights} nuit${nights > 1 ? 's' : ''})')
      ..writeln('Chambres : $_rooms  |  Occupants : $_adults adulte(s)${_children > 0 ? ' + $_children enfant(s)' : ''}')
      ..writeln('Lit : $_bed  |  $_smoking')
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

    final phone = (widget.phone ?? '').trim();

    showModalBottomSheet(
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
                  Icon(Icons.info_outline_rounded, color: widget.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Cet hôtel ne propose pas pour l’instant la réservation en ligne.\n"
                      "${phone.isNotEmpty ? "Vous pouvez les contacter directement par téléphone :" : "Aucun numéro n’a été renseigné."}",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                _CallCard(
                  phoneNumber: phone,
                  onCall: () => _call(phone),
                  primaryColor: widget.primaryColor,
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceVariant.withOpacity(.35),
                  ),
                  child: const Text("Numéro non renseigné par l’hôtel."),
                ),
              const SizedBox(height: 12),
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
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("OK, j’ai compris"),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

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

  void _onReservePressed() {
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez accepter les conditions de contact.")),
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    _showNotAvailableSheet();
  }

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
              subtitle: (widget.phone?.trim().isNotEmpty ?? false)
                  ? widget.phone!.trim()
                  : (widget.address ?? "Sélectionnez vos dates et préférences"),
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _CounterCard(
                                  title: "Chambres",
                                  value: _rooms,
                                  onChanged: (v) => setState(() => _rooms = v.clamp(1, 10)),
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CounterCard(
                                  title: "Adultes",
                                  value: _adults,
                                  onChanged: (v) => setState(() => _adults = v.clamp(1, 10)),
                                  primaryColor: widget.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CounterCard(
                            title: "Enfants",
                            value: _children,
                            onChanged: (v) => setState(() => _children = v.clamp(0, 10)),
                            primaryColor: widget.primaryColor,
                          ),
                        ],
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
                    // Préférences
                    _Section(
                      title: "Préférences",
                      primaryColor: widget.primaryColor,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _bed,
                            items: _bedOptions
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
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
                  onPressed: _onReservePressed,
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text("Réserver"),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white, // ✅ plus de onPrimary
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          IconButton(
            onPressed: () => onChanged(value - 1),
            icon: Icon(Icons.remove_circle_outline, color: primaryColor),
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: Icon(Icons.add_circle_outline, color: primaryColor),
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

  const _CallCard({
    required this.phoneNumber,
    required this.onCall,
    required this.primaryColor,
  });

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Téléphone"),
                const SizedBox(height: 6),
                SelectableText(
                  phoneNumber,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.phone_rounded),
            label: const Text("Appeler"),
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white, // ✅ plus de onPrimary
            ),
          ),
        ],
      ),
    );
  }
}
