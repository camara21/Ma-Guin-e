import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final _client = Supabase.instance.client;

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

    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForAnnonce(String annonceId) async {
    final raw = await _client
        .from('messages')
        .select('id, sender_id, receiver_id, contenu, lu, date_envoi')
        .eq('contexte', 'annonce')
        .eq('annonce_id', annonceId)
        .order('date_envoi', ascending: true);

    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForPrestataire(String prestataireId) async {
    final raw = await _client
        .from('messages')
        .select('id, sender_id, receiver_id, contenu, lu, date_envoi')
        .eq('contexte', 'prestataire')
        .eq('prestataire_id', prestataireId)
        .order('date_envoi', ascending: true);

    return (raw as List).cast<Map<String, dynamic>>();
  }

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
  }

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
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _client
        .from('messages')
        .update({'lu': true})
        .eq('id', messageId);
  }

  /// Écoute tous les nouveaux messages (Realtime)
  StreamSubscription<List<Map<String, dynamic>>> subscribeAll(VoidCallback onUpdate) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('date_envoi')
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            onUpdate();
          }
        });
  }

  /// Compte les messages non lus reçus par l'utilisateur
  Future<int> getUnreadMessagesCount(String userId) async {
  final result = await _client
      .from('messages')
      .select('id')
      .eq('receiver_id', userId)
      .eq('lu', false);

  final data = result as List;
  return data.length;
  }
}
