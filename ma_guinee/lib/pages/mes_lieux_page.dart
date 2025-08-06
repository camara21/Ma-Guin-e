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
  Color get bleu => const Color(0xFF1E3FCF);
  Color get rouge => const Color(0xFFCE1126);
  Color get jaune => const Color(0xFFFFC700);
  Color get vert => const Color(0xFF009460);

  @override
  void initState() {
    super.initState();
    _chargerLieux();
  }

  Future<void> _chargerLieux() async {
    setState(() => _loading = true);
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
  }

  Future<void> _ajouterOuEditerLieu({Map<String, dynamic>? lieu}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InscriptionLieuPage(lieu: lieu),
      ),
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
            style: ElevatedButton.styleFrom(backgroundColor: rouge, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('lieux').delete().eq('id', lieu['id']);
      _chargerLieux();
    }
  }

  void _ouvrirDetail(Map<String, dynamic> lieu) {
    final type = (lieu['type'] ?? '').toLowerCase();
    if (type == 'divertissement') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DivertissementDetailPage(lieu: lieu)),
      );
    } else if (type == 'culte') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CulteDetailPage(lieu: lieu)),
      );
    } else if (type == 'tourisme') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TourismeDetailPage(lieu: lieu)),
      );
    } else {
      // Fallback, tu peux ajouter une page par défaut
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune page de détail pour ce type de lieu.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Mes lieux"),
        backgroundColor: bleu,
        foregroundColor: Colors.white,
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
                      final imageUrl = (lieu['images'] is List && lieu['images'].isNotEmpty)
                          ? lieu['images'][0]
                          : null;
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _ouvrirDetail(lieu),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                color: bleu.withOpacity(0.09),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(Icons.place, color: bleu, size: 28),
                              ),
                            ),
                            title: Text(
                              lieu['nom'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, color: bleu),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((lieu['ville'] ?? '').isNotEmpty)
                                  Text(lieu['ville'], style: TextStyle(fontSize: 13, color: vert)),
                                if ((lieu['type'] ?? '').isNotEmpty)
                                  Text(
                                    "Type : ${lieu['type']}",
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
                                  ),
                                if ((lieu['sous_categorie'] ?? '').isNotEmpty)
                                  Text(
                                    "Sous-catégorie : ${lieu['sous_categorie']}",
                                    style: TextStyle(fontSize: 12, color: rouge),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: bleu, size: 23),
                                  tooltip: "Modifier",
                                  onPressed: () => _ajouterOuEditerLieu(lieu: lieu),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: rouge, size: 23),
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
