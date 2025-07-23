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
      final response = await _supabase
          .from('lieux_culte')
          .select()
          .order('nom', ascending: true);

      if (response == null) {
        debugPrint('Réponse vide');
        setState(() => _loading = false);
        return;
      }
      final data = response as List<dynamic>;
      _lieux = data.map((e) => Map<String, dynamic>.from(e)).toList();
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
        final type = (lieu['type'] ?? '').toString().toLowerCase();
        return nom.contains(lower) || ville.contains(lower) || type.contains(lower);
      }).toList();
    });
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
                hintText: 'Rechercher un lieu de culte...',
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

                          return Card(
                            elevation: 1,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                            margin: const EdgeInsets.only(bottom: 13),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(firstImage),
                                radius: 24,
                                backgroundColor: Colors.grey.shade200,
                              ),
                              title: Text(
                                lieu['nom'] ?? 'Nom inconnu',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.5,
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                '${lieu['type'] ?? 'Type inconnu'} • ${lieu['ville'] ?? ''}',
                                style: const TextStyle(color: Colors.black54, fontSize: 14),
                              ),
                              trailing: Icon(
                                lieu['type']?.toLowerCase().contains('mosquée') ?? false
                                    ? Icons.mosque
                                    : Icons.church,
                                color: lieu['type']?.toLowerCase().contains('mosquée') ?? false
                                    ? const Color(0xFF009460)
                                    : const Color(0xFFCE1126),
                                size: 30,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CulteDetailPage(lieu: lieu),
                                  ),
                                );
                              },
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
