import 'package:supabase_flutter/supabase_flutter.dart';

class EventsService {
  final SupabaseClient _sb = Supabase.instance.client;

  /// Vérifie qu’un utilisateur est connecté et renvoie son ID
  String _requireUserId() {
    final user = _sb.auth.currentUser;
    if (user == null) {
      throw StateError('Utilisateur non connecté.');
    }
    return user.id;
  }

  /// Récupère la liste des évènements (option : seulement ceux publiés)
  Future<List<Map<String, dynamic>>> fetchEvents({
    bool onlyPublished = true,
  }) async {
    var query = _sb.from('events').select('*');

    // Filtrer uniquement les événements publiés si demandé
    if (onlyPublished) {
      query = query.eq('status', 'published');
    }

    // Trier par date de début
    final dynamic resp = await query.order('start_at', ascending: true);

    final List data = (resp as List);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Récupère les catégories de tickets d’un événement
  Future<List<Map<String, dynamic>>> fetchTicketTypes(String eventId) async {
    final dynamic resp =
        await _sb.from('ticket_types').select('*').eq('event_id', eventId);

    final List data = (resp as List);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Crée une commande + ses lignes + génère les tickets
  /// (Ici, paiement simulé avec status=paid)
  Future<Map<String, dynamic>> createOrder({
    required String eventId,
    required List<Map<String, dynamic>>
        items, // {ticket_type_id, quantity, unit_cents}
    String devise = 'EUR',
  }) async {
    final uid = _requireUserId();

    // Calcul du montant total
    final int totalCents = items.fold<int>(
      0,
      (sum, e) => sum + ((e['quantity'] as int) * (e['unit_cents'] as int)),
    );

    // 1) Création de la commande
    final dynamic ordersResp = await _sb
        .from('orders')
        .insert({
          'buyer_id': uid,
          'total_cents': totalCents,
          'devise': devise,
          'status': 'paid', // mock
          'payment_provider': 'mock',
        })
        .select()
        .limit(1);

    final List orders = (ordersResp as List);
    if (orders.isEmpty) {
      throw StateError('Échec de création de la commande.');
    }

    final Map<String, dynamic> order =
        Map<String, dynamic>.from(orders.first as Map);
    final String orderId = order['id'] as String;

    // 2) Création des lignes de commande
    for (final item in items) {
      await _sb.from('order_items').insert({
        'order_id': orderId,
        'ticket_type_id': item['ticket_type_id'],
        'quantity': item['quantity'],
        'unit_cents': item['unit_cents'],
      });
    }

    // 3) Génération des tickets via la fonction RPC
    await _sb.rpc('issue_tickets_from_order', params: {'p_order_id': orderId});

    return order;
  }

  /// Récupère les tickets de l’utilisateur connecté
  Future<List<Map<String, dynamic>>> fetchMyTickets() async {
    final uid = _requireUserId();
    final dynamic resp = await _sb
        .from('tickets')
        .select('*, events(titre, start_at, lieu), ticket_types(nom)')
        .eq('buyer_id', uid)
        .order('issued_at', ascending: false);

    final List data = (resp as List);
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Scanne un ticket depuis un QR Code (via RPC use_ticket)
  Future<Map<String, dynamic>> scanTicket(String qrCode) async {
    final dynamic resp = await _sb.rpc('use_ticket', params: {'qr': qrCode});

    if (resp == null) {
      return {'ok': false, 'reason': 'NO_RESPONSE'};
    }

    if (resp is Map) {
      return Map<String, dynamic>.from(resp as Map);
    }

    return {
      'ok': false,
      'reason': 'UNEXPECTED_RESPONSE',
      'data': resp.toString(),
    };
  }
}
