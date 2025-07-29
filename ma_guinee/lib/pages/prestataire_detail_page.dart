// lib/pages/prestataire_detail_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'messages_prestataire_page.dart';

class PrestataireDetailPage extends StatefulWidget {
  /// data : Map<String,dynamic> (PrestataireModel.toJson())
  final Map<String, dynamic> data;
  const PrestataireDetailPage({super.key, required this.data});

  @override
  State<PrestataireDetailPage> createState() => _PrestataireDetailPageState();
}

class _PrestataireDetailPageState extends State<PrestataireDetailPage> {
  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();

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
    final receiverId = widget.data['id']?.toString() ?? '';
    final prestataireName = widget.data['metier']?.toString() ?? '';
    final prestataireId = receiverId;

    if (me == null) {
      _snack("Connexion requise.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPrestatairePage(
          prestataireId: prestataireId,
          prestataireName: prestataireName,
          receiverId: receiverId,
          senderId: me.id,
        ),
      ),
    );
  }

  void _sendAvis() {
    if (_noteUtilisateur == 0 || _avisController.text.trim().isEmpty) {
      _snack("Note + avis requis.");
      return;
    }
    // TODO: insert into table avis_prestataires
    _snack("Merci pour votre avis !");
    setState(() {
      _noteUtilisateur = 0;
      _avisController.clear();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _stars(int rating, {Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return IconButton(
          icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber),
          onPressed: onTap == null ? null : () => onTap(i + 1),
          iconSize: 25,
          splashRadius: 17,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final photo = data['photo_url']?.toString() ?? '';
    final metier = data['metier']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final ville = data['ville']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final phone = data['phone']?.toString() ?? '';

    // On cache le bouton "Échanger" si l'utilisateur connecté est ce prestataire
    final meId = Supabase.instance.client.auth.currentUser?.id;
    final prestId = data['id']?.toString() ?? '';
    final isMe = meId != null && meId == prestId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text(
          metier.isEmpty ? 'Prestataire' : metier,
          style: const TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: photo.isNotEmpty
                ? Image.network(photo, height: 190, width: double.infinity, fit: BoxFit.cover)
                : Container(
                    height: 190,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  ),
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF113CFC),
                radius: 22,
                child: Icon(Icons.engineering, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metier, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                    Text(category, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 17, color: Color(0xFFCE1126)),
                        const SizedBox(width: 3),
                        Text(ville, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (description.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: const Color(0xFFF8F6F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Text(description, style: const TextStyle(fontSize: 16, color: Colors.black87)),
              ),
            ),
          const SizedBox(height: 17),

          if (!isMe)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Color(0xFF009460)),
                  tooltip: "Appeler",
                  onPressed: () => _call(phone),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                  tooltip: "WhatsApp",
                  onPressed: () => _whatsapp(phone),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    label: const Text("Échanger"),
                    onPressed: _openChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF113CFC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 22),

          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Noter ce prestataire :", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  _stars(_noteUtilisateur, onTap: (r) => setState(() => _noteUtilisateur = r)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _avisController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Avis (facultatif)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _sendAvis,
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text("Envoyer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
