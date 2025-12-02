// lib/services/message_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageService {
  final _client = Supabase.instance.client;

  // Notifications internes optionnelles
  final StreamController<void> unreadChanged =
      StreamController<void>.broadcast();
  final ValueNotifier<int> optimisticUnreadDelta = ValueNotifier<int>(0);

  // ---------------- Helpers ----------------
  DateTime _asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isDeletedForMe(Map<String, dynamic> m, String myId) {
    final isSender = (m['sender_id']?.toString() == myId);
    return isSender
        ? (m['deleted_for_sender_at'] != null)
        : (m['deleted_for_receiver_at'] != null);
  }

  // ---------------- Conversations ----------------
  Future<List<Map<String, dynamic>>> fetchUserConversations(
      String userId) async {
    // A) tous les messages où je suis sender OU receiver
    final rawParticipant = await _client
            .from('messages')
            .select('''
              id,sender_id,receiver_id,contenu,contexte,
              annonce_id,annonce_titre,prestataire_id,prestataire_name,
              lu,date_envoi,deleted_for_sender_at,deleted_for_receiver_at
            ''')
            .or('sender_id.eq.$userId,receiver_id.eq.$userId')
            .order('date_envoi', ascending: false) ??
        [];

    // B) je suis propriétaire d’un prestataire (utilisateur_id OU owner_user_id)
    final ownersA = await _client
        .from('prestataires')
        .select('id')
        .eq('utilisateur_id', userId)
        .catchError((_) => []);
    final ownersB = await _client
        .from('prestataires')
        .select('id')
        .eq('owner_user_id', userId)
        .catchError((_) => []);

    final myPrestaIds = <String>{
      for (final p in (ownersA as List? ?? const [])) p['id']?.toString() ?? '',
      for (final p in (ownersB as List? ?? const [])) p['id']?.toString() ?? '',
    }.where((e) => e.isNotEmpty).toList();

    // C) Messages prestataire attachés à MES prestataires
    var rawPrestaOwner = <dynamic>[];
    if (myPrestaIds.isNotEmpty) {
      rawPrestaOwner = await _client
              .from('messages')
              .select('''
                id,sender_id,receiver_id,contenu,contexte,
                annonce_id,annonce_titre,prestataire_id,prestataire_name,
                lu,date_envoi,deleted_for_sender_at,deleted_for_receiver_at
              ''')
              .eq('contexte', 'prestataire')
              .inFilter('prestataire_id', myPrestaIds)
              .order('date_envoi', ascending: false) ??
          [];
    }

    // D) Fusion + dédoublonnage + tri
    final byId = <String, Map<String, dynamic>>{};
    for (final e in [...rawParticipant, ...rawPrestaOwner]) {
      final m = Map<String, dynamic>.from(e as Map);
      byId[m['id'].toString()] = m;
    }

    final list = byId.values.toList()
      ..sort((a, b) =>
          _asDate(b['date_envoi']).compareTo(_asDate(a['date_envoi'])));

    return list;
  }

  // ---------------- Threads ----------------
  static const _colsThread = '''
    id,sender_id,receiver_id,contenu,lu,date_envoi,
    deleted_for_sender_at,deleted_for_receiver_at
  ''';

  Future<List<Map<String, dynamic>>> fetchMessagesForAnnonce(
      String annonceId) async {
    final raw = await _client
        .from('messages')
        .select(_colsThread)
        .eq('contexte', 'annonce')
        .eq('annonce_id', annonceId)
        .order('date_envoi', ascending: true);
    return (raw as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForLogement(
      String logementId) async {
    // logement == annonce_id
    final raw = await _client
        .from('messages')
        .select(_colsThread)
        .eq('contexte', 'logement')
        .eq('annonce_id', logementId)
        .order('date_envoi', ascending: true);
    return (raw as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForPrestataire(
      String prestataireId) async {
    final raw = await _client
        .from('messages')
        .select(_colsThread)
        .eq('contexte', 'prestataire')
        .eq('prestataire_id', prestataireId)
        .order('date_envoi', ascending: true);
    return (raw as List? ?? const []).cast<Map<String, dynamic>>();
  }

  // Filtrage des messages masqués
  Future<List<Map<String, dynamic>>> fetchMessagesForAnnonceVisibleTo({
    required String viewerUserId,
    required String annonceId,
  }) async {
    final all = await fetchMessagesForAnnonce(annonceId);
    return all.where((m) => !_isDeletedForMe(m, viewerUserId)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForLogementVisibleTo({
    required String viewerUserId,
    required String logementId,
  }) async {
    final all = await fetchMessagesForLogement(logementId);
    return all.where((m) => !_isDeletedForMe(m, viewerUserId)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMessagesForPrestataireVisibleTo({
    required String viewerUserId,
    required String prestataireId,
  }) async {
    final all = await fetchMessagesForPrestataire(prestataireId);
    return all.where((m) => !_isDeletedForMe(m, viewerUserId)).toList();
  }

  // ---------------- Envoi ----------------
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

    // 🔔 Push FCM vers le destinataire (non bloquant)
    try {
      await _client.functions.invoke('push-send', body: {
        'title': 'Nouveau message',
        'body': contenu.isEmpty ? 'Vous avez reçu un nouveau message' : contenu,
        'user_id': receiverId,
        'data': {
          'type': 'message',
          'contexte': 'annonce',
          'sender_id': senderId,
          'receiver_id': receiverId,
          'annonce_id': annonceId,
          'logement_id': '',
          'prestataire_id': '',
          'annonce_titre': annonceTitre,
          'prestataire_name': '',
          'title': annonceTitre,
        },
      });
    } catch (_) {}
  }

  Future<void> sendMessageToLogement({
    required String senderId,
    required String receiverId,
    required String logementId,
    required String logementTitre,
    required String contenu,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'contexte': 'logement',
      'annonce_id': logementId,
      'annonce_titre': logementTitre,
      'contenu': contenu,
      'date_envoi': DateTime.now().toIso8601String(),
      'lu': false,
    });
    unreadChanged.add(null);

    // 🔔 Push FCM vers le destinataire (non bloquant)
    try {
      await _client.functions.invoke('push-send', body: {
        'title': 'Nouveau message',
        'body': contenu.isEmpty ? 'Vous avez reçu un nouveau message' : contenu,
        'user_id': receiverId,
        'data': {
          'type': 'message',
          'contexte': 'logement',
          'sender_id': senderId,
          'receiver_id': receiverId,
          'annonce_id': logementId,
          'logement_id': logementId,
          'prestataire_id': '',
          'annonce_titre': logementTitre,
          'prestataire_name': '',
          'logement_titre': logementTitre,
          'title': logementTitre,
        },
      });
    } catch (_) {}
  }

  Future<void> sendMessageToPrestataire({
    required String senderId,
    required String receiverId,
    required String prestataireId,
    required String prestataireName,
    required String contenu,
  }) async {
    var resolvedReceiver = receiverId;

    if (resolvedReceiver.isEmpty) {
      final r1 = await _client
          .from('prestataires')
          .select('utilisateur_id')
          .eq('id', prestataireId)
          .maybeSingle()
          .catchError((_) => null);

      final r2 = await _client
          .from('prestataires')
          .select('owner_user_id')
          .eq('id', prestataireId)
          .maybeSingle()
          .catchError((_) => null);

      resolvedReceiver = (r1?['utilisateur_id']?.toString() ??
          r2?['owner_user_id']?.toString() ??
          '');

      if (resolvedReceiver.isEmpty) {
        throw Exception(
            "Le prestataire $prestataireId n'a pas de propriétaire.");
      }
    }

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

    // 🔔 Push FCM vers le propriétaire du prestataire (non bloquant)
    try {
      await _client.functions.invoke('push-send', body: {
        'title': 'Nouveau message',
        'body': contenu.isEmpty ? 'Vous avez reçu un nouveau message' : contenu,
        'user_id': resolvedReceiver,
        'data': {
          'type': 'message',
          'contexte': 'prestataire',
          'sender_id': senderId,
          'receiver_id': resolvedReceiver,
          'annonce_id': '',
          'logement_id': '',
          'prestataire_id': prestataireId,
          'annonce_titre': '',
          'prestataire_name': prestataireName,
          'title': prestataireName,
        },
      });
    } catch (_) {}
  }

  // ---------------- Lecture ----------------
  Future<void> markThreadAsReadInstant({
    required String viewerUserId,
    required String contexte,
    String? annonceOrLogementId,
    String? prestataireId,
    required String otherUserId,
  }) async {
    try {
      final isAnnOrLog = (contexte == 'annonce' || contexte == 'logement');

      final builder = _client.from('messages').update({'lu': true})
        ..eq('contexte', contexte)
        ..eq('receiver_id', viewerUserId)
        ..eq('sender_id', otherUserId)
        ..eq('lu', false);

      if (isAnnOrLog) {
        builder.eq('annonce_id', annonceOrLogementId ?? '');
      } else {
        builder.eq('prestataire_id', prestataireId ?? '');
      }

      await builder;
    } catch (_) {
    } finally {
      unreadChanged.add(null);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('messages')
          .update({'lu': true})
          .eq('receiver_id', userId)
          .eq('lu', false);

      // notifications
      try {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('utilisateur_id', userId)
            .eq('type', 'message')
            .eq('is_read', false);
      } catch (_) {
        await _client
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('type', 'message')
            .eq('is_read', false);
      }
    } catch (_) {
    } finally {
      unreadChanged.add(null);
    }
  }

  // ---------------- Suppression pour moi ----------------
  Future<void> deleteMessageForMe({
    required String messageId,
    required String currentUserId,
  }) async {
    final row = await _client
        .from('messages')
        .select(
            'sender_id,receiver_id,deleted_for_sender_at,deleted_for_receiver_at,hard_delete_at')
        .eq('id', messageId)
        .maybeSingle();

    if (row == null) return;

    final senderId = row['sender_id'].toString();
    final receiverId = row['receiver_id'].toString();
    final now = DateTime.now().toUtc();
    final in30d = now.add(const Duration(days: 30));

    final isSender = currentUserId == senderId;
    final isReceiver = currentUserId == receiverId;
    if (!isSender && !isReceiver) return;

    DateTime hardDeleteAt = in30d;
    final existing = row['hard_delete_at']?.toString() ?? '';
    if (existing.isNotEmpty) {
      final d = DateTime.tryParse(existing);
      if (d != null && d.isBefore(in30d)) {
        hardDeleteAt = d.toUtc();
      }
    }

    final patch = <String, dynamic>{
      'hard_delete_at': hardDeleteAt.toIso8601String(),
      if (isSender) 'deleted_for_sender_at': now.toIso8601String(),
      if (isReceiver) 'deleted_for_receiver_at': now.toIso8601String(),
    };

    await _client.from('messages').update(patch).eq('id', messageId);
    unreadChanged.add(null);
  }

  // ---------------- Masquage d’un fil ----------------
  Future<void> hideThread({
    required String userId,
    required String contexte,
    String? annonceId,
    String? prestataireId,
    required String peerUserId,
  }) async {
    final ctxId = (contexte == 'prestataire') ? prestataireId : annonceId;

    await _client.from('conversation_hidden').upsert(
      {
        'user_id': userId,
        'contexte': contexte,
        'context_id': ctxId ?? '',
        'peer_id': peerUserId,
      },
      onConflict: 'user_id,contexte,context_id,peer_id',
    );
  }

  Future<Set<String>> fetchHiddenThreadKeys(String userId) async {
    try {
      final rows = await _client
          .from('conversation_hidden')
          .select('contexte,context_id,peer_id')
          .eq('user_id', userId);

      final keys = <String>{};
      for (final r in (rows as List? ?? const [])) {
        final ctx = r['contexte'].toString();
        final ctxId = r['context_id'].toString();
        final peer = r['peer_id'].toString();
        keys.add('$ctx-$ctxId-$peer');
      }
      return keys;
    } catch (_) {
      return <String>{};
    }
  }

  // ---------------- Realtime utilitaire ----------------
  StreamSubscription<List<Map<String, dynamic>>> subscribeAll(
      VoidCallback onUpdate) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('date_envoi')
        .listen((_) {
          try {
            onUpdate();
          } catch (_) {}
        });
  }

  // ---------------- Compteurs ----------------
  Future<int> getUnreadMessagesCount(String userId) async {
    final res =
        await _client.from('messages').select('lu').eq('receiver_id', userId);
    final list = (res as List?) ?? const [];
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

  void decUnreadOptimistic([int n = 1]) {
    final v = optimisticUnreadDelta.value + n;
    optimisticUnreadDelta.value = v < 0 ? 0 : v;
  }

  void clearOptimisticDelta() => optimisticUnreadDelta.value = 0;

  Future<void> disposeService() async {
    unreadChanged.close();
  }
}
