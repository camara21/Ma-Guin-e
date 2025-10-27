// lib/pages/billetterie/ticket_scanner_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    // Nécessaire pour Android/iOS lors d’un hot reload
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
        SnackBar(content: Text('Billet validé ✅ (#$res)')),
      );
      setState(() => _last = token);

      // petite pause pour éviter de revalider le même QR
      await Future.delayed(const Duration(milliseconds: 700));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalide: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
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
          // Zone scanner + overlay simple
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    // Plusieurs barcodes possibles: on prend le premier non vide
                    for (final b in capture.barcodes) {
                      final token = (b.rawValue ?? '').trim();
                      if (token.isNotEmpty && !_processing) {
                        _consume(token);
                        break;
                      }
                    }
                  },
                ),
                // Overlay visuel
                IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
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
                  : _last == null
                      ? const Text('Encadrez le QR du billet.')
                      : Text('Dernier QR scanné: $_last'),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }
}
