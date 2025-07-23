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
        final otherId =
            msg['sender_id'] == user.id ? msg['receiver_id'] : msg['sender_id'];
        final key =
            '${msg['contexte'] ?? ''}|$otherId|${msg['annonce_id'] ?? ''}|${msg['prestataire_id'] ?? ''}';
        if (!mapConv.containsKey(key) ||
            DateTime.parse(msg['date_envoi'])
                .isAfter(DateTime.parse(mapConv[key]!['date_envoi']))) {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur chargement conversations : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.toLowerCase();
    final filtered = _conversations.where((msg) {
      return (msg['contenu'] ?? '').toLowerCase().contains(search);
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
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
                          final isAnnonce = msg['contexte'] == 'annonce';
                          final otherId =
                              msg['sender_id'] == Supabase.instance.client.auth.currentUser!.id
                                  ? msg['receiver_id']
                                  : msg['sender_id'];

                          final name = isAnnonce
                              ? "Annonce"
                              : (msg['contexte'] == 'prestataire' ? "Prestataire" : "Conversation");

                          final preview = msg['contenu'] ?? '';
                          final date = msg['date_envoi'] ?? '';
                          final unread = msg['lu'] == false;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAnnonce
                                  ? const Color(0xFF113CFC)
                                  : const Color(0xFFCE1126),
                              child: Icon(
                                  isAnnonce ? Icons.campaign : Icons.engineering,
                                  color: Colors.white),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                ),
                                Text(
                                  date.split("T").first,
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
                                      annonceId: msg['annonce_id'],
                                      receiverId: otherId,
                                      senderId:
                                          Supabase.instance.client.auth.currentUser?.id ?? "",
                                      annonceTitre: "Annonce",
                                    ),
                                  ),
                                );
                              } else if (msg['contexte'] == 'prestataire') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MessagesPrestatairePage(
                                      prestataireId: msg['prestataire_id'],
                                      receiverId: otherId,
                                      senderId:
                                          Supabase.instance.client.auth.currentUser?.id ?? "",
                                      prestataireName: "Prestataire",
                                    ),
                                  ),
                                );
                              }
                            },
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
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
