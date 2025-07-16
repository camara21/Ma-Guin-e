import 'package:flutter/material.dart';
import 'package:ma_guinee/models/annonce_model.dart';

class AnnonceCard extends StatelessWidget {
  final AnnonceModel annonce;
  final VoidCallback? onTap;

  const AnnonceCard({
    super.key,
    required this.annonce,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: annonce.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  annonce.images.first,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.image_not_supported),
              ),
        title: Text(
          annonce.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              annonce.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              "${annonce.ville} • ${annonce.categorie}",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
