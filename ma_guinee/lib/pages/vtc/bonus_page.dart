import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VtcBonusPage extends StatefulWidget {
  const VtcBonusPage({super.key});

  @override
  State<VtcBonusPage> createState() => _VtcBonusPageState();
}

class _VtcBonusPageState extends State<VtcBonusPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  int _todayCount = 0;
  int _weekCount = 0;
  num _weekEarnings = 0;
  List<Map<String, dynamic>> _lastRides = [];

  String get _me => _sb.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_me.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    try {
      // On récupère les 200 dernières courses terminées pour ce chauffeur
      final rows = await _sb
          .from('courses')
          .select('id, depose_a, statut, prix_gnf, depart_adresse, arrivee_adresse')
          .eq('chauffeur_id', _me)
          .eq('statut', 'terminee')
          .order('depose_a', ascending: false)
          .limit(200);

      final list = (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();

      // Calculs jour/semaine (local)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(Duration(days: startOfDay.weekday - 1)); // Lundi

      int today = 0;
      int week = 0;
      num weekEarn = 0;
      for (final m in list) {
        final s = m['depose_a']?.toString();
        final dt = s != null ? DateTime.tryParse(s)?.toLocal() : null;
        if (dt == null) continue;
        if (!dt.isBefore(startOfDay)) today++;
        if (!dt.isBefore(startOfWeek)) {
          week++;
          final p = m['prix_gnf'];
          if (p is num) weekEarn += p;
          else if (p != null) {
            final n = num.tryParse(p.toString());
            if (n != null) weekEarn += n;
          }
        }
      }

      setState(() {
        _todayCount = today;
        _weekCount = week;
        _weekEarnings = weekEarn;
        _lastRides = list.take(10).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Petits objectifs de bonus (exemple)
  int get _weekTarget => 20; // 20 courses = palier bonus
  num get _weekBonusAmount => 50000; // 50k GNF de bonus au palier

  double get _weekProgress => (_weekCount / _weekTarget).clamp(0, 1).toDouble();

  String _fmtGNF(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final remain = s.length - i - 1;
      buf.write(s[i]);
      if (remain > 0 && remain % 3 == 0) buf.write(' ');
    }
    return '${buf.toString()} GNF';
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bonus')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Aujourd'hui
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.today_rounded),
                      title: Text('Aujourd’hui', style: th.textTheme.titleMedium),
                      subtitle: Text('$_todayCount courses terminées'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Objectif semaine
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Objectif de la semaine', style: th.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('$_weekCount / $_weekTarget courses • Gains: ${_fmtGNF(_weekEarnings)}'),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: _weekProgress, minHeight: 10),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _weekCount >= _weekTarget
                                ? '🎉 Bonus atteint: ${_fmtGNF(_weekBonusAmount)}'
                                : 'Encore ${_weekTarget - _weekCount} courses pour gagner ${_fmtGNF(_weekBonusAmount)}',
                            style: th.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Historique récent
                  Text('Dernières courses', style: th.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_lastRides.isEmpty)
                    const Card(
                      elevation: 0,
                      child: ListTile(title: Text('Aucune course terminée récemment')),
                    )
                  else
                    ..._lastRides.map((m) {
                      final whenStr = () {
                        final s = m['depose_a']?.toString();
                        final dt = s != null ? DateTime.tryParse(s)?.toLocal() : null;
                        if (dt == null) return '-';
                        final d = '${_pad(dt.day)}/${_pad(dt.month)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
                        return d;
                      }();
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(.15)),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: Text('${m['depart_adresse'] ?? '-'} → ${m['arrivee_adresse'] ?? '-'}',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(whenStr),
                          trailing: Text(_fmtGNF((m['prix_gnf'] as num?) ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  static String _pad(int v) => v < 10 ? '0$v' : '$v';
}
