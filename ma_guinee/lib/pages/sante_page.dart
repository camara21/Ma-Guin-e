import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sante_detail_page.dart';

class SantePage extends StatefulWidget {
  const SantePage({super.key});

  @override
  State<SantePage> createState() => _SantePageState();
}

class _SantePageState extends State<SantePage> {
  List<Map<String, dynamic>> centres = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  Future<void> _loadCentres() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('cliniques')
        .select()
        .order('nom');
    setState(() {
      centres = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Services de santé",
          style: TextStyle(
            color: Color(0xFF009460),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF009460)),
        elevation: 1,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : centres.isEmpty
              ? const Center(child: Text("Aucun centre de santé trouvé."))
              : ListView.builder(
                  itemCount: centres.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final centre = centres[index];
                    final List<String> images =
                        (centre['images'] as List?)?.cast<String>() ?? [];
                    final image = images.isNotEmpty
                        ? images[0]
                        : 'https://via.placeholder.com/150';

                    return Card(
                      color: Colors.green.shade50.withOpacity(0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(image),
                          radius: 26,
                        ),
                        title: Text(
                          centre['nom'] ?? "Sans nom",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF113CFC),
                          ),
                        ),
                        subtitle: Text(
                          '${centre['ville'] ?? ""} • ${centre['specialite'] ?? centre['description'] ?? ""}',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF009460), size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SanteDetailPage(cliniqueId: centre['id']),
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
