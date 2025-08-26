import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuiviCoursePage extends StatefulWidget {
  final String courseId;
  const SuiviCoursePage({super.key, required this.courseId});

  @override
  State<SuiviCoursePage> createState() => _SuiviCoursePageState();
}

class _SuiviCoursePageState extends State<SuiviCoursePage> {
  final _sb = Supabase.instance.client;

  Map<String, dynamic>? _course;
  Map<String, dynamic>? _lastPos;
  bool _loading = true;
  RealtimeChannel? _chanCourse;
  RealtimeChannel? _chanPos;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  @override
  void dispose() {
    _chanCourse?.unsubscribe();
    _chanPos?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadCourse() async {
    setState(() => _loading = true);
    try {
      final row = await _sb
          .from('courses')
          .select('id, status, chauffeur_id, depart_label, arrivee_label, price_final, price_estimated')
          .eq('id', widget.courseId)
          .maybeSingle();

      setState(() => _course = row);
      _subscribeCourse();
      if (row?['chauffeur_id'] != null) {
        await _loadLastPos(row!['chauffeur_id'] as String);
        _subscribePos(row['chauffeur_id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement course: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _subscribeCourse() {
    _chanCourse = _sb.channel('course_${widget.courseId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'courses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.courseId,
        ),
        callback: (_) => _loadCourse(),
      )
      ..subscribe();
  }

  Future<void> _loadLastPos(String chauffeurId) async {
    try {
      final row = await _sb
          .from('positions_chauffeur')
          .select('lat, lng, speed, at')
          .eq('chauffeur_id', chauffeurId)
          .order('at', ascending: false)
          .limit(1)
          .maybeSingle();
      setState(() => _lastPos = row);
    } catch (_) {}
  }

  void _subscribePos(String chauffeurId) {
    _chanPos = _sb.channel('pos_$chauffeurId')
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
          final r = payload.newRecord;
          setState(() => _lastPos = r);
        },
      )
      ..subscribe();
  }

  Future<void> _terminer() async {
    try {
      await _sb.from('courses').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course terminée.')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  Future<void> _annuler() async {
    try {
      await _sb.from('courses').update({'status': 'cancelled'}).eq('id', widget.courseId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final c = _course;
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi de la course')),
      body: c == null
          ? const Center(child: Text('Course introuvable'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statut: ${c['status']}'),
                  const SizedBox(height: 8),
                  Text('Départ: ${c['depart_label'] ?? '-'}'),
                  Text('Arrivée: ${c['arrivee_label'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text('Prix prévu: ${c['price_final'] ?? c['price_estimated'] ?? '-'} GNF'),
                  const Divider(height: 24),
                  Text('Position chauffeur: ${_lastPos == null ? 'N/A' : '(${_lastPos!['lat']}, ${_lastPos!['lng']})  v=${_lastPos!['speed'] ?? '-'}  @${_lastPos!['at'] ?? ''}'}'),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: c['status'] == 'pending' || c['status'] == 'accepted' ? _annuler : null,
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: c['status'] == 'en_route' || c['status'] == 'accepted' ? _terminer : null,
                          child: const Text('Terminer'),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
    );
  }
}
