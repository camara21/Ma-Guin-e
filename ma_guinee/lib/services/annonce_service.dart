import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/services/api_service.dart';

class AnnonceService {
  static const String table = 'annonces';

  /// 🔄 Récupérer toutes les annonces (les plus récentes d’abord)
  static Future<List<AnnonceModel>> getAllAnnonces() async {
    final response = await ApiService.client
        .from(table)
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => AnnonceModel.fromJson(e))
        .toList();
  }

  /// ➕ Ajouter une annonce
  static Future<void> addAnnonce(AnnonceModel annonce) async {
    await ApiService.insert(table, annonce.toJson());
  }

  /// 📝 Mettre à jour une annonce
  static Future<void> updateAnnonce(String id, AnnonceModel annonce) async {
    await ApiService.update(table, id, annonce.toJson());
  }

  /// 🗑 Supprimer une annonce
  static Future<void> deleteAnnonce(String id) async {
    await ApiService.delete(table, id);
  }

  /// 🔍 Annonces par catégorie
  static Future<List<AnnonceModel>> getByCategorie(String categorie) async {
    final response = await ApiService.client
        .from(table)
        .select()
        .eq('categorie', categorie)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => AnnonceModel.fromJson(e))
        .toList();
  }

  /// 👤 Annonces d’un utilisateur
  static Future<List<AnnonceModel>> getByUser(String userId) async {
    final response = await ApiService.client
        .from(table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => AnnonceModel.fromJson(e))
        .toList();
  }
}
