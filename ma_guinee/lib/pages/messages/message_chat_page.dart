// lib/pages/messages/message_chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/user_provider.dart';
import '../../models/utilisateur_model.dart';

// 🔗 même service / modèles que la page détail
import '../../services/logement_service.dart';
import '../../models/logement_models.dart';
import '../logement/logement_detail_page.dart';

class MessageChatPage extends StatefulWidget {
  const MessageChatPage({
    super.key,
    required this.peerUserId,     // autre participant
    required this.title,          // nom interlocuteur (AppBar)
    required this.contextType,    // 'annonce' | 'prestataire' | 'logement' (alias -> 'annonce')
    required this.contextId,      // id annonce/logement OU id prestataire
    this.contextTitle,            // titre du logement (si dispo)
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

  final _text = TextEditingController();
  final _scroll = ScrollController();

  late Stream<List<_Msg>> _stream;
  bool _sending = false;

  // alias: logement -> annonce
  String get _ctx => (widget.contextType == 'logement') ? 'annonce' : widget.contextType;

  // Offre (via LogementService)
  final _logements = LogementService();
  late Future<_Offer?> _offerFuture;

  String? _myId() {
    try {
      final u = context.read<UserProvider?>()?.utilisateur;
      final id = (u as UtilisateurModel?)?.id;
      if (id != null && id.toString().isNotEmpty) return id.toString();
    } catch (_) {}
    return _sb.auth.currentUser?.id;
  }

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => _fetchThread());
    _offerFuture = (_ctx == 'annonce') ? _fetchOfferFromService() : Future.value(null);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Lit le logement via LogementService (même logique que détail)
  Future<_Offer?> _fetchOfferFromService() async {
    try {
      final b = await _logements.getById(widget.contextId);
      if (b == null) {
        // fallback minimal pour afficher qqch si jamais l’ID n’existe plus
        return _Offer(
          id: widget.contextId,
          titre: (widget.contextTitle ?? 'Logement').toString(),
          imageUrl: null,
          ville: '',
          commune: '',
          prixLabel: null,
        );
      }

      final img = b.photos.isNotEmpty ? b.photos.first : null;
      final prixLabel = _fmtPrixWithMode(b.prixGnf, b.mode);

      return _Offer(
        id: b.id,
        titre: b.titre,
        imageUrl: img,
        ville: b.ville ?? '',
        commune: b.commune ?? '',
        prixLabel: prixLabel,
      );
    } catch (_) {
      // en cas d’erreur réseau, on affiche au moins le titre
      return _Offer(
        id: widget.contextId,
        titre: (widget.contextTitle ?? 'Logement').toString(),
        imageUrl: null,
        ville: '',
        commune: '',
        prixLabel: null,
      );
    }
  }
  // ─────────────────────────────────────────────────────────────

  Future<List<_Msg>> _fetchThread() async {
    final me = _myId();
    if (me == null) return [];

    final pair =
        'and(sender_id.eq.$me,receiver_id.eq.${widget.peerUserId}),and(sender_id.eq.${widget.peerUserId},receiver_id.eq.$me)';

    final ctxs = (_ctx == 'annonce') ? ['annonce', 'logement'] : [_ctx];

    final sel = await _sb
        .from('messages')
        .select('id, sender_id, receiver_id, contenu, contexte, annonce_id, prestataire_id, date_envoi, lu')
        .or(pair)
        .inFilter('contexte', ctxs)
        .eq(_ctx == 'annonce' ? 'annonce_id' : 'prestataire_id', widget.contextId)
        .order('date_envoi', ascending: true);

    final rows = (sel as List).cast<Map<String, dynamic>>();

    final idsToMark = rows
        .where((m) => (m['receiver_id']?.toString() == me) && (m['lu'] != true))
        .map((m) => m['id'].toString())
        .toList();
    if (idsToMark.isNotEmpty) {
      await _sb.from('messages').update({'lu': true}).inFilter('id', idsToMark);
    }

    return rows.map(_Msg.fromMap).toList(growable: false);
  }

  Future<void> _send() async {
    final me = _myId();
    final txt = _text.text.trim();
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
        'contexte': _ctx,
        'contenu': txt,
        'date_envoi': DateTime.now().toIso8601String(),
        'lu': false,
      };
      if (_ctx == 'annonce') {
        data['annonce_id'] = widget.contextId;
        if (widget.contextTitle != null) data['annonce_titre'] = widget.contextTitle;
      } else {
        data['prestataire_id'] = widget.contextId;
        if (widget.contextTitle != null) data['prestataire_name'] = widget.contextTitle;
      }

      await _sb.from('messages').insert(data);
      _text.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _myId();
    final showOfferCard = (_ctx == 'annonce'); // alias logement

    return Scaffold(
      appBar: AppBar(title: Text('Message • ${widget.title}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<_Msg>>(
              stream: _stream,
              builder: (context, snap) {
                final msgs = snap.data ?? const <_Msg>[];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });

                return FutureBuilder<_Offer?>(
                  future: _offerFuture,
                  builder: (context, offerSnap) {
                    final off = offerSnap.data;
                    final hasOffer = showOfferCard && off != null;
                    final total = msgs.length + (hasOffer ? 1 : 0);

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: total,
                      itemBuilder: (_, i) {
                        if (hasOffer && i == 0) {
                          // 👉 PREMIER "MESSAGE" = CARTE LOGEMENT
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _OfferMessageBubble(
                              offer: off!,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LogementDetailPage(logementId: off.id),
                                  ),
                                );
                              },
                            ),
                          );
                        }

                        final m = msgs[i - (hasOffer ? 1 : 0)];
                        final isMine = (m.senderId == me);
                        return _Bubble(
                          isMine: isMine,
                          body: m.body,
                          time: _fmtTime(context, m.dateEnvoi),
                        );
                      },
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
                      controller: _text,
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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

  // même logique d'affichage que la page détail, condensée ici
  String? _fmtPrixWithMode(num? value, LogementMode? mode) {
    if (value == null) return null;
    String unit = (mode == LogementMode.achat) ? 'GNF' : 'GNF / mois';
    if (value >= 1000000) {
      final m = (value / 1000000).toStringAsFixed(1).replaceAll('.0', '');
      return '$m M $unit';
    }
    final s = value.toStringAsFixed(0);
    return '$s $unit';
  }
}

class _OfferMessageBubble extends StatelessWidget {
  const _OfferMessageBubble({required this.offer, required this.onTap});
  final _Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // style bulle "système" à gauche
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
              // vignette photo
              (offer.imageUrl == null || offer.imageUrl!.isEmpty)
                  ? Container(width: 110, height: 86, color: Colors.grey.shade300)
                  : Image.network(offer.imageUrl!, width: 110, height: 86, fit: BoxFit.cover),
              const SizedBox(width: 10),
              // infos
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
                      Text(
                        [offer.ville, offer.commune].where((e) => e.isNotEmpty).join(' • '),
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                style: TextStyle(fontSize: 10, color: (isMine ? fgMine : fgOther).withOpacity(0.7)),
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
