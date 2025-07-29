import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';
import 'messages_annonce_page.dart';
import 'messages_prestataire_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _searchController = TextEditingController();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _conversations = [];
        _loading = false;
      });
      return;
    }

    try {
      final data = await _messageService.fetchUserConversations(user.id);

      final Map<String, Map<String, dynamic>> mapConv = {};
      for (var msg in data) {
        final senderId = msg['sender_id']?.toString() ?? '';
        final receiverId = msg['receiver_id']?.toString() ?? '';
        final otherId = senderId == user.id ? receiverId : senderId;
        final contexte = msg['contexte']?.toString() ?? '';
        final annonceId = msg['annonce_id']?.toString() ?? '';
        final prestataireId = msg['prestataire_id']?.toString() ?? '';

        final key = '$contexte|$otherId|$annonceId|$prestataireId';
        final existing = mapConv[key];
        final dateEnvoi = DateTime.tryParse(msg['date_envoi']?.toString() ?? '');
        final existingDate = existing != null
            ? DateTime.tryParse(existing['date_envoi']?.toString() ?? '')
            : null;

        if (existing == null ||
            (dateEnvoi != null && existingDate != null && dateEnvoi.isAfter(existingDate))) {
          mapConv[key] = msg;
        }
      }

      setState(() {
        _conversations = mapConv.values.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _conversations = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement conversations : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final search = _searchController.text.toLowerCase();
    final filtered = _conversations.where((msg) {
      return (msg['contenu']?.toString().toLowerCase() ?? '')
          .contains(search);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Color(0xFF113CFC),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.7,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF113CFC)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: const Color(0xFFF4F4F6),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("Aucune conversation."))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(indent: 80, endIndent: 15, height: 2),
                        itemBuilder: (context, i) {
                          final msg = filtered[i];
                          final contexte = msg['contexte']?.toString() ?? '';
                          final isAnnonce = contexte == 'annonce';
                          final senderId = msg['sender_id']?.toString() ?? '';
                          final receiverId = msg['receiver_id']?.toString() ?? '';
                          final otherId = senderId == user!.id ? receiverId : senderId;
                          final preview = msg['contenu']?.toString() ?? '';
                          final dateStr = msg['date_envoi']?.toString() ?? '';
                          final unread = msg['lu'] == false;

                          final title = isAnnonce
                              ? (msg['annonce_titre']?.toString() ?? 'Annonce')
                              : (msg['prestataire_name']?.toString() ??
                                  'Prestataire');

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAnnonce
                                  ? const Color(0xFF113CFC)
                                  : const Color(0xFFCE1126),
                              child: Icon(
                                isAnnonce ? Icons.campaign : Icons.engineering,
                                color: Colors.white,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                  ),
                                ),
                                Text(
                                  dateStr.split("T").first,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFCE1126),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (isAnnonce) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesAnnoncePage(
                                      annonceId:
                                          msg['annonce_id']?.toString() ?? '',
                                      annonceTitre: msg['annonce_titre']
                                              ?.toString() ??
                                          'Annonce',
                                      receiverId: otherId,
                                      senderId: user.id,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesPrestatairePage(
                                      prestataireId:
                                          msg['prestataire_id']?.toString() ??
                                              '',
                                      prestataireName: msg['prestataire_name']
                                              ?.toString() ??
                                          'Prestataire',
                                      receiverId: otherId,
                                      senderId: user.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 4),
                            minVerticalPadding: 8,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
