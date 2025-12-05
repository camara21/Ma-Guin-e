// lib/pages/messages/message_chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Service & modèles logement (même source que la page détail)
import '../../services/logement_service.dart';
import '../../models/logement_models.dart';

// Détail logement
import '../../pages/logement/logement_detail_page.dart';

// MessageService
import '../../services/message_service.dart';

class MessageChatPage extends StatefulWidget {
  const MessageChatPage({
    super.key,
    required this.peerUserId, // id de l'interlocuteur
    required this.title, // titre dans l'appbar
    required this.contextType, // 'logement' | 'prestataire'
    required this.contextId, // id du logement / prestataire
    this.contextTitle,
  });

  final String peerUserId;
  final String title;
  final String contextType;
  final String contextId;
  final String? contextTitle;

  @override
  State<MessageChatPage> createState() => _MessageChatPageState();
}

class _MessageChatPageState extends State<MessageChatPage> {
  final _sb = Supabase.instance.client;

  // même pattern que la page détail
  final LogementService _logSvc = LogementService();
  final MessageService _svc = MessageService();

  // état messages
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();

  // on garde exactement la même logique que MessagesAnnoncePage
  List<Map<String, dynamic>> _msgs = <Map<String, dynamic>>[];
  bool _loading = true;
  Timer? _pollTimer;

  // Carte (en-tête)
  late Future<_Offer?> _offerFuture;

  String get _ctx => widget.contextType; // 'logement' | 'prestataire'
  bool get _showOfferCard => (_ctx == 'logement');
  String? get _myId => _sb.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _offerFuture = _showOfferCard
        ? _fetchLogementHeaderViaService(widget.contextId)
        : Future.value(null);

