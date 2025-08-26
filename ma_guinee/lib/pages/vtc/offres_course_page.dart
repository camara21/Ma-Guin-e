import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes.dart';

class OffresCoursePage extends StatefulWidget {
  final String demandeId;
  const OffresCoursePage({super.key, required this.demandeId});

  @override
  State<OffresCoursePage> createState() => _OffresCoursePageState();
}

class _OffresCoursePageState extends State<OffresCoursePage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _offres = [];
  bool _loading = true;
  RealtimeChannel? _chan;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _chan?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('offres_course')
          .select('id, chauffeur_id, price, eta_min, vehicle_label, created_at')
          .eq('course_id', widget.demandeId)
          .order('created_at', ascending: false);
      setState(() => _offres = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement offres: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _chan = _sb.channel('offres_${widget.demandeId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'offres_course',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'course_id',
          value: widget.demandeId,
        ),
        callback: (_) => _load(),
      )
      ..subscribe();
  }

  Future<void> _accepterOffre(Map<String, dynamic> offre) async {
    try {
      await _sb.from('courses').update({
        'chauffeur_id': offre['chauffeur_id'],
        'price_final': offre['price'],
        'status': 'accepted',
      }).eq('id', widget.demandeId);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.vtcSuivi, arguments: {
        'courseId': widget.demandeId,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec acceptation: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Offres disponibles')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offres.isEmpty
              ? const Center(child: Text('Aucune offre pour l’instant…'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final o = _offres[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: th.dividerColor.withOpacity(.2))),
                      title: Text('${o['price']} GNF  •  ~${o['eta_min']} min'),
                      subtitle: Text('Véhicule: ${o['vehicle_label'] ?? 'N/A'}\nChauffeur: ${o['chauffeur_id']}'),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        onPressed: () => _accepterOffre(o),
                        child: const Text('Accepter'),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _offres.length,
                ),
    );
  }
}
