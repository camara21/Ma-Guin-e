// lib/services/live_service.dart
//
// Service LIVE (rooms + chat + compteurs) compatible TOUTES versions 2.x.
// -> Pas de paramètre "filter" : on filtre dans le callback.
// -> Évite tout conflit d'imports (un seul import supabase_flutter).

import 'package:supabase_flutter/supabase_flutter.dart';

class LiveService {
  final _sb = Supabase.instance.client;

  // -------- LECTURE --------
  Future<List<Map<String, dynamic>>> fetchLiveRooms({int limit = 50}) async {
    final rows = await _sb
        .from('live_rooms')
        .select(
          'id, host_id, title, thumbnail_url, started_at, ended_at, '
          'is_live, viewers_count, likes_count',
        )
        .order('is_live', ascending: false)
        .order('started_at', ascending: false)
        .limit(limit);
    return _castList(rows);
  }

  Future<List<Map<String, dynamic>>> listMessages(String roomId, {int limit = 100}) async {
    final rows = await _sb
        .from('live_messages')
        .select('id, room_id, sender_id, message, created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = _castList(rows);
    list.sort((a, b) =>
        DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
    return list;
  }

  // -------- ACTIONS (RPC) --------
  Future<String> startLive({String? title, String? thumbnailUrl}) async {
    final res = await _sb.rpc('live_start', params: {
      'p_title': title,
      'p_thumbnail_url': thumbnailUrl,
    });
    return res as String;
  }

  Future<void> endLive(String roomId) async {
    await _sb.rpc('live_end', params: {'p_room_id': roomId});
  }

  Future<void> join(String roomId) async {
    await _sb.rpc('live_join', params: {'p_room_id': roomId});
  }

  Future<void> leave(String roomId) async {
    await _sb.rpc('live_leave', params: {'p_room_id': roomId});
  }

  Future<String> sendMessage(String roomId, String message) async {
    final id = await _sb.rpc('live_send_message', params: {
      'p_room_id': roomId,
      'p_message': message,
    });
    return id as String;
  }

  Future<int> like(String roomId) async {
    final count = await _sb.rpc('live_like', params: {'p_room_id': roomId});
    return count as int;
  }

  // -------- REALTIME (sans "filter") --------

  /// Abonnement aux INSERT de live_messages ; filtrage manuel par room_id.
  RealtimeChannel subscribeMessages(
    String roomId,
    void Function(Map<String, dynamic> row) onInsert,
  ) {
    final ch = _sb.channel('live_messages:$roomId');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'live_messages',
      callback: (payload) {
        final row = Map<String, dynamic>.from(payload.newRecord);
        if (row['room_id'] == roomId) {
          onInsert(row);
        }
      },
    ).subscribe();

    return ch;
  }

  /// Abonnement aux UPDATE de live_rooms ; filtrage manuel par id.
  RealtimeChannel subscribeRoomMeta(
    String roomId,
    void Function(Map<String, dynamic> row) onUpdate,
  ) {
    final ch = _sb.channel('live_rooms:$roomId');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'live_rooms',
      callback: (payload) {
        final row = Map<String, dynamic>.from(payload.newRecord);
        if (row['id'] == roomId) {
          onUpdate(row);
        }
      },
    ).subscribe();

    return ch;
  }

  void unsubscribe(RealtimeChannel ch) => _sb.removeChannel(ch);

  // -------- UTILS --------
  List<Map<String, dynamic>> _castList(dynamic rows) {
    return (rows as List)
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
