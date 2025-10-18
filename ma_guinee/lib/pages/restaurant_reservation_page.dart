// lib/pages/restaurant_reservation_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class RestaurantReservationPage extends StatefulWidget {
  final String restoName;
  final String? phone;        // téléphone du restaurant (affiché, pas prérempli)
  final String? address;      // optionnel
  final String? coverImage;   // optionnel (URL)
  final Color primaryColor;   // pour matcher la page détail

  const RestaurantReservationPage({
    super.key,
    required this.restoName,
    this.phone,
    this.address,
    this.coverImage,
    this.primaryColor = const Color(0xFF113CFC),
  });

  @override
  State<RestaurantReservationPage> createState() => _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends State<RestaurantReservationPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  int _adults = 2;
  int _children = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // téléphone du CLIENT (jamais prérempli)
  final _notesCtrl = TextEditingController();

  String _seating = 'Peu importe';
  final List<String> _occasions = ['Aucune', 'Anniversaire', 'RDV pro', 'Rendez-vous', 'Famille'];
  String _occasion = 'Aucune';
  bool _accept = true;

  @override
  void initState() {
    super.initState();
    // sécurité: init Intl si hot-restart
    initializeDateFormatting('fr_FR');
    // ✅ le champ téléphone client n’est PAS prérempli
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

  Future<void> _call(String? number) async {
    final raw = (number ?? '').trim();
    final num = _digitsOnly(raw);
    if (num.isEmpty) return;
    final uri = Uri.parse('tel:$num');
    await launchUrl(uri);
  }

  void _showNotAvailableSheet() {
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final resume = StringBuffer()
      ..writeln('Demande de réservation')
      ..writeln('Restaurant : ${widget.restoName}')
      ..writeln('Date & heure : ${DateFormat('EEEE d MMMM y, HH:mm', 'fr_FR').format(dt)}')
      ..writeln('Convives : $_adults adulte(s)${_children > 0 ? " + $_children enfant(s)" : ""}')
      ..writeln('Placement : $_seating')
      ..writeln('Occasion : $_occasion')
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

    final phone = (widget.phone ?? '').trim();
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 8,
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
                      "Ce restaurant ne propose pas pour l’instant la réservation.\n"
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
                ),
              if (phone.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceVariant.withOpacity(.35),
                  ),
                  child: const Text("Numéro non renseigné par le restaurant."),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        // harmoniser couleurs avec la page détail
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: widget.primaryColor,
                  secondary: widget.primaryColor,
                  onPrimary: Colors.white,
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
      helpText: "Heure d'arrivée",
      // ✅ évite l’erreur de saisie manuelle sur Web
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        // forcer 24h + thème couleurs
        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
        final themed = Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: widget.primaryColor,
                secondary: widget.primaryColor,
                onPrimary: Colors.white,
              ),
        );
        return MediaQuery(
          data: mq,
          child: Theme(data: themed, child: child!),
        );
      },
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _onReservePressed() {
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez accepter les conditions de contact."),
      ));
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
        title: Text("Réserver – ${widget.restoName}"),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              title: widget.restoName,
              // 👉 affiche d'abord le téléphone du restaurant s'il existe
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
                    _Section(
                      title: "Combien de personnes ?",
                      primaryColor: widget.primaryColor,
                      child: Row(
                        children: [
                          Expanded(
                            child: _CounterCard(
                              title: "Adultes",
                              value: _adults,
                              onChanged: (v) => setState(() => _adults = v.clamp(1, 20)),
                              primaryColor: widget.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterCard(
                              title: "Enfants",
                              value: _children,
                              onChanged: (v) => setState(() => _children = v.clamp(0, 20)),
                              primaryColor: widget.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

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
                              labelText: "Notes (allergies, haute-chaise, message au chef…) ",
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
                  onPressed: _onReservePressed,
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text("Réserver"),
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
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.white,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _CounterCard extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final Color primaryColor;
  const _CounterCard({required this.title, required this.value, required this.onChanged, required this.primaryColor});

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
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
