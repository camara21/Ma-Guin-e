// lib/pages/wontanara/api_wontanara.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import 'constantes.dart';
import 'models.dart';

/// Client Supabase partagé pour tout le module Wontanara.
final SupabaseClient sb = Supabase.instance.client;

//
// ===================== PUBLICATIONS =====================
//

class ApiPublications {
  /// Liste le flux de publications d'une zone.
  static Future<List<Publication>> listerFlux(
    String zoneId, {
    int limit = 40,
  }) async {
    final data = await sb
        .from('wontanara_publications')
        .select('id,zone_id,type,titre,contenu,created_at,expires_at,statut')
        .eq('zone_id', zoneId)
        .eq('statut', 'active')
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (data as List)
        .map((e) => Publication.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  /// Publier une nouvelle information / alerte / entraide, etc.
  static Future<String> publier({
    required String zoneId,
    required String type,
    required String titre,
    String? contenu,
    Duration duree = const Duration(hours: 2),
  }) async {
    final uid = sb.auth.currentUser?.id;

    final inserted = await sb
        .from('wontanara_publications')
        .insert({
          'user_id': uid,
          'zone_id': zoneId,
          'type': type,
          'titre': titre.trim(),
          'contenu': (contenantNull(contenu)).trim(),
          'images': <String>[],
          'statut': 'active',
          // Optionnel : tu peux aussi stocker expires_at côté SQL via trigger
          'duree': 'PT${duree.inHours}H',
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }
}

//
// ===================== ENTRAIDE =====================
//

class ApiEntraide {
  /// Ouvre un canal d'entraide lié à une publication.
  static Future<String> ouvrir(String publicationId) async {
    final uid = sb.auth.currentUser?.id;

    final r = await sb
        .from('wontanara_entraides')
        .insert({
          'publication_id': publicationId,
          'demandeur_id': uid,
          'statut': 'ouverte',
        })
        .select('id')
        .single();

    return r['id'] as String;
  }
}

//
// ===================== SERVICES LOCAUX =====================
//

class ApiServicesLocaux {
  static Future<List<ServiceLocal>> lister(
    String zoneId, {
    int limit = 50,
  }) async {
    final data = await sb
        .from('wontanara_services')
        .select(
          'id,user_id,zone_id,categorie,description,tarif,disponibilite,fiabilite,created_at',
        )
        .eq('zone_id', zoneId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (data as List)
        .map((e) => ServiceLocal.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  static Future<String> creer({
    required String zoneId,
    required String categorie,
    String? description,
    String? tarif,
  }) async {
    final uid = sb.auth.currentUser?.id;

    final row = await sb
        .from('wontanara_services')
        .insert({
          'user_id': uid,
          'zone_id': zoneId,
          'categorie': categorie.trim(),
          'description': (contenantNull(description)).trim(),
          'tarif': (contenantNull(tarif)).trim(),
          'disponibilite': true,
          'fiabilite': 0,
        })
        .select('id')
        .single();

    return row['id'] as String;
  }
}

//
// ===================== CHAT =====================
//

class ApiChat {
  /// Crée (ou récupère) le salon de chat d'une zone.
  static Future<String> ensureRoomZone(String zoneId) async {
    try {
      final ins = await sb
          .from('wontanara_chat_rooms')
          .insert({'zone_id': zoneId, 'kind': 'zone'})
          .select('id')
          .single();

      return ins['id'] as String;
    } catch (_) {
      // Si déjà existant (contrainte unique), on récupère le salon
      final row = await sb
          .from('wontanara_chat_rooms')
          .select('id')
          .eq('zone_id', zoneId)
          .eq('kind', 'zone')
          .single();

      return row['id'] as String;
    }
  }

  /// Liste les messages d'une zone (via son salon).
  static Future<List<Message>> listerMessages(
    String zoneId, {
    int limit = 100,
  }) async {
    final roomId = await ensureRoomZone(zoneId);

    final data = await sb
        .from('wontanara_messages')
        .select('id,room_id,sender_id,contenu,created_at,expires_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    final list = (data as List)
        .map((e) => Message.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  /// Envoie un message dans le chat de la zone.
  static Future<void> envoyerMessageZone(String zoneId, String texte) async {
    final roomId = await ensureRoomZone(zoneId);

    await sb.from('wontanara_messages').insert({
      'room_id': roomId,
      'sender_id': sb.auth.currentUser?.id,
      'contenu': texte,
      'expires_at':
          DateTime.now().add(const Duration(hours: 48)).toIso8601String(),
    });
  }
}

//
// ===================== VOTES =====================
//

class ApiVotes {
  static Future<List<VoteItem>> lister(String zoneId) async {
    final data = await sb
        .from('wontanara_votes')
        .select('id,zone_id,titre,description,mode,statut,created_at')
        .eq('zone_id', zoneId)
        .order('created_at', ascending: false);

    final list = (data as List)
        .map((e) => VoteItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  static Future<List<VoteOption>> options(String voteId) async {
    final data = await sb
        .from('wontanara_vote_options')
        .select('id,vote_id,libelle,ordre')
        .eq('vote_id', voteId)
        .order('ordre');

    final list = (data as List)
        .map((e) => VoteOption.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  static Future<String> creerVote(
    String zoneId,
    String titre,
    String desc, {
    String mode = 'public',
  }) async {
    final uid = sb.auth.currentUser?.id;

    final row = await sb
        .from('wontanara_votes')
        .insert({
          'user_id': uid,
          'zone_id': zoneId,
          'titre': titre.trim(),
          'description': desc.trim(),
          'mode': mode,
          'statut': 'ouvert',
          'opens_at': DateTime.now().toIso8601String(),
          'closes_at':
              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        })
        .select('id')
        .single();

    return row['id'] as String;
  }

  static Future<void> ajouterOption(
    String voteId,
    String libelle,
    int ordre,
  ) async {
    await sb.from('wontanara_vote_options').insert({
      'vote_id': voteId,
      'libelle': libelle,
      'ordre': ordre,
    });
  }

  static Future<void> voter(String voteId, String optionId) async {
    await sb.from('wontanara_vote_ballots').insert({
      'vote_id': voteId,
      'option_id': optionId,
      'user_id': sb.auth.currentUser?.id,
    });
  }
}

//
// ===================== COLLECTE =====================
//

class ApiCollecte {
  static Future<List<Collecte>> lister(String zoneId) async {
    final data = await sb
        .from('wontanara_collectes')
        .select('id,zone_id,type,statut,created_at')
        .eq('zone_id', zoneId)
        .order('created_at', ascending: false);

    final list = (data as List)
        .map((e) => Collecte.fromMap(e as Map<String, dynamic>))
        .toList();

    return list;
  }

  static Future<String> signaler(String zoneId, String type) async {
    final row = await sb
        .from('wontanara_collectes')
        .insert({
          'signalant_id': sb.auth.currentUser?.id,
          'collecteur_id': null,
          'zone_id': zoneId,
          'type': type,
          'statut': 'signalee',
          'photos': <String>[],
        })
        .select('id')
        .single();

    return row['id'] as String;
  }
}

/// Petites aides pour éviter les `null` sur les champs texte.
String contenantNull(String? value) => value ?? '';
