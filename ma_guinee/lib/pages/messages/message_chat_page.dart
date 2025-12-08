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
    required this.logementId, // id du logement (annonce_id)
    required this.logementTitre, // titre de l’annonce/logement
  });

  final String peerUserId;
  final String logementId;
  final String logementTitre;

  @override
  State<MessageChatPage> createState() => _MessageChatPageState();
}

class _MessageChatPageState extends State<MessageChatPage> {
  final _sb = Supabase.instance.client;

  final LogementService _logSvc = LogementService();
  final MessageService _svc = MessageService();

  // état messages
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _msgs = <Map<String, dynamic>>[];
  bool _loading = true;
  Timer? _pollTimer;

  // Carte (en-tête)
  late Future<_Offer?> _offerFuture;

  String? get _myId => _sb.auth.currentUser?.id;

  // ===== Helpers temps & entries =====
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

    final wd = weekDays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd ${d.day} $m';
  }

  String _timeLabel(BuildContext ctx, DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt.toLocal());
    return t.format(ctx);
  }

  /// Construit une liste d’entrées avec séparateurs de date
  /// IMPORTANT : on ne trie plus → on respecte l’ordre d’arrivée (id ASC)
  List<_ChatEntry> _buildEntries() {
    final List<_ChatEntry> entries = [];
    DateTime? lastDay;

    for (final m in _msgs) {
      final d = _asDate(m['date_envoi']);
      final day = DateTime(d.year, d.month, d.day);

      if (lastDay == null || !_sameDay(day, lastDay)) {
        entries.add(_DateSeparatorEntry(day));
        lastDay = day;
      }

      entries.add(_MessageEntry(m));
    }

    return entries;
  }

  /// Scroll auto vers le bas :
  /// - forcé quand on ouvre ou qu’on envoie
  /// - sinon uniquement si l’utilisateur est déjà proche du bas
  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      final max = _scroll.position.maxScrollExtent;
      final current = _scroll.position.pixels;
      final distanceFromBottom = max - current;

      if (!force && distanceFromBottom > 80) {
        // l’utilisateur lit plus haut → on ne touche pas
        return;
      }

      _scroll.animateTo(
        max,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ====== HEADER LOGEMENT (utilise le service, getById -> LogementModel?) ======
  Future<_Offer?> _fetchLogementHeaderViaService(String id) async {
    try {
      final LogementModel? bien = await _logSvc.getById(id);
      if (bien == null) {
        return _Offer(
          id: id,
          titre: widget.logementTitre,
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
        titre: widget.logementTitre,
        imageUrl: null,
        ville: '',
        commune: '',
        prixLabel: null,
      );
    }
  }

  // ====================== CYCLE DE VIE ======================

  @override
  void initState() {
    super.initState();
    _offerFuture = _fetchLogementHeaderViaService(widget.logementId);
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

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadAndMarkRead(initial: false);
    });
  }

  // ================= MESSAGES : CHARGEMENT =================

  Future<void> _loadAndMarkRead({bool initial = false}) async {
    final me = _myId;
    if (me == null) return;
    if (!mounted) return;

    if (initial) {
      setState(() => _loading = true);
    }

    try {
      final previousLastId =
          _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;

      // Logement => messages.contexte = 'logement' ET annonce_id = logementId
      final msgs = await _svc.fetchMessagesForLogementVisibleTo(
        viewerUserId: me,
        logementId: widget.logementId,
      );

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
        // ordre id ASC fourni par le service → on ne re-trie pas ici
        _msgs = msgs;
        if (initial) _loading = false;
      });

      final newLastId = _msgs.isNotEmpty ? _msgs.last['id']?.toString() : null;
      if (initial || previousLastId != newLastId) {
        _scrollToEnd(force: initial);
      }
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

  // ================= MESSAGES : ENVOI =================

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

    // UI optimiste (ajout en fin de liste)
    setState(() {
      _msgs.add({
        'id': -1,
        'sender_id': me,
        'receiver_id': widget.peerUserId,
        'contenu': txt,
        'contexte': 'logement',
        'annonce_id': widget.logementId, // logement = annonce_id
        'lu': true,
        'date_envoi': DateTime.now().toIso8601String(),
      });
    });
    _scrollToEnd(force: true);

    try {
      await _svc.sendMessageToLogement(
        senderId: me,
        receiverId: widget.peerUserId,
        logementId: widget.logementId,
        logementTitre: widget.logementTitre,
        contenu: txt,
      );

      // refresh rapide, sans casser le scroll si l’utilisateur lit
      await _loadAndMarkRead(initial: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de l'envoi du message : $e")),
      );
    }
  }

  // Suppression / masquage DE TOUTE la conversation pour MOI
  Future<void> _deleteWholeConversation() async {
    final me = _myId;
    if (me == null) return;

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer la discussion ?'),
            content: const Text(
              "Cette discussion sera supprimée de votre boîte de messages "
              "pour ce logement. Vous pourrez toujours renvoyer un message plus tard.",
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

    try {
      await _svc.hideThread(
        userId: me,
        contexte: 'logement',
        annonceId: widget.logementId,
        prestataireId: null,
        peerUserId: widget.peerUserId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation supprimée.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);
    const gris = Color(0xFFF8F8FB);

    return Scaffold(
      backgroundColor: gris,
      appBar: AppBar(
        title: Text(widget.logementTitre),
        actions: [
          IconButton(
            tooltip: 'Supprimer la conversation',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteWholeConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: FutureBuilder<_Offer?>(
                      future: _offerFuture,
                      builder: (context, snap) {
                        final hasCard = (snap.data != null);

                        final entries = _buildEntries();
                        final total = entries.length + (hasCard ? 1 : 0);

                        if (!hasCard && entries.isEmpty) {
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: total,
                          itemBuilder: (_, i) {
                            if (hasCard && i == 0) {
                              final off = snap.data!;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                ),
                                child: _OfferMessageBubble(
                                  offer: off,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LogementDetailPage(
                                          logementId: off.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }

                            final entry = entries[i - (hasCard ? 1 : 0)];

                            if (entry is _DateSeparatorEntry) {
                              return _DateChip(label: _dayLabel(entry.day));
                            }

                            final msgEntry = entry as _MessageEntry;
                            final m = msgEntry.msg;
                            final mine = (m['sender_id']?.toString() == _myId);
                            final date = _asDate(m['date_envoi']);

                            return _Bubble(
                              isMine: mine,
                              body: (m['contenu'] ?? '').toString(),
                              time: _timeLabel(context, date),
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
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _send,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bleu,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(14),
                            ),
                            child: const Icon(Icons.send,
                                color: Colors.white, size: 20),
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
  const _Bubble({
    required this.isMine,
    required this.body,
    required this.time,
  });

  final bool isMine;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    const bleu = Color(0xFF113CFC);
    const gris = Color(0xFFF3F5FA);

    final bg = isMine ? bleu : gris;
    final fg = isMine ? Colors.white : Colors.black87;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 6,
          bottom: 6,
          left: isMine ? 40 : 12,
          right: isMine ? 12 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 8),
            bottomRight: Radius.circular(isMine ? 8 : 18),
          ),
          boxShadow: [
            if (isMine)
              BoxShadow(
                color: Colors.blue.shade100,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: TextStyle(color: fg),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: fg.withOpacity(isMine ? .8 : .6),
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

// ===== Entries pour le ListView =====

abstract class _ChatEntry {
  const _ChatEntry();
}

class _DateSeparatorEntry extends _ChatEntry {
  final DateTime day;
  const _DateSeparatorEntry(this.day);
}

class _MessageEntry extends _ChatEntry {
  final Map<String, dynamic> msg;
  const _MessageEntry(this.msg);
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
