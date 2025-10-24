import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SlotDispo {
  final String id;
  final int cliniqueId;
  final DateTime startAt;
  final DateTime endAt;
  final int maxPatients;
  final int? placesRestantes;
  final bool lockedByClinic;

  SlotDispo({
    required this.id,
    required this.cliniqueId,
    required this.startAt,
    required this.endAt,
    required this.maxPatients,
    this.placesRestantes,
    this.lockedByClinic = false,
  });

  factory SlotDispo.fromJson(Map<String, dynamic> j) => SlotDispo(
        id: j['id'],
        cliniqueId: (j['clinique_id'] as num).toInt(),
        startAt: DateTime.parse(j['start_at']).toLocal(),
        endAt: DateTime.parse(j['end_at']).toLocal(),
        maxPatients: (j['max_patients'] ?? 1) as int,
        placesRestantes: j['places_restantes'],
      );

  SlotDispo copyWith({bool? lockedByClinic}) => SlotDispo(
        id: id,
        cliniqueId: cliniqueId,
        startAt: startAt,
        endAt: endAt,
        maxPatients: maxPatients,
        placesRestantes: placesRestantes,
        lockedByClinic: lockedByClinic ?? this.lockedByClinic,
      );
}

class Rdv {
  final String id;
  final String patientId;
  final int cliniqueId;
  final String? slotId;
  final DateTime startAt;
  final DateTime endAt;
  final String statut;
  final String? motif;
  final String? noteClinique;
  final String? patientNom;
  final String? patientTel;
  final DateTime? createdAt;

  Rdv({
    required this.id,
    required this.patientId,
    required this.cliniqueId,
    required this.slotId,
    required this.startAt,
    required this.endAt,
    required this.statut,
    this.motif,
    this.noteClinique,
    this.patientNom,
    this.patientTel,
    this.createdAt,
  });

  factory Rdv.fromJson(Map<String, dynamic> j) => Rdv(
        id: j['id'],
        patientId: j['patient_id'],
        cliniqueId: (j['clinique_id'] as num).toInt(),
        slotId: j['slot_id'],
        startAt: DateTime.parse(j['start_at']).toLocal(),
        endAt: DateTime.parse(j['end_at']).toLocal(),
        statut: j['statut'],
        motif: j['motif'],
        noteClinique: j['note_clinique'],
        patientNom: j['patient_nom'],
        patientTel: j['patient_tel'],
        createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : null,
      );
}

class RdvService {
  final supa = Supabase.instance.client;

  Future<List<SlotDispo>> slotsPourClinique(int cliniqueId, {int windowDays = 14}) async {
    final nowUtc = DateTime.now().toUtc();
    final endUtc = nowUtc.add(Duration(days: windowDays));

    final data = await supa
        .from('sante_disponibilites_stats')
        .select('*')
        .eq('clinique_id', cliniqueId)
        .gte('start_at', nowUtc.toIso8601String())
        .lt('start_at', endUtc.toIso8601String())
        .order('start_at', ascending: true);

    return (data as List).map((e) => SlotDispo.fromJson(e)).toList();
  }

  Future<void> prendreRdv({
    required int cliniqueId,
    required SlotDispo slot,
    String? motif,
    String? patientNom,
    String? patientTel,
  }) async {
    final uid = supa.auth.currentUser!.id;

    // Annuler les RDV actifs pour ce slot et ce patient (évite le blocage de contrainte)
    await supa.from('sante_rdv')
      .update({'statut': 'annule'})
      .eq('slot_id', slot.id)
      .eq('patient_id', uid)
      .not('statut', 'in', ['annule', 'annule_clinique']);

    // Insertion propre (respect des contraintes d'exclusion)
    await supa.from('sante_rdv').insert({
      'patient_id': uid,
      'clinique_id': cliniqueId,
      'slot_id': slot.id,
      'start_at': slot.startAt.toUtc().toIso8601String(),
      'end_at': slot.endAt.toUtc().toIso8601String(),
      'statut': 'confirme',
      'motif': motif,
      'patient_nom': patientNom,
      'patient_tel': patientTel,
    });
  }

  Future<List<Rdv>> mesRdv() async {
    final uid = supa.auth.currentUser!.id;
    final data = await supa
        .from('sante_rdv')
        .select('*')
        .eq('patient_id', uid)
        .order('start_at', ascending: true);
    return (data as List).map((e) => Rdv.fromJson(e)).toList();
  }

  Future<void> annulerRdv(String rdvId) async {
    await supa.from('sante_rdv').update({'statut': 'annule'}).eq('id', rdvId);
  }

  Future<void> annulerRdvParClinique(String rdvId, {String? note}) async {
    await supa.from('sante_rdv').update({
      'statut': 'annule_clinique',
      if (note != null && note.isNotEmpty) 'note_clinique': note,
    }).eq('id', rdvId);
  }

  Future<List<Rdv>> rdvPourClinique(int cliniqueId) async {
    final data = await supa
        .from('sante_rdv')
        .select('*')
        .eq('clinique_id', cliniqueId)
        .order('start_at', ascending: true);
    return (data as List).map((e) => Rdv.fromJson(e)).toList();
  }

  Future<String> creerSlot({
    required int cliniqueId,
    required DateTime startAt,
    required DateTime endAt,
    int maxPatients = 1,
  }) async {
    final res = await supa
        .from('sante_disponibilites')
        .insert({
          'clinique_id': cliniqueId,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
          'max_patients': maxPatients,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  Future<void> supprimerSlot(String slotId) async {
    await supa.from('sante_disponibilites').delete().eq('id', slotId);
  }

  Future<int> creerSlotsRecurrents({
    required int cliniqueId,
    required DateTime fromDate,
    required DateTime toDate,
    required TimeOfDay start,
    required TimeOfDay end,
    required List<int> daysOfWeek,
    int durationMinutes = 30,
    int capacityPerSlot = 1,
  }) async {
    final List<Map<String, dynamic>> rows = [];
    DateTime day = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final last = DateTime(toDate.year, toDate.month, toDate.day);

    while (!day.isAfter(last)) {
      if (daysOfWeek.contains(day.weekday)) {
        var st = DateTime(day.year, day.month, day.day, start.hour, start.minute);
        final endDay = DateTime(day.year, day.month, day.day, end.hour, end.minute);

        while (st.isBefore(endDay)) {
          final en = st.add(Duration(minutes: durationMinutes));
          if (en.isAfter(endDay)) break;

          rows.add({
            'clinique_id': cliniqueId,
            'start_at': st.toUtc().toIso8601String(),
            'end_at': en.toUtc().toIso8601String(),
            'max_patients': capacityPerSlot,
          });
          st = en;
        }
      }
      day = day.add(const Duration(days: 1));
    }

    if (rows.isEmpty) return 0;
    await supa.from('sante_disponibilites').insert(rows);
    return rows.length;
  }
}
