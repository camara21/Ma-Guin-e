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
  //   DETECTION NOTIFICATION ADMIN
  // -------------------------------------------------------------
  static bool isAdminPayload(Map<String, dynamic> data) {
    if (data.containsKey('type')) return true;

    final inner = data['data'];

    if (inner is Map && inner.containsKey('type')) return true;

    if (inner is String) {
      try {
        final decoded = jsonDecode(inner);
        if (decoded is Map && decoded.containsKey('type')) return true;
      } catch (_) {}
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

    final ctx = navKey.currentState?.overlay?.context;
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
  //   NAVIGATION POUR LES MESSAGES
  // -------------------------------------------------------------
  static Future<void> openMessageFromData(Map<String, dynamic> data) async {
    try {
      final sb = Supabase.instance.client;
      final me = sb.auth.currentUser;
      if (me == null) {
        navKey.currentState
            ?.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
        return;
      }

      // Dernier message reçu
      final rows = await sb
          .from('messages')
          .select()
          .eq('receiver_id', me.id)
          .order('date_envoi', ascending: false)
          .limit(1);

      if (rows.isEmpty) return;
      final m = rows.first;

      final contexte = (m['contexte'] ?? '').toString();
      final senderId = (m['sender_id'] ?? '').toString();
      final receiverId = (m['receiver_id'] ?? '').toString();

      final myId = me.id;
      final otherId = senderId == myId ? receiverId : senderId;
      if (otherId.isEmpty) return;

      final ctx = navKey.currentState?.overlay?.context;
      if (ctx == null) {
        debugPrint('[PushNav] openMessageFromData → context NULL ❌');
        return;
      }

      // ANNONCE
      if (contexte == 'annonce') {
        final annonceId = (m['annonce_id'] ?? '').toString();
        final titre = (m['annonce_titre'] ?? 'Annonce').toString();

        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => MessagesAnnoncePage(
              annonceId: annonceId,
              annonceTitre: titre,
              receiverId: otherId,
              senderId: me.id,
            ),
          ),
        );
        return;
      }

      // LOGEMENT
      if (contexte == 'logement') {
        final logementId = (m['logement_id'] ?? '').toString();
        final titre = (m['annonce_titre'] ?? 'Logement').toString();

        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => MessageChatPage(
              peerUserId: otherId,
              title: titre,
              contextType: 'logement',
              contextId: logementId,
              contextTitle: titre,
            ),
          ),
        );
        return;
      }

      // PRESTATAIRE
      final prestaId = (m['prestataire_id'] ?? '').toString();
      final prestaTitre =
          (m['prestataire_name'] ?? m['prestataire_nom'] ?? 'Prestataire')
              .toString();

      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => MessageChatPage(
            peerUserId: otherId,
            title: prestaTitre,
            contextType: 'prestataire',
            contextId: prestaId,
            contextTitle: prestaTitre,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PushNav] erreur openMessageFromData: $e');
    }
  }
}
