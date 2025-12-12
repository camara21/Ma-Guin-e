import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Récupérer la référence Supabase
  static SupabaseClient get client => _client;

  /// Utilitaires d'authentification
  static bool get isLoggedIn => _client.auth.currentUser != null;

  static String? get currentUserId => _client.auth.currentUser?.id;

  /// Exemple : récupérer un tableau générique
  static Future<List<Map<String, dynamic>>> fetchTable(String table) async {
    final response = await _client.from(table).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Exemple : insérer un enregistrement
  static Future<void> insert(String table, Map<String, dynamic> data) async {
    await _client.from(table).insert(data);
  }

  /// Exemple : mettre à jour un enregistrement
  static Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from(table).update(data).eq('id', id);
  }

  /// Supprimer un élément
  static Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }
}
