// lib/navigation/push_nav.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nav_key.dart';
import '../routes.dart';
import '../pages/messages_annonce_page.dart';
import '../pages/messages/message_chat_page.dart';

class PushNav {
  PushNav._(); // pas d'instance

  /// Appelé quand l'utilisateur tape sur une notification "nouveau message".
  /// On ignore le contenu du payload FCM et on ouvre
  /// la dernière conversation reçue par l'utilisateur.
  static Future<void> openMessageFromData(Map<String, dynamic> data) async {
    try {
      final supa = Supabase.instance.client;
      final me = supa.auth.currentUser;

      // Pas connecté -> on renvoie vers l'écran de bienvenue
      if (me == null) {
        navKey.currentState
            ?.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
        return;
      }

      // On récupère le DERNIER message reçu par cet utilisateur
      final List rows = await supa
          .from('messages')
          .select()
          .eq('receiver_id', me.id)
          .order('date_envoi', ascending: false)
          .limit(1);

      if (rows.isEmpty) {
        // Rien à ouvrir
        return;
      }

      final m = rows.first as Map<String, dynamic>;

      final contexte = (m['contexte'] ?? '').toString();
      final senderId = (m['sender_id'] ?? '').toString();
      final receiverId = (m['receiver_id'] ?? '').toString();
      final myId = me.id;

      // Normalement, pour une notif "nouveau message", receiverId == myId
      final otherId = (senderId == myId) ? receiverId : senderId;
      if (otherId.isEmpty) return;

      if (contexte == 'annonce') {
        final annonceId = (m['annonce_id'] ?? '').toString();
        if (annonceId.isEmpty) return;

        final rawTitre = (m['annonce_titre'] ?? '').toString();
        final titre = rawTitre.trim().isNotEmpty ? rawTitre.trim() : 'Annonce';

        navKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => MessagesAnnoncePage(
              annonceId: annonceId,
              annonceTitre: titre,
              receiverId: otherId,
              senderId: myId,
            ),
          ),
        );
        return;
      }

      if (contexte == 'logement') {
        final logementId =
            (m['logement_id'] ?? m['annonce_id'] ?? '').toString();
        if (logementId.isEmpty) return;

        final rawTitre = (m['annonce_titre'] ?? '').toString();
        final titre = rawTitre.trim().isNotEmpty ? rawTitre.trim() : 'Logement';

        navKey.currentState?.push(
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

      // Par défaut : prestataire / autres contextes
      final prestaId = (m['prestataire_id'] ?? '').toString();
      final rawPrestaName =
          (m['prestataire_name'] ?? m['prestataire_nom'] ?? '').toString();
      final prestaTitre = rawPrestaName.trim().isNotEmpty
          ? rawPrestaName.trim()
          : 'Prestataire';

      navKey.currentState?.push(
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
    } catch (_) {
      // En cas d'erreur, on ne fait rien pour ne pas crasher l'app
    }
  }
}
