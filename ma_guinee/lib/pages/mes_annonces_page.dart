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
  // ===== PALETTE FIXE (inspirée SFR) =====
  static const Color annoncesPrimary     = Color(0xFFE60000); // rouge actions (pressed)
  static const Color annoncesSecondary   = Color(0xFFFFE5E5); // fond doux
  static const Color annoncesOnPrimary   = Color(0xFFFFFFFF);
  static const Color annoncesOnSecondary = Color(0xFF1F2937);

  // Neutres
  static const Color _pageBg   = Color(0xFFF5F7FA);
  static const Color _cardBg   = Color(0xFFFFFFFF);
  static const Color _stroke   = Color(0xFFE5E7EB);
  static const Color _text     = Color(0xFF1F2937);
  static const Color _text2    = Color(0xFF6B7280);

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

    // Style pour icônes qui deviennent rouges uniquement lorsqu'elles sont pressées
    Color _iconColor(Set<MaterialState> s) =>
        s.contains(MaterialState.pressed) ? annoncesPrimary : _text2;

    final iconBtnStyle = ButtonStyle(
      foregroundColor:
          MaterialStateProperty.resolveWith<Color>(_iconColor),
      overlayColor: MaterialStateProperty.all(
        annoncesSecondary.withOpacity(0.35),
      ),
      splashFactory: InkSplash.splashFactory,
    );

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0.5,
        // Icônes de l'AppBar en neutre (pas rouge permanent)
        iconTheme: const IconThemeData(color: _text),
        title: const Text(
          'Mes annonces',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        foregroundColor: _text,
      ),
      body: p.isLoadingUser || p.isLoadingAnnonces
          ? const Center(child: CircularProgressIndicator())
          : annonces.isEmpty
              ? Center(
                  child: Text(
                    "Vous n'avez publié aucune annonce.",
                    style: TextStyle(color: _text2, fontSize: 17),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: annonces.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final AnnonceModel a = annonces[i];
                    final thumb = (a.images.isNotEmpty) ? a.images.first : null;

                    return Material(
                      color: annoncesSecondary.withOpacity(0.18), // léger voile
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/annonce_detail',
                            arguments: a,
                          );
                        },
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            color: _cardBg,
                            border: Border.all(color: _stroke),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: thumb != null
                                    ? Image.network(
                                        thumb,
                                        width: 74,
                                        height: 74,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 74,
                                          height: 74,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      )
                                    : Container(
                                        width: 74,
                                        height: 74,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.titre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _text,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      a.categorie,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: _text2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit, size: 22),
                                    style: iconBtnStyle,
                                    onPressed: () async {
                                      final updated =
                                          await Navigator.pushNamed(
                                        context,
                                        '/edit_annonce',
                                        arguments: a.toJson(),
                                      );
                                      if (updated != null && mounted) {
                                        await p.loadAnnoncesUtilisateur(
                                            p.utilisateur!.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Annonce modifiée avec succès !",
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete, size: 22),
                                    style: iconBtnStyle,
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                  "Supprimer l'annonce"),
                                              content: const Text(
                                                "Cette action est irréversible. Voulez-vous continuer ?",
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text("Annuler"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                    "Supprimer",
                                                    style: TextStyle(
                                                        color: annoncesPrimary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (ok) {
                                        await p.supprimerAnnonce(a.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Annonce supprimée avec succès !",
                                              ),
                                            ),
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
                      ),
                    );
                  },
                ),
    );
  }
}
