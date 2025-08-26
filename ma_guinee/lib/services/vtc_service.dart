// lib/services/vtc_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception fonctionnelle claire pour le domaine VTC.
class VtcException implements Exception {
  final String message;
  final Object? cause;
  VtcException(this.message, [this.cause]);
  @override
  String toString() => 'VtcException: $message ${cause ?? ""}';
}

/// Service VTC — toutes les opérations DB & temps réel centralisées.
/// Utilise Supabase et expose des méthodes prêtes pour la prod.
class VtcService {
  final SupabaseClient _sb;
  final bool debug;

  VtcService(this._sb, {this.debug = false});

  // --------------------------
  // Helpers bas niveau
  // --------------------------

  Future<T> _retry<T>(
    Future<T> Function() run, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 300),
  }) async {
    assert(maxAttempts >= 1);
    VtcException? last;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final r = await run();
        return r;
      } catch (e) {
        last = VtcException('Échec tentative $attempt/$maxAttempts', e);
        if (attempt == maxAttempts) break;
        final jitter = math.Random().nextDouble() * 0.25 + 0.75; // 0.75x–1.0x
        final delay = baseDelay * math.pow(2, attempt - 1).toInt();
        await Future.delayed(Duration(milliseconds: (delay.inMilliseconds * jitter).round()));
      }
    }
    throw last ?? VtcException('Échec inconnu');
  }

  PostgrestFilterBuilder<Map<String, dynamic>> _select(
    String table,
    String columns, [
    void Function(PostgrestFilterBuilder<Map<String, dynamic>>)? filter,
  ]) {
    final q = _sb.from(table).select(columns);
    if (filter != null) filter(q);
    return q;
  }

  // --------------------------
  // Règles tarifaires & estimation
  // --------------------------

  Future<num> estimerTarif({
    required String city,
    required String vehicle, // 'car' | 'moto'
    required double distanceKm,
    required double dureeMin,
  }) async {
    return _retry(() async {
      final rule = await _select('regles_tarifaires', 'base, per_km, per_min, surge', (q) {
        q.eq('city', city).eq('vehicle', vehicle).limit(1);
      }).maybeSingle();

      final base = (rule?['base'] as num?) ?? 10000;
      final perKm = (rule?['per_km'] as num?) ?? 2000;
      final perMin = (rule?['per_min'] as num?) ?? 200;
      final surge = (rule?['surge'] as num?) ?? 1;

      final total = (base + perKm * distanceKm + perMin * dureeMin) * surge;
      return total.round();
    });
  }

  Future<Map<String, dynamic>> upsertRegleTarifaire({
    required String city,
    required String vehicle,
    required num base,
    required num perKm,
    required num perMin,
    num surge = 1,
    String? id,
  }) async {
    return _retry(() async {
      final payload = {
        'city': city,
        'vehicle': vehicle,
        'base': base,
        'per_km': perKm,
        'per_min': perMin,
        'surge': surge,
      };
      if (id == null) {
        final inserted = await _sb.from('regles_tarifaires').insert(payload).select().single();
        return inserted;
      } else {
        final updated = await _sb.from('regles_tarifaires').update(payload).eq('id', id).select().single();
        return updated;
      }
    });
  }

  Future<void> deleteRegleTarifaire(String id) => _retry(() async {
        await _sb.from('regles_tarifaires').delete().eq('id', id);
      });

  Future<List<Map<String, dynamic>>> listRegles() => _retry(() async {
        final rows = await _select('regles_tarifaires', 'id, city, vehicle, base, per_km, per_min, surge',
            (q) => q.order('city').order('vehicle'));
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  // --------------------------
  // Demande / Course (client)
  // --------------------------

  Future<String> creerDemandeCourse({
    required String clientId,
    required String vehicle,
    required String city,
    required String departLabel,
    required String arriveeLabel,
    required double distanceKm,
    required double dureeMin,
    num? priceEstimated,
  }) async {
    return _retry(() async {
      final inserted = await _sb.from('courses').insert({
        'client_id': clientId,
        'status': 'pending',
        'vehicle': vehicle,
        'city': city,
        'depart_label': departLabel,
        'arrivee_label': arriveeLabel,
        'distance_km': distanceKm,
        'duration_min': dureeMin,
        'price_estimated': priceEstimated,
      }).select('id').single();
      return inserted['id'] as String;
    });
  }

  Future<Map<String, dynamic>?> getCourse(String courseId) => _retry(() async {
        final row = await _select(
          'courses',
          'id, status, chauffeur_id, client_id, depart_label, arrivee_label, price_final, price_estimated, created_at',
          (q) => q.eq('id', courseId).limit(1),
        ).maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  Future<void> terminerCourse(String courseId) => _retry(() async {
        await _sb.from('courses').update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', courseId);
      });

  Future<void> annulerCourse(String courseId) => _retry(() async {
        await _sb.from('courses').update({'status': 'cancelled'}).eq('id', courseId);
      });

  RealtimeChannel subscribeCourse(
    String courseId, {
    required void Function() onChange,
  }) {
    final chan = _sb.channel('course_$courseId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: courseId,
        ),
        callback: (_) => onChange(),
      )
      ..subscribe();
    return chan;
  }

  // --------------------------
  // Offres (chauffeur -> client)
  // --------------------------

  Future<List<Map<String, dynamic>>> listOffres(String courseId) => _retry(() async {
        final rows = await _select('offres_course', 'id, chauffeur_id, price, eta_min, vehicle_label, created_at',
            (q) => q.eq('course_id', courseId).order('created_at', ascending: false));
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  RealtimeChannel subscribeOffres(
    String courseId, {
    required void Function() onInsert,
  }) {
    final chan = _sb.channel('offres_$courseId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'offres_course',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'course_id',
          value: courseId,
        ),
        callback: (_) => onInsert(),
      )
      ..subscribe();
    return chan;
  }

  Future<void> accepterOffre({
    required String courseId,
    required String chauffeurId,
    required num price,
  }) =>
      _retry(() async {
        await _sb.from('courses').update({
          'chauffeur_id': chauffeurId,
          'price_final': price,
          'status': 'accepted',
        }).eq('id', courseId);
      });

  Future<void> proposerOffre({
    required String courseId,
    required String chauffeurId,
    required num price,
    required int etaMin,
    String? vehicleLabel,
  }) =>
      _retry(() async {
        await _sb.from('offres_course').insert({
          'course_id': courseId,
          'chauffeur_id': chauffeurId,
          'price': price,
          'eta_min': etaMin,
          'vehicle_label': vehicleLabel,
        });
      });

  // --------------------------
  // Positions chauffeur (tracking)
  // --------------------------

  Future<Map<String, dynamic>?> getLastPosition(String chauffeurId) => _retry(() async {
        final row = await _select('positions_chauffeur', 'lat, lng, speed, at', (q) {
          q.eq('chauffeur_id', chauffeurId).order('at', ascending: false).limit(1);
        }).maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  RealtimeChannel subscribePositions(
    String chauffeurId, {
    required void Function(Map<String, dynamic> newPos) onInsert,
  }) {
    final chan = _sb.channel('pos_$chauffeurId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'positions_chauffeur',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chauffeur_id',
          value: chauffeurId,
        ),
        callback: (payload) {
          final r = Map<String, dynamic>.from(payload.newRecord);
          onInsert(r);
        },
      )
      ..subscribe();
    return chan;
  }

  // --------------------------
  // Portefeuille & paiements
  // --------------------------

  Future<num> getSoldeChauffeur(String userId) => _retry(() async {
        final row = await _select('portefeuilles_chauffeur', 'solde', (q) => q.eq('user_id', userId).limit(1)).maybeSingle();
        return (row?['solde'] as num?) ?? 0;
      });

  Future<List<Map<String, dynamic>>> getJournalPortefeuille(String userId) => _retry(() async {
        final rows = await _select('journal_portefeuille', 'id, type, montant, libelle, created_at', (q) {
          q.eq('user_id', userId).order('created_at', ascending: false);
        });
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<void> demanderRetrait({required String userId, required num montant}) => _retry(() async {
        await _sb.from('demandes_retrait').insert({'user_id': userId, 'montant': montant, 'status': 'pending'});
      });

  Future<List<Map<String, dynamic>>> listPaiements(String userId) => _retry(() async {
        final rows = await _sb
            .from('paiements')
            .select('id, course_id, payer_id, payee_id, amount, method, status, created_at')
            .or('payer_id.eq.$userId,payee_id.eq.$userId')
            .order('created_at', ascending: false);
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<void> marquerPaiementPaye(String paiementId) => _retry(() async {
        await _sb.from('paiements').update({'status': 'paid'}).eq('id', paiementId);
      });

  // --------------------------
  // Créneaux chauffeur
  // --------------------------

  Future<List<Map<String, dynamic>>> listCreneaux(String userId) => _retry(() async {
        final rows = await _select('creneaux_chauffeur', 'id, start_time, end_time, active', (q) {
          q.eq('user_id', userId).order('start_time', ascending: true);
        });
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<void> addCreneau({
    required String userId,
    required DateTime start,
    required DateTime end,
    bool active = true,
  }) =>
      _retry(() async {
        if (!end.isAfter(start)) {
          throw VtcException('Horaire invalide: end <= start');
        }
        await _sb.from('creneaux_chauffeur').insert({
          'user_id': userId,
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
          'active': active,
        });
      });

  Future<void> toggleCreneau(String id, bool currentActive) => _retry(() async {
        await _sb.from('creneaux_chauffeur').update({'active': !currentActive}).eq('id', id);
      });

  Future<void> deleteCreneau(String id) => _retry(() async {
        await _sb.from('creneaux_chauffeur').delete().eq('id', id);
      });

  // --------------------------
  // Véhicules / Motos
  // --------------------------

  Future<List<Map<String, dynamic>>> listVehicules(String ownerUserId) => _retry(() async {
        final rows = await _select('vehicules', 'id, type, marque, modele, plaque, couleur, actif, created_at',
            (q) => q.eq('owner_user_id', ownerUserId).order('created_at', ascending: false));
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<void> upsertVehicule({
    String? id,
    required String ownerUserId,
    required String type, // 'car' | 'moto'
    required String marque,
    required String modele,
    required String plaque,
    required String couleur,
    bool actif = true,
  }) =>
      _retry(() async {
        final payload = {
          'owner_user_id': ownerUserId,
          'type': type,
          'marque': marque,
          'modele': modele,
          'plaque': plaque,
          'couleur': couleur,
          'actif': actif,
        };
        if (id == null) {
          await _sb.from('vehicules').insert(payload);
        } else {
          await _sb.from('vehicules').update(payload).eq('id', id);
        }
      });

  Future<void> toggleVehicule(String id, bool actif) => _retry(() async {
        await _sb.from('vehicules').update({'actif': !actif}).eq('id', id);
      });

  Future<void> deleteVehicule(String id) => _retry(() async {
        await _sb.from('vehicules').delete().eq('id', id);
      });

  // --------------------------
  // Chauffeur (profil & statut)
  // --------------------------

  Future<Map<String, dynamic>?> getChauffeurByUser(String userId) => _retry(() async {
        final row = await _select('chauffeurs', 'id, user_id, city, vehicle_pref, is_online, is_verified', (q) {
          q.or('id.eq.$userId,user_id.eq.$userId').limit(1);
        }).maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  Future<void> toggleOnline(String chauffeurId, bool online) => _retry(() async {
        await _sb.from('chauffeurs').update({'is_online': online}).eq('id', chauffeurId);
      });

  /// Inscription/Onboarding chauffeur: crée chauffeur + portefeuille si absent + met role
  Future<void> ensureChauffeurProfile({
    required String userId,
    required String city,
    required String vehiclePref,
    required String permisNum,
  }) =>
      _retry(() async {
        await _sb.from('chauffeurs').upsert({
          'id': userId,
          'user_id': userId,
          'city': city,
          'vehicle_pref': vehiclePref,
          'permis_num': permisNum,
          'is_online': false,
          'is_verified': false,
        }, onConflict: 'id');

        // portefeuille via RPC si dispo, sinon fallback
        try {
          await _sb.rpc('ensure_portefeuille', params: {'p_user_id': userId});
        } catch (_) {
          final existing =
              await _sb.from('portefeuilles_chauffeur').select('user_id').eq('user_id', userId).maybeSingle();
          if (existing == null) {
            await _sb.from('portefeuilles_chauffeur').insert({'user_id': userId, 'solde': 0});
          }
        }

        // role = chauffeur
        await _sb.from('utilisateurs').update({'role': 'chauffeur'}).eq('id', userId);
      });

  // --------------------------
  // Découverte/Flux chauffeur
  // --------------------------

  Future<List<Map<String, dynamic>>> listDemandesCompatibles({
    required String city,
    required String vehiclePref,
    int limit = 30,
  }) =>
      _retry(() async {
        final rows = await _select('courses',
            'id, city, vehicle, depart_label, arrivee_label, distance_km, price_estimated, created_at', (q) {
          q.eq('status', 'pending').eq('city', city).eq('vehicle', vehiclePref).order('created_at', ascending: false).limit(limit);
        });
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<List<Map<String, dynamic>>> listCoursesActivesChauffeur(String chauffeurId) => _retry(() async {
        final rows = await _select('courses',
            'id, status, client_id, depart_label, arrivee_label, price_final, created_at', (q) {
          q.eq('chauffeur_id', chauffeurId).in_('status', ['accepted', 'en_route']).order('created_at', ascending: false);
        });
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  // --------------------------
  // Flux client (active & historique)
  // --------------------------

  Future<Map<String, dynamic>?> getCourseActiveClient(String clientId) => _retry(() async {
        final row = await _select('courses',
            'id, status, price_estimated, price_final, depart_label, arrivee_label, chauffeur_id, created_at', (q) {
          q.eq('client_id', clientId).in_('status', ['pending', 'accepted', 'en_route']).order('created_at', ascending: false).limit(1);
        }).maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  Future<List<Map<String, dynamic>>> listHistoriqueClient({
    required String clientId,
    String? cursorCreatedAtDesc, // si fourni, récupère les éléments avant ce timestamp (desc)
    int pageSize = 20,
  }) =>
      _retry(() async {
        final q = _sb
            .from('courses')
            .select('id, status, price_final, depart_label, arrivee_label, created_at')
            .eq('client_id', clientId)
            .order('created_at', ascending: false)
            .limit(pageSize);
        if (cursorCreatedAtDesc != null) {
          q.lt('created_at', cursorCreatedAtDesc);
        }
        final rows = await q;
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  // --------------------------
  // Admin
  // --------------------------

  Future<List<Map<String, dynamic>>> listChauffeursEnAttente() => _retry(() async {
        final rows = await _select('chauffeurs', 'id, user_id, city, vehicle_pref, is_verified',
            (q) => q.eq('is_verified', false));
        return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });

  Future<void> validerChauffeur(String chauffeurId) => _retry(() async {
        await _sb.from('chauffeurs').update({'is_verified': true}).eq('id', chauffeurId);
      });

  Future<void> supprimerChauffeur(String chauffeurId) => _retry(() async {
        await _sb.from('chauffeurs').delete().eq('id', chauffeurId);
      });

  Future<List<Map<String, dynamic>>> revenusPlateformeDerniersJours(int nbJours) => _retry(() async {
        try {
          final rows = await _select('v_revenus_plateforme_jour', 'jour, total_gnf',
              (q) => q.order('jour', ascending: false).limit(nbJours));
          return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {
          // fallback si la vue n'existe pas
          final rows = await _sb.rpc('revenus_plateforme_par_jour', params: {'p_days': nbJours});
          return (rows as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        }
      });
}

// ---------------------------------------------------------
// Instance globale pratique (optionnel)
// ---------------------------------------------------------

/// Utilisation rapide :
///   final vtc = vtcService; await vtc.estimerTarif(...);
VtcService get vtcService => VtcService(Supabase.instance.client);
