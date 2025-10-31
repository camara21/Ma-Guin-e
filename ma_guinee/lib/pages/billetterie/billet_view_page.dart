// lib/pages/billetterie/billet_view_page.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

// PDF export
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// === Couleurs de base ===
const kAppBlue = Color(0xFF0175C2); // bleu app
const _kNavy = Color(0xFF0C2340);   // textes forts
const _kGold = Color(0xFFFFC400);   // badge VIP lisible sur bleu

// Brand (logo “Soneya Events” sur la carte)
const _kBrandNavy = Color(0xFF0C2340);
const _kBrandYellow = Color(0xFFFFD54F);

class TicketPalette {
  final Color start; // base
  final Color end;   // accent événement
  final Color text;  // texte principal
  const TicketPalette({required this.start, required this.end, required this.text});
}

Color _hashAccent(String seed) {
  int h = 0;
  for (final r in seed.codeUnits) h = (h * 31 + r) & 0xFFFFFF;
  final hue = (h % 240).toDouble();
  final clampedHue = hue < 30 ? hue + 210 : hue; // évite l’orange
  final hsl = HSLColor.fromAHSL(1, clampedHue % 360, 0.6, 0.55);
  return hsl.toColor();
}

TicketPalette paletteFromEvent(Map<String, dynamic> ev) {
  final cStr = (ev['theme_color'] ?? ev['couleur'] ?? '').toString().trim();
  Color accent;
  if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(cStr)) {
    final hex = cStr.startsWith('#') ? cStr.substring(1) : cStr;
    accent = Color(int.parse('0xFF$hex'));
  } else {
    final seed = (ev['id'] ?? ev['titre'] ?? 'event').toString();
    accent = _hashAccent(seed);
  }
  return TicketPalette(start: kAppBlue, end: accent, text: _kNavy);
}

class BilletViewPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const BilletViewPage({super.key, required this.data});

  @override
  State<BilletViewPage> createState() => _BilletViewPageState();
}

class _BilletViewPageState extends State<BilletViewPage> {
  late final Map<String, dynamic> ev;
  late final Map<String, dynamic> bi;
  late final TicketPalette pal;

  late final int qty;
  late final String baseToken;
  late final List<String> tokens; // un token par billet

  late final String titreEvent, ville, lieu, organisateur, devise, categorie, posterUrl;
  late final String dateTxt, heureTxt;
  late final double prixUnitaire, frais, total;

  final _page = PageController();
  int _index = 0;

  // Fonts PDF
  pw.Font? _pdfRegular;
  pw.Font? _pdfBold;

  @override
  void initState() {
    super.initState();

    ev = (widget.data['evenements'] is Map)
        ? Map<String, dynamic>.from(widget.data['evenements'] as Map)
        : <String, dynamic>{};
    bi = (widget.data['billets'] is Map)
        ? Map<String, dynamic>.from(widget.data['billets'] as Map)
        : <String, dynamic>{};

    pal = paletteFromEvent(ev);

    // --- Données dynamiques (aucune valeur figée) ---
    titreEvent   = (ev['titre'] ?? '').toString();
    ville        = (ev['ville'] ?? '').toString();
    lieu         = (ev['lieu']  ?? '').toString();
    organisateur = (ev['organisateur'] ?? '').toString();
    posterUrl    = (ev['photo_url'] ?? ev['cover_url'] ?? '').toString();

    qty       = int.tryParse((widget.data['quantite'] ?? '1').toString()) ?? 1;
    devise    = (widget.data['devise'] ?? '').toString();
    categorie = (bi['titre'] ?? '').toString();

    prixUnitaire = double.tryParse((widget.data['prix_unitaire'] ?? widget.data['prix'] ?? '0').toString()) ?? 0;
    frais        = double.tryParse((widget.data['frais'] ?? '0').toString()) ?? 0;
    total        = double.tryParse((widget.data['prix_total'] ?? (prixUnitaire * qty + frais)).toString())
                    ?? (prixUnitaire * qty + frais);

    DateTime? date;
    final rawDate = ev['date_debut']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) date = DateTime.tryParse(rawDate);
    dateTxt  = (date != null) ? DateFormat('dd MMMM yyyy', 'fr_FR').format(date!).toUpperCase() : '';
    heureTxt = (date != null) ? DateFormat('HH:mm', 'fr_FR').format(date!) : '';

