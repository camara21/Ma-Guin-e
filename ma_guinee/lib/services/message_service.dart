import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMessagesForAnnonce(String annonceId) async {
    if (annonceId.isEmpty) throw Exception("annonceId est vide");
    final response = await supabase
        .from('messages')
        .select()
        .eq('annonce_id', annonceId)
        .order('date_envoi', ascending: true);

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      throw Exception("Erreur récupération messages annonce");
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForPrestataire(String prestataireId) async {
    if (prestataireId.isEmpty) throw Exception("prestataireId est vide");
    final response = await supabase
        .from('messages')
        .select()
        .eq('prestataire_id', prestataireId)
        .order('date_envoi', ascending: true);

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      throw Exception("Erreur récupération messages prestataire");
    }
  }

  Future<void> sendMessageToAnnonce({
    required String senderId,
    required String receiverId,
    required String annonceId,
    required String contenu,
  }) async {
    if ([senderId, receiverId, annonceId, contenu].any((e) => e.isEmpty)) {
      throw Exception("Tous les champs sont requis pour envoyer un message");
    }
    final message = {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'annonce_id': annonceId,
      'contenu': contenu,
      'lu': false,
      'date_envoi': DateTime.now().toIso8601String(),
      'contexte': 'annonce',
    };
    await supabase.from('messages').insert(message);
  }

  Future<void> sendMessageToPrestataire({
    required String senderId,
    required String receiverId,
    required String prestataireId,
    required String contenu,
  }) async {
    if ([senderId, receiverId, prestataireId, contenu].any((e) => e.isEmpty)) {
      throw Exception("Tous les champs sont requis pour envoyer un message");
    }
    final message = {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'prestataire_id': prestataireId,
      'contenu': contenu,
      'lu': false,
      'date_envoi': DateTime.now().toIso8601String(),
      'contexte': 'prestataire',
    };
    await supabase.from('messages').insert(message);
  }

  // Abonnement en temps réel sans type explicite
  subscribeToAnnonceMessages(String annonceId, void Function() onNewMessage) {
    return supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'annonce_id',
            value: annonceId,
          ),
          callback: (payload) => onNewMessage(),
        )
        .subscribe();
  }

  subscribeToPrestataireMessages(String prestataireId, void Function() onNewMessage) {
    return supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'prestataire_id',
            value: prestataireId,
          ),
          callback: (payload) => onNewMessage(),
        )
        .subscribe();
  }

  Future<List<Map<String, dynamic>>> fetchUserConversations(String userId) async {
    if (userId.isEmpty) throw Exception("userId est vide");
    final response = await supabase
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('date_envoi', ascending: false);

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      throw Exception("Erreur récupération conversations");
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    if (messageId.isEmpty) throw Exception("messageId est vide");
    await supabase.from('messages').update({'lu': true}).eq('id', messageId);
  }
}