    _loadAndMarkRead(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ====== HEADER LOGEMENT (utilise le service, getById -> LogementModel?) ======
  Future<_Offer?> _fetchLogementHeaderViaService(String id) async {
    try {
      final LogementModel? bien = await _logSvc.getById(id);
      if (bien == null) {
        return _Offer(
          id: id,
          titre: widget.contextTitle ?? 'Logement',
          imageUrl: null,
          ville: '',
          commune: '',
          prixLabel: null,
        );
      }

      // première image (souvent déjà en URL publique via le service)
      String? imageUrl;
      if (bien.photos.isNotEmpty) {
        final first = bien.photos
            .firstWhere((p) => p.trim().isNotEmpty, orElse: () => '');
        if (first.isNotEmpty) {
          imageUrl = first.startsWith('http')
              ? first
              : _sb.storage.from('logements').getPublicUrl(
                    first.startsWith('logements/')
                        ? first.substring('logements/'.length)
                        : first,
                  );
        }
      }

      // libellé prix identique aux pages logement
      String? prixLabel;
      final v = bien.prixGnf;
      if (v != null) {
        if (v >= 1000000) {
          final m = (v / 1000000).toStringAsFixed(1).replaceAll('.0', '');
          prixLabel =
              bien.mode == LogementMode.achat ? '$m M GNF' : '$m M GNF / mois';
        } else {
          final s = v.toStringAsFixed(0);
          prixLabel =
              bien.mode == LogementMode.achat ? '$s GNF' : '$s GNF / mois';
        }
      }

      return _Offer(
        id: bien.id,
        titre: bien.titre,
        imageUrl: imageUrl,
        ville: bien.ville ?? '',
        commune: bien.commune ?? '',
        prixLabel: prixLabel,
      );
    } catch (_) {
      return _Offer(
        id: id,
        titre: widget.contextTitle ?? 'Logement',
        imageUrl: null,
        ville: '',
        commune: '',
        prixLabel: null,
      );
    }
  }

  // ================= MESSAGES =================

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadAndMarkRead(initial: false);
    });
  }

  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v.toLocal();
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d.toLocal();
    }
    return DateTime.now();
  }

  Future<void> _loadAndMarkRead({bool initial = false}) async {
    final me = _myId;
    if (me == null) return;
    if (!mounted) return;

    if (initial) {
      setState(() => _loading = true);
    }

    try {
      List<Map<String, dynamic>> msgs;

      if (_ctx == 'prestataire') {
        // même logique que MessagesAnnoncePage mais pour prestataire
        msgs = await _svc.fetchMessagesForPrestataireVisibleTo(
          viewerUserId: me,
          prestataireId: widget.contextId,
        );
      } else {
        // logement => réutilise annonce_id dans la table messages
        msgs = await _svc.fetchMessagesForLogementVisibleTo(
          viewerUserId: me,
          logementId: widget.contextId,
        );
      }

      // Marquer comme lus pour moi
      final idsToMark = <String>[];
      for (final m in msgs) {
        final isForMe = (m['receiver_id']?.toString() == me);
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
        _msgs = msgs;
        if (initial) _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() => _loading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')),
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

  Future<void> _send() async {
    final me = _myId;
    final txt = _msgCtrl.text.trim();

    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour envoyer un message.')),
      );
      return;
    }
    if (txt.isEmpty) return;

    _msgCtrl.clear();

    // -------- UI optimiste (comme MessagesAnnoncePage) ----------
    setState(() {
      _msgs.add({
        'id': -1,
        'sender_id': me,
        'receiver_id': widget.peerUserId,
        'contenu': txt,
        'contexte': _ctx,
        if (_ctx == 'prestataire')
          'prestataire_id': widget.contextId
        else
          'annonce_id': widget.contextId, // logement utilise annonce_id
        'lu': true,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _scrollToEnd();
    // ------------------------------------------------------------

    try {
      if (_ctx == 'prestataire') {
        await _svc.sendMessageToPrestataire(
          senderId: me,
          receiverId: widget.peerUserId,
          prestataireId: widget.contextId,
          prestataireName: widget.contextTitle ?? '',
          contenu: txt,
        );
      } else {
        await _svc.sendMessageToLogement(
          senderId: me,
          receiverId: widget.peerUserId,
          logementId: widget.contextId,
          logementTitre: widget.contextTitle ?? widget.title,
          contenu: txt,
        );
      }

      // on force un refresh rapide, comme sur les annonces
      await _loadAndMarkRead(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  String _fmtTime(BuildContext ctx, DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt.toLocal());
    return t.format(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _showOfferCard
                        ? FutureBuilder<_Offer?>(
                            future: _offerFuture,
                            builder: (context, snap) {
                              final hasCard = (snap.data != null);
                              final total = _msgs.length + (hasCard ? 1 : 0);

                              if (!hasCard && _msgs.isEmpty) {
                                return Center(
                                  child: Text(
                                    "Aucune discussion pour ce logement.\nÉcrivez un message pour commencer.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: _scroll,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                itemCount: total,
                                itemBuilder: (_, i) {
                                  if (hasCard && i == 0) {
                                    final off = snap.data!;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 8, left: 0, right: 0, top: 0),
                                      child: _OfferMessageBubble(
                                        offer: off,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  LogementDetailPage(
                                                      logementId: off.id),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }
                                  final m = _msgs[i - (hasCard ? 1 : 0)]
                                      as Map<String, dynamic>;
                                  final mine =
                                      (m['sender_id']?.toString() == _myId);
                                  final date = _asDate(m['date_envoi']);

                                  return _Bubble(
                                    isMine: mine,
                                    body: (m['contenu'] ?? '').toString(),
                                    time: _fmtTime(context, date),
                                  );
                                },
                              );
                            },
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) {
                              final m = _msgs[i] as Map<String, dynamic>;
                              final mine =
                                  (m['sender_id']?.toString() == _myId);
                              final date = _asDate(m['date_envoi']);

                              return _Bubble(
                                isMine: mine,
                                body: (m['contenu'] ?? '').toString(),
                                time: _fmtTime(context, date),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _msgCtrl,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'Écrire un message…',
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // pas de spinner, envoi instantané comme MessagesAnnoncePage
                          ElevatedButton.icon(
                            onPressed: _send,
                            icon: const Icon(Icons.send),
                            label: const Text('Envoyer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ===== UI + DTOs =====

class _OfferMessageBubble extends StatelessWidget {
  const _OfferMessageBubble({required this.offer, required this.onTap});
  final _Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant;
    final fg = Theme.of(context).colorScheme.onSurface;

    return InkWell(
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
            (offer.imageUrl == null || offer.imageUrl!.isEmpty)
                ? Container(width: 110, height: 86, color: Colors.grey.shade300)
                : Image.network(
                    offer.imageUrl!,
                    width: 110,
                    height: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 86,
                      color: Colors.grey.shade300,
                    ),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.titre.isEmpty ? 'Logement' : offer.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                    ),
                    if (offer.prixLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        offer.prixLabel!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    if (offer.ville.isNotEmpty || offer.commune.isNotEmpty)
                      Text(
                        [offer.ville, offer.commune]
                            .where((e) => e.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(color: fg.withOpacity(.75)),
                      ),
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
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isMine, required this.body, required this.time});
  final bool isMine;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    final bgMine = Theme.of(context).colorScheme.primary;
    final fgMine = Theme.of(context).colorScheme.onPrimary;
    final bgOther = Theme.of(context).colorScheme.surfaceVariant;
    final fgOther = Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? bgMine : bgOther,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: TextStyle(color: isMine ? fgMine : fgOther)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: (isMine ? fgMine : fgOther).withOpacity(.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Offer {
  final String id;
  final String titre;
  final String? imageUrl;
  final String ville;
  final String commune;
  final String? prixLabel;
  _Offer({
    required this.id,
    required this.titre,
    required this.imageUrl,
    required this.ville,
    required this.commune,
    required this.prixLabel,
  });
}
