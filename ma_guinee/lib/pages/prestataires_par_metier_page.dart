import 'package:flutter/material.dart';
import 'prestataire_detail_page.dart';

class PrestatairesParMetierPage extends StatelessWidget {
  final String metier;
  final List<Map<String, dynamic>> allPrestataires;

  const PrestatairesParMetierPage({
    Key? key,
    required this.metier,
    required this.allPrestataires,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final m = metier.toLowerCase();
    final filtres = allPrestataires.where((p) {
      return (p['metier'] ?? '').toString().toLowerCase() == m;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FB),
      appBar: AppBar(
        title: Text(
          'Prestataires : $metier',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0.8,
      ),
      body: filtres.isEmpty
          ? const Center(child: Text("Aucun prestataire trouvé."))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtres.length,
              itemBuilder: (_, i) {
                final p = filtres[i];
                final nom = (p['nom'] ?? p['name'] ?? '').toString();
                final ville = (p['ville'] ?? '').toString();
                final photo = (p['photo_url'] ?? p['image'] ?? '').toString();
                final metier = (p['metier'] ?? '').toString();

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.purple.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : const AssetImage('assets/avatar.png') as ImageProvider,
                    ),
                    title: Text(nom.isEmpty ? metier : nom,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('$metier • $ville'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrestataireDetailPage(data: p),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
