import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'inscription_lieu_page.dart';
import 'divertissement_detail_page.dart';
import 'culte_detail_page.dart';
import 'tourisme_detail_page.dart';

class MesLieuxPage extends StatefulWidget {
  const MesLieuxPage({super.key});

  @override
  State<MesLieuxPage> createState() => _MesLieuxPageState();
}

class _MesLieuxPageState extends State<MesLieuxPage> {
  List<Map<String, dynamic>> _lieux = [];
  bool _loading = true;

  // Palette officielle
  static const bleu  = Color(0xFF1E3FCF);
  static const rouge = Color(0xFFCE1126);
  static const jaune = Color(0xFFFFC700);
  static const vert  = Color(0xFF009460);

  @override
  void initState() {
    super.initState();
    _chargerLieux();
  }

  Future<void> _chargerLieux() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _lieux = [];
          _loading = false;
        });
        return;
      }
      final response = await Supabase.instance.client
          .from('lieux')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _lieux = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de charger vos lieux : $e")),
      );
    }
  }

  Future<void> _ajouterOuEditerLieu({Map<String, dynamic>? lieu}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InscriptionLieuPage(lieu: lieu)),
    );
    if (result == true || result == "deleted") {
      _chargerLieux();
    }
  }

  Future<void> _supprimerLieu(Map<String, dynamic> lieu) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment supprimer ce lieu ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: rouge,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('lieux').delete().eq('id', lieu['id']);
        _chargerLieux();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Suppression impossible : $e")),
        );
      }
    }
  }

  void _ouvrirDetail(Map<String, dynamic> lieu) {
    final type = (lieu['type'] ?? '').toString().toLowerCase().trim();
    if (type == 'divertissement') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DivertissementDetailPage(lieu: lieu)));
    } else if (type == 'culte') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CulteDetailPage(lieu: lieu)));
    } else if (type == 'tourisme') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => TourismeDetailPage(lieu: lieu)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune page de détail pour ce type de lieu.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabledFg = Colors.white.withOpacity(.55);
    final disabledIcon = Colors.white.withOpacity(.55);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Mes lieux"),
        backgroundColor: bleu,
        foregroundColor: Colors.white,
        actions: [
          // === Bouton “Mes réservations” DÉSACTIVÉ (grisé) ===
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: TextButton.icon(
              onPressed: null, // <-- désactivé
              icon: Icon(Icons.book_online, color: disabledIcon),
              label: Text(
                "Mes réservations",
                style: TextStyle(color: disabledFg),
              ),
              style: TextButton.styleFrom(
                // pour forcer l'aspect grisé même en Material 3
                disabledForegroundColor: disabledFg,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lieux.isEmpty
              ? const Center(child: Text("Aucun lieu enregistré."))
              : RefreshIndicator(
                  onRefresh: _chargerLieux,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: _lieux.length,
                    itemBuilder: (context, index) {
                      final lieu = _lieux[index];

                      return Card(
                        color: Colors.white,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _ouvrirDetail(lieu),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                color: bleu.withOpacity(0.09),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.place, color: bleu, size: 28),
                              ),
                            ),
                            title: Text(
                              (lieu['nom'] ?? '') as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: bleu,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((lieu['ville'] ?? '').toString().isNotEmpty)
                                  Text(
                                    (lieu['ville'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: vert,
                                    ),
                                  ),
                                if ((lieu['type'] ?? '').toString().isNotEmpty)
                                  Text(
                                    "Type : ${lieu['type']}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                if ((lieu['sous_categorie'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  const SizedBox(height: 2),
                                if ((lieu['sous_categorie'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    "Sous-catégorie : ${lieu['sous_categorie']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: rouge,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: bleu, size: 23),
                                  tooltip: "Modifier",
                                  onPressed: () => _ajouterOuEditerLieu(lieu: lieu),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: rouge, size: 23),
                                  tooltip: "Supprimer",
                                  onPressed: () => _supprimerLieu(lieu),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ajouterOuEditerLieu(),
        backgroundColor: bleu,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
    );
  }
}
