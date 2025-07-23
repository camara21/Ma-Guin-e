import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../models/annonce_model.dart';

class MesAnnoncesPage extends StatefulWidget {
  const MesAnnoncesPage({super.key});

  @override
  State<MesAnnoncesPage> createState() => _MesAnnoncesPageState();
}

class _MesAnnoncesPageState extends State<MesAnnoncesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<UserProvider>();
      if (p.utilisateur == null) await p.chargerUtilisateurConnecte();
      if (p.utilisateur != null) {
        await p.loadAnnoncesUtilisateur(p.utilisateur!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserProvider>();
    final annonces = p.annoncesUtilisateur;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces')),
      body: p.isLoadingUser || p.isLoadingAnnonces
          ? const Center(child: CircularProgressIndicator())
          : annonces.isEmpty
              ? const Center(child: Text("Vous n'avez publié aucune annonce."))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: annonces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = annonces[i];
                    final thumb = (a.images.isNotEmpty) ? a.images.first : null;

                    return InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/annonce_detail', arguments: a);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EFF7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: thumb != null
                                  ? Image.network(
                                      thumb,
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 68,
                                        height: 68,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : Container(
                                      width: 68,
                                      height: 68,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.titre,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 15.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a.categorie,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifier',
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () async {
                                    final updated = await Navigator.pushNamed(
                                      context,
                                      '/edit_annonce',
                                      arguments: a.toJson(),
                                    );
                                    if (updated != null && mounted) {
                                      await p.loadAnnoncesUtilisateur(p.utilisateur!.id);
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("Supprimer l'annonce"),
                                            content: const Text(
                                                "Cette action est irréversible. Continuer ?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text("Annuler"),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text("Supprimer",
                                                    style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (ok) {
                                      await p.supprimerAnnonce(a.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Annonce supprimée.")),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
