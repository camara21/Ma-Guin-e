import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AnpQrWidget extends StatelessWidget {
  final String codeAnp;

  const AnpQrWidget({
    super.key,
    required this.codeAnp,
  });

  @override
  Widget build(BuildContext context) {
    if (codeAnp.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Conteneur avec ombre pour faire premium
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: QrImageView(
            data: codeAnp,
            version: QrVersions.auto,
            size: 200,
            gapless: true,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          codeAnp,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Scannez ce QR code pour obtenir mon ANP",
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
