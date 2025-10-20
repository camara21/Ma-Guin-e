import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Palette Tourisme
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);
const Color tourismeOnSecondary = Color(0xFF000000);

class ReservationTourismePage extends StatefulWidget {
  final Map<String, dynamic> lieu; // doit contenir nom/ville/phone éventuel

  const ReservationTourismePage({super.key, required this.lieu});

  @override
  State<ReservationTourismePage> createState() => _ReservationTourismePageState();
}

class _ReservationTourismePageState extends State<ReservationTourismePage> {
  final _formKey = GlobalKey<FormState>();

  // Visite
  DateTime _visitDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 10, minute: 0);
  int _adults = 2;
  int _children = 0;

  // Coordonnées (jamais préremplies)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

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
  String _extractPhone(Map<String, dynamic> m) {
    final raw = (m['contact'] ?? m['telephone'] ?? m['phone'] ?? m['tel'] ?? '')
        .toString()
        .trim();
    return _digitsOnly(raw);
  }

  Future<void> _call(String number) async {
    final num = _digitsOnly(number);
    if (num.isEmpty) return;
    final uri = Uri.parse('tel:$num');
    await launchUrl(uri);
  }

  void _showNotAvailableSheet() {
    final nomLieu = (widget.lieu['nom'] ?? 'Site touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();
    final phone = _extractPhone(widget.lieu);

    final resume = StringBuffer()
      ..writeln('Demande de réservation (visite)')
      ..writeln('Site : $nomLieu${ville.isNotEmpty ? " – $ville" : ""}')
      ..writeln('Date : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_visitDate)}')
      ..writeln("Heure d'arrivée : ${_arrivalTime.format(context)}")
      ..writeln('Participants : $_adults adulte(s)${_children > 0 ? ' + $_children enfant(s)' : ''}')
      ..write(_notesCtrl.text.isNotEmpty ? '\nNotes : ${_notesCtrl.text}' : '');

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
                children: const [
                  Icon(Icons.info_outline_rounded, color: tourismePrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "La réservation en ligne n’est pas encore disponible pour ce site.\n"
                      "Veuillez contacter directement le gestionnaire par téléphone.",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                _CallCard(
                  phoneNumber: phone,
                  onCall: () => _call(phone),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceVariant.withOpacity(.35),
                  ),
                  child: const Text("Aucun numéro n’a été renseigné."),
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

  Future<void> _pickVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => _themePicker(child),
    );
    if (picked != null) setState(() => _visitDate = picked);
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
          primary: tourismePrimary,
          secondary: tourismePrimary,
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
    final nomLieu = (widget.lieu['nom'] ?? 'Site touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();
    final cover = (widget.lieu['photo_url'] ?? (widget.lieu['images'] is List && (widget.lieu['images'] as List).isNotEmpty
        ? (widget.lieu['images'] as List).first.toString()
        : '')) as String;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: tourismePrimary,
        foregroundColor: Colors.white,
        title: const Text("Réserver – Visite"),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              title: nomLieu,
              subtitle: ville.isNotEmpty ? ville : "Sélectionnez la date et vos infos",
              imageUrl: cover.isNotEmpty ? cover : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Date & heure d'arrivée
                    _Section(
                      title: "Votre visite",
                      trailing: Text(
                        "${_formatDate(_visitDate)} • ${_arrivalTime.format(context)}",
                        style: theme.textTheme.labelMedium?.copyWith(color: tourismePrimary),
                      ),
                      child: Column(
                        children: [
                          _TileButton(
                            icon: Icons.event_rounded,
                            label: "Date : ${_formatDate(_visitDate)}",
                            onTap: _pickVisitDate,
                          ),
                          const SizedBox(height: 10),
                          _TileButton(
                            icon: Icons.schedule_rounded,
                            label: "Heure d'arrivée : ${_arrivalTime.format(context)}",
                            onTap: _pickArrivalTime,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Participants
                    _Section(
                      title: "Participants",
                      child: Column(
                        children: [
                          _CounterCard(
                            title: "Adultes",
                            value: _adults,
                            onChanged: (v) => setState(() => _adults = v.clamp(1, 50)),
                          ),
                          const SizedBox(height: 10),
                          _CounterCard(
                            title: "Enfants",
                            value: _children,
                            onChanged: (v) => setState(() => _children = v.clamp(0, 50)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Coordonnées
                    _Section(
                      title: "Vos informations",
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
                    // Notes & consentement
                    _Section(
                      title: "Compléments",
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: "Notes (préférences, guide, etc.)",
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _accept,
                            onChanged: (v) => setState(() => _accept = v ?? false),
                            title: const Text("J’accepte d’être contacté(e) par le site pour finaliser ma demande."),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
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
                    backgroundColor: tourismePrimary,
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

/// ===== Widgets réutilisables (style tourisme) =====

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceVariant.withOpacity(.25),
        border: Border.all(color: tourismePrimary.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: tourismePrimary)),
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

  const _HeroBanner({required this.title, required this.subtitle, this.imageUrl});

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
        color: tourismePrimary.withOpacity(.12),
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
                const Text(
                  "Réserver une visite",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
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

  const _TileButton({required this.icon, required this.label, required this.onTap});

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
            const Icon(Icons.chevron_right_rounded, color: tourismePrimary),
            const SizedBox(width: 8),
            Icon(icon, color: tourismePrimary),
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

  const _CounterCard({required this.title, required this.value, required this.onChanged});

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
            icon: const Icon(Icons.remove_circle_outline, color: tourismePrimary),
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline, color: tourismePrimary),
          ),
        ],
      ),
    );
  }
}

class _CallCard extends StatelessWidget {
  final String phoneNumber;
  final VoidCallback onCall;

  const _CallCard({required this.phoneNumber, required this.onCall});

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
            style: FilledButton.styleFrom(
              backgroundColor: tourismePrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
