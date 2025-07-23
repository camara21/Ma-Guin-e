import 'package:flutter/foundation.dart'; // pour debugPrint
import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/services/api_service.dart';

class AnnonceService {
  static const String table = 'annonces';

  /// 🔄 Récupérer toutes les annonces (les plus récentes d’abord)
  static Future<List<AnnonceModel>> getAllAnnonces() async {
    try {
      final response = await ApiService.client
          .from(table)
          .select()
          .order('created_at', ascending: false);

      if (response == null) return [];

      return List<Map<String, dynamic>>.from(response)
          .map((e) => AnnonceModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("Erreur getAllAnnonces: $e");
      return [];
    }
  }

  /// ➕ Ajouter une annonce
  static Future<void> addAnnonce(AnnonceModel annonce) async {
    try {
      await ApiService.insert(table, annonce.toJson());
    } catch (e) {
      debugPrint("Erreur addAnnonce: $e");
      rethrow; // Remonter l'erreur pour gestion éventuelle
    }
  }

  /// 📝 Mettre à jour une annonce
  static Future<void> updateAnnonce(String id, AnnonceModel annonce) async {
    try {
      await ApiService.update(table, id, annonce.toJson());
    } catch (e) {
      debugPrint("Erreur updateAnnonce: $e");
      rethrow;
    }
  }

  /// 🗑 Supprimer une annonce
  static Future<void> deleteAnnonce(String id) async {
    try {
      await ApiService.delete(table, id);
    } catch (e) {
      debugPrint("Erreur deleteAnnonce: $e");
      rethrow;
    }
  }

  /// 🔍 Annonces par catégorie
  static Future<List<AnnonceModel>> getByCategorie(String categorie) async {
    try {
      final response = await ApiService.client
          .from(table)
          .select()
          .eq('categorie', categorie)
          .order('created_at', ascending: false);

      if (response == null) return [];

      return List<Map<String, dynamic>>.from(response)
          .map((e) => AnnonceModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("Erreur getByCategorie: $e");
      return [];
    }
  }

  /// 👤 Annonces d’un utilisateur
  static Future<List<AnnonceModel>> getByUser(String userId) async {
    try {
      final response = await ApiService.client
          .from(table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response == null) return [];

      return List<Map<String, dynamic>>.from(response)
          .map((e) => AnnonceModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint("Erreur getByUser: $e");
      return [];
    }
  }
}
