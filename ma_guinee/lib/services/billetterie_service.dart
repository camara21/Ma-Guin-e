import 'package:supabase_flutter/supabase_flutter.dart';

class BilletterieService {
  final _sb = Supabase.instance.client;

  Future<Map<String, dynamic>?> getEvenement(String eventId) async {
    final List<Map<String, dynamic>> rows = await _sb
        .from('evenements')
        .select()
        .eq('id', eventId)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> listBilletsByEvent(String eventId) async {
    final List<Map<String, dynamic>> rows = await _sb
        .from('billets')
        .select()
        .eq('evenement_id', eventId)
        .eq('actif', true)
        .order('ordre');
    return rows;
  }

  Future<String> reserverBillet({
    required String billetId,
    required int quantite,
  }) async {
    final res = await _sb.rpc('book_ticket', params: {
      'p_billet_id': billetId,
      'p_quantite': quantite,
    });
    return res as String; // reservation_id
  }

  Future<List<Map<String, dynamic>>> listMesReservations() async {
    final List<Map<String, dynamic>> rows = await _sb
        .from('reservations_billets')
        .select(
          // relations via clés étrangères (billet_id, evenement_id)
          'id, billet_id, evenement_id, quantite, total_gnf, statut, qr_token, created_at, '
          'billets(titre, prix_gnf), '
          'evenements(titre, date_debut, ville, lieu)',
        )
        .order('created_at', ascending: false);
    return rows;
  }

  String? publicImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _sb.storage.from('evenement-photos').getPublicUrl(path);
  }
}
