// lib/pages/billetterie/ticket_scanner_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Palette Billetterie
const _kEventPrimary = Color(0xFF7B2CBF);
const _kOnPrimary   = Colors.white;

class TicketScannerPage extends StatefulWidget {
  const TicketScannerPage({super.key});

  @override
  State<TicketScannerPage> createState() => _TicketScannerPageState();
}

class _TicketScannerPageState extends State<TicketScannerPage> {
  final _sb = Supabase.instance.client;

  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _processing = false;
  String? _last;

  @override
  void reassemble() {
    super.reassemble();
    // Requis sur Android lors d’un hot reload
    if (Platform.isAndroid) {
      _controller.stop();
    }
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _consume(String token) async {
    if (_processing) return; // anti-doublon
    setState(() => _processing = true);
    try {
      final res = await _sb.rpc('consume_qr', params: {'p_qr_token': token});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Billet validé ✅ (#$res)'),
          backgroundColor: const Color(0xFF2E7D32), // vert succès
        ),
      );
      setState(() => _last = token);

      // petite pause pour éviter de revalider le même QR
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalide: $e'),
          backgroundColor: const Color(0xFFB00020), // rouge erreur
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Scanner des billets'),
        actions: [
          IconButton(
            tooltip: 'Flash',
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Caméra',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () async {
              await _controller.switchCamera();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone scanner + overlay
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final token = (b.rawValue ?? '').trim();
                      if (token.isNotEmpty && !_processing) {
                        _consume(token);
                        break;
                      }
                    }
                  },
                ),
                // Masque sombre pour mieux voir la zone
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(.15),
                          Colors.black.withOpacity(.25),
                        ],
                      ),
                    ),
                  ),
                ),
                // Fenêtre de cadrage
                IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kEventPrimary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: _kEventPrimary.withOpacity(.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Zone d’état
          Expanded(
            child: Center(
              child: _processing
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _last == null ? 'Encadrez le QR du billet.' : 'Dernier QR scanné:',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (_last != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kEventPrimary.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _kEventPrimary.withOpacity(.25)),
                            ),
                            child: Text(
                              _last!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: _kEventPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
