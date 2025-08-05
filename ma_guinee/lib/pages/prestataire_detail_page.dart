import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'messages_prestataire_page.dart';

class PrestataireDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const PrestataireDetailPage({super.key, required this.data});

  @override
  State<PrestataireDetailPage> createState() => _PrestataireDetailPageState();
}

class _PrestataireDetailPageState extends State<PrestataireDetailPage> {
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  List<Map<String, dynamic>> _recommandations = [];
  bool loadingReco = false;

  @override
  void initState() {
    super.initState();
    _loadRecommandations();
  }

  String _categoryForJob(String? job) {
    if (job == null) return '';
    final Map<String, List<String>> categories = {
      'Technologies & Digital': [
        'Développeur / Développeuse', 'Ingénieur logiciel', 'Data Scientist',
        'Développeur mobile', 'Designer UI/UX', 'Administrateur systèmes',
        'Chef de projet IT', 'Technicien réseau', 'Analyste sécurité',
        'Community Manager', 'Growth Hacker', 'Webmaster', 'DevOps Engineer',
      ],
      // Autres catégories...
    };
    for (final e in categories.entries) {
      if (e.value.contains(job)) return e.key;
    }
    return '';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _call(String? phone) async {
    final tel = (phone ?? widget.data['telephone'] ?? '').toString();
    final telClean = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (telClean.isEmpty) return _snack("Numéro non disponible");
    final uri = Uri.parse('tel:$telClean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack("Impossible de lancer l'appel");
    }
  }

  void _whatsapp(String? phone) async {
    final tel = (phone ?? widget.data['telephone'] ?? '').toString();
    final telClean = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (telClean.isEmpty) return _snack("Numéro non disponible");
    final uri = Uri.parse('https://wa.me/$telClean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack("WhatsApp non disponible ou numéro invalide");
    }
  }

  void _openChat() {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return _snack("Connexion requise.");
    final receiverId = widget.data['id']?.toString() ?? '';
    final prestataireNom = widget.data['metier']?.toString() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPrestatairePage(
          prestataireId: receiverId,
          prestataireNom: prestataireNom,
          receiverId: receiverId,
          senderId: me.id,
        ),
      ),
    );
  }

  void _sendAvis() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _snack("Connexion requise.");
    if (_noteUtilisateur == 0 || _avisController.text.trim().isEmpty) {
      return _snack("Note et avis requis.");
    }

    await Supabase.instance.client.from('avis').insert({
      'prestataire_id': widget.data['id'],
      'utilisateur_id': user.id,
      'note': _noteUtilisateur,
      'commentaire': _avisController.text.trim(),
    });

    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });
    _snack("Avis envoyé !");
  }

  void _loadRecommandations() async {
    setState(() => loadingReco = true);
    final metier = widget.data['metier']?.toString() ?? '';
    final category = widget.data['category']?.toString() ?? _categoryForJob(metier);
    final ville = widget.data['ville']?.toString() ?? '';
    final id = widget.data['id'];

    final res = await Supabase.instance.client
        .from('prestataires')
        .select()
        .eq('category', category)
        .eq('ville', ville)
        .neq('id', id)
        .limit(6);

    setState(() {
      _recommandations = List<Map<String, dynamic>>.from(res);
      loadingReco = false;
    });
  }

  void _showImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final photo = data['photo_url']?.toString() ?? '';
    final metier = data['metier'] ?? '';
    final ville = data['ville'] ?? '';
    final phone = data['phone'] ?? data['telephone'] ?? '';
    final description = data['description'] ?? '';
    final category = data['category'] ?? _categoryForJob(metier);
    final isMe = Supabase.instance.client.auth.currentUser?.id == data['id'];

    final isWeb = MediaQuery.of(context).size.width > 650;
    final primaryColor = const Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: Text(
          metier,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: isWeb ? 26 : 20),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Image principale cliquable
              GestureDetector(
                onTap: () {
                  if (photo.isNotEmpty) _showImage(photo);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: photo.isNotEmpty
                      ? Image.network(photo, height: isWeb ? 260 : 180, fit: BoxFit.cover)
                      : Container(height: isWeb ? 260 : 180, color: Colors.grey[300], child: const Icon(Icons.person, size: 70, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 18),

              // Bloc nom métier/catégorie/ville
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: isWeb ? 37 : 27,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metier.toString(),
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          category.toString(),
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Color(0xFFCE1126), size: 18),
                            const SizedBox(width: 3),
                            Text(ville.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              if (description.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(description, style: const TextStyle(fontSize: 15)),
                ),

              const SizedBox(height: 22),
              // Boutons
              if (!isMe)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _call(phone),
                      icon: const Icon(Icons.phone, color: Color(0xFF009460)),
                      tooltip: "Appeler",
                    ),
                    IconButton(
                      onPressed: () => _whatsapp(phone),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                      tooltip: "WhatsApp",
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text("Échanger"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: _openChat,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),
              // Bloc avis
              const Text("Laisser un avis :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(i < _noteUtilisateur ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setState(() => _noteUtilisateur = i + 1),
                  );
                }),
              ),
              TextField(
                controller: _avisController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Écrire un avis...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _sendAvis,
                icon: const Icon(Icons.send),
                label: const Text("Envoyer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFCD116),
                  foregroundColor: Colors.black,
                ),
              ),

              const SizedBox(height: 34),
              // Suggestions
              if (loadingReco)
                const Center(child: CircularProgressIndicator())
              else if (_recommandations.isNotEmpty) ...[
                const Text("Prestataires similaires", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  itemCount: _recommandations.length,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92,
                  ),
                  itemBuilder: (_, i) {
                    final p = _recommandations[i];
                    final img = p['photo_url']?.toString() ?? '';
                    final name = p['metier'] ?? '';
                    final ville = p['ville'] ?? '';
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrestataireDetailPage(data: p))),
                      child: Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 9),
                            CircleAvatar(
                              backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                              backgroundColor: Colors.grey[200],
                              radius: 25,
                              child: img.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ville,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
