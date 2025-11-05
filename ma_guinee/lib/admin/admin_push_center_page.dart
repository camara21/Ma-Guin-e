import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPushCenterPage extends StatefulWidget {
  const AdminPushCenterPage({super.key});

  @override
  State<AdminPushCenterPage> createState() => _AdminPushCenterPageState();
}

class _AdminPushCenterPageState extends State<AdminPushCenterPage> {
  final _sb = Supabase.instance.client;

  // ---- Form fields
  final _titleCtrl = TextEditingController(text: 'Annonce Soneya 🔔');
  final _bodyCtrl  = TextEditingController(text: 'Bonjour, voici une notification de test 🚀');
  final _urlCtrl   = TextEditingController(text: '/');
  final _dataCtrl  = TextEditingController(text: '{"type":"info"}');

  // ---- Audience
  Audience _aud = Audience.userId;

  // user_id
  final _userIdCtrl = TextEditingController(); // UUID

  // token
  final _tokenCtrl = TextEditingController();  // FCM token

  // zone géographique (lat/lon/rayon)
  final _latCtrl    = TextEditingController(text: '9.6412');     // Conakry approx
  final _lonCtrl    = TextEditingController(text: '-13.5784');   // Conakry approx
  final _radiusCtrl = TextEditingController(text: '25');         // km

