import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/utilisateur_model.dart';
import '../models/annonce_model.dart';

class UserProvider extends ChangeNotifier {
  UtilisateurModel? _utilisateur;
  List<AnnonceModel> _annonces = [];

  bool _isLoadingAnnonces = false;
  bool _isLoadingUser = false;

  UtilisateurModel? get utilisateur => _utilisateur;
  bool get estConnecte => _utilisateur != null;

  List<AnnonceModel> get annonces => _annonces;
  bool get isLoadingAnnonces => _isLoadingAnnonces;
  bool get isLoadingUser => _isLoadingUser;

  /// Annonces de l'utilisateur connecté
  List<AnnonceModel> get annoncesUtilisateur {
    if (_utilisateur == null) return [];
    final uid = _utilisateur!.id.toLowerCase();
    return _annonces.where((a) => a.userId.toLowerCase() == uid).toList();
  }

  /// Charge l'utilisateur connecté puis ses annonces
  Future<void> chargerUtilisateurConnecte() async {
    _isLoadingUser = true;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      final authUser = supabase.auth.currentUser;

      if (authUser == null) {
        clearUtilisateur();
        return;
      }

      final profil = await supabase
          .from('utilisateurs')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (profil != null) {
        _utilisateur = UtilisateurModel.fromJson(profil as Map<String, dynamic>);
        await loadAnnoncesUtilisateur(_utilisateur!.id);
      } else {
        clearUtilisateur();
      }
    } catch (e, st) {
      debugPrint("chargerUtilisateurConnecte error: $e\n$st");
      clearUtilisateur();
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  /// Charge les annonces d'un utilisateur
  Future<void> loadAnnoncesUtilisateur(String userId) async {
    _isLoadingAnnonces = true;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('annonces')
          .select()
          .eq('user_id', userId)
          .order('date_creation', ascending: false); // ton champ est 'date_creation'

      _annonces = (response as List<dynamic>)
          .map((e) => AnnonceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint("loadAnnoncesUtilisateur error: $e\n$st");
      _annonces = [];
    } finally {
      _isLoadingAnnonces = false;
      notifyListeners();
    }
  }

  Future<void> supprimerAnnonce(String annonceId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('annonces').delete().eq('id', annonceId);
      _annonces.removeWhere((a) => a.id == annonceId);
      notifyListeners();
    } catch (e, st) {
      debugPrint("supprimerAnnonce error: $e\n$st");
      rethrow;
    }
  }

  void setUtilisateur(UtilisateurModel user) {
    _utilisateur = user;
    notifyListeners();
  }

  void clearUtilisateur() {
    _utilisateur = null;
    _annonces = [];
    _isLoadingAnnonces = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    clearUtilisateur();
  }
}
