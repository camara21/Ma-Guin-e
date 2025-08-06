import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'culte_detail_page.dart';

class CultePage extends StatefulWidget {
  const CultePage({super.key});

  @override
  State<CultePage> createState() => _CultePageState();
}

class _CultePageState extends State<CultePage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _lieux = [];
  List<Map<String, dynamic>> _filteredLieux = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLieux();
  }

  Future<void> _fetchLieux() async {
    setState(() => _loading = true);
    try {
      // Ne récupère que les lieux avec catégorie/type/culte, insensible à la casse
      final response = await _supabase
          .from('lieux')
          .select()
          .ilike('categorie', 'culte')  // ou bien 'type' si tu préfères
          .order('nom', ascending: true);

      if (response == null) {
        setState(() => _loading = false);
        return;
      }
      final data = response as List<dynamic>;
      _lieux = data.map((e) => Map<String, dynamic>.from(e)).toList();

      // Trier les mosquées en premier, puis le reste par nom
      _lieux.sort((a, b) {
        final aMosquee = ((a['type']?.toString().toLowerCase().contains('mosquée') ?? false) ||
                          (a['sous_categorie']?.toString().toLowerCase().contains('mosquée') ?? false));
        final bMosquee = ((b['type']?.toString().toLowerCase().contains('mosquée') ?? false) ||
                          (b['sous_categorie']?.toString().toLowerCase().contains('mosquée') ?? false));
        if (aMosquee && !bMosquee) return -1;
        if (!aMosquee && bMosquee) return 1;
        return (a['nom'] ?? '').toString().toLowerCase()
            .compareTo((b['nom'] ?? '').toString().toLowerCase());
      });

      _filteredLieux = List.from(_lieux);
    } catch (e) {
      debugPrint('Erreur récupération lieux culte : $e');
    }
    setState(() => _loading = false);
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLieux = List.from(_lieux);
      });
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredLieux = _lieux.where((lieu) {
        final nom = (lieu['nom'] ?? '').toString().toLowerCase();
        final ville = (lieu['ville'] ?? '').toString().toLowerCase();
        return nom.contains(lower) || ville.contains(lower);
      }).toList();
    });
  }

  IconData getIconForLieu(Map<String, dynamic> lieu) {
    final type = (lieu['type'] ?? '').toString().toLowerCase();
    final sousCat = (lieu['sous_categorie'] ?? '').toString().toLowerCase();
    if (type.contains('mosquée') || sousCat.contains('mosquée')) return Icons.mosque;
    if (type.contains('église') || sousCat.contains('église') || type.contains('cathédrale') || sousCat.contains('cathédrale')) return Icons.church;
    if (type.contains('sanctuaire') || sousCat.contains('sanctuaire')) return Icons.shield_moon;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Lieux de culte',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 21,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou ville...',
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: _search,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLieux.isEmpty
                    ? const Center(child: Text("Aucun lieu de culte trouvé."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredLieux.length,
                        itemBuilder: (context, index) {
                          final lieu = _filteredLieux[index];
                          final images = (lieu['images'] as List?)?.cast<String>() ?? [];
                          final firstImage = images.isNotEmpty
                              ? images[0]
                              : 'https://via.placeholder.com/150';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CulteDetailPage(lieu: lieu),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      bottomLeft: Radius.circular(20),
                                    ),
                                    child: Image.network(
                                      firstImage,
                                      width: 110,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        width: 110,
                                        height: 110,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.image_not_supported),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lieu['nom'] ?? 'Nom inconnu',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${lieu['type'] ?? 'Type inconnu'} • ${lieu['ville'] ?? ''}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      getIconForLieu(lieu),
                                      color: ((lieu['type']?.toString().toLowerCase().contains('mosquée') ?? false) ||
                                              (lieu['sous_categorie']?.toString().toLowerCase().contains('mosquée') ?? false))
                                          ? const Color(0xFF009460)
                                          : const Color(0xFFCE1126),
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
