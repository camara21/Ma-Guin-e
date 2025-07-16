import 'package:flutter/material.dart';
import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/services/annonce_service.dart';

class AnnonceProvider extends ChangeNotifier {
  List<AnnonceModel> _annonces = [];
  bool _isLoading = false;

  List<AnnonceModel> get annonces => _annonces;
  bool get isLoading => _isLoading;

  /// 🔄 Charger toutes les annonces
  Future<void> loadAnnonces() async {
    _isLoading = true;
    notifyListeners();

    try {
      _annonces = await AnnonceService.getAllAnnonces();
    } catch (e) {
      debugPrint("Erreur chargement annonces: $e");
      _annonces = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// ➕ Ajouter une annonce localement + côté serveur
  Future<void> addAnnonce(AnnonceModel annonce) async {
    try {
      await AnnonceService.addAnnonce(annonce);
      _annonces.insert(0, annonce); // on ajoute en haut
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur ajout annonce: $e");
    }
  }

  /// 🗑 Supprimer une annonce localement + côté serveur
  Future<void> deleteAnnonce(String id) async {
    try {
      await AnnonceService.deleteAnnonce(id);
      _annonces.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Erreur suppression annonce: $e");
    }
  }

  /// 🔍 Filtrer par catégorie (ex: Vente, Emploi…)
  List<AnnonceModel> filterByCategorie(String categorie) {
    if (categorie == 'Tous') return _annonces;
    return _annonces.where((a) => a.categorie == categorie).toList();
  }

  /// 🔍 Annonces par utilisateur
  List<AnnonceModel> annoncesByUser(String userId) {
    return _annonces.where((a) => a.userId == userId).toList();
  }
}
