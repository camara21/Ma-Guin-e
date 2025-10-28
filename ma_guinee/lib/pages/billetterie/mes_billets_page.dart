// lib/pages/billetterie/mes_billets_page.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../services/billetterie_service.dart';
import 'billet_view_page.dart';

// Palette Billetterie
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary = Colors.white;

class MesBilletsPage extends StatefulWidget {
  const MesBilletsPage({super.key});

  @override
  State<MesBilletsPage> createState() => _MesBilletsPageState();
}

class _MesBilletsPageState extends State<MesBilletsPage> {
  final _svc = BilletterieService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.listMesReservations();
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Export direct (sans passer par la preview)
  Future<void> _exportBilletPdf(Map<String, dynamic> data) async {
    try {
      final bytes = await _buildPdf(data);
      final ev = (data['evenements'] is Map)
          ? Map<String, dynamic>.from(data['evenements'] as Map)
          : <String, dynamic>{};
      final title = (ev['titre'] ?? 'Evenement').toString();
      final fileName = 'billet_${_slug(title)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export PDF: $e')),
      );
    }
  }

  // Génère le PDF (même rendu que la preview)
  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
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

    // QR -> PNG
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
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(_kEventPrimary.value),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300, width: 1),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Image(pw.MemoryImage(pngBytes), width: 160, height: 160),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _kv('Type de billet', '$billetTitle • x$qty'),
                          if (ville.isNotEmpty || lieu.isNotEmpty) _kv('Lieu', '$lieu • $ville'),
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
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
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

  String _slug(String s) {
    final base = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return base.isEmpty ? 'billet' : base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Mes billets'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Aucune réservation.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _BilletCard(
                        data: _items[i],
                        onTapOpenPreview: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BilletViewPage(data: _items[i]),
                            ),
                          );
                        },
                        onTapDownload: () => _exportBilletPdf(_items[i]),
                      ),
                    ),
    );
  }
}

class _BilletCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTapOpenPreview;
  final VoidCallback onTapDownload;

  const _BilletCard({
    required this.data,
    required this.onTapOpenPreview,
    required this.onTapDownload,
  });

  Color _statusBg(String s) {
    switch (s) {
      case 'utilise':
        return const Color(0xFF2E7D32).withOpacity(.12);
      case 'annule':
        return const Color(0xFFB00020).withOpacity(.12);
      default:
        return _kEventPrimary.withOpacity(.12);
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'utilise':
        return const Color(0xFF2E7D32);
      case 'annule':
        return const Color(0xFFB00020);
      default:
        return _kEventPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ev = (data['evenements'] is Map)
        ? Map<String, dynamic>.from(data['evenements'] as Map)
        : null;
    final bi = (data['billets'] is Map)
        ? Map<String, dynamic>.from(data['billets'] as Map)
        : null;

    DateTime? date;
    final rawDate = ev?['date_debut']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    }
    final dateTxt = (date != null)
        ? DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(date)
        : '';

    final statut = (data['statut'] ?? '').toString();

    // ⬇️ La carte est cliquable => ouvre la preview
    return InkWell(
      onTap: onTapOpenPreview,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.secondary.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // QR
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.secondary.withOpacity(.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: (data['qr_token'] ?? '').toString(),
                  size: 86,
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev?['titre']?.toString() ?? 'Événement',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${bi?['titre'] ?? 'Billet'} • x${data['quantite']}'),
                    const SizedBox(height: 4),
                    Text('${ev?['lieu'] ?? ''} • ${ev?['ville'] ?? ''}'),
                    if (dateTxt.isNotEmpty) Text(dateTxt),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusBg(statut),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statut.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _statusFg(statut),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onTapDownload,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Télécharger PDF'),
                          style: TextButton.styleFrom(
                            foregroundColor: _kEventPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Utilitaires locaux
pw.Widget _kv(String k, String v) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$k : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: v),
        ],
      ),
    ),
  );
}
