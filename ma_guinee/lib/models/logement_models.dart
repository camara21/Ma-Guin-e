// lib/models/logement_models.dart
import 'dart:convert';

/// Type d'opération
enum LogementMode { location, achat }

String logementModeToString(LogementMode m) =>
    m == LogementMode.achat ? 'achat' : 'location';

/// Parse robuste depuis la DB (gère null/espaces/majuscules)
LogementMode logementModeFromDb(dynamic v) {
  final s = v?.toString().trim().toLowerCase();
  switch (s) {
    case 'achat':
      return LogementMode.achat;
    case 'location':
    default:
      return LogementMode.location;
  }
}

/// Catégorie de bien
enum LogementCategorie { maison, appartement, studio, terrain, autres }

String logementCategorieToString(LogementCategorie c) {
  switch (c) {
    case LogementCategorie.maison:
      return 'maison';
    case LogementCategorie.appartement:
      return 'appartement';
    case LogementCategorie.studio:
      return 'studio';
    case LogementCategorie.terrain:
      return 'terrain';
    case LogementCategorie.autres:
      return 'autres';
  }
}

/// Parse robuste depuis la DB (gère null/espaces/majuscules)
LogementCategorie logementCategorieFromDb(dynamic v) {
  final s = v?.toString().trim().toLowerCase();
  switch (s) {
    case 'maison':
      return LogementCategorie.maison;
    case 'appartement':
      return LogementCategorie.appartement;
    case 'studio':
      return LogementCategorie.studio;
    case 'terrain':
      return LogementCategorie.terrain;
    default:
      return LogementCategorie.autres;
  }
}

/// Modèle principal
class LogementModel {
  final String id;
  final String userId;
  final String titre;
  final String? description;
  final LogementMode mode;               // location | achat
  final LogementCategorie categorie;     // maison | appartement | studio | terrain | autres
  final num? prixGnf;                    // GNF (vente) ou loyer mensuel
  final String? ville;
  final String? commune;
  final String? adresse;
  final num? superficieM2;
  final int? chambres;
  final double? lat;
  final double? lng;
  final List<String> photos;             // URLs publiques (via table logement_photos)
  final DateTime creeLe;

  /// 📞 colonne SQL: contact_telephone
  final String? contactTelephone;

  LogementModel({
    required this.id,
    required this.userId,
    required this.titre,
    required this.mode,
    required this.categorie,
    required this.creeLe,
    this.description,
    this.prixGnf,
    this.ville,
    this.commune,
    this.adresse,
    this.superficieM2,
    this.chambres,
    this.lat,
    this.lng,
    this.photos = const [],
    this.contactTelephone,
  });

