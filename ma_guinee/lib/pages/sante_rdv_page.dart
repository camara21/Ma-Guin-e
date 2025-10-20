// lib/pages/sante_rdv_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Palette Santé (JAUNE + VERT uniquement)
const kHealthYellow = Color(0xFFFCD116);
const kHealthGreen  = Color(0xFF009460);
const kText         = Color(0xFF1B1B1B);

class SanteRdvPage extends StatefulWidget {
  final String cliniqueName;
  final String? phone;      // téléphone de la clinique (affiché)
  final String? address;    // optionnel
  final String? coverImage; // optionnel (URL bannière)
  final Color primaryColor; // thème (vert par défaut)

  const SanteRdvPage({
    super.key,
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
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController(); // téléphone du PATIENT
  final _motifCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _accept = true;

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
    _motifCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ===== Helpers =====
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  String get _dateLabel {
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    return DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme.copyWith(
          primary: widget.primaryColor,
          secondary: widget.primaryColor,
          onPrimary: Colors.white,
          surface: Colors.white,
        );
        return Theme(data: Theme.of(context).copyWith(colorScheme: scheme), child: child!);
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: "Heure du rendez-vous",
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        final mq = MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true);
        final scheme = Theme.of(context).colorScheme.copyWith(
          primary: widget.primaryColor,
          secondary: widget.primaryColor,
          onPrimary: Colors.white,
        );
        return MediaQuery(
          data: mq,
          child: Theme(data: Theme.of(context).copyWith(colorScheme: scheme), child: child!),
        );
      },
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _call(String? number) async {
    final raw = (number ?? '').trim();
    final num = _digitsOnly(raw);
    if (num.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Numéro de la clinique non disponible.")),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$num');
    await launchUrl(uri);
  }

  String _composeResume() {
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final b = StringBuffer()
      ..writeln('Demande de rendez-vous médical')
      ..writeln('Clinique : ${widget.cliniqueName}')
      ..writeln('Date & heure : ${DateFormat('EEEE d MMMM y, HH:mm', 'fr_FR').format(dt)}')
      ..writeln('Patient : ${_nameCtrl.text.trim()}')
      ..writeln('Téléphone : ${_phoneCtrl.text.trim()}')
      ..writeln('Motif : ${_motifCtrl.text.trim()}');
    if (_notesCtrl.text.trim().isNotEmpty) b.writeln('Notes : ${_notesCtrl.text.trim()}');
    return b.toString();
  }

  void _onReservePressed() {
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez accepter les conditions de contact.")),
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    _showCallSheet();
  }

  // ======== Bottom sheet : message + couleurs vert/jaune ========
  void _showCallSheet() {
    final resume = _composeResume();
    final phone = (widget.phone ?? '').trim();
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
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
                  Icon(Icons.local_hospital_rounded, color: widget.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone.isNotEmpty
                          ? "La prise de rendez-vous en ligne n’est pas disponible pour l’instant pour ce praticien.\nVous pouvez le contacter par téléphone :"
                          : "La prise de rendez-vous en ligne n’est pas disponible pour l’instant pour ce praticien.\nAucun numéro de la clinique n’a été renseigné.",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.surfaceVariant.withOpacity(.6),
                ),
                child: Text(resume, style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 12),
              if (phone.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    await _call(phone);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: const Text("Appeler la clinique"),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.primaryColor, // vert
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: scheme.surfaceVariant.withOpacity(.35),
                  ),
                  child: const Text("Numéro de la clinique non renseigné."),
                ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("OK, j’ai compris"),
                style: FilledButton.styleFrom(
                  foregroundColor: widget.primaryColor, // accent vert
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Thème local pour forcer les couleurs de formulaire (focus/cursor/checkbox)
    final formTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: widget.primaryColor,
        secondary: widget.primaryColor,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(widget.primaryColor),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kHealthGreen, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: kHealthGreen,
        selectionColor: Color(0x33009460),
        selectionHandleColor: kHealthGreen,
      ),
    );

    return Theme(
      data: formTheme,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text("Rendez-vous • ${widget.cliniqueName}"),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kHealthYellow, kHealthGreen], // JAUNE → VERT
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: CustomScrollView(
          slivers: [
            // Bandeau hero (image + gradient J→V)
            SliverToBoxAdapter(
              child: _HeroBanner(
                title: widget.cliniqueName,
                subtitle: (widget.phone?.trim().isNotEmpty ?? false)
                    ? widget.phone!.trim()
                    : (widget.address ?? "Sélectionnez la date, l’heure et vos informations"),
                imageUrl: widget.coverImage,
              ),
            ),

            // Formulaire
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _Section(
                        title: "Quand souhaitez-vous consulter ?",
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
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: widget.primaryColor,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        title: "Informations patient",
                        primaryColor: widget.primaryColor,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: "Nom et prénom",
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2) ? "Votre nom" : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Téléphone",
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 6) ? "Votre numéro" : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _motifCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: "Motif de consultation",
                                prefixIcon: Icon(Icons.edit_note_rounded),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().length < 5) ? "Précisez le motif" : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: "Notes (allergies, dossier, message…)",
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
                              "J’accepte d’être contacté(e) par la clinique pour finaliser le rendez-vous."),
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

        // Barre d’action collée en bas (vert)
        bottomSheet: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
                    label: const Text("Demander le RDV"),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.primaryColor, // vert
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== Widgets réutilisables ======

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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(color: primaryColor),
            ),
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

  const _HeroBanner({
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Image (optimisée) ou fond jaune/vert
          Positioned.fill(
            child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 1200,
                    maxWidthDiskCache: 1200,
                    placeholder: (_, __) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kHealthYellow, kHealthGreen],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kHealthYellow, kHealthGreen],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kHealthYellow, kHealthGreen],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
          ),
          // Overlay pour lisibilité
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(.40), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          // Titre + sous-titre
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 8),
                Expanded(
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
