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
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _whatsapp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openChat() {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) {
      _snack("Connexion requise.");
      return;
    }
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

    setState(() => _recommandations = List<Map<String, dynamic>>.from(res));
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
    final phone = data['phone'] ?? '';
    final description = data['description'] ?? '';
    final category = data['category'] ?? _categoryForJob(metier);
    final isMe = Supabase.instance.client.auth.currentUser?.id == data['id'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: Text(
          metier,
          style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: photo.isNotEmpty
                ? Image.network(photo, height: 200, fit: BoxFit.cover)
                : Container(height: 200, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (photo.isNotEmpty) _showImage(photo);
                },
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metier, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(category, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 16),
                        const SizedBox(width: 3),
                        Text(ville),
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(description),
            ),
          const SizedBox(height: 16),
          if (!isMe)
            Row(
              children: [
                IconButton(
                  onPressed: () => _call(phone),
                  icon: const Icon(Icons.phone, color: Color(0xFF009460)),
                ),
                IconButton(
                  onPressed: () => _whatsapp(phone),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text("Échanger"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF113CFC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _openChat,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          const Text("Laisser un avis :", style: TextStyle(fontWeight: FontWeight.bold)),
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
            decoration: const InputDecoration(
              hintText: "Écrire un avis...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _sendAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
          ),
          const SizedBox(height: 30),
          if (_recommandations.isNotEmpty) ...[
            const Text("Prestataires similaires", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ..._recommandations.map((p) {
              final img = p['photo_url']?.toString() ?? '';
              final name = p['metier'] ?? '';
              final ville = p['ville'] ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
                  backgroundColor: Colors.grey[300],
                  child: img.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(name),
                subtitle: Text(ville),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrestataireDetailPage(data: p),
                    ),
                  );
                },
              );
            }),
          ]
        ],
      ),
    );
  }
}
