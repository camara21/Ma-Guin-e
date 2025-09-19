import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../services/jobs_service.dart';

class CvMakerPage extends StatefulWidget {
  const CvMakerPage({super.key});
  @override
  State<CvMakerPage> createState() => _CvMakerPageState();
}

class _CvMakerPageState extends State<CvMakerPage> {
  // 🎨 Palette Home Jobs
  static const kBlue = Color(0xFF1976D2);
  static const kBg   = Color(0xFFF6F7F9);

  final _form = GlobalKey<FormState>();
  final _svc = JobsService();

  // Champs utilisateur
  final _nom         = TextEditingController();
  final _telephone   = TextEditingController();
  final _email       = TextEditingController();
  final _ville       = TextEditingController(text: 'Conakry');
  final _posteVise   = TextEditingController(text: 'Poste recherché');
  final _resume      = TextEditingController(text: "Motivation courte (2-3 lignes).");
  final _competences = TextEditingController(text: "Compétence 1, Compétence 2, Compétence 3");
  final _experience  = TextEditingController(text: "Entreprise / Poste / Dates / Réalisations principales");
  final _formation   = TextEditingController(text: "Diplôme / Établissement / Année");

  // Assistant IA locale
  String _niveau = 'Intermédiaire'; // Débutant, Intermédiaire, Senior
  final _annees  = TextEditingController(); // facultatif (ex: 3)

  bool _genBusy = false;
  bool _uploading = false;

  // ========= Génération locale (sans API) =========

