import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favoris_provider.dart';

class FavorisPage extends StatelessWidget {
  const FavorisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final favorisProvider = context.watch<FavorisProvider>();
    final favoris = favorisProvider.favoris;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: favoris.isEmpty
          ? const Center(
              child: Text(
                "Aucun favori pour l’instant.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favoris.length,
              itemBuilder: (context, index) {
                final itemId = favoris[index]; // ici ce sont des IDs

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                      radius: 26,
                    ),
                    title: Text(
                      'Favori #$itemId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Type inconnu pour le moment'),
                    trailing: const Icon(Icons.favorite, color: Color(0xFFCE1126)),
                    onTap: () {
                      // ➕ futur affichage de détail
                    },
                  ),
                );
              },
            ),
    );
  }
}
