import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, FilteringTextInputFormatter;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CvMakerPage extends StatefulWidget {
  const CvMakerPage({super.key});
  @override
  State<CvMakerPage> createState() => _CvMakerPageState();
}

class _CvMakerPageState extends State<CvMakerPage> {
  // Palette UI
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);

  final _form = GlobalKey<FormState>();

  // Formulaires
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _ville = TextEditingController(text: 'Conakry');
  final _posteVise = TextEditingController(text: 'Poste recherché');
  final _resume = TextEditingController(
    text: "Résumé court (2–3 lignes).",
  );
  final _competences = TextEditingController(
    text: "Communication, Travail en équipe, Autonomie",
  );
  final _experience = TextEditingController(
    text: "Entreprise / Poste / Dates / Réalisations",
  );
  final _formation = TextEditingController(
    text: "Diplôme / Établissement / Année",
  );
  final _distinctions = TextEditingController(text: "Top 3 (optionnel)");
  final _langues = TextEditingController(
    text: "Français (courant), Anglais (intermédiaire)",
  );

  // Assistant “IA locale”
  String _niveau = 'Intermédiaire'; // Débutant, Intermédiaire, Senior
  final _annees = TextEditingController(); // ex: 3

  // Photo
  Uint8List? _avatarBytes;

  // Palettes (Bleu pro par défaut)
  final List<String> _paletteKeys = const [
    'Bleu pro',
    'Émeraude',
    'Violet',
    'Teal',
    'Charbon',
  ];
  String _paletteKey = 'Bleu pro';

  // Polices PDF (pour accents)
  pw.Font? _fontRegular;
  pw.Font? _fontBold;

  bool _genBusy = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  // Charge les fichiers Inter_24pt depuis assets
  Future<void> _loadFonts() async {
    try {
      final reg = await rootBundle.load('assets/fonts/Inter_24pt-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Inter_24pt-Bold.ttf');
      _fontRegular = pw.Font.ttf(reg);
      _fontBold = pw.Font.ttf(bold);
    } catch (_) {
      _fontRegular = pw.Font.helvetica();
      _fontBold = pw.Font.helveticaBold();
    }
    if (mounted) setState(() {});
  }

  // ========= Génération locale (sans API) =========

  Future<void> _generateSmart({bool force = false}) async {
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

      if (force || _resume.text.trim().length < 20) {
        _resume.text = _smartSummary(
          nom: '${_prenom.text} ${_nom.text}'.trim(),
          role: role,
          niveau: niveau,
          annees: y,
          ville: ville,
        );
      }
      if (force || _competences.text.trim().length < 10) {
        _competences.text = _smartSkills(role, niveau).join(', ');
      }
      if (force || _experience.text.trim().length < 10) {
        _experience.text = _smartExperience(role, niveau, y).join('\n');
      }
      if (force || _formation.text.trim().length < 10) {
        _formation.text = _smartEducation(role, niveau).join('\n');
      }
      if (force || _distinctions.text.trim().isEmpty) {
        _distinctions.text =
            "Reconnaissance interne, Meilleur projet (${DateTime.now().year}), "
            "Implication associative (optionnel)";
      }
      if (force || _langues.text.trim().isEmpty) {
        _langues.text = "Français (courant), Anglais (intermédiaire)";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenu généré.')),
      );
    } finally {
      if (mounted) setState(() => _genBusy = false);
    }
  }

  void _ensureContent() {
    if (_posteVise.text.trim().isEmpty) _posteVise.text = 'Poste recherché';
    if (_resume.text.trim().length < 20 ||
        _competences.text.trim().length < 10 ||
        _experience.text.trim().length < 10 ||
        _formation.text.trim().length < 10 ||
        _langues.text.trim().isEmpty) {
      _generateSmart(force: true);
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
    final expStr = (annees != null && annees > 0)
        ? '$annees an${annees > 1 ? "s" : ""} d’expérience'
        : 'motivé(e)';
    final lvl = {
          'Débutant': 'débutant(e) structuré(e)',
          'Intermédiaire': 'confirmé(e)',
          'Senior': 'senior orienté(e) résultats',
        }[niveau] ??
        'confirmé(e)';

    return "$role $lvl, $expStr. Basé(e) à $ville, disponible rapidement. "
        "Axé(e) sur l’impact, la qualité et la satisfaction client. "
        "Ouvert(e) aux missions sur l’ensemble du territoire guinéen.";
  }

  List<String> _smartSkills(String role, String niveau) {
    final base = <String>[
      'Communication',
      'Travail en équipe',
      'Autonomie',
      'Résolution de problèmes'
    ];
    final roleMap = <String, List<String>>{
      'Développeur': ['Flutter', 'Dart', 'REST', 'Git', 'SQL', 'UI/UX'],
      'Commercial': ['Prospection', 'Négociation', 'CRM', 'Reporting', 'Terrain'],
      'Comptable': [
        'SAGE',
        'Comptabilité générale',
        'Trésorerie',
        'Fiscalité',
        'Excel'
      ],
      'Logisticien': [
        'Chaîne d’approvisionnement',
        'Gestion de stock',
        'Planification'
      ],
      'Infirmier': [
        'Soins infirmiers',
        'Prise en charge',
        'Asepsie',
        'Dossier patient'
      ],
      'Médecin': [
        'Diagnostic',
        'Suivi patient',
        'Protocoles',
        'Urgences',
        'Éthique'
      ],
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
        }[niveau] ??
        <String>[];

    final all = {...base, ...match.value, ...lvlBoost}.toList();
    if (all.length > 9) all.removeRange(9, all.length);
    return all;
  }

  List<String> _smartExperience(String role, String niveau, int? annees) {
    final bullets = <String>[];
    final scope = (annees ?? 0) >= 4 ? 'Pilotage de' : 'Contribution à';
    final impact = (niveau == 'Senior')
        ? 'Pilotage d’équipes et optimisation des coûts'
        : 'Amélioration des indicateurs clés';

    if (role.toLowerCase().contains('développ')) {
      bullets.addAll([
        '$scope projets mobiles Flutter de A à Z (recueil du besoin → mise en production).',
        'Conception d’UI performantes, offline-first et intégrations API REST.',
        '$impact : délais -20 %, crash rate < 1 %, satisfaction utilisateur en hausse.',
      ]);
    } else if (role.toLowerCase().contains('commercial')) {
      bullets.addAll([
        '$scope portefeuilles B2B/B2C (prospection, closing, fidélisation).',
        'Reporting, suivi des objectifs et veille concurrentielle terrain.',
        '$impact : CA mensuel +15–30 % selon secteurs, churn en baisse.',
      ]);
    } else if (role.toLowerCase().contains('comptable')) {
      bullets.addAll([
        'Tenue de la comptabilité générale et analytique (SAGE / Excel).',
        'Déclarations fiscales, rapprochements bancaires, trésorerie rigoureuse.',
        '$impact : clôtures dans les délais, conformité accrue, zéro pénalité.',
      ]);
    } else if (role.toLowerCase().contains('médecin')) {
      bullets.addAll([
        'Consultations, diagnostic et suivi de patients selon les protocoles.',
        'Coordination avec l’équipe soignante et le plateau technique.',
        '$impact : amélioration de la prise en charge et de la satisfaction patient.',
      ]);
    } else {
      bullets.addAll([
        '$scope activités clés liées au poste ($role).',
        'Coordination avec les équipes et parties prenantes.',
        '$impact mesurable sur qualité, délai et satisfaction.',
      ]);
    }
    return bullets;
  }

  List<String> _smartEducation(String role, String niveau) {
    return [
      'Licence / Master lié au poste ($role) — Université / École — Année',
      'Certifications pertinentes (ex : Google, Microsoft, PMI, etc.)',
    ];
  }

  String _tighten(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' très ', ' ')
      .replaceAll(' vraiment ', ' ')
      .trim();

  String _dedupeSkills(String s) {
    final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final set = <String>{};
    for (final p in parts) {
      set.add(p[0].toUpperCase() + p.substring(1));
    }
    return set.join(', ');
  }

  String _polishBullets(String s) {
    final lines =
        s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(r'[.!?]$').hasMatch(lines[i])) lines[i] = '${lines[i]}.';
    }
    return lines.join('\n');
  }

  // ========= Palettes PDF =========
  Map<String, Map<String, int>> get _palettes => {
        'Bleu pro': {
          'primary': 0xFF1976D2,
          'sidebar': 0xFFEFF4FA,
          'accent': 0xFF1E88E5
        },
        'Émeraude': {
          'primary': 0xFF059669,
          'sidebar': 0xFFE9FDF7,
          'accent': 0xFF10B981
        },
        'Violet': {
          'primary': 0xFF7C3AED,
          'sidebar': 0xFFF3E8FF,
          'accent': 0xFF9333EA
        },
        'Teal': {
          'primary': 0xFF0D9488,
          'sidebar': 0xFFE6FFFA,
          'accent': 0xFF14B8A6
        },
        'Charbon': {
          'primary': 0xFF374151,
          'sidebar': 0xFFF3F4F6,
          'accent': 0xFF111827
        },
      };

  // ========= Photo =========
  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.single.bytes;
    if (bytes == null) return;
    setState(() => _avatarBytes = bytes);
  }

  // ========= PDF (2 colonnes) =========
  Future<Uint8List> _buildPdfBytes() async {
    _ensureContent(); // complète si nécessaire

    final theme = pw.ThemeData.withFont(
      base: _fontRegular ?? pw.Font.helvetica(),
      bold: _fontBold ?? pw.Font.helveticaBold(),
    );
    final doc = pw.Document(theme: theme);

    final p = _palettes[_paletteKey]!;
    final cPrimary = PdfColor.fromInt(p['primary']!);
    final cSidebarBg = PdfColor.fromInt(p['sidebar']!);
    final cAccent = PdfColor.fromInt(p['accent']!);
    final cTextDark = PdfColor.fromInt(0xFF1F2937);
    final cTextMute = PdfColor.fromInt(0xFF6B7280);

    PdfColor _alphaFromInt(int baseColor, double opacity) {
      final o = opacity.clamp(0.0, 1.0);
      final rgb = baseColor & 0x00FFFFFF;
      final a = ((o * 255).round() & 0xFF) << 24;
      return PdfColor.fromInt(a | rgb);
    }

    final cBorder = _alphaFromInt(p['accent']!, .25);

    String _initials(String first, String last) {
      final a = first.isNotEmpty ? first[0] : '';
      final b = last.isNotEmpty ? last[0] : '';
      return (a + b).isEmpty ? 'CV' : (a + b).toUpperCase();
    }

    List<String> _splitComma(String s) =>
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    List<String> _splitLines(String s) =>
        s.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    pw.Widget _sideTitle(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            t.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
              color: cTextDark,
            ),
          ),
        );

    pw.Widget _bullet(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: cTextDark,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  text,
                  style: pw.TextStyle(fontSize: 11, color: cTextDark),
                ),
              ),
            ],
          ),
        );

    pw.Widget _sectionTitle(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            t.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
              color: cPrimary,
            ),
          ),
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Colonne gauche
              pw.Container(
                width: 170,
                padding: const pw.EdgeInsets.fromLTRB(14, 18, 14, 18),
                decoration: pw.BoxDecoration(
                  color: cSidebarBg,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Photo + nom en dessous
                    pw.Center(
                      child: _avatarBytes != null
                          ? pw.Container(
                              width: 86,
                              height: 86,
                              decoration: pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                border: pw.Border.all(color: cPrimary, width: 2),
                              ),
                              child: pw.ClipOval(
                                child: pw.Image(
                                  pw.MemoryImage(_avatarBytes!),
                                  width: 86,
                                  height: 86,
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            )
                          : pw.Container(
                              width: 86,
                              height: 86,
                              decoration: pw.BoxDecoration(
                                color: cPrimary,
                                shape: pw.BoxShape.circle,
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                _initials(_prenom.text, _nom.text),
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 26,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Center(
                      child: pw.Text(
                        '${_prenom.text} ${_nom.text}'.trim().isEmpty
                            ? 'Votre nom'
                            : '${_prenom.text} ${_nom.text}'.trim(),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: cTextDark,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 16),

                    _sideTitle('Coordonnées'),
                    pw.Row(children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: cPrimary,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          _telephone.text.isEmpty ? '—' : _telephone.text,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: cPrimary,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          _email.text.isEmpty ? '—' : _email.text,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Container(
                        width: 8,
                        height: 8,
                        decoration: pw.BoxDecoration(
                          color: cPrimary,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          _ville.text.isEmpty ? '—' : _ville.text,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ]),

                    pw.SizedBox(height: 14),
                    _sideTitle('Compétences'),
                    ..._splitComma(_competences.text).map((e) => _bullet(e)),

                    pw.SizedBox(height: 14),
                    _sideTitle('Langues'),
                    ..._splitComma(_langues.text).map((e) => _bullet(e)),

                    if (_distinctions.text.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 14),
                      _sideTitle('Distinctions'),
                      ..._splitLines(_distinctions.text).map((e) => _bullet(e)),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(width: 18),

              // Colonne droite
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: cBorder, width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _posteVise.text.isEmpty
                                ? 'Poste recherché'
                                : _posteVise.text,
                            style: pw.TextStyle(
                              color: cPrimary,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (_niveau.isNotEmpty ||
                              _annees.text.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              [
                                if (_niveau.isNotEmpty) _niveau,
                                if (_annees.text.trim().isNotEmpty)
                                  "${_annees.text.trim()} an(s) d'exp."
                              ].join(' • '),
                              style: pw.TextStyle(color: cTextMute, fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    _sectionTitle('Résumé'),
                    pw.Text(
                      _resume.text,
                      style: pw.TextStyle(
                        color: cTextDark,
                        fontSize: 11,
                        lineSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    _sectionTitle('Expérience'),
                    ..._splitLines(_experience.text).map((e) => _bullet(e)),
                    pw.SizedBox(height: 12),
                    _sectionTitle('Diplômes'),
                    ..._splitLines(_formation.text).map((e) => _bullet(e)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  Future<void> _preview() async {
    final bytes = await _buildPdfBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ========= Enregistrement local & partage =========
  Future<String> _saveToDevice(Uint8List bytes) async {
    final safeName = [
      'CV',
      _prenom.text.trim().isEmpty ? null : _prenom.text.trim(),
      _nom.text.trim().isEmpty ? null : _nom.text.trim(),
      DateTime.now().millisecondsSinceEpoch.toString()
    ].whereType<String>().join('_').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/CVs');
    if (!await folder.exists()) await folder.create(recursive: true);

    final filePath = '${folder.path}/$safeName.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<void> _downloadPdf() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final bytes = await _buildPdfBytes();

      if (kIsWeb) {
        // Web : déclenche directement le téléchargement/partage
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'CV_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CV prêt au téléchargement.')),
          );
        }
        return;
      }

      // Mobile/Desktop : enregistre dans Documents/CVs et ouvre
      final savedPath = await _saveToDevice(bytes);
      await OpenFilex.open(savedPath);

      // Et propose aussi le partage
      await Printing.sharePdf(bytes: bytes, filename: savedPath.split('/').last);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CV enregistré : $savedPath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'enregistrer le CV : $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ====== Assistant (IA) responsive, placé EN BAS ======
  Widget _assistantSection() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: _posteVise,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: _dec('Poste visé', icon: Icons.work_outline).copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 8),

            // Champs adaptatifs
            LayoutBuilder(builder: (ctx, c) {
              final narrow = c.maxWidth < 560;
              final row = Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _niveau,
                      decoration: _dec('Niveau', icon: Icons.auto_awesome),
                      items: const [
                        DropdownMenuItem(
                            value: 'Débutant', child: Text('Débutant')),
                        DropdownMenuItem(
                            value: 'Intermédiaire',
                            child: Text('Intermédiaire')),
                        DropdownMenuItem(value: 'Senior', child: Text('Senior')),
                      ],
                      onChanged: (v) =>
                          setState(() => _niveau = v ?? 'Intermédiaire'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _annees,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec("Années d'expérience (optionnel)",
                          icon: Icons.timelapse),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paletteKey,
                      decoration:
                          _dec('Palette couleur', icon: Icons.palette_outlined),
                      items: _paletteKeys
                          .map(
                              (k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _paletteKey = v ?? 'Bleu pro'),
                    ),
                  ),
                ],
              );

              if (!narrow) return row;

              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _niveau,
                    decoration: _dec('Niveau', icon: Icons.auto_awesome),
                    items: const [
                      DropdownMenuItem(
                          value: 'Débutant', child: Text('Débutant')),
                      DropdownMenuItem(
                          value: 'Intermédiaire', child: Text('Intermédiaire')),
                      DropdownMenuItem(value: 'Senior', child: Text('Senior')),
                    ],
                    onChanged: (v) =>
                        setState(() => _niveau = v ?? 'Intermédiaire'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _annees,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec("Années d'expérience (optionnel)",
                        icon: Icons.timelapse),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _paletteKey,
                    decoration:
                        _dec('Palette couleur', icon: Icons.palette_outlined),
                    items: _paletteKeys
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _paletteKey = v ?? 'Bleu pro'),
                  ),
                ],
              );
            }),

            const SizedBox(height: 10),

            // Boutons adaptatifs
            LayoutBuilder(builder: (ctx, c) {
              final narrow = c.maxWidth < 420;
              final genBtn = OutlinedButton.icon(
                onPressed: _genBusy ? null : () => _generateSmart(force: true),
                icon: _genBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                label: const Text('Générer pour moi'),
              );
              final rewriteBtn = OutlinedButton.icon(
                onPressed: _genBusy
                    ? null
                    : () {
                        _resume.text = _tighten(_resume.text);
                        _competences.text = _dedupeSkills(_competences.text);
                        _experience.text = _polishBullets(_experience.text);
                        _formation.text = _polishBullets(_formation.text);
                        _distinctions.text =
                            _polishBullets(_distinctions.text);
                        _langues.text = _dedupeSkills(_langues.text);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Texte réécrit de façon plus professionnelle.'),
                          ),
                        );
                      },
                icon: const Icon(Icons.upgrade),
                label: const Text('Réécrire + pro'),
              );

              if (!narrow) {
                return Row(
                  children: [
                    Expanded(child: genBtn),
                    const SizedBox(width: 8),
                    Expanded(child: rewriteBtn),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: genBtn),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: rewriteBtn),
                ],
              );
            }),
          ],
        ),
      ),
    );
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
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  void dispose() {
    _annees.dispose();
    _prenom.dispose();
    _nom.dispose();
    _telephone.dispose();
    _email.dispose();
    _ville.dispose();
    _posteVise.dispose();
    _resume.dispose();
    _competences.dispose();
    _experience.dispose();
    _formation.dispose();
    _distinctions.dispose();
    _langues.dispose();
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
            // ===== Infos personnelles =====
            Text('Informations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.black12,
                  backgroundImage:
                      _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo),
                        label: const Text('Ajouter / Remplacer la photo'),
                        onPressed: _pickPhoto,
                      ),
                      if (_avatarBytes != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Retirer la photo'),
                          onPressed: () => setState(() => _avatarBytes = null),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prenom,
                    decoration: _dec('Prénom', icon: Icons.person_outline),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obligatoire' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _nom,
                    decoration: _dec('Nom', icon: Icons.badge_outlined),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obligatoire' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _telephone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              decoration:
                  _dec('Compétences (séparées par des virgules)'),
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
              decoration: _dec('Diplômes (une ligne = un point)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _langues,
              maxLines: 2,
              decoration: _dec(
                  'Langues (ex : Français — courant, Anglais — intermédiaire)'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _distinctions,
              maxLines: 2,
              decoration: _dec('Distinctions (optionnel)'),
            ),

            const SizedBox(height: 16),

            // ===== Assistant (IA) — en bas & responsive =====
            Text('Assistant (IA locale)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _assistantSection(),

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
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Télécharger le PDF'),
                    onPressed: _saving ? null : _downloadPdf,
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
