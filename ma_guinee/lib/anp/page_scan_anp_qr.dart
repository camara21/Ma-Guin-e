import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PageScanAnpQr extends StatefulWidget {
  const PageScanAnpQr({super.key});

  @override
  State<PageScanAnpQr> createState() => _PageScanAnpQrState();
}

class _PageScanAnpQrState extends State<PageScanAnpQr> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false; // pour éviter plusieurs pops

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Extrait UNIQUEMENT le code ANP GN-... depuis le texte du QR.
  /// Exemple :
  ///   "NOM: MOHAMED CAMARA ANP: GN-28-72-WY-WU"
  ///   => "GN-28-72-WY-WU"
  String? _extractAnpCode(String raw) {
    if (raw.isEmpty) return null;

    final upper = raw.toUpperCase().trim();

    // 1) Motif GN-.... (lettres/chiffres + tirets)
    final reg = RegExp(r'GN-[0-9A-Z-]+');
    final match = reg.firstMatch(upper);
    if (match != null) {
      return match.group(0); // ex: GN-28-72-WY-WU
    }

    // 2) Fallback léger : on découpe le texte et on prend le premier "mot" GN-
    final parts = upper.split(RegExp(r'\s+'));
    for (final p in parts) {
      if (p.startsWith('GN-')) {
        // On nettoie tous les caractères bizarres autour
        final cleaned = p.replaceAll(RegExp(r'[^0-9A-Z\-]'), '');
        if (cleaned.isNotEmpty) return cleaned;
      }
    }

    // ❌ AUCUN code ANP trouvé → on renvoie null
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final val = barcodes.first.rawValue;
    if (val == null || val.trim().isEmpty) return;

    // 👉 On essaie de récupérer UNIQUEMENT le code ANP
    final anpCode = _extractAnpCode(val);

    if (anpCode == null || anpCode.isEmpty) {
      // Pas de code ANP valide → on ignore ce QR (on ne renvoie JAMAIS le texte complet)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ce QR ne contient pas de code ANP valide."),
        ),
      );
      return;
    }

    _handled = true;

    // ✅ On renvoie UNIQUEMENT le code ANP (ex: GN-28-72-WY-WU)
    Navigator.of(context).pop<String>(anpCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Scanner un code ANP",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Flux caméra + détection QR
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay centré style cadre
          IgnorePointer(
            ignoring: true,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Texte d'aide en bas
          const Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Placez le QR code de l’ANP dans le cadre",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Le scan se fera automatiquement.\n"
                  "Seul le code ANP sera utilisé pour la recherche.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