  // ---- UI state
  bool _sending = false;
  String? _resultText;
  int _sent = 0;
  int _failed = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _dataCtrl.dispose();
    _userIdCtrl.dispose();
    _tokenCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _parseDataJson() {
    final raw = _dataCtrl.text.trim();
    if (raw.isEmpty) return null;
    final obj = jsonDecode(raw);
    if (obj is Map<String, dynamic>) return obj;
    throw 'Données (JSON) doit être un objet { ... }';
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _resultText = null;
      _sent = 0;
      _failed = 0;
    });

    try {
      final title = _titleCtrl.text.trim();
      final body  = _bodyCtrl.text.trim();
      if (title.isEmpty || body.isEmpty) {
        throw 'Titre et message sont requis.';
      }

      final Map<String, dynamic> data = {
        if (_urlCtrl.text.trim().isNotEmpty) 'url': _urlCtrl.text.trim(),
        ...?_parseDataJson(),
      };

      switch (_aud) {
        case Audience.token:
          final t = _tokenCtrl.text.trim();
          if (t.isEmpty) throw 'FCM token manquant.';
          await _sendToToken(t, title, body, data);
          break;

        case Audience.userId:
          final uid = _userIdCtrl.text.trim();
          if (uid.isEmpty) throw 'user_id manquant.';
          await _sendToUserId(uid, title, body, data);
          break;

        case Audience.zone:
          final lat = double.tryParse(_latCtrl.text.trim());
          final lon = double.tryParse(_lonCtrl.text.trim());
          final rkm = double.tryParse(_radiusCtrl.text.trim());
          if (lat == null || lon == null || rkm == null) {
            throw 'Latitude, longitude et rayon (km) sont requis.';
          }
          await _sendToZone(lat, lon, rkm, title, body, data);
          break;

        case Audience.everyone:
          await _sendToEveryone(title, body, data);
          break;
      }

      setState(() {
        _resultText = 'OK — envoyées: $_sent  |  échecs: $_failed';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification envoyée')),
        );
      }
    } catch (e) {
      setState(() => _resultText = 'Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---------------- ENVOIS ----------------

  Future<void> _sendToToken(
      String token, String title, String body, Map<String, dynamic> data) async {
    await _sb.functions.invoke('push-send', body: {
      'token': token,
      'title': title,
      'body': body,
      if (data.isNotEmpty) 'data': data,
    });
    _sent = 1;
  }

  Future<void> _sendToUserId(
      String userId, String title, String body, Map<String, dynamic> data) async {
    final res = await _sb.functions.invoke('push-send', body: {
      'user_id': userId,
      'title': title,
      'body': body,
      if (data.isNotEmpty) 'data': data,
    });
    final d = res.data;
    if (d is Map && d['ok'] == true) {
      _sent  = (d['sent'] as num?)?.toInt() ?? 0;
      _failed = (d['failed'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> _sendToZone(
      double lat, double lon, double rkm, String title, String body, Map<String, dynamic> data) async {
    // 1) On essaie une RPC côté DB si elle existe: rpc_users_in_radius(lat, lon, radius_km)
    List<String> userIds = [];
    try {
      final res = await _sb.rpc('rpc_users_in_radius', params: {
        'lat': lat,
        'lon': lon,
        'radius_km': rkm,
      });
      if (res is List) {
        for (final row in res) {
          final id = (row['id'] ?? '').toString();
          if (id.isNotEmpty) userIds.add(id);
        }
      }
    } catch (_) {
      // 2) Fallback client: charge utilisateurs avec last_lat/last_lon et filtre Haversine en Dart
      final rows = await _sb
          .from('utilisateurs')
          .select('id, last_lat, last_lon')
          .not('last_lat', 'is', null)
          .not('last_lon', 'is', null);
      for (final r in rows as List) {
        final id = (r['id'] ?? '').toString();
        final la = (r['last_lat'] as num?)?.toDouble();
        final lo = (r['last_lon'] as num?)?.toDouble();
        if (id.isEmpty || la == null || lo == null) continue;
        final dkm = _haversineKm(lat, lon, la, lo);
        if (dkm <= rkm) userIds.add(id);
      }
    }

    userIds = userIds.toSet().toList();
    if (userIds.isEmpty) {
      _sent = 0; _failed = 0;
      return;
    }

    // Envoi par paquets via push-send (user_id)
    const batchSize = 25;
    for (var i = 0; i < userIds.length; i += batchSize) {
      final chunk = userIds.sublist(i, (i + batchSize).clamp(0, userIds.length));
      final futures = chunk.map((uid) async {
        try {
          final res = await _sb.functions.invoke('push-send', body: {
            'user_id': uid,
            'title': title,
            'body': body,
            if (data.isNotEmpty) 'data': data,
          });
          final d = res.data;
          if (d is Map && d['ok'] == true) {
            _sent  += (d['sent'] as num?)?.toInt() ?? 0;
            _failed += (d['failed'] as num?)?.toInt() ?? 0;
          } else {
            _failed += 1;
          }
        } catch (_) {
          _failed += 1;
        }
      });
      await Future.wait(futures);
      if (!mounted) break;
      setState(() {}); // progression visuelle
    }
  }

  Future<void> _sendToEveryone(
      String title, String body, Map<String, dynamic> data) async {
    // 1) tente la function push-broadcast si elle existe
    try {
      final res = await _sb.functions.invoke('push-broadcast', body: {
        'title': title,
        'body': body,
        if (data.isNotEmpty) 'data': data,
      });
      final d = res.data;
      if (d is Map && d['ok'] == true) {
        _sent  = (d['sent'] as num?)?.toInt() ?? 0;
        _failed = (d['failed'] as num?)?.toInt() ?? 0;
        return;
      }
    } catch (_) {
      // ignore → fallback client
    }

    // 2) fallback: envoie à tous les user_id
    final rows = await _sb.from('utilisateurs').select('id');
    final ids = <String>[
      for (final r in rows as List) (r['id'] ?? '').toString()
    ].where((e) => e.isNotEmpty).toList();

    const batchSize = 25;
    for (var i = 0; i < ids.length; i += batchSize) {
      final chunk = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
      final futures = chunk.map((uid) async {
        try {
          final res = await _sb.functions.invoke('push-send', body: {
            'user_id': uid,
            'title': title,
            'body': body,
            if (data.isNotEmpty) 'data': data,
          });
          final d = res.data;
          if (d is Map && d['ok'] == true) {
            _sent  += (d['sent'] as num?)?.toInt() ?? 0;
            _failed += (d['failed'] as num?)?.toInt() ?? 0;
          } else {
            _failed += 1;
          }
        } catch (_) {
          _failed += 1;
        }
      });
      await Future.wait(futures);
      if (!mounted) break;
      setState(() {}); // progression
    }
  }

  // ---------------- HELPERS ----------------

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(_deg2rad(lat1))*math.cos(_deg2rad(lat2)) *
        math.sin(dLon/2)*math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre de notifications'),
        actions: [
          IconButton(
            tooltip: 'Envoyer',
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Message',
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'URL / Deep link (optionnel)',
                          hintText: '/messages ou https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _dataCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Données JSON (optionnel)',
                          hintText: '{"type":"info"}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _card(
            title: 'Audience',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Utilisateur (user_id)'),
                      selected: _aud == Audience.userId,
                      onSelected: (_) => setState(() => _aud = Audience.userId),
                    ),
                    ChoiceChip(
                      label: const Text('Appareil (FCM token)'),
                      selected: _aud == Audience.token,
                      onSelected: (_) => setState(() => _aud = Audience.token),
                    ),
                    ChoiceChip(
                      label: const Text('Zone géographique'),
                      selected: _aud == Audience.zone,
                      onSelected: (_) => setState(() => _aud = Audience.zone),
                    ),
                    ChoiceChip(
                      label: const Text('Tout le monde'),
                      selected: _aud == Audience.everyone,
                      onSelected: (_) => setState(() => _aud = Audience.everyone),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_aud == Audience.userId) ...[
                  TextField(
                    controller: _userIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'user_id (UUID)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else if (_aud == Audience.token) ...[
                  TextField(
                    controller: _tokenCtrl,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'FCM token',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else if (_aud == Audience.zone) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _lonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _radiusCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Rayon (km)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cible les utilisateurs dont (last_lat, last_lon) sont dans le rayon.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ] else ...[
                  const Text(
                    'Envoi global : tous les utilisateurs enregistrés recevront la notification.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer'),
              ),
              const SizedBox(width: 12),
              if (_sending)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              const Spacer(),
              if (_resultText != null)
                Text(_resultText!, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

enum Audience { userId, token, zone, everyone }
