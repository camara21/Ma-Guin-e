import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/events_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _svc = EventsService();
  String _status = '';

  void _onDetect(BarcodeCapture barcodes) async {
    if (barcodes.barcodes.isEmpty) return;
    final qr = barcodes.barcodes.first.rawValue;
    if (qr == null) return;

    final res = await _svc.scanTicket(qr);
    setState(() => _status = res.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner billet')),
      body: Column(
        children: [
          Expanded(child: MobileScanner(onDetect: _onDetect)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Résultat: $_status'),
          ),
        ],
      ),
    );
  }
}