    baseToken = (widget.data['qr_token'] ?? '').toString();
    tokens    = List.generate(qty, (i) => baseToken.isEmpty ? 'N/A' : (qty > 1 ? '$baseToken-${i + 1}' : baseToken));
  }

  String _fmt(num v) => NumberFormat('#,###', 'fr_FR').format(v);

  /// Montant par billet (incluant la part de frais si total disponible)
  double _montantBillet() {
    if (qty <= 0) return prixUnitaire; // fallback
    if (total > 0) return total / qty;
    // sinon on répartit les frais
    return prixUnitaire + (frais / qty);
  }

  // Chargement des polices (fallback Helvetica)
  Future<pw.Font> _loadPdfFont(String path, {pw.Font? fallback}) async {
    try {
      final bd = await rootBundle.load(path);
      return pw.Font.ttf(bd);
    } catch (_) {
      return fallback ?? pw.Font.helvetica();
    }
  }

  // ===== Export PDF : 1 billet par page (A5 paysage), MONTANT PAR BILLET =====
  Future<void> _downloadAllAsPdf() async {
    try {
      _pdfRegular ??= await _loadPdfFont('assets/fonts/Inter_24pt-Regular.ttf');
      _pdfBold    ??= await _loadPdfFont('assets/fonts/Inter_24pt-Bold.ttf', fallback: _pdfRegular);

      final doc = pw.Document(theme: pw.ThemeData.withFont(base: _pdfRegular!, bold: _pdfBold!));

      final accentLight = HSLColor.fromColor(pal.end).withLightness(0.65).toColor();
      final pdfA = PdfColor.fromInt(pal.end.value);
      final pdfB = PdfColor.fromInt(accentLight.value);
      final borderGrey = PdfColor.fromInt(0xFFE0E0E0);

      pw.ImageProvider? poster;
      if (posterUrl.isNotEmpty) { try { poster = await networkImage(posterUrl); } catch (_) {} }

      Future<pw.MemoryImage> _qr(String data) async {
        final p = QrPainter(data: data.isEmpty ? 'N/A' : data, version: QrVersions.auto, gapless: true);
        final img = await p.toImage(900);
        final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List() ?? Uint8List(0);
        return pw.MemoryImage(bytes);
      }

      final montantParBillet = _montantBillet();

      for (var i = 0; i < qty; i++) {
        final qrImg = await _qr(tokens[i]);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a5.landscape,
            margin: const pw.EdgeInsets.all(18),
            build: (ctx) => pw.Stack(
              children: [
                // Fond dégradé arrondi
                pw.Container(
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [pdfB, pdfA],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                ),
                // Encoches
                pw.Positioned(left: -8, top: PdfPageFormat.a5.width / 4.2,
                  child: pw.Container(width: 32, height: 32, decoration: const pw.BoxDecoration(color: PdfColors.white, shape: pw.BoxShape.circle))),
                pw.Positioned(right: -8, bottom: PdfPageFormat.a5.width / 4.2,
                  child: pw.Container(width: 32, height: 32, decoration: const pw.BoxDecoration(color: PdfColors.white, shape: pw.BoxShape.circle))),

                // Contenu
                pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // LEFT
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (titreEvent.isNotEmpty)
                              pw.Text(titreEvent.toUpperCase(),
                                  style: pw.TextStyle(color: PdfColors.white, fontSize: 30, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                            if (titreEvent.isNotEmpty) pw.SizedBox(height: 6),
                            if (ville.isNotEmpty)
                              pw.Text(ville.toUpperCase(),
                                  style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                            if (ville.isNotEmpty) pw.SizedBox(height: 18),
                            if (dateTxt.isNotEmpty || lieu.isNotEmpty)
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  if (dateTxt.isNotEmpty)
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(dateTxt,
                                            style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                        if (heureTxt.isNotEmpty) pw.SizedBox(height: 2),
                                        if (heureTxt.isNotEmpty)
                                          pw.Text(heureTxt, style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                                      ],
                                    ),
                                  if (dateTxt.isNotEmpty) pw.SizedBox(width: 30),
                                  if (lieu.isNotEmpty)
                                    pw.Text(lieu.toUpperCase(),
                                        style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            pw.SizedBox(height: 12),
                            // Petit panneau blanc avec détails (opacité via ARGB)
                            pw.Container(
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromInt(0xEAFFFFFF), // ~92% d'opacité
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              padding: const pw.EdgeInsets.all(12),
                              child: pw.Column(
                                children: [
                                  if (categorie.isNotEmpty) _pwKv('Catégorie', categorie),
                                  _pwKv('Quantité', 'x$qty'),
                                  _pwKv('Prix unitaire', '${_fmt(prixUnitaire)} ${devise.isEmpty ? '' : devise}'),
                                  _pwKv('Frais', '${_fmt(frais)} ${devise.isEmpty ? '' : devise}'),
                                  pw.Divider(),
                                  _pwKvStrong('Total', '${_fmt(total)} ${devise.isEmpty ? '' : devise}'),
                                ],
                              ),
                            ),
                            pw.Spacer(),
                            // Logo Soneya + MONTANT PAR BILLET
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 30, height: 30,
                                  decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColor.fromInt(_kBrandYellow.value)),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('S',
                                    style: pw.TextStyle(color: PdfColor.fromInt(_kBrandNavy.value), fontWeight: pw.FontWeight.bold, fontSize: 18)),
                                ),
                                pw.SizedBox(width: 8),
                                pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('SONEYA', style: pw.TextStyle(color: PdfColor.fromInt(_kBrandNavy.value), fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                    pw.Text('EVENTS', style: pw.TextStyle(color: PdfColor.fromInt(_kBrandNavy.value), fontSize: 10)),
                                  ],
                                ),
                                pw.Spacer(),
                                pw.Text('${_fmt(montantParBillet)} ${devise.isEmpty ? '' : devise}',
                                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 24)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Perforation
                      pw.Container(
                        width: 20,
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: List.generate(
                            18,
                            (idx) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Container(width: 2, height: 6, color: PdfColors.white),
                            ),
                          ),
                        ),
                      ),

                      // RIGHT (QR)
                      pw.Expanded(
                        flex: 5,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(16)),
                          child: pw.Stack(
                            children: [
                              pw.Center(
                                child: pw.Container(
                                  width: 160, height: 160,
                                  decoration: pw.BoxDecoration(
                                    borderRadius: pw.BorderRadius.circular(12),
                                    border: pw.Border.all(color: borderGrey, width: 1),
                                  ),
                                  child: pw.ClipRRect(
                                    horizontalRadius: 12, verticalRadius: 12,
                                    child: pw.Image(qrImg, fit: pw.BoxFit.contain),
                                  ),
                                ),
                              ),
                              if (categorie.isNotEmpty)
                                pw.Positioned(
                                  top: 0, right: 0,
                                  child: pw.Container(
                                    width: 54, height: 54,
                                    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColor.fromInt(kAppBlue.value)),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      categorie.toUpperCase(),
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                                ),
                              if (poster != null)
                                pw.Positioned(
                                  left: 0, bottom: 0,
                                  child: pw.Container(
                                    width: 58, height: 58,
                                    decoration: pw.BoxDecoration(
                                      borderRadius: pw.BorderRadius.circular(8),
                                      border: pw.Border.all(color: borderGrey, width: 1),
                                    ),
                                    child: pw.ClipRRect(
                                      horizontalRadius: 8, verticalRadius: 8,
                                      child: pw.Image(poster, fit: pw.BoxFit.cover),
                                    ),
                                  ),
                                ),
                              if (qty > 1)
                                pw.Positioned(
                                  bottom: 2, right: 2,
                                  child: pw.Text('Billet #${i + 1}',
                                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF616161), fontWeight: pw.FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Positioned(
                  right: 24, bottom: 12,
                  child: pw.Text('Généré par Soneya • ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.now())}',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                ),
              ],
            ),
          ),
        );
      }

      final fileName = 'billets_${_slug(titreEvent.isEmpty ? "event" : titreEvent)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur export PDF: $e')));
    }
  }

  String _slug(String s) => s.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  @override
  Widget build(BuildContext context) {
    final montantParBillet = _montantBillet();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(qty > 1 ? 'Billets' : 'Billet'),
        backgroundColor: pal.start,
        foregroundColor: Colors.white,
        actions: [
          // Icône carte mémoire = export PDF (une page par billet)
          IconButton(
            tooltip: 'Télécharger',
            icon: const Icon(Icons.sd_card_rounded),
            onPressed: _downloadAllAsPdf,
          ),
        ],
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (ctx, c) {
            final maxW = math.min(c.maxWidth, 980.0);

            return Column(
              children: [
                const SizedBox(height: 10),
                if (qty > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: kAppBlue.withOpacity(.1), borderRadius: BorderRadius.circular(16)),
                    child: AnimatedBuilder(
                      animation: _page,
                      builder: (_, __) {
                        final i = (_page.hasClients ? _page.page?.round() ?? _index : _index) + 1;
                        return Text('$i / $qty', style: const TextStyle(fontWeight: FontWeight.w800));
                      },
                    ),
                  ),
                const SizedBox(height: 12),

                // Swipe entre billets
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: maxW,
                        child: AspectRatio(
                          aspectRatio: 3.1,
                          child: PageView.builder(
                            controller: _page,
                            itemCount: qty,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (_, i) {
                              // Scale anti-overflow
                              return FittedBox(
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: 1000,
                                  height: 1000 / 3.1,
                                  child: _TicketCard(
                                    palette: pal,
                                    left: _TicketLeft(
                                      palette: pal,
                                      posterUrl: posterUrl,
                                      titreEvent: titreEvent,
                                      ville: ville,
                                      lieu: lieu,
                                      dateTxt: dateTxt,
                                      heureTxt: heureTxt,
                                      cat: categorie,
                                      qty: qty,
                                      devise: devise,
                                      prixUnitaire: prixUnitaire,
                                      frais: frais,
                                      total: total,
                                      montantBillet: montantParBillet, // <<< montant spécifique
                                      organisateur: organisateur,
                                    ),
                                    right: _TicketRight(
                                      token: tokens[i],
                                      palette: pal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Indicateurs de page
                if (qty > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        qty,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? kAppBlue : kAppBlue.withOpacity(.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===============================
//        Ticket Card Shell
// ===============================
class _TicketCard extends StatelessWidget {
  final Widget left;
  final Widget right;
  final TicketPalette palette;
  const _TicketCard({required this.left, required this.right, required this.palette});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TicketClipper(notchRadius: 16),
      child: CustomPaint(
        painter: _TicketBackgroundPainter(palette),
        child: Row(
          children: [
            Expanded(flex: 3, child: Container(padding: const EdgeInsets.fromLTRB(24, 22, 18, 22), child: left)),
            SizedBox(width: 1.5, child: CustomPaint(painter: _PerforationPainter())),
            Expanded(flex: 2, child: Container(padding: const EdgeInsets.fromLTRB(18, 22, 24, 22), child: right)),
          ],
        ),
      ),
    );
  }
}

// ===============================
//        Left Panel Content
// ===============================
class _TicketLeft extends StatelessWidget {
  final TicketPalette palette;
  final String posterUrl;
  final String titreEvent, ville, lieu, dateTxt, heureTxt, cat, devise, organisateur;
  final int qty;
  final double prixUnitaire, frais, total, montantBillet;

  const _TicketLeft({
    required this.palette,
    required this.posterUrl,
    required this.titreEvent,
    required this.ville,
    required this.lieu,
    required this.dateTxt,
    required this.heureTxt,
    required this.cat,
    required this.qty,
    required this.devise,
    required this.prixUnitaire,
    required this.frais,
    required this.total,
    required this.montantBillet,
    required this.organisateur,
  });

  String _fmt(num v) => NumberFormat('#,###', 'fr_FR').format(v);

  @override
  Widget build(BuildContext context) {
    final navy = palette.text;

    return DefaultTextStyle(
      style: TextStyle(color: navy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne top: Titre + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  titreEvent.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.05),
                ),
              ),
              const SizedBox(width: 12),
              if (cat.isNotEmpty) _VipBadge(text: cat.toUpperCase()),
            ],
          ),
          const SizedBox(height: 8),

          if (ville.isNotEmpty)
            Text(ville.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: .5)),
          if (ville.isNotEmpty) const SizedBox(height: 6),

          Wrap(
            runSpacing: 6,
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (dateTxt.isNotEmpty) _ChipInfo(icon: Icons.calendar_month, text: dateTxt),
              if (heureTxt.isNotEmpty) _ChipInfo(icon: Icons.schedule, text: heureTxt),
              if (lieu.isNotEmpty) _ChipInfo(icon: Icons.place, text: lieu),
            ],
          ),
          const SizedBox(height: 10),

          // Bloc prix détaillé global
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (cat.isNotEmpty) _kv('Catégorie', '$cat'),
                _kv('Quantité', 'x$qty'),
                _kv('Prix unitaire', '${_fmt(prixUnitaire)} ${devise.isEmpty ? '' : devise}'),
                _kv('Frais', '${_fmt(frais)} ${devise.isEmpty ? '' : devise}'),
                const Divider(height: 16),
                _kvStrong('Total', '${_fmt(total)} ${devise.isEmpty ? '' : devise}'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bloc logo Soneya + MONTANT POUR CE BILLET
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _kBrandYellow),
                alignment: Alignment.center,
                child: const Text('S', style: TextStyle(color: _kBrandNavy, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SONEYA', style: TextStyle(color: _kBrandNavy, fontWeight: FontWeight.w900, fontSize: 12)),
                  Text('EVENTS', style: TextStyle(color: _kBrandNavy, fontSize: 10)),
                ],
              ),
              const Spacer(),
              Text(
                '${_fmt(montantBillet)} ${devise.isEmpty ? '' : devise}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Flexible(child: Text(v, textAlign: TextAlign.right)),
        ],
      );

  Widget _kvStrong(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      );
}

class _VipBadge extends StatelessWidget {
  final String text;
  const _VipBadge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(text, style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, letterSpacing: .5)),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChipInfo({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.9), borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: _kNavy),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: _kNavy, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ===============================
//        Right Panel (QR)
// ===============================
class _TicketRight extends StatelessWidget {
  final String token;
  final TicketPalette palette;
  const _TicketRight({required this.token, required this.palette});

  @override
  Widget build(BuildContext context) {
    String short = token;
    if (short.length > 8) short = '${token.substring(0, 4)}…${token.substring(token.length - 4)}';

    return Column(
      children: [
        const Spacer(),
        // >>> Tap pour plein écran
        GestureDetector(
          onTap: () => _showQrFullScreen(context, token),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            padding: const EdgeInsets.all(10),
            child: Hero(
              tag: 'qr-$token',
              child: QrImageView(
                data: token.isEmpty ? 'N/A' : token,
                version: QrVersions.auto,
                size: 150,
                gapless: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('SCANNER ICI', style: TextStyle(color: palette.text, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(short, style: TextStyle(color: palette.text.withOpacity(.75), fontSize: 12)),
        const Spacer(),
      ],
    );
  }

  static Future<void> _showQrFullScreen(BuildContext context, String token) async {
    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.85),
      barrierDismissible: true,
      barrierLabel: 'QR',
      pageBuilder: (_, __, ___) {
        return Center(
          child: Hero(
            tag: 'qr-$token',
            child: Material(
              color: Colors.transparent,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: token.isEmpty ? 'N/A' : token,
                    version: QrVersions.auto,
                    size: 420, // grand QR
                    gapless: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    );
  }
}

// ===============================
//         Shapes & Painters
// ===============================
class _TicketClipper extends CustomClipper<Path> {
  final double notchRadius;
  const _TicketClipper({this.notchRadius = 16});
  @override
  Path getClip(Size size) {
    final r = notchRadius;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    final cy = size.height / 2;
    final leftNotch  = Path()..addOval(Rect.fromCircle(center: Offset(0, cy), radius: r));
    final rightNotch = Path()..addOval(Rect.fromCircle(center: Offset(size.width, cy), radius: r));
    return Path.combine(PathOperation.difference, Path.combine(PathOperation.difference, path, leftNotch), rightNotch);
  }
  @override
  bool shouldReclip(covariant _TicketClipper old) => old.notchRadius != notchRadius;
}

class _TicketBackgroundPainter extends CustomPainter {
  final TicketPalette palette;
  const _TicketBackgroundPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [palette.start, palette.end],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), paint);

    // Motif ondulé subtil
    final wave = Paint()..color = Colors.white.withOpacity(.08);
    const amp = 8.0, stepX = 22.0;
    for (double y = 16; y < size.height; y += 22) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += stepX) {
        path.quadraticBezierTo(x + stepX / 4, y - amp, x + stepX / 2, y);
        path.quadraticBezierTo(x + 3 * stepX / 4, y + amp, x + stepX, y);
      }
      canvas.drawPath(path, wave);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0, gap = 6.0;
    final paint = Paint()..color = Colors.white.withOpacity(.85)..strokeWidth = 1.5;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + dash, size.height)), paint);
      y += dash + gap;
    }
    // ombre légère
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x22000000));
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ===== Helpers PDF (kv) =====
pw.Widget _pwKv(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 4),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_kNavy.value))),
      pw.SizedBox(width: 10),
      pw.Flexible(child: pw.Text(v, textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColor.fromInt(_kNavy.value)))),
    ],
  ),
);

pw.Widget _pwKvStrong(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_kNavy.value))),
      pw.SizedBox(width: 10),
      pw.Flexible(child: pw.Text(v, textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_kNavy.value)))),
    ],
  ),
);
