// lib/pages/messages/message_chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Service & modèles logement (même source que la page détail)
import '../../services/logement_service.dart';
import '../../models/logement_models.dart';

// Détail logement
import '../../pages/logement/logement_detail_page.dart';

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

  // état messages
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  late Stream<List<_Msg>> _stream;
  bool _sending = false;

  // Carte (en-tête)
  late Future<_Offer?> _offerFuture;

  String get _ctx => widget.contextType; // 'logement' | 'prestataire'
  bool get _showOfferCard => (_ctx == 'logement');
  String? get _myId => _sb.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => _fetchThread());
    _offerFuture = _showOfferCard
        ? _fetchLogementHeaderViaService(widget.contextId)
        : Future.value(null);
  }

  @override
  void dispose() {
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
        final first =
            bien.photos.firstWhere((p) => p.trim().isNotEmpty, orElse: () => '');
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
  Future<List<_Msg>> _fetchThread() async {
    final me = _myId;
    if (me == null) return const <_Msg>[];

    final pair =
        'and(sender_id.eq.$me,receiver_id.eq.${widget.peerUserId}),and(sender_id.eq.${widget.peerUserId},receiver_id.eq.$me)';

    final sel = await _sb
        .from('messages')
        .select(
            'id,sender_id,receiver_id,contenu,contexte,annonce_id,prestataire_id,date_envoi,lu')
        .or(pair)
        .eq('contexte', _ctx)
        // logement réutilise annonce_id
        .eq(_ctx == 'prestataire' ? 'prestataire_id' : 'annonce_id',
            widget.contextId)
        .order('date_envoi', ascending: true);

    final rows = (sel as List).cast<Map<String, dynamic>>();

    // marquer comme lus
    final toMark = rows
        .where((m) => (m['receiver_id']?.toString() == me) && (m['lu'] != true))
        .map((m) => m['id'].toString())
        .toList();
    if (toMark.isNotEmpty) {
      await _sb.from('messages').update({'lu': true}).inFilter('id', toMark);
    }

    return rows.map(_Msg.fromMap).toList(growable: false);
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

    setState(() => _sending = true);
    try {
      final data = <String, dynamic>{
        'sender_id': me,
        'receiver_id': widget.peerUserId,
        'contexte': _ctx, // 'logement' OU 'prestataire'
        'contenu': txt,
        'date_envoi': DateTime.now().toIso8601String(),
        'lu': false,
      };
      if (_ctx == 'prestataire') {
        data['prestataire_id'] = widget.contextId;
        if (widget.contextTitle != null) {
          data['prestataire_name'] = widget.contextTitle;
        }
      } else {
        // logement => stocké dans annonce_id
        data['annonce_id'] = widget.contextId;
        if (widget.contextTitle != null) {
          data['annonce_titre'] = widget.contextTitle;
        }
      }

      await _sb.from('messages').insert(data);
      _msgCtrl.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur d’envoi : $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _myId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (_showOfferCard)
            FutureBuilder<_Offer?>(
              future: _offerFuture,
              builder: (context, snap) {
                final off = snap.data;
                if (snap.connectionState != ConnectionState.done || off == null) {
                  return const SizedBox(height: 4);
                }
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8, left: 12, right: 12, top: 10),
                  child: _OfferMessageBubble(
                    offer: off,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LogementDetailPage(logementId: off.id)),
                      );
                    },
                  ),
                );
              },
            ),
          Expanded(
            child: StreamBuilder<List<_Msg>>(
              stream: _stream,
              builder: (context, snap) {
                final msgs = snap.data ?? const <_Msg>[];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = (m.senderId == me);
                    return _Bubble(
                      isMine: mine,
                      body: m.body,
                      time: _fmtTime(context, m.dateEnvoi),
                    );
                  },
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
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Envoi…' : 'Envoyer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(BuildContext ctx, DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt.toLocal());
    return t.format(ctx);
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
                    errorBuilder: (_, __, ___) =>
                        Container(width: 110, height: 86, color: Colors.grey.shade300),
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
                    color: (isMine ? fgMine : fgOther).withOpacity(.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime dateEnvoi;

  _Msg({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.dateEnvoi,
  });

  factory _Msg.fromMap(Map<String, dynamic> m) => _Msg(
        id: m['id'].toString(),
        senderId: m['sender_id'].toString(),
        receiverId: m['receiver_id'].toString(),
        body: (m['contenu'] ?? '').toString(),
        dateEnvoi: DateTime.parse(m['date_envoi'].toString()),
      );
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
