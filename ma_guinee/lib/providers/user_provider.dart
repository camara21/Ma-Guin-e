import 'package:flutter/material.dart';
import '../models/utilisateur_model.dart';

class UserProvider extends ChangeNotifier {
  UtilisateurModel? _utilisateur;

  UtilisateurModel? get utilisateur => _utilisateur;

  bool get estConnecte => _utilisateur != null;

  /// ✅ Initialisation après login
  void setUtilisateur(UtilisateurModel user) {
    _utilisateur = user;
    notifyListeners();
  }

  /// 🔄 Modifier partiellement (ex: modifier nom uniquement)
  void updateUtilisateur(UtilisateurModel user) {
    _utilisateur = user;
    notifyListeners();
  }

  /// 🔓 Déconnexion
  void clearUtilisateur() {
    _utilisateur = null;
    notifyListeners();
  }
}
