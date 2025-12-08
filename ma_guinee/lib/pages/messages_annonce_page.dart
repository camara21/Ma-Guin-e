// lib/pages/messages/message_annonce_page.dart (ou messages_annonce_page.dart)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/message_service.dart';
import 'annonce_detail_page.dart';
import '../models/annonce_model.dart';

class MessagesAnnoncePage extends StatefulWidget {
  final String annonceId;
  final String annonceTitre;
  final String receiverId; // id du destinataire (vendeur)
  final String senderId; // mon id (expéditeur)

  const MessagesAnnoncePage({
    super.key,
    required this.annonceId,
    required this.annonceTitre,
    required this.receiverId,
    required this.senderId,
  });

  @override
  State<MessagesAnnoncePage> createState() => _MessagesAnnoncePageState();
}

class _MessagesAnnoncePageState extends State<MessagesAnnoncePage> {
  final _svc = MessageService();
  final _sb = Supabase.instance.client;

  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = <Map<String, dynamic>>[];
  bool _loading = true;

  late Future<_AnnonceCard?> _annonceFuture;

  // Polling périodique
  Timer? _pollTimer;

  // ====== URL publique + bucket ======
  static const String _annonceBucket = 'annonce-photos';
  String? _publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final objectPath =
        path.startsWith('$bucket/') ? path.substring(bucket.length + 1) : path;
    return _sb.storage.from(bucket).getPublicUrl(objectPath);
  }
  // ===================================

  // ===== Helpers temps (affichage) =====
  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v.toLocal();
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d.toLocal();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);

    if (_sameDay(day, today)) return "Aujourd'hui";
    if (_sameDay(day, yesterday)) return "Hier";

    const weekDays = [
      'lun.',
      'mar.',
      'mer.',
      'jeu.',
      'ven.',
      'sam.',
      'dim.',
    ];
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final wd = weekDays[day.weekday - 1];
    final month = months[day.month - 1];
    return '$wd ${day.day} $month';
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  List<_ChatEntry> _buildChatEntries(List<Map<String, dynamic>> msgs) {
    final List<_ChatEntry> entries = [];
    DateTime? lastDay;
    for (final m in msgs) {
      final dt = _asDate(m['date_envoi']);
      final day = DateTime(dt.year, dt.month, dt.day);
      if (lastDay == null || !_sameDay(day, lastDay)) {
        entries.add(_ChatDate(day));
        lastDay = day;
      }
      entries.add(_ChatMessage(m));
    }
    return entries;
  }
  // ================================================

  @override
  void initState() {
    super.initState();
    _annonceFuture = _fetchAnnonceCard();
    _loadAndMarkRead(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadAndMarkRead(initial: false);
    });
  }

  // Carte produit à afficher en haut du chat
  Future<_AnnonceCard?> _fetchAnnonceCard() async {
    try {
      final row = await _sb
          .from('annonces')
          .select('id, titre, images, prix, devise, ville')
          .eq('id', widget.annonceId)
          .maybeSingle();

      if (row == null) {
        return _AnnonceCard(
          id: widget.annonceId,
          titre: widget.annonceTitre,
          imageUrl: null,
          prixLabel: null,
          ville: '',
        );
      }

      List<String> images = const <String>[];
      final rawImages = row['images'];

      List<String> _stringifyList(dynamic v) {
        if (v is List) {
          return v
              .map((e) {
                if (e == null) return '';
                if (e is String) return e;
                if (e is Map) {
                  final m = Map<String, dynamic>.from(e);
                  return (m['path'] ?? m['url'] ?? m['publicUrl'] ?? '')
                      .toString();
                }
                return e.toString();
              })
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return const <String>[];
      }

      if (rawImages is List) {
        images = _stringifyList(rawImages);
      } else if (rawImages is String && rawImages.isNotEmpty) {
        try {
          final parsed = jsonDecode(rawImages);
          images = _stringifyList(parsed);
        } catch (_) {}
      }

      final String? image =
          images.isNotEmpty ? _publicUrl(_annonceBucket, images.first) : null;

      final prix = row['prix'];
      final devise = (row['devise'] ?? '').toString();
      final prixLabel = (prix is num)
          ? '${prix.toInt()} ${devise.isEmpty ? 'GNF' : devise}'
          : null;

      return _AnnonceCard(
        id: (row['id'] ?? '').toString(),
        titre: (row['titre'] ?? '').toString(),
        imageUrl: image,
        prixLabel: prixLabel,
        ville: (row['ville'] ?? '').toString(),
      );
    } catch (_) {
      return _AnnonceCard(
        id: widget.annonceId,
        titre: widget.annonceTitre,
        imageUrl: null,
        prixLabel: null,
        ville: '',
      );
    }
  }

  // Chargement + marquage LU
  Future<void> _loadAndMarkRead({bool initial = false}) async {
    if (!mounted) return;
    if (initial) {
      setState(() => _loading = true);
    }
    try {
      final currentUser = _sb.auth.currentUser;
      final viewerId = currentUser?.id ?? widget.senderId;

      final previousLastId =
          _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;

      final msgs = await _svc.fetchMessagesForAnnonceVisibleTo(
        viewerUserId: viewerId,
        annonceId: widget.annonceId,
      );

      // marquer lus
      final idsToMark = <String>[];
      for (final m in msgs) {
        final isForMe = (m['receiver_id']?.toString() == viewerId);
        final notRead = (m['lu'] == false || m['lu'] == null);
        if (isForMe && notRead) {
          final id = m['id']?.toString();
          if (id != null) idsToMark.add(id);
        }
      }
      if (idsToMark.isNotEmpty) {
        await _sb
            .from('messages')
            .update({'lu': true}).inFilter('id', idsToMark);
        _svc.unreadChanged.add(null);
      }

      if (!mounted) return;
      setState(() {
        // ordre directement celui de la base (id ASC) → ne bouge jamais
        _msgs = msgs;
        if (initial) _loading = false;
      });

      final newLastId = _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;
      if (initial || previousLastId != newLastId) {
        _scrollToEnd();
      }
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() => _loading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur de chargement : $e")),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // Envoi
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    final now = DateTime.now();

    // UI optimiste
    setState(() {
      _msgs.add({
        'id': -1, // temporaire, remplacé au prochain poll
        'sender_id': widget.senderId,
        'receiver_id': widget.receiverId,
        'contenu': text,
        'lu': true,
        'date_envoi': now.toIso8601String(),
      });
    });
    _scrollToEnd();

    try {
      await _svc.sendMessageToAnnonce(
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        annonceId: widget.annonceId,
        annonceTitre: widget.annonceTitre,
        contenu: text,
      );

      // le polling va recharger la vraie ligne (id auto)
      await _loadAndMarkRead(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  // Supprimer POUR MOI un seul message
  Future<void> _deleteForMe(String messageId) async {
    final currentUser = _sb.auth.currentUser;
    final meId = currentUser?.id ?? widget.senderId;

    try {
      await _svc.deleteMessageForMe(
        messageId: messageId,
        currentUserId: meId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Suppression impossible : $e")),
      );
    } finally {
      await _loadAndMarkRead(initial: false);
    }
  }

  // Supprimer TOUTE la discussion pour moi
  Future<void> _deleteWholeThread() async {
    final currentUser = _sb.auth.currentUser;
    if (currentUser == null) return;

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer la discussion ?'),
            content: const Text(
              "Cette discussion sera masquée pour vous (l'historique sera effacé de votre vue). "
              "Vous pourrez toujours réécrire plus tard sur cette annonce.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer la discussion'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    final myId = currentUser.id;
    final otherId =
        (myId == widget.senderId) ? widget.receiverId : widget.senderId;

    try {
      await _svc.hideThread(
        userId: myId,
        contexte: 'annonce',
        annonceId: widget.annonceId,
        prestataireId: null,
        peerUserId: otherId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la suppression : $e")),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  // Ouvrir détail annonce
  Future<void> _openAnnonceDetail(_AnnonceCard a) async {
    final row =
        await _sb.from('annonces').select().eq('id', a.id).maybeSingle();

    if (row != null) {
      final model = AnnonceModel.fromJson(Map<String, dynamic>.from(row));
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnnonceDetailPage(annonce: model)),
      );
      return;
    }

    final minimalJson = <String, dynamic>{
      'id': a.id,
      'titre': a.titre,
      'images': a.imageUrl == null ? <String>[] : <String>[a.imageUrl!],
      'prix': null,
      'devise': 'GNF',
      'ville': a.ville,
      'description': '',
      'user_id': widget.receiverId,
      'telephone': '',
    };
    final model = AnnonceModel.fromJson(minimalJson);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnonceDetailPage(annonce: model)),
    );
  }

  Widget _dateSeparator(DateTime day) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          const SizedBox(width: 8),
          Text(
            _dayLabel(day),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  // Bulle + long-press supprimer pour moi
  Widget _bubble(Map<String, dynamic> m) {
    final me = m['sender_id']?.toString() == widget.senderId;
    final myColor = me ? const Color(0xFF113CFC) : const Color(0xFFF3F5FA);
    final dt = _asDate(m['date_envoi']);
    final time = _timeLabel(dt);

    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () async {
          final id = m['id']?.toString();
          if (id == null || id == '-1') return;
          final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer ce message ?'),
                  content: const Text(
                    "Il sera supprimé pour vous maintenant et définitivement de la base après 30 jours. "
                    "L'autre personne le verra encore jusque-là.",
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Supprimer pour moi')),
                  ],
                ),
              ) ??
              false;
          if (ok) await _deleteForMe(id);
        },
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: EdgeInsets.only(
              top: 6, bottom: 6, left: me ? 40 : 12, right: me ? 12 : 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: myColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(me ? 18 : 8),
              bottomRight: Radius.circular(me ? 8 : 18),
            ),
            boxShadow: [
              if (me)
                BoxShadow(
                    color: Colors.blue.shade100,
                    blurRadius: 2,
                    offset: const Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (m['contenu'] ?? '').toString(),
                style: TextStyle(
                    color: me ? Colors.white : Colors.black87, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: (me ? Colors.white : Colors.black87)
                        .withOpacity(me ? 0.8 : 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bleuMaGuinee = Color(0xFF113CFC);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: bleuMaGuinee),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.annonceTitre,
          style: const TextStyle(
              color: bleuMaGuinee, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: bleuMaGuinee),
        actions: [
          IconButton(
            tooltip: 'Supprimer la discussion',
            icon: const Icon(Icons.delete_outline, color: bleuMaGuinee),
            onPressed: _deleteWholeThread,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: FutureBuilder<_AnnonceCard?>(
                      future: _annonceFuture,
                      builder: (context, snap) {
                        final hasCard = (snap.data != null);
                        final chatEntries = _buildChatEntries(_msgs);
                        final total = chatEntries.length + (hasCard ? 1 : 0);

                        if (!hasCard && chatEntries.isEmpty) {
                          return Center(
                            child: Text(
                              "Aucune discussion pour cette annonce.\nÉcrivez un message pour commencer.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scroll,
                          itemCount: total,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemBuilder: (_, i) {
                            if (hasCard && i == 0) {
                              final a = snap.data!;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                                child: _AnnonceMessageCard(
                                  annonce: a,
                                  onTap: () {
                                    _openAnnonceDetail(a);
                                  },
                                ),
                              );
                            }

                            final entry = chatEntries[i - (hasCard ? 1 : 0)];
                            if (entry is _ChatDate) {
                              return _dateSeparator(entry.day);
                            } else if (entry is _ChatMessage) {
                              return _bubble(entry.message);
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F5FA),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: _ctrl,
                              decoration: const InputDecoration(
                                hintText: "Écrire un message…",
                                border: InputBorder.none,
                              ),
                              minLines: 1,
                              maxLines: 5,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        ElevatedButton(
                          onPressed: _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: bleuMaGuinee,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(13),
                            elevation: 2,
                          ),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ----- Modèles / widgets -----
class _AnnonceCard {
  final String id;
  final String titre;
  final String? imageUrl;
  final String? prixLabel;
  final String ville;

  _AnnonceCard({
    required this.id,
    required this.titre,
    required this.imageUrl,
    required this.prixLabel,
    required this.ville,
  });
}

class _AnnonceMessageCard extends StatelessWidget {
  const _AnnonceMessageCard({required this.annonce, required this.onTap});
  final _AnnonceCard annonce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant;
    final fg = Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(14),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              (annonce.imageUrl == null || annonce.imageUrl!.isEmpty)
                  ? Container(
                      width: 110, height: 86, color: Colors.grey.shade300)
                  : Image.network(
                      annonce.imageUrl!,
                      width: 110,
                      height: 86,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 110, height: 86, color: Colors.grey.shade300),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        annonce.titre.isEmpty ? 'Annonce' : annonce.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontWeight: FontWeight.w700, color: fg),
                      ),
                      if (annonce.prixLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          annonce.prixLabel!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      if (annonce.ville.isNotEmpty)
                        Text(annonce.ville,
                            style: TextStyle(color: fg.withOpacity(.75))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----- Modèle interne pour la liste -----
abstract class _ChatEntry {}

class _ChatDate extends _ChatEntry {
  final DateTime day;
  _ChatDate(this.day);
}

class _ChatMessage extends _ChatEntry {
  final Map<String, dynamic> message;
  _ChatMessage(this.message);
}
