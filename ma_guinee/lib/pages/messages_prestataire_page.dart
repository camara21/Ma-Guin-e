import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/message_service.dart';

class MessagesPrestatairePage extends StatefulWidget {
  final String prestataireId;
  final String prestataireNom;
  final String receiverId; // ID du destinataire
  final String senderId;   // ID de l’expéditeur (moi)

  const MessagesPrestatairePage({
    super.key,
    required this.prestataireId,
    required this.prestataireNom,
    required this.receiverId,
    required this.senderId,
  });

  @override
  State<MessagesPrestatairePage> createState() => _MessagesPrestatairePageState();
}

class _MessagesPrestatairePageState extends State<MessagesPrestatairePage> {
  final _svc = MessageService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _chargerEtMarquerCommeLu();

    // ✅ On écoute toute la table, pas de .eq() ici (Supabase 2.x)
    _sub = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .listen((_) => _chargerEtMarquerCommeLu());
  }

  Future<void> _chargerEtMarquerCommeLu() async {
    setState(() => _loading = true);
    try {
      // 1) Charger uniquement les messages de CE prestataire
      final msgs = await _svc.fetchMessagesForPrestataire(widget.prestataireId);

      // 2) Lister les messages destinés à moi et non lus
      final idsAValider = <String>[];
      for (var m in msgs) {
        final estPourMoi = (m['receiver_id']?.toString() == widget.senderId);
        final pasEncoreLu = (m['lu'] == false || m['lu'] == null);
        if (estPourMoi && pasEncoreLu) {
          final id = m['id']?.toString();
          if (id != null) idsAValider.add(id);
        }
      }

      // 3) Marquer comme lus en base
      if (idsAValider.isNotEmpty) {
        await Supabase.instance.client
            .from('messages')
            .update({'lu': true})
            .inFilter('id', idsAValider);

        // 🔔 prévenir le badge global (MainNavigationPage)
        _svc.unreadChanged.add(null);
      }

      if (!mounted) return;
      setState(() {
        _msgs = msgs;
        _loading = false;
      });

      _defilerEnBas();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Erreur chargement/lu (prestataire): $e');
    }
  }

  void _defilerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _envoyer() async {
    final texte = _ctrl.text.trim();
    if (texte.isEmpty) return;

    _ctrl.clear();

    // Affichage instantané (optimistic UI)
    setState(() {
      _msgs.add({
        'sender_id': widget.senderId,
        'receiver_id': widget.receiverId,
        'contenu': texte,
        'lu': true,
        'id': -1,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _defilerEnBas();

    try {
      // Envoi réel vers Supabase via le service
      await _svc.sendMessageToPrestataire(
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        prestataireId: widget.prestataireId,
        prestataireName: widget.prestataireNom,
        contenu: texte,
      );
      // Le stream temps réel mettra à jour la liste
    } catch (e) {
      debugPrint('Erreur envoi message (prestataire): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  Widget _bulleMessage(Map<String, dynamic> m) {
    final moi = m['sender_id'] == widget.senderId;
    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: moi ? const Color(0xFF113CFC) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          (m['contenu'] ?? '').toString(),
          style: TextStyle(
            color: moi ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF113CFC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.prestataireNom,
          style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) => _bulleMessage(_msgs[i]),
                    ),
                  ),
                  _zoneSaisie(),
                ],
              ),
      ),
    );
  }

  Widget _zoneSaisie() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5FA),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: "Écrire un message…",
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _envoyer(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _envoyer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF113CFC),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
