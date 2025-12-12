import 'package:flutter/material.dart';
import '../models/annonce_model.dart';

class AnnonceGridCard extends StatelessWidget {
  final AnnonceModel annonce;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavori;

  const AnnonceGridCard({
    super.key,
    required this.annonce,
    this.onTap,
    this.onToggleFavori,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl =
        (annonce.images != null && annonce.images.isNotEmpty)
            ? annonce.images.first
            : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo principale
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: double.infinity,
                      height: 110,
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
            ),
            // Titre
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Text(
                annonce.titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                  color: Colors.black87,
                ),
              ),
            ),
            // Prix
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
              child: Text(
                '${annonce.prix ?? ""} ${annonce.devise ?? "GNF"}',
                style: const TextStyle(
                  color: Color(0xFF113CFC),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            // Catégorie, ville et favori en bas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Infos à gauche
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            annonce.categorie ?? "",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            annonce.ville ?? "",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bouton favori à droite
                    GestureDetector(
                      onTap: onToggleFavori,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(left: 4, bottom: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          annonce.estFavori == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: annonce.estFavori == true
                              ? Colors.red
                              : Colors.grey,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
