import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Palette Tourisme
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);
const Color tourismeOnSecondary = Color(0xFF000000);

class ReservationTourismePage extends StatefulWidget {
  final Map<String, dynamic> lieu; // doit contenir au moins {id, nom, ville}

  const ReservationTourismePage({super.key, required this.lieu});

  @override
  State<ReservationTourismePage> createState() => _ReservationTourismePageState();
}

class _ReservationTourismePageState extends State<ReservationTourismePage> {
  final _formKey = GlobalKey<FormState>();
  final _sb = Supabase.instance.client;

  // Champs
  DateTime _visitDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _arrivalTime = const TimeOfDay(hour: 10, minute: 0);
  int _adults = 2;
  int _children = 0;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _accept = true;
  bool _loading = false;

  String get _lieuId => (widget.lieu['id'] ?? '').toString();

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

  // Convertir date/heure au format SQL
  String _sqlDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _sqlTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _insertReservation() async {
    if (_lieuId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Identifiant du lieu manquant.")),
      );
      return;
    }

    final userId = _sb.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour réserver.")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _sb.from('reservations_tourisme').insert({
        'lieu_id': _lieuId,
        'user_id': userId,
        'client_nom': _nameCtrl.text.trim(),
        'client_phone': _phoneCtrl.text.trim(),
        'visit_date': _sqlDate(_visitDate),
        'arrival_time': _sqlTime(_arrivalTime),
        'adults': _adults,
        'children': _children,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'consent_contact': _accept,
        'status': 'confirme', // ✅ insertion confirmée directement
      });

      if (!mounted) return;
      _showConfirmSheet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfirmSheet() {
    final nomLieu = (widget.lieu['nom'] ?? 'Lieu touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();
    final resume = StringBuffer()
      ..writeln("✅ Réservation confirmée")
      ..writeln("Site : $nomLieu${ville.isNotEmpty ? " – $ville" : ""}")
      ..writeln(
          "Date : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_visitDate)} à ${_arrivalTime.format(context)}")
      ..writeln("Adultes : $_adults, Enfants : $_children")
      ..writeln("Client : ${_nameCtrl.text.trim()} – ${_phoneCtrl.text.trim()}")
      ..write(_notesCtrl.text.isNotEmpty ? "\nNotes : ${_notesCtrl.text.trim()}" : "");

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_rounded, color: tourismePrimary, size: 36),
            const SizedBox(height: 8),
            const Text("Réservation enregistrée avec succès",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.withOpacity(.15),
              ),
              child: Text(resume.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text("Fermer"),
              style: FilledButton.styleFrom(
                backgroundColor: tourismePrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'),
      initialDate: _visitDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => _themePicker(child),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime,
      builder: (context, child) => _themePicker(child),
    );
    if (picked != null) setState(() => _arrivalTime = picked);
  }

  Theme _themePicker(Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: tourismePrimary,
          onPrimary: Colors.white,
        ),
      ),
      child: child!,
    );
  }

  void _onReserve() {
    if (_loading) return;
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez accepter les conditions."),
      ));
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    _insertReservation();
  }

  @override
  Widget build(BuildContext context) {
    final nom = (widget.lieu['nom'] ?? 'Lieu touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: tourismePrimary,
        foregroundColor: Colors.white,
        title: const Text("Réserver une visite"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(nom, style: Theme.of(context).textTheme.headlineSmall),
              if (ville.isNotEmpty)
                Text(ville, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),

              // Date + heure
              ListTile(
                leading: const Icon(Icons.event),
                title: Text(DateFormat('EEE d MMM', 'fr_FR').format(_visitDate)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickDate,
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(_arrivalTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: _pickTime,
              ),

              const Divider(),

              // Adultes / Enfants
              _counter("Adultes", _adults, (v) => setState(() => _adults = v)),
              _counter("Enfants", _children, (v) => setState(() => _children = v)),

              const Divider(),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nom et prénom"),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? "Nom invalide"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Téléphone"),
                validator: (v) => (v == null || v.trim().length < 6)
                    ? "Numéro invalide"
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: "Notes ou remarques"),
                maxLines: 3,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accept,
                onChanged: (v) => setState(() => _accept = v ?? false),
                title: const Text(
                    "J’accepte d’être contacté(e) pour confirmer ma visite."),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _onReserve,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.event_available),
            label: Text(_loading ? "Envoi..." : "Confirmer la réservation"),
            style: FilledButton.styleFrom(
              backgroundColor: tourismePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _counter(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text("$value", style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
