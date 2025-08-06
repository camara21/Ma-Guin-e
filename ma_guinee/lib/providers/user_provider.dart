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

  List<AnnonceModel> get annoncesUtilisateur {
    if (_utilisateur == null) return [];
    final uid = _utilisateur!.id.toLowerCase();
    return _annonces.where((a) => a.userId.toLowerCase() == uid).toList();
  }

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

      if (profil == null) {
        clearUtilisateur();
        return;
      }

      final data = Map<String, dynamic>.from(profil);

      // 🔄 Ajout des espaces liés
      data['espacePrestataire'] = await _getEspace(
        table: 'prestataires',
        fkColumn: 'utilisateur_id',
        userId: authUser.id,
      );

      data['restos'] = await _getEspaces(
        table: 'restaurants',
        fkColumn: 'user_id',
        userId: authUser.id,
      );

      data['hotels'] = await _getEspaces(
        table: 'hotels',
        fkColumn: 'user_id',
        userId: authUser.id,
      );

      data['cliniques'] = await _getEspaces(
        table: 'cliniques',
        fkColumn: 'user_id',
        userId: authUser.id,
      );

      // 🔵 Ajout des lieux
      data['lieux'] = await _getEspaces(
        table: 'lieux',
        fkColumn: 'user_id',
        userId: authUser.id,
      );

      // ✅ Création du modèle utilisateur avec CGU et lieux
      _utilisateur = UtilisateurModel.fromJson(data);

      debugPrint("💡 Restos : ${_utilisateur?.restos}");
      debugPrint("🏨 Hotels : ${_utilisateur?.hotels}");
      debugPrint("🏥 Cliniques : ${_utilisateur?.cliniques}");
      debugPrint("📍 Lieux : ${_utilisateur?.lieux}");

      await loadAnnoncesUtilisateur(_utilisateur!.id);
    } catch (e, st) {
      debugPrint("chargerUtilisateurConnecte error: $e\n$st");
      clearUtilisateur();
    } finally {
      _isLoadingUser = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> _getEspace({
    required String table,
    required String fkColumn,
    required String userId,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from(table)
          .select()
          .eq(fkColumn, userId)
          .maybeSingle();
      return res == null ? null : Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint("_getEspace($table) error: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getEspaces({
    required String table,
    required String fkColumn,
    required String userId,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from(table)
          .select()
          .eq(fkColumn, userId);

      return (res as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint("_getEspaces($table) error: $e");
      return [];
    }
  }

  Future<void> loadAnnoncesUtilisateur(String userId) async {
    _isLoadingAnnonces = true;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('annonces')
          .select()
          .eq('user_id', userId)
          .order('date_creation', ascending: false);
      _annonces = (response as List)
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

  Future<void> supprimerRestaurant(String restoId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('restaurants').delete().eq('id', restoId);
      _utilisateur?.restos.removeWhere((r) => r['id'] == restoId);
      notifyListeners();
    } catch (e, st) {
      debugPrint("supprimerRestaurant error: $e\n$st");
      rethrow;
    }
  }

  Future<void> supprimerHotel(String hotelId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('hotels').delete().eq('id', hotelId);
      _utilisateur?.hotels.removeWhere((h) => h['id'] == hotelId);
      notifyListeners();
    } catch (e, st) {
      debugPrint("supprimerHotel error: $e\n$st");
      rethrow;
    }
  }

  Future<void> supprimerClinique(String cliniqueId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('cliniques').delete().eq('id', cliniqueId);
      _utilisateur?.cliniques.removeWhere((c) => c['id'] == cliniqueId);
      notifyListeners();
    } catch (e, st) {
      debugPrint("supprimerClinique error: $e\n$st");
      rethrow;
    }
  }

  // 🔵 Supprimer un lieu
  Future<void> supprimerLieu(String lieuId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('lieux').delete().eq('id', lieuId);
      _utilisateur?.lieux.removeWhere((l) => l['id'] == lieuId);
      notifyListeners();
    } catch (e, st) {
      debugPrint("supprimerLieu error: $e\n$st");
      rethrow;
    }
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
