// lib/pages/jobs/employer/offre_edit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/job_models.dart';
import '../../../services/jobs_service.dart';
import '../../../utils/guinea.dart'; // villesGN, communesConakry, kContratsDb, contratLabel, dateForDb

class OffreEditPage extends StatefulWidget {
  final EmploiModel? existing; // null => création ; non-null => édition
  final String employeurId;    // requis pour respecter la policy RLS
  const OffreEditPage({super.key, this.existing, required this.employeurId});

  @override
  State<OffreEditPage> createState() => _OffreEditPageState();
}

class _OffreEditPageState extends State<OffreEditPage> {
  // Palette
  static const kBlue = Color(0xFF1976D2);
  static const kBg   = Color(0xFFF6F7F9);

  final _form = GlobalKey<FormState>();
  final _svc  = JobsService();

  final _titre       = TextEditingController();
  final _salMin      = TextEditingController();
  final _salMax      = TextEditingController();
  final _description = TextEditingController();
  final _exigences   = TextEditingController();
  final _avantages   = TextEditingController();

  final _ville   = ValueNotifier<String?>(null);
  final _commune = ValueNotifier<String?>(null);
  final _contrat = ValueNotifier<String?>(null); // slug ENUM: 'cdi','cdd',...

  bool _remote = false;
  DateTime? _dateLimite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titre.text        = e.titre;
      _ville.value       = e.ville;
      _commune.value     = e.commune;
      _contrat.value     = e.typeContrat; // slug enum
      if (e.salMin != null) _salMin.text = e.salMin.toString();
      if (e.salMax != null) _salMax.text = e.salMax.toString();
      _description.text  = e.description ?? '';
      _exigences.text    = e.exigences ?? '';
      _avantages.text    = e.avantages ?? '';
      _remote            = e.teletravail;
      _dateLimite        = e.dateLimite;
    }
  }

  @override
  void dispose() {
    _titre.dispose();
    _salMin.dispose();
    _salMax.dispose();
    _description.dispose();
    _exigences.dispose();
    _avantages.dispose();
    super.dispose();
  }

  String? _validateSalairePair() {
    if (_salMin.text.isEmpty || _salMax.text.isEmpty) return null;
    final min = num.tryParse(_salMin.text);
    final max = num.tryParse(_salMax.text);
    if (min == null || max == null) return 'Montants invalides';
    if (min > max) return 'Le salaire min doit être ≤ au salaire max';
    return null;
  }

  Future<void> _pickDateLimite() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateLimite ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Choisir la date limite pour postuler',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked != null) setState(() => _dateLimite = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final pairErr = _validateSalairePair();
    if (pairErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pairErr)));
      return;
    }

    final payload = {
      'employeur_id': widget.employeurId,           // indispensable pour RLS
      'titre'       : _titre.text.trim(),
      'ville'       : _ville.value,
      'commune'     : _commune.value,
      'type_contrat': _contrat.value,               // slug ENUM
      'teletravail' : _remote,
      'salaire_min_gnf': _salMin.text.isEmpty ? null : num.tryParse(_salMin.text),
      'salaire_max_gnf': _salMax.text.isEmpty ? null : num.tryParse(_salMax.text),
      'description' : _description.text.trim(),
      'exigences'   : _exigences.text.trim().isEmpty ? null : _exigences.text.trim(),
      'avantages'   : _avantages.text.trim().isEmpty ? null : _avantages.text.trim(),
      'date_limite' : dateForDb(_dateLimite),       // 'YYYY-MM-DD' ou null
    };

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await _svc.creerOffre(payload);
      } else {
        await _svc.majOffre(widget.existing!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l’enregistrement : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l’offre ?'),
        content: const Text('Cette action supprimera aussi les candidatures liées (cascade).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _svc.supprimerOffre(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    }
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kBlue),
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2, color: kBlue),
        borderRadius: BorderRadius.circular(4),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      fillColor: Colors.white,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> communes =
        _ville.value == 'Conakry' ? communesConakry : const <String>[];

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: Text(widget.existing == null ? 'Nouvelle offre' : 'Modifier l’offre'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            // Titre du poste
            TextFormField(
              controller: _titre,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Titre du poste', Icons.work_outline),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 10),

            // Ville
            DropdownButtonFormField<String>(
              value: _ville.value,
              isExpanded: true,
              decoration: _dec('Ville', Icons.location_city),
              items: villesGN
                  .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _ville.value = v;
                  _commune.value = null;
                });
              },
              validator: (v) => v == null ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 10),

            // Commune (si Conakry)
            if (_ville.value == 'Conakry') ...[
              DropdownButtonFormField<String>(
                value: _commune.value,
                isExpanded: true,
                decoration: _dec('Commune', Icons.place_outlined),
                items: communes
                    .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _commune.value = v),
              ),
              const SizedBox(height: 10),
            ],

            // Type de contrat
            DropdownButtonFormField<String>(
              value: _contrat.value,
              isExpanded: true,
              decoration: _dec('Type de contrat', Icons.badge_outlined),
              items: kContratsDb
                  .map((slug) => DropdownMenuItem<String>(
                        value: slug,
                        child: Text(contratLabel(slug)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _contrat.value = v),
              validator: (v) => v == null ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 10),

            // Salaire min / max
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salMin,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('Salaire minimum (GNF / mois)', Icons.attach_money),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _salMax,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('Salaire maximum (GNF / mois)', Icons.money_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Télétravail
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: SwitchListTile(
                value: _remote,
                onChanged: (v) => setState(() => _remote = v),
                title: const Text('Télétravail'),
                activeColor: kBlue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            TextFormField(
              controller: _description,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Description', Icons.description_outlined),
              validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 10),

            // Exigences
            TextFormField(
              controller: _exigences,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Exigences', Icons.rule_folder_outlined),
            ),
            const SizedBox(height: 10),

            // Avantages
            TextFormField(
              controller: _avantages,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Avantages', Icons.card_giftcard_outlined),
            ),
            const SizedBox(height: 12),

            // Date limite (facultative)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Icons.event, color: kBlue),
                title: const Text('Date limite pour postuler'),
                subtitle: Text(
                  _dateLimite == null ? 'Non définie' : (dateForDb(_dateLimite!)!),
                ),
                trailing: TextButton(onPressed: _pickDateLimite, child: const Text('Choisir')),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
