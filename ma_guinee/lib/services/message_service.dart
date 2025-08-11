import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final _client = Supabase.instance.client;

  /// 🔔 Fallback local pour prévenir l'UI
  final StreamController<void> unreadChanged =
      StreamController<void>.broadcast();

  /// ---------------------------------
  /// Conversations de l’utilisateur
  /// ---------------------------------
  Future<List<Map<String, dynamic>>> fetchUserConversations(String userId) async {
    // Conversations où je suis sender OU receiver
    final rawA = await _client
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
        .order('date_envoi', ascending: false) ?? [];

    // Conversations prestataire liées à mes prestataires
    final myPrestas = await _client
        .from('prestataires')
        .select('id')
        .eq('owner_user_id', userId);

    List<String> myPrestaIds = [];
    for (final p in (myPrestas as List? ?? [])) {
      final id = p['id']?.toString();
      if (id != null && id.isNotEmpty) myPrestaIds.add(id);
    }

    List rawB = [];
    if (myPrestaIds.isNotEmpty) {
      rawB = await _client
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
          .eq('contexte', 'prestataire')
          .inFilter('prestataire_id', myPrestaIds)
          .order('date_envoi', ascending: false) ?? [];
    }

    // Fusion + dédoublonnage
    final Map<String, Map<String, dynamic>> map = {};
    for (final e in [...rawA, ...rawB]) {
      final m = Map<String, dynamic>.from(e as Map);
      map[m['id'].toString()] = m;
    }
    final list = map.values.toList()
      ..sort((a, b) =>
          DateTime.tryParse('${b['date_envoi']}')!
              .compareTo(DateTime.tryParse('${a['date_envoi']}')!));

    return list;
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
    unreadChanged.add(null);
  }

  /// ---------------------------------
  /// Envoi message prestataire (sécurisé)
  /// ---------------------------------
  Future<void> sendMessageToPrestataire({
    required String senderId,
    required String receiverId, // ignoré si résolu
    required String prestataireId,
    required String prestataireName,
    required String contenu,
  }) async {
    // Résolution stricte du vrai destinataire
    final p = await _client
        .from('prestataires')
        .select('owner_user_id')
        .eq('id', prestataireId)
        .maybeSingle();

    if (p == null || (p['owner_user_id'] ?? '').toString().isEmpty) {
      throw Exception("Le prestataire $prestataireId n'a pas d'owner_user_id défini.");
    }
    final resolvedReceiver = (p['owner_user_id'] as String);

    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': resolvedReceiver,
      'contexte': 'prestataire',
      'prestataire_id': prestataireId,
      'prestataire_name': prestataireName,
      'contenu': contenu,
      'date_envoi': DateTime.now().toIso8601String(),
      'lu': false,
    });

    unreadChanged.add(null);
  }

  /// ---------------------------------
  /// Marquer 1 ou plusieurs messages comme lus
  /// ---------------------------------
  Future<void> markMessageAsRead(String messageId) async {
    await _client.from('messages').update({'lu': true}).eq('id', messageId);
    unreadChanged.add(null);
  }

  Future<void> markMessagesAsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('messages').update({'lu': true}).inFilter('id', ids);
    unreadChanged.add(null);
  }

  /// ---------------------------------
  /// Écouter tous les changements (pour rafraîchir une page)
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

  // ---------------------------------------------------------------------------
  // 📌 COMPTEUR NON-LUS – APPROCHE "messages"
  // ---------------------------------------------------------------------------
  Future<int> getUnreadMessagesCount(String userId) async {
    final result = await _client
        .from('messages')
        .select('lu')
        .eq('receiver_id', userId);

    final list = (result as List?) ?? const [];
    return list.where((r) => r['lu'] != true).length;
  }

  Stream<int> unreadCountStream(String userId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((rows) => rows.where((r) => r['lu'] != true).length)
        .distinct();
  }

  // ---------------------------------------------------------------------------
  // ✅ COMPTEUR NON-LUS – APPROCHE "notifications"
  // ---------------------------------------------------------------------------
  Future<int> getUnreadMessageNotifs(String userId) async {
    final res = await _client
        .from('notifications')
        .select('is_read, type')
        .eq('user_id', userId);

    final list = (res as List?) ?? const [];
    return list.where((n) =>
        (n['type']?.toString() == 'message') && (n['is_read'] != true)).length;
  }

  Stream<int> unreadMessageNotifsStream(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows
            .where((n) =>
                (n['type']?.toString() == 'message') &&
                (n['is_read'] != true))
            .length)
        .distinct();
  }

  Stream<int> badgeStream(String userId, {bool useNotifications = true}) {
    return useNotifications
        ? unreadMessageNotifsStream(userId)
        : unreadCountStream(userId);
  }

  Future<void> disposeService() async {
    await unreadChanged.close();
  }
}
