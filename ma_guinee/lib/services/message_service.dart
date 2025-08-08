import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final _client = Supabase.instance.client;

  /// 🔔 Événement local pour prévenir l’UI qu’il faut recalculer le badge.
  final StreamController<void> unreadChanged = StreamController<void>.broadcast();

  /// ---------------------------------
  /// Conversations de l’utilisateur
  /// ---------------------------------
  Future<List<Map<String, dynamic>>> fetchUserConversations(String userId) async {
    final raw = await _client
        .from('messages')
        .select('''
          id,
          sender_id,
          receiver_id,
          contenu,
          contexte,
          annonce_id,
          annonce_titre,
          prestataire_id,
          prestataire_name,
          lu,
          date_envoi
        ''')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('date_envoi', ascending: false);

    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  /// ---------------------------------
  /// Messages pour une annonce
  /// ---------------------------------
  Future<List<Map<String, dynamic>>> fetchMessagesForAnnonce(String annonceId) async {
    final raw = await _client
        .from('messages')
        .select('id, sender_id, receiver_id, contenu, lu, date_envoi')
        .eq('contexte', 'annonce')
        .eq('annonce_id', annonceId)
        .order('date_envoi', ascending: true);

    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  /// ---------------------------------
  /// Messages pour un prestataire
  /// ---------------------------------
  Future<List<Map<String, dynamic>>> fetchMessagesForPrestataire(String prestataireId) async {
    final raw = await _client
        .from('messages')
        .select('id, sender_id, receiver_id, contenu, lu, date_envoi')
        .eq('contexte', 'prestataire')
        .eq('prestataire_id', prestataireId)
        .order('date_envoi', ascending: true);

    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  /// ---------------------------------
  /// Envoi message annonce
  /// ---------------------------------
  Future<void> sendMessageToAnnonce({
    required String senderId,
    required String receiverId,
    required String annonceId,
    required String annonceTitre,
    required String contenu,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'contexte': 'annonce',
      'annonce_id': annonceId,
      'annonce_titre': annonceTitre,
      'contenu': contenu,
      'date_envoi': DateTime.now().toIso8601String(),
      'lu': false,
    });
    unreadChanged.add(null); // 🔔 mettre à jour le badge
  }

  /// ---------------------------------
  /// Envoi message prestataire
  /// ---------------------------------
  Future<void> sendMessageToPrestataire({
    required String senderId,
    required String receiverId,
    required String prestataireId,
    required String prestataireName,
    required String contenu,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'contexte': 'prestataire',
      'prestataire_id': prestataireId,
      'prestataire_name': prestataireName,
      'contenu': contenu,
      'date_envoi': DateTime.now().toIso8601String(),
      'lu': false,
    });
    unreadChanged.add(null); // 🔔 mettre à jour le badge
  }

  /// ---------------------------------
  /// Marquer 1 message comme lu
  /// ---------------------------------
  Future<void> markMessageAsRead(String messageId) async {
    await _client.from('messages').update({'lu': true}).eq('id', messageId);
    unreadChanged.add(null);
  }

  /// ---------------------------------
  /// Marquer plusieurs messages comme lus
  /// ---------------------------------
  Future<void> markMessagesAsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('messages').update({'lu': true}).inFilter('id', ids);
    unreadChanged.add(null);
  }

  /// ---------------------------------
  /// Écouter tous les changements
  /// ---------------------------------
  StreamSubscription<List<Map<String, dynamic>>> subscribeAll(VoidCallback onUpdate) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('date_envoi')
        .listen((_) {
      try {
        onUpdate();
      } catch (e, st) {
        debugPrint('Erreur dans onUpdate: $e\n$st');
      }
    });
  }

  /// ---------------------------------
  /// Compter les messages non lus
  /// ---------------------------------
  Future<int> getUnreadMessagesCount(String userId) async {
    final result = await _client
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('lu', false);

    if (result == null) return 0;
    return (result as List).length;
  }
}
