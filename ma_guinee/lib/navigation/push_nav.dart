// lib/navigation/push_nav.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nav_key.dart';
import '../routes.dart';

// Messages
import '../pages/messages_annonce_page.dart';
import '../pages/messages/message_chat_page.dart';

// Popup Admin
import '../admin/admin_popup_page.dart';

class PushNav {
  PushNav._();

  // -------------------------------------------------------------
  //   DETECTION NOTIFICATION ADMIN (NE JAMAIS ATTRAPER "message")
  // -------------------------------------------------------------
  static bool isAdminPayload(Map<String, dynamic> data) {
    try {
      String kind = (data['kind'] ?? '').toString().toLowerCase();
      String type = (data['type'] ?? '').toString().toLowerCase();

      // 1) Les notifications de chat ne sont JAMAIS admin
      if (kind == 'message' || type == 'message') {
        return false;
      }

      // 2) Nouveau format : kind = admin
      if (kind == 'admin') return true;

      // 3) Ancien format : seulement "type" = info / alert / etc.
      if (type.isNotEmpty && type != 'message') return true;

      // 4) Compatibilité legacy si l'info est dans data["data"]
      final inner = data['data'];
      if (inner is Map) {
        final ik = (inner['kind'] ?? '').toString().toLowerCase();
        final it = (inner['type'] ?? '').toString().toLowerCase();

        if (ik == 'message' || it == 'message') return false;
        if (ik == 'admin') return true;
        if (it.isNotEmpty && it != 'message') return true;
      } else if (inner is String) {
        try {
          final decoded = jsonDecode(inner);
          if (decoded is Map) {
            final ik = (decoded['kind'] ?? '').toString().toLowerCase();
            final it = (decoded['type'] ?? '').toString().toLowerCase();

            if (ik == 'message' || it == 'message') return false;
            if (ik == 'admin') return true;
            if (it.isNotEmpty && it != 'message') return true;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[PushNav] isAdminPayload error: $e');
    }

    return false;
  }

  // -------------------------------------------------------------
  //   POPUP ADMIN GLOBAL (overlay.context)
  // -------------------------------------------------------------
  static Future<void> showAdminDialog({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final url = data?['url']?.toString();

    final ctx = navKey.currentState?.overlay?.context ?? navKey.currentContext;
    if (ctx == null) {
      debugPrint('[PushNav] showAdminDialog → context NULL ❌');
      return;
    }

    await Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.35),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: AdminPopupPage(
              title: title,
              body: body,
              url: url,
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  //   NAVIGATION POUR LES MESSAGES (utilise d'abord la payload FCM)
  // -------------------------------------------------------------
  static Future<void> openMessageFromData(Map<String, dynamic> incoming) async {
    try {
      final sb = Supabase.instance.client;
      final me = sb.auth.currentUser;
      if (me == null) {
        // utilisateur non connecté : renvoyer vers welcome (sécurisé)
        navKey.currentState
            ?.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
        return;
      }

      final ctx =
          navKey.currentState?.overlay?.context ?? navKey.currentContext;
      if (ctx == null) {
        debugPrint('[PushNav] openMessageFromData → context NULL ❌');
        return;
      }

      // --- Normaliser payload (fusionne incoming + incoming["data"] si besoin) ---
      final Map<String, String> payload = _normalizeToStringMap(incoming);

      debugPrint('[PushNav] payload normalisé = $payload');

      // Extraire champs possibles (tolérant plusieurs variantes de clé)
      String? contexte =
          payload['contexte'] ?? payload['type'] ?? payload['kind'];
      String? senderId =
          payload['sender_id'] ?? payload['senderId'] ?? payload['from'];
      String? receiverId = payload['receiver_id'] ??
          payload['receiverId'] ??
          payload['to'] ??
          payload['user_id'];
      String? annonceId = payload['annonce_id'] ??
          payload['annonceId'] ??
          payload['logement_id'] ??
          payload['logementId'];
      String? logementId = payload['logement_id'] ??
          payload['logementId'] ??
          payload['annonce_id'] ??
          payload['annonceId'];
      String? prestataireId = payload['prestataire_id'] ??
          payload['prestataireId'] ??
          payload['context_id'];
      String? messageId =
          payload['message_id'] ?? payload['messageId'] ?? payload['msg_id'];

      // Déduire otherId si possible
      String? otherId;
      final myId = me.id;
      if ((senderId?.isNotEmpty ?? false) &&
          (receiverId?.isNotEmpty ?? false)) {
        otherId = (senderId == myId) ? receiverId : senderId;
      } else if ((senderId?.isNotEmpty ?? false) &&
          !(receiverId?.isNotEmpty ?? false)) {
        otherId = (senderId == myId) ? null : senderId;
      } else if ((receiverId?.isNotEmpty ?? false) &&
          !(senderId?.isNotEmpty ?? false)) {
        otherId = (receiverId == myId) ? null : receiverId;
      }

      // Si payload contient message_id -> tenter de récupérer le message par id (prioritaire)
      Map<String, dynamic>? messageRow;
      if (messageId != null && messageId.isNotEmpty) {
        try {
          final row = await sb
              .from('messages')
              .select()
              .eq('id', messageId)
              .maybeSingle();
          if (row != null) {
            messageRow = Map<String, dynamic>.from(row as Map);
            debugPrint(
                '[PushNav] message récupéré par message_id = $messageId');
          }
        } catch (e) {
          debugPrint('[PushNav] Erreur fetch message by id: $e');
        }
      }

      // Si pas de messageRow mais payload contient suffisamment d'infos (sender/receiver),
      // essayer de récupérer le dernier message entre eux
      if (messageRow == null &&
          (senderId?.isNotEmpty ?? false) &&
          (receiverId?.isNotEmpty ?? false)) {
        try {
          final rows = await sb
              .from('messages')
              .select()
              .or('and(sender_id.eq.$senderId,receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.$senderId)')
              .order('date_envoi', ascending: false)
              .limit(1);
          if (rows != null && (rows as List).isNotEmpty) {
            messageRow = Map<String, dynamic>.from(rows.first as Map);
            debugPrint('[PushNav] message récupéré par paire sender/receiver');
          }
        } catch (e) {
          debugPrint('[PushNav] Erreur fetch last by pair: $e');
        }
      }

      // Si on a messageRow on s'en sert ; sinon on utilisera la payload directe quand possible ; sinon fallback DB (dernier reçu)
      if (messageRow != null) {
        contexte = (messageRow['contexte'] ?? contexte ?? '').toString();
        senderId = (messageRow['sender_id'] ?? senderId ?? '').toString();
        receiverId = (messageRow['receiver_id'] ?? receiverId ?? '').toString();
        annonceId = (messageRow['annonce_id'] ?? annonceId ?? '').toString();
        logementId =
            (messageRow['logement_id'] ?? logementId ?? annonceId ?? '')
                .toString();
        prestataireId =
            (messageRow['prestataire_id'] ?? prestataireId ?? '').toString();
      }

      // Si toujours pas d'otherId et messageRow absent, fallback : dernier message reçu par moi
      if ((otherId == null || otherId.isEmpty) && messageRow == null) {
        try {
          final rows = await sb
              .from('messages')
              .select()
              .eq('receiver_id', myId)
              .order('date_envoi', ascending: false)
              .limit(1);
          if (rows != null && (rows as List).isNotEmpty) {
            messageRow = Map<String, dynamic>.from(rows.first as Map);
            debugPrint('[PushNav] fallback last received message utilisé');
            contexte = (messageRow['contexte'] ?? contexte ?? '').toString();
            senderId = (messageRow['sender_id'] ?? senderId ?? '').toString();
            receiverId =
                (messageRow['receiver_id'] ?? receiverId ?? '').toString();
            annonceId =
                (messageRow['annonce_id'] ?? annonceId ?? '').toString();
            logementId =
                (messageRow['logement_id'] ?? logementId ?? annonceId ?? '')
                    .toString();
            prestataireId =
                (messageRow['prestataire_id'] ?? prestataireId ?? '')
                    .toString();
            otherId = senderId == myId ? receiverId : senderId;
          }
        } catch (e) {
          debugPrint('[PushNav] fallback DB fetch failed: $e');
        }
      }

      // final safety: recalc otherId if possible
      if ((otherId == null || otherId.isEmpty) &&
          (senderId?.isNotEmpty ?? false)) {
        otherId = (senderId == myId) ? receiverId : senderId;
      }

      if (otherId == null || otherId.isEmpty) {
        debugPrint(
            '[PushNav] impossible de déterminer otherId → abort navigation');
        return;
      }

      // Normaliser le contexte en minuscules
      contexte = (contexte ?? '').toLowerCase();

      // =========================================================
      //   ROUTAGE SELON CONTEXTE
      // =========================================================

      // 1) Annonce : on garde l'écran MessagesAnnoncePage
      if (contexte == 'annonce') {
        final ctxId = (annonceId ?? '').toString();
        final titre =
            payload['annonce_titre'] ?? payload['title'] ?? 'Message annonce';
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => MessagesAnnoncePage(
              annonceId: ctxId,
              annonceTitre: titre,
              receiverId: otherId!,
              senderId: myId,
            ),
          ),
        );
        return;
      }

      // 2) Logement : utiliser le chat logement (MessageChatPage)
      if (contexte == 'logement') {
        // dans ta table, tu mets le logement dans annonce_id,
        // donc logementId peut valoir soit logement_id, soit annonce_id
        final ctxId =
            (logementId?.isNotEmpty == true ? logementId : (annonceId ?? ''))
                .toString();

        final titre = payload['logement_titre'] ??
            payload['annonce_titre'] ??
            payload['title'] ??
            'Logement';

        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => MessageChatPage(
              peerUserId: otherId!,
              title: titre,
              contextType: 'logement',
              contextId: ctxId,
              contextTitle: titre,
            ),
          ),
        );
        return;
      }

      // 3) Prestataire
      if (contexte == 'prestataire') {
        final prestaId = prestataireId ?? '';
        final titre =
            payload['prestataire_name'] ?? payload['title'] ?? 'Prestataire';
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => MessageChatPage(
              peerUserId: otherId!,
              title: titre,
              contextType: 'prestataire',
              contextId: prestaId,
              contextTitle: titre,
            ),
          ),
        );
        return;
      }

      // 4) Contexte inconnu → fallback chat prestataire générique
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => MessageChatPage(
            peerUserId: otherId!,
            title: payload['title'] ?? 'Conversation',
            contextType: 'prestataire',
            contextId: prestataireId ?? '',
            contextTitle: payload['title'] ?? 'Conversation',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PushNav] erreur openMessageFromData: $e');
    }
  }

  // ---------- Helpers ----------
  static Map<String, String> _normalizeToStringMap(
      Map<String, dynamic> incoming) {
    final out = <String, String>{};

    // copie initiale (values -> toString)
    incoming.forEach((k, v) {
      if (v == null) return;
      out[k.toString()] = v.toString();
    });

    // si incoming['data'] existe et est JSON encodé ou Map, fusionner
    final inner = incoming['data'];
    if (inner != null) {
      if (inner is String) {
        try {
          final parsed = jsonDecode(inner);
          if (parsed is Map) {
            parsed.forEach((k, v) {
              if (v != null) out[k.toString()] = v.toString();
            });
          }
        } catch (_) {
          // ignore parse error
        }
      } else if (inner is Map) {
        (inner as Map).forEach((k, v) {
          if (v != null) out[k.toString()] = v.toString();
        });
      }
    }

    return out;
  }
}
