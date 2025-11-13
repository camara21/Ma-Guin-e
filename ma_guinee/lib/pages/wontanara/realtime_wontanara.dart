// lib/pages/wontanara/realtime_wontanara.dart

import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _sb = Supabase.instance.client;

/// Abos Realtime pratiques
class RealtimeWontanara {
  /// Nouvelles publications dans une zone
  static RealtimeChannel abonnPubZone(
    String zoneId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    final ch = _sb.channel('wnt_pub_$zoneId');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'wontanara_publications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'zone_id',
        value: zoneId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record != null) {
          onInsert(record as Map<String, dynamic>);
        }
      },
    );

    ch.subscribe();
    return ch;
  }

  /// 💬 Nouveaux messages dans le **chat de la zone** (salon de quartier)
  ///
  /// - Assure qu'une room `kind = 'zone'` existe pour `zoneId`
  /// - Souscrit ensuite sur les messages de cette room.
  static Future<RealtimeChannel> abonnMessagesZone(
    String zoneId,
    void Function(Map<String, dynamic>) onInsert,
  ) async {
    // Assure la room
    final room = await _sb
        .from('wontanara_chat_rooms')
        .select('id')
        .eq('zone_id', zoneId)
        .eq('kind', 'zone')
        .maybeSingle();

    late final String roomId;

    if (room == null) {
      final inserted = await _sb
          .from('wontanara_chat_rooms')
          .insert({'zone_id': zoneId, 'kind': 'zone'})
          .select('id')
          .single();

      roomId = inserted['id'].toString();
    } else {
      roomId = room['id'].toString();
    }

    final ch = _sb.channel('wnt_chat_$roomId');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'wontanara_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record != null) {
          onInsert(record as Map<String, dynamic>);
        }
      },
    );

    ch.subscribe();
    return ch;
  }

  /// 💬 Nouveaux messages dans une **room spécifique** (chat éphémère, privé, etc.)
  ///
  /// Ici on suppose que la room existe déjà dans `wontanara_chat_rooms`
  /// (créée par ton API / RPC). On ne fait que s'abonner aux messages.
  static RealtimeChannel abonnMessagesRoom(
    String roomId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    final ch = _sb.channel('wnt_chat_$roomId');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'wontanara_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record != null) {
          onInsert(record as Map<String, dynamic>);
        }
      },
    );

    ch.subscribe();
    return ch;
  }
}
