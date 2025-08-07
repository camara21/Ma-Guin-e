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
  List<Map<String, dynamic>> _avis = [];
  double _noteMoyenne = 0;
  List<Map<String, dynamic>> _recommandations = [];
  bool loadingReco = false;

  @override
  void initState() {
    super.initState();
    _loadRecommandations();
    _loadAvis();
  }

  Future<void> _loadAvis() async {
    final id = widget.data['id'];
    final res = await Supabase.instance.client
        .from('avis')
        .select('note, commentaire, created_at, utilisateurs(nom, prenom, photo_url)')
        .eq('contexte', 'prestataire')
        .eq('cible_id', id)
        .order('created_at', ascending: false);

    final notes = res.map((e) => e['note'] as num).toList();
    final moyenne = notes.isNotEmpty ? notes.reduce((a, b) => a + b) / notes.length : 0;

    setState(() {
      _avis = List<Map<String, dynamic>>.from(res);
      _noteMoyenne = moyenne.toDouble(); // ✅ Correction ici
    });
  }

  void _sendAvis() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _snack("Connexion requise.");
    final commentaire = _avisController.text.trim();

    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      return _snack("Note et commentaire requis.");
    }

    final cibleId = widget.data['id'];

    final existing = await Supabase.instance.client
        .from('avis')
        .select()
        .eq('utilisateur_id', user.id)
        .eq('contexte', 'prestataire')
        .eq('cible_id', cibleId)
        .maybeSingle();

    if (existing != null) {
      await Supabase.instance.client
          .from('avis')
          .update({
            'note': _noteUtilisateur,
            'commentaire': commentaire,
          })
          .eq('id', existing['id']);
      _snack("Avis mis à jour !");
    } else {
      await Supabase.instance.client.from('avis').insert({
        'utilisateur_id': user.id,
        'contexte': 'prestataire',
        'cible_id': cibleId,
        'note': _noteUtilisateur,
        'commentaire': commentaire,
      });
      _snack("Avis envoyé !");
    }

    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });

    _loadAvis();
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
      _snack("WhatsApp non disponible");
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

  void _loadRecommandations() async {
    setState(() => loadingReco = true);
    final ville = widget.data['ville']?.toString() ?? '';
    final id = widget.data['id'];

    final res = await Supabase.instance.client
        .from('prestataires')
        .select()
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
    final metier = data['metier'] ?? '';
    final ville = data['ville'] ?? '';
    final photo = data['photo_url']?.toString() ?? '';
    final phone = data['phone'] ?? data['telephone'] ?? '';
    final description = data['description'] ?? '';
    final isMe = Supabase.instance.client.auth.currentUser?.id == data['id'];
    final primaryColor = const Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        title: Text(metier, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (photo.isNotEmpty)
                GestureDetector(
                  onTap: () => _showImage(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(photo, height: 200, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(ville.toString(), style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Text(description.toString()),
              const SizedBox(height: 20),
              if (!isMe)
                Row(
                  children: [
                    IconButton(onPressed: () => _call(phone), icon: const Icon(Icons.phone, color: Colors.green)),
                    IconButton(onPressed: () => _whatsapp(phone), icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green)),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text("Échanger"),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: _openChat,
                    )
                  ],
                ),
              const Divider(height: 30),
              const Text("Laisser un avis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                decoration: const InputDecoration(hintText: "Votre avis", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _sendAvis,
                icon: const Icon(Icons.send),
                label: const Text("Envoyer"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFCD116), foregroundColor: Colors.black),
              ),
              const Divider(height: 30),
              Text("Note moyenne : ${_noteMoyenne.toStringAsFixed(1)} ⭐️", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ..._avis.map((avis) {
                final user = avis['utilisateurs'] ?? {};
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photo_url'] != null ? NetworkImage(user['photo_url']) : null,
                    child: user['photo_url'] == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text("${user['prenom'] ?? ''} ${user['nom'] ?? ''}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${avis['note']} ⭐️"),
                      if (avis['commentaire'] != null) Text(avis['commentaire']),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