  Future<void> _generateSmart() async {
    if (_posteVise.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique d’abord le poste visé.')),
      );
      return;
    }
    setState(() => _genBusy = true);
    try {
      final role = _posteVise.text.trim();
      final niveau = _niveau;
      final y = int.tryParse(_annees.text.trim());
      final ville = _ville.text.trim().isEmpty ? 'Conakry' : _ville.text.trim();

      // Résumé
      _resume.text = _smartSummary(
        nom: _nom.text.trim(),
        role: role,
        niveau: niveau,
        annees: y,
        ville: ville,
      );

      // Compétences
      _competences.text = _smartSkills(role, niveau).join(', ');

      // Expériences (bullets)
      _experience.text = _smartExperience(role, niveau, y).join('\n');

      // Formations
      _formation.text = _smartEducation(role, niveau).join('\n');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenu généré. Tu peux encore ajuster 👍')),
      );
    } finally {
      if (mounted) setState(() => _genBusy = false);
    }
  }

  Future<void> _rewritePro() async {
    setState(() => _genBusy = true);
    try {
      _resume.text = _tighten(_resume.text);
      _competences.text = _dedupeSkills(_competences.text);
      _experience.text = _polishBullets(_experience.text);
      _formation.text = _polishBullets(_formation.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Texte réécrit de façon plus pro.')),
      );
    } finally {
      if (mounted) setState(() => _genBusy = false);
    }
  }

  // ========= Helpers "IA locale" =========

  String _smartSummary({
    required String nom,
    required String role,
    required String niveau,
    int? annees,
    required String ville,
  }) {
    final expStr = annees != null && annees > 0 ? '$annees an${annees > 1 ? "s" : ""} d’expérience' : 'motivé(e)';
    final lvl = {
      'Débutant': 'débutant(e) structuré(e)',
      'Intermédiaire': 'confirmé(e)',
      'Senior': 'senior orienté(e) résultats',
    }[niveau] ?? 'confirmé(e)';

    return "$role $lvl, $expStr. Basé(e) à $ville, disponible rapidement. "
           "Focus sur l’impact, la qualité et la satisfaction client. "
           "Ouvert(e) aux missions sur l’ensemble du territoire guinéen.";
  }

  List<String> _smartSkills(String role, String niveau) {
    final base = <String>[
      'Communication', 'Travail en équipe', 'Autonomie', 'Résolution de problèmes'
    ];
    final roleMap = <String, List<String>>{
      'Développeur': ['Flutter', 'Dart', 'REST', 'Git', 'SQL', 'UI/UX'],
      'Commercial': ['Prospection', 'Négociation', 'CRM', 'Reporting', 'Terrain'],
      'Comptable': ['SAGE', 'Comptabilité générale', 'Trésorerie', 'Fiscalité', 'Excel'],
      'Logisticien': ['Chaîne d’approvisionnement', 'Gestion de stock', 'Planification', 'SINISTRES'],
      'Infirmier': ['Soins infirmiers', 'Prise en charge', 'Asepsie', 'Dossier patient'],
    };

    final key = role.toLowerCase();
    final match = roleMap.entries.firstWhere(
      (e) => key.contains(e.key.toLowerCase()),
      orElse: () => const MapEntry('autre', []),
    );

    final lvlBoost = {
      'Débutant': <String>['Curiosité', 'Capacité d’apprentissage'],
      'Intermédiaire': <String>['Organisation', 'Fiabilité'],
      'Senior': <String>['Leadership', 'Pilotage'],
    }[niveau] ?? <String>[];

    final all = {...base, ...match.value, ...lvlBoost}.toList();
    if (all.length > 9) all.removeRange(9, all.length);
    return all;
  }

  List<String> _smartExperience(String role, String niveau, int? annees) {
    final bullets = <String>[];
    final scope = (annees ?? 0) >= 4 ? 'Pilotage de' : 'Contribution à';
    final impact = (niveau == 'Senior') ? 'Pilotage d’équipes et optimisation des coûts' : 'Amélioration des indicateurs clés';

    if (role.toLowerCase().contains('développeur')) {
      bullets.addAll([
        '$scope projets mobiles Flutter de A à Z (recueil besoin → Release).',
        'Mise en place d’UI performantes, offline-first et intégrations API REST.',
        '$impact : temps de livraison -20%, crash rate <1%, satisfaction utilisateur ↑.',
      ]);
    } else if (role.toLowerCase().contains('commercial')) {
      bullets.addAll([
        '$scope portefeuilles B2B/B2C en Guinée (prospection, closing, fidélisation).',
        'Reporting régulier, suivi des objectifs et veille concurrentielle terrain.',
        '$impact : CA mensuel +15–30% selon secteurs, churn en baisse.',
      ]);
    } else if (role.toLowerCase().contains('comptable')) {
      bullets.addAll([
        'Tenue de la comptabilité générale et analytique (SAGE / Excel).',
        'Déclarations fiscales et rapprochements bancaires, trésorerie rigoureuse.',
        '$impact : clôtures dans les délais, conformité accrue, zéro pénalité.',
      ]);
    } else {
      bullets.addAll([
        '$scope activités clés liées au poste ($role).',
        'Coordination avec les équipes et parties prenantes locales.',
        '$impact mesurable sur qualité, délai et satisfaction.',
      ]);
    }
    return bullets;
  }

  List<String> _smartEducation(String role, String niveau) {
    return [
      'Licence / Master lié au poste ($role) – Université / École – Année',
      'Certifications pertinentes (ex: Google, Microsoft, PMI, etc.)',
    ];
  }

  String _tighten(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' très ', ' ')
        .replaceAll(' vraiment ', ' ')
        .trim();
  }

  String _dedupeSkills(String s) {
    final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final set = <String>{};
    for (final p in parts) {
      set.add(p[0].toUpperCase() + p.substring(1));
    }
    return set.join(', ');
  }

  String _polishBullets(String s) {
    final lines = s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'[.!?]$').hasMatch(lines[i])) lines[i] = '${lines[i]}.';
    }
    return lines.join('\n');
  }

  // ========= PDF =========

  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document();

    pw.Widget sectionTitle(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
    );

    List<String> _splitComma(String s) =>
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    List<String> _splitLines(String s) =>
        s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(kBlue.value),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(_nom.text,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                            )),
                        pw.SizedBox(height: 2),
                        pw.Text(_posteVise.text,
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                      ],
                    ),
                    pw.Text(
                      '${_ville.text} • ${_telephone.text}${_email.text.isNotEmpty ? " • ${_email.text}" : ""}',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),
              sectionTitle('Profil'),
              pw.Text(_resume.text),

              pw.SizedBox(height: 10),
              sectionTitle('Compétences'),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _splitComma(_competences.text)
                    .map((c) => pw.Bullet(text: c))
                    .toList(),
              ),

              pw.SizedBox(height: 10),
              sectionTitle('Expériences'),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _splitLines(_experience.text)
                    .map((l) => pw.Bullet(text: l))
                    .toList(),
              ),

              pw.SizedBox(height: 10),
              sectionTitle('Formations'),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: _splitLines(_formation.text)
                    .map((l) => pw.Bullet(text: l))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    return await doc.save();
  }

  Future<void> _preview() async {
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _saveAndUpload() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _uploading = true);
    try {
      final pdf = await _buildPdfBytes();
      final path = await _svc.uploadCv(
        pdf,
        filename: 'cv_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (mounted) Navigator.pop(context, path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload CV: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ========= UI =========

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: kBlue) : null,
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: kBlue, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  void dispose() {
    _annees.dispose();
    _nom.dispose();
    _telephone.dispose();
    _email.dispose();
    _ville.dispose();
    _posteVise.dispose();
    _resume.dispose();
    _competences.dispose();
    _experience.dispose();
    _formation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: const Text('Générer mon CV'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ===== Assistant (IA locale) =====
            Text('Assistant (IA locale)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _posteVise,
                      decoration: _dec('Poste visé', icon: Icons.work_outline),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Obligatoire' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _niveau,
                            decoration: _dec('Niveau', icon: Icons.auto_awesome),
                            items: const [
                              DropdownMenuItem(value: 'Débutant', child: Text('Débutant')),
                              DropdownMenuItem(value: 'Intermédiaire', child: Text('Intermédiaire')),
                              DropdownMenuItem(value: 'Senior', child: Text('Senior')),
                            ],
                            onChanged: (v) => setState(() => _niveau = v ?? 'Intermédiaire'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _annees,
                            keyboardType: TextInputType.number,
                            decoration: _dec("Années d'expérience (optionnel)", icon: Icons.timelapse),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _genBusy ? null : _generateSmart,
                            icon: _genBusy
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_fix_high),
                            label: const Text('Générer pour moi'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _genBusy ? null : _rewritePro,
                            icon: const Icon(Icons.upgrade),
                            label: const Text('Réécrire + pro'),
                          ),
                        ),
                      ],
                    ),
                    // TODO: Cloud AI (Edge Function)
                    // ElevatedButton.icon(
                    //   onPressed: _callCloudAI,
                    //   icon: const Icon(Icons.cloud),
                    //   label: const Text('Générer avec IA (cloud)'),
                    // ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== Infos personnelles =====
            Text('Informations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nom,
              decoration: _dec('Nom complet', icon: Icons.person_outline),
              validator: (v) => v == null || v.isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _telephone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Téléphone', icon: Icons.phone),
              validator: (v) => v == null || v.isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email (optionnel)', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ville,
              decoration: _dec('Ville', icon: Icons.location_city),
            ),

            const SizedBox(height: 16),

            // ===== Contenu du CV =====
            Text('Contenu du CV', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _resume,
              maxLines: 3,
              decoration: _dec('Résumé'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _competences,
              maxLines: 2,
              decoration: _dec('Compétences (séparées par des virgules)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _experience,
              maxLines: 4,
              decoration: _dec('Expériences (une ligne = un point)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _formation,
              maxLines: 3,
              decoration: _dec('Formations (une ligne = un point)'),
            ),

            const SizedBox(height: 16),

            // ===== Actions =====
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Aperçu PDF'),
                    onPressed: _preview,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Générer & téléverser'),
                    onPressed: _uploading ? null : _saveAndUpload,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