  factory LogementModel.fromMap(Map<String, dynamic> m) {
    List<String> _photos = const [];
    final p = m['photos'];
    if (p is List) {
      _photos = p
          .map((e) => e?.toString() ?? '')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (p is String && p.isNotEmpty) {
      try {
        final arr = jsonDecode(p);
        if (arr is List) {
          _photos = arr
              .map((e) => e?.toString() ?? '')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    num? _num(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse(v.toString().trim()));
    int? _int(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString().trim()));
    double? _dbl(dynamic v) {
      final n = _num(v);
      return n?.toDouble();
    }
    String? _s(dynamic v) {
      final t = v?.toString().trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    return LogementModel(
      id: m['id']?.toString() ?? '',
      userId: m['user_id']?.toString() ?? '',
      titre: m['titre']?.toString() ?? '',
      description: _s(m['description']),
      mode: logementModeFromDb(m['mode']),
      categorie: logementCategorieFromDb(m['categorie']),
      prixGnf: _num(m['prix_gnf']),
      ville: _s(m['ville']),
      commune: _s(m['commune']),
      adresse: _s(m['adresse']),
      superficieM2: _num(m['superficie_m2']),
      chambres: _int(m['chambres']),
      lat: _dbl(m['lat']),
      lng: _dbl(m['lng']),
      photos: _photos,
      creeLe:
          DateTime.tryParse(m['cree_le']?.toString() ?? '') ?? DateTime.now(),
      contactTelephone: _s(m['contact_telephone']),
    );
  }

  /// ⚠️ Sans `photos` (elles sont stockées dans `logement_photos`)
  Map<String, dynamic> toInsertMap() => {
        'titre': titre,
        'description': description,
        'mode': logementModeToString(mode),
        'categorie': logementCategorieToString(categorie),
        'prix_gnf': prixGnf,
        'ville': ville,
        'commune': commune,
        'adresse': adresse,
        'superficie_m2': superficieM2,
        'chambres': chambres,
        'lat': lat,
        'lng': lng,
        'contact_telephone': contactTelephone,
      }..removeWhere((_, v) => v == null);

  LogementModel copyWith({
    String? id,
    String? userId,
    String? titre,
    String? description,
    LogementMode? mode,
    LogementCategorie? categorie,
    num? prixGnf,
    String? ville,
    String? commune,
    String? adresse,
    num? superficieM2,
    int? chambres,
    double? lat,
    double? lng,
    List<String>? photos,
    DateTime? creeLe,
    String? contactTelephone,
  }) {
    return LogementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      categorie: categorie ?? this.categorie,
      prixGnf: prixGnf ?? this.prixGnf,
      ville: ville ?? this.ville,
      commune: commune ?? this.commune,
      adresse: adresse ?? this.adresse,
      superficieM2: superficieM2 ?? this.superficieM2,
      chambres: chambres ?? this.chambres,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photos: photos ?? this.photos,
      creeLe: creeLe ?? this.creeLe,
      contactTelephone: contactTelephone ?? this.contactTelephone,
    );
  }
}

/// Paramètres de recherche
class LogementSearchParams {
  final String? q; // mot-clé
  final LogementMode? mode;
  final LogementCategorie? categorie;
  final String? ville;
  final String? commune;
  final num? prixMin;
  final num? prixMax;
  final num? surfaceMin;
  final num? surfaceMax;
  final int? chambres;
  final String orderBy; // 'cree_le' | 'prix_gnf' | 'superficie_m2'
  final bool ascending;
  final int limit;
  final int offset;
  final double? nearLat;
  final double? nearLng;
  final int? nearKm;

  const LogementSearchParams({
    this.q,
    this.mode,
    this.categorie,
    this.ville,
    this.commune,
    this.prixMin,
    this.prixMax,
    this.surfaceMin,
    this.surfaceMax,
    this.chambres,
    this.orderBy = 'cree_le',
    this.ascending = false,
    this.limit = 20,
    this.offset = 0,
    this.nearLat,
    this.nearLng,
    this.nearKm,
  });

  LogementSearchParams copyWith({
    String? q,
    LogementMode? mode,
    LogementCategorie? categorie,
    String? ville,
    String? commune,
    num? prixMin,
    num? prixMax,
    num? surfaceMin,
    num? surfaceMax,
    int? chambres,
    String? orderBy,
    bool? ascending,
    int? limit,
    int? offset,
    double? nearLat,
    double? nearLng,
    int? nearKm,
  }) {
    return LogementSearchParams(
      q: q ?? this.q,
      mode: mode ?? this.mode,
      categorie: categorie ?? this.categorie,
      ville: ville ?? this.ville,
      commune: commune ?? this.commune,
      prixMin: prixMin ?? this.prixMin,
      prixMax: prixMax ?? this.prixMax,
      surfaceMin: surfaceMin ?? this.surfaceMin,
      surfaceMax: surfaceMax ?? this.surfaceMax,
      chambres: chambres ?? this.chambres,
      orderBy: orderBy ?? this.orderBy,
      ascending: ascending ?? this.ascending,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      nearLat: nearLat ?? this.nearLat,
      nearLng: nearLng ?? this.nearLng,
      nearKm: nearKm ?? this.nearKm,
    );
  }
}
