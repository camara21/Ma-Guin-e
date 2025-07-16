import 'package:flutter/material.dart';
import '../models/lieu_model.dart';

class LieuCard extends StatelessWidget {
  final LieuModel lieu;
  final VoidCallback? onTap;

  const LieuCard({
    super.key,
    required this.lieu,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(lieu.imageUrl),
          radius: 26,
        ),
        title: Text(
          lieu.nom,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${lieu.type} • ${lieu.ville ?? 'Localisation inconnue'}'),
        trailing: const Icon(Icons.location_on, color: Color(0xFF009460)),
        onTap: onTap,
      ),
    );
  }
}
