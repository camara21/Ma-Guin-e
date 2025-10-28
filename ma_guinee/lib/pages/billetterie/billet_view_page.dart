// lib/pages/billetterie/billet_view_page.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

class BilletViewPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const BilletViewPage({super.key, required this.data});

  // Construit le PDF du billet
  static Future<Uint8List> _buildPdf(
      Map<String, dynamic> data, PdfPageFormat format) async {
    final ev = (data['evenements'] is Map)
        ? Map<String, dynamic>.from(data['evenements'] as Map)
        : <String, dynamic>{};
    final bi = (data['billets'] is Map)
        ? Map<String, dynamic>.from(data['billets'] as Map)
        : <String, dynamic>{};

    final title = (ev['titre'] ?? 'Événement').toString();
    final billetTitle = (bi['titre'] ?? 'Billet').toString();
    final qty = (data['quantite'] ?? 1).toString();
    final lieu = (ev['lieu'] ?? '').toString();
    final ville = (ev['ville'] ?? '').toString();
    final statut = (data['statut'] ?? '').toString().toUpperCase();
    final token = (data['qr_token'] ?? '').toString();

    DateTime? date;
    final rawDate = ev['date_debut']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    }
    final dateTxt = (date != null)
        ? DateFormat('EEE d MMM yyyy • HH:mm', 'fr_FR').format(date)
        : '';

    // QR PNG haute résolution
    final qrPainter = QrPainter(
      data: token.isEmpty ? 'N/A' : token,
      version: QrVersions.auto,
      gapless: true,
    );
    final uiImage = await qrPainter.toImage(700);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData?.buffer.asUint8List() ?? Uint8List(0);
    final qrImg = pw.MemoryImage(pngBytes);

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context ctx) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            padding: const pw.EdgeInsets.all(18),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bandeau titre
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(_kEventPrimary.value),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Billet — $title',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      pw.Text(
                        statut,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Détails + QR
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border:
                            pw.Border.all(color: PdfColors.grey300, width: 1),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Image(qrImg, width: 160, height: 160),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _kv('Type de billet', '$billetTitle • x$qty'),
                          if (ville.isNotEmpty || lieu.isNotEmpty)
                            _kv('Lieu', '$lieu • $ville'),
                          if (dateTxt.isNotEmpty) _kv('Date', dateTxt),
                          _kv('Token', token.isEmpty ? '—' : token),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Généré par Soneya • ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$k : ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  static String _slug(String s) {
    final base = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return base.isEmpty ? 'billet' : base;
  }

  @override
  Widget build(BuildContext context) {
    final ev = (data['evenements'] is Map)
        ? Map<String, dynamic>.from(data['evenements'] as Map)
        : <String, dynamic>{};
    final title = (ev['titre'] ?? 'Evenement').toString();
    final fileName =
        'billet_${_slug(title)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Prévisualisation du billet'),
        // ➜ On ne met plus de bouton à droite
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,   // garde l’icône imprimante en bas
        allowSharing: true,    // ➜ le bouton « partager » (cercle) en bas partage le PDF
        canDebug: false,       // supprime le petit bouton blanc à droite
        useActions: true,
        pdfFileName: fileName,
        build: (format) => _buildPdf(data, format),
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}
