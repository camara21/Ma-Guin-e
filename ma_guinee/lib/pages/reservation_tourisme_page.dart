import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ inputFormatters + contextMenuBuilder
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Palette Tourisme
const Color tourismePrimary = Color(0xFFDAA520);
const Color tourismeSecondary = Color(0xFFFFD700);
const Color tourismeOnPrimary = Color(0xFF000000);
const Color tourismeOnSecondary = Color(0xFF000000);

class ReservationTourismePage extends StatefulWidget {
  final Map<String, dynamic> lieu; // {id, nom, ville}

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

  // Helpers
  String _sqlDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _sqlTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  // ---------- Dialogue de relecture/validation ----------
  Future<bool> _showReviewAndConfirm() async {
    final nomLieu = (widget.lieu['nom'] ?? 'Lieu touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();
    final dt = _combine(_visitDate, _arrivalTime);

    final recap = StringBuffer()
      ..writeln('Veuillez confirmer votre réservation :\n')
      ..writeln('Site : $nomLieu${ville.isNotEmpty ? " – $ville" : ""}')
      ..writeln('Date & heure : ${DateFormat('EEEE d MMMM y, HH:mm', 'fr_FR').format(dt)}')
      ..writeln('Adultes : $_adults, Enfants : $_children')
      ..writeln('Client : ${_nameCtrl.text.trim()}')
      ..write(_notesCtrl.text.trim().isNotEmpty ? '\nNotes : ${_notesCtrl.text.trim()}' : '');

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recap.toString()),
            const SizedBox(height: 12),
            const Text(
              "Après validation, vous pourrez retrouver vos réservations dans :\nProfil → Mes réservations",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- Règles métier locales (mêmes que Restaurant) ----------
  Future<String?> _validateBusinessRulesLocally() async {
    final uid    = _sb.auth.currentUser?.id;
    final dayStr = _sqlDate(_visitDate);
    final phone  = _phoneCtrl.text.trim(); // déjà filtré chiffres dans le champ
    final requested = _combine(_visitDate, _arrivalTime);

    var base = _sb.from('reservations_tourisme').select().eq('visit_date', dayStr);
    // base = base.neq('status', 'annule'); // décommente si tu as la colonne

    final List rows = uid != null
        ? await base.or('user_id.eq.$uid,client_phone.eq.$phone')
        : await base.eq('client_phone', phone);

    final List<Map<String, dynamic>> items =
        rows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();

    final sameDayAll = items.map((r) {
      final timeStr = (r['arrival_time'] as String?) ?? '00:00';
      final parts = timeStr.split(':');
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      return {
        'dt': DateTime(_visitDate.year, _visitDate.month, _visitDate.day, hh, mm),
        'lieu_id': r['lieu_id']?.toString() ?? '',
      };
    }).toList();

    // 3 max par jour (tous lieux)
    if (sameDayAll.length >= 3) {
      return "Limite atteinte : vous avez déjà 3 réservations pour cette journée.";
    }

    // 2 max dans le même lieu
    final samePlace = sameDayAll.where((e) => e['lieu_id'] == _lieuId).toList();
    if (samePlace.length >= 2) {
      return "Vous avez déjà 2 réservations pour ce lieu sur cette journée.";
    }

    for (final e in sameDayAll) {
      final dt = e['dt'] as DateTime;

      // 1 seule exactement à la même heure
      if (dt.hour == requested.hour && dt.minute == requested.minute) {
        return "Vous avez déjà une réservation à cette heure.";
      }

      // Ecart >= 2h si même lieu
      if (e['lieu_id'] == _lieuId) {
        final diff = (dt.difference(requested).inMinutes).abs();
        if (diff < 120) {
          return "L'écart entre deux réservations dans le même lieu doit être d'au moins 2 heures.";
        }
      }
    }

    return null; // OK
  }

  // ---------- Insertion ----------
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
      // on n’envoie que des chiffres pour le téléphone
      final sanitizedPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

      await _sb.from('reservations_tourisme').insert({
        'lieu_id': _lieuId,
        'user_id': userId,
        'client_nom': _nameCtrl.text.trim(),
        'client_phone': sanitizedPhone,
        'visit_date': _sqlDate(_visitDate),
        'arrival_time': _sqlTime(_arrivalTime),
        'adults': _adults,
        'children': _children,
        'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        'consent_contact': _accept,
        'status': 'confirme',
      });

      if (!mounted) return;
      _showConfirmSheetAndReturn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Feuille de succès -> OK = retour page détail ----------
  void _showConfirmSheetAndReturn() {
    final outerCtx = context; // on capture le contexte de la page
    final nomLieu = (widget.lieu['nom'] ?? 'Lieu touristique').toString();
    final ville = (widget.lieu['ville'] ?? '').toString();
    final resume = StringBuffer()
      ..writeln("✅ Réservation confirmée")
      ..writeln("Site : $nomLieu${ville.isNotEmpty ? " – $ville" : ""}")
      ..writeln("Date : ${DateFormat('EEEE d MMMM y', 'fr_FR').format(_visitDate)} à "
                "${_arrivalTime.format(outerCtx)}")
      ..writeln("Adultes : $_adults, Enfants : $_children")
      ..writeln("Client : ${_nameCtrl.text.trim()}")
      ..write(_notesCtrl.text.isNotEmpty ? "\nNotes : ${_notesCtrl.text.trim()}" : "");

    showModalBottomSheet(
      context: outerCtx,
      showDragHandle: true,
      backgroundColor: Theme.of(outerCtx).colorScheme.surface,
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(
              children: [
                Icon(Icons.verified_rounded, color: tourismePrimary, size: 36),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Réservation enregistrée avec succès",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.withOpacity(.15),
              ),
              child: Text(resume.toString(),
                  style: Theme.of(sheetCtx).textTheme.bodySmall),
            ),
            const SizedBox(height: 10),
            const Text(
              "Vous pouvez retrouver toutes vos réservations dans :\nProfil → Mes réservations",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx); // ferme la feuille
                // puis retour à la page précédente (détail)
                if (mounted) {
                  Navigator.pop(outerCtx, true);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text("OK"),
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

  // ---------- Sélecteurs date/heure ----------
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

  // ---------- CTA ----------
  Future<void> _onReserve() async {
    if (_loading) return;
    if (!_accept) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Veuillez accepter les conditions."),
      ));
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    final msg = await _validateBusinessRulesLocally();
    if (msg != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final ok = await _showReviewAndConfirm();
    if (!ok) return;

    await _insertReservation();
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
              _counter("Adultes", _adults, (v) => setState(() => _adults = v.clamp(1, 100))),
              _counter("Enfants", _children, (v) => setState(() => _children = v.clamp(0, 100))),

              const Divider(),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Nom et prénom"),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? "Nom invalide" : null,
              ),
              const SizedBox(height: 8),

              // Téléphone : chiffres uniquement + blocage du collage
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
                  final filtered = editableTextState.contextMenuButtonItems
                      .where((item) => !item.type.toString().toLowerCase().contains('paste'))
                      .toList();
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: editableTextState.contextMenuAnchors,
                    buttonItems: filtered,
                  );
                },
                decoration: const InputDecoration(labelText: "Téléphone (chiffres uniquement)"),
                validator: (v) {
                  final s = (v ?? '').trim();
                  return RegExp(r'^\d{6,15}$').hasMatch(s)
                      ? null
                      : "Numéro invalide (6 à 15 chiffres, sans espace)";
                },
              ),

              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: "Notes ou remarques"),
                maxLines: 3,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accept,
                onChanged: (v) => setState(() => _accept = v ?? false),
                title: const Text("J’accepte d’être contacté(e) pour confirmer ma visite."),
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
                ? const SizedBox(width: 18, height: 18,
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
