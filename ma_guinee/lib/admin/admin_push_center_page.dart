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

  // —— Message
  final _titleCtrl = TextEditingController(text: 'Annonce Soneya 🔔');
  final _bodyCtrl  = TextEditingController(text: 'Bonjour, voici une notification ✨');
  final _urlCtrl   = TextEditingController(text: '/');
  final _dataCtrl  = TextEditingController(text: '{"type":"info"}');
  final _soundCtrl = TextEditingController(text: 'default');
  final _badgeCtrl = TextEditingController(text: '1');

  // —— Audience
  Audience _aud = Audience.userId;

  // user_id
  final _userIdCtrl = TextEditingController(); // UUID

  // token
  final _tokenCtrl = TextEditingController();  // FCM token

  // zone géographique
  final _latCtrl    = TextEditingController(text: '9.6412');     // Conakry approx
  final _lonCtrl    = TextEditingController(text: '-13.5784');   // Conakry approx
  final _radiusCtrl = TextEditingController(text: '25');         // km

  // —— UI / état
  bool _sending = false;
  String? _resultText;
  Map<String, dynamic>? _lastResponse;
  double _progress = 0.0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _urlCtrl.dispose();
    _dataCtrl.dispose();
    _soundCtrl.dispose();
    _badgeCtrl.dispose();
    _userIdCtrl.dispose();
    _tokenCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  // ===================== Helpers =====================

  String _uuidV4() {
    final r = math.Random.secure();
    String hex(int len) => List<int>.generate(len, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final a = hex(4), b = hex(2), c = hex(2), d = hex(2), e = hex(6);
    final v = ((int.parse(c.substring(0, 2), radix: 16) & 0x0f) | 0x40)
        .toRadixString(16);
    final w = ((int.parse(d.substring(0, 2), radix: 16) & 0x3f) | 0x80)
        .toRadixString(16);
    return '${a.substring(0,8)}-${b.substring(0,4)}-$v${c.substring(2,4)}-$w${d.substring(2,4)}-${e.substring(0,12)}';
  }

  Map<String, dynamic>? _parseDataJson() {
    final raw = _dataCtrl.text.trim();
    if (raw.isEmpty) return null;
    final obj = jsonDecode(raw);
    if (obj is Map<String, dynamic>) return obj;
    throw 'Données JSON invalides: utilisez un objet { "k": "v" }';
  }

  int? _parseInt(String s) => int.tryParse(s.trim());

  Future<void> _pickUserDialog() async {
    final qCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    String? selectedId;

    await showDialog(
      context: context,
      builder: (ctx) {
        Future<void> search() async {
          final q = qCtrl.text.trim();
          if (q.isEmpty) return;
          final rows = await _sb
              .from('utilisateurs')
              .select('id,email,phone,full_name')
              .or('email.ilike.%$q%,phone.ilike.%$q%,full_name.ilike.%$q%')
              .limit(50);
          results = List<Map<String,dynamic>>.from(rows as List);
          (ctx as Element).markNeedsBuild();
        }

        return AlertDialog(
          title: const Text('Rechercher un utilisateur'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email / Téléphone / Nom',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: search,
                    ),
                  ),
                  onSubmitted: (_) => search(),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = results[i];
                      final id = '${r['id']}';
                      return RadioListTile<String>(
                        value: id,
                        groupValue: selectedId,
                        onChanged: (v) { selectedId = v; (ctx as Element).markNeedsBuild(); },
                        title: Text(r['full_name']?.toString() ?? '(sans nom)'),
                        subtitle: Text('${r['email'] ?? ''}  ${r['phone'] ?? ''}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: selectedId == null ? null : () {
                _userIdCtrl.text = selectedId!;
                Navigator.pop(ctx);
              },
              child: const Text('Sélectionner'),
            ),
          ],
        );
      }
    );
  }

  // ===================== Envoi =====================

  Future<void> _send() async {
    if (_sending) return;

    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _toast('Titre et message sont requis.');
      return;
    }

    Map<String, dynamic>? data;
    try {
      data = _parseDataJson();
    } catch (e) {
      _toast('Erreur JSON: $e');
      return;
    }

    final extras = <String, dynamic>{};
    final sound = _soundCtrl.text.trim();
    if (sound.isNotEmpty) extras['sound'] = sound;
    final badge = _parseInt(_badgeCtrl.text);
    if (badge != null && badge >= 0) extras['badge'] = badge;

    setState(() {
      _sending = true;
      _resultText = null;
      _lastResponse = null;
      _progress = 0;
    });

    final idempotencyKey = _uuidV4();

    try {
      Map<String, dynamic> base(String key, dynamic value) => {
        key: value,
        'title': title,
        'body': body,
        if (_urlCtrl.text.trim().isNotEmpty) 'url': _urlCtrl.text.trim(),
        if (data != null) 'data': data,
        if (extras.isNotEmpty) ...extras,
        'idempotency_key': idempotencyKey,
      };

      Map<String, dynamic>? resp;

      switch (_aud) {
        case Audience.token:
          final t = _tokenCtrl.text.trim();
          if (t.isEmpty) throw 'FCM token manquant.';
          resp = await _invokePush(base('token', t));
          break;

        case Audience.userId:
          final uid = _userIdCtrl.text.trim();
          if (uid.isEmpty) throw 'user_id manquant.';
          resp = await _invokePush(base('user_id', uid));
          break;

        case Audience.zone:
          final lat = double.tryParse(_latCtrl.text.trim());
          final lon = double.tryParse(_lonCtrl.text.trim());
          final rkm = double.tryParse(_radiusCtrl.text.trim());
          if (lat == null || lon == null || rkm == null) {
            throw 'Latitude, longitude et rayon (km) sont requis.';
          }
          // Appel direct côté serveur (plus efficace)
          resp = await _invokePush({
            'geo': {'lat': lat, 'lon': lon, 'radius_km': rkm},
            ...base('_', true)..remove('_'),
          });
          break;

        case Audience.everyone:
          resp = await _invokePush(base('all', true));
          break;
      }

      setState(() {
        _lastResponse = resp;
        final sent   = (resp?['sent'] as num?)?.toInt() ?? (resp?['envoyées'] as num?)?.toInt() ?? 0;
        final failed = (resp?['failed'] as num?)?.toInt() ?? (resp?['échouées'] as num?)?.toInt() ?? 0;
        final pruned = (resp?['pruned'] as num?)?.toInt() ?? 0;
        final total  = (resp?['total'] as num?)?.toInt();
        _resultText = 'OK — envoyées: $sent  |  échecs: $failed  |  supprimés: $pruned${total != null ? "  |  total: $total" : ""}';
        _progress = 1.0;
      });
      _toast('Notification envoyée');
    } catch (e) {
      setState(() { _resultText = 'Erreur: $e'; _progress = 0; });
      _toast('Erreur: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<Map<String, dynamic>> _invokePush(Map<String, dynamic> body) async {
    final res = await _sb.functions.invoke('push-send', body: body);
    final d = res.data;
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===================== UI =====================

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
          _card(title: 'Aperçu', child: _preview()),
          const SizedBox(height: 16),

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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _soundCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Son (Android/iOS)',
                          hintText: 'default',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _badgeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                        decoration: const InputDecoration(
                          labelText: 'Badge iOS',
                          hintText: '1',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'user_id (UUID)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickUserDialog,
                        icon: const Icon(Icons.search),
                        label: const Text('Rechercher'),
                      ),
                    ],
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
                    'Cible via la function (geo) — PostGIS côté serveur (users_in_radius).',
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
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer'),
              ),
              const SizedBox(width: 12),
              if (_sending)
                Row(
                  children: [
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                    ),
                  ],
                ),
              const Spacer(),
              if (_resultText != null)
                Text(_resultText!, style: const TextStyle(color: Colors.black54)),
            ],
          ),

          if (_lastResponse != null) ...[
            const SizedBox(height: 16),
            _card(
              title: 'Détails retour serveur',
              child: SelectableText(const JsonEncoder.withIndent('  ').convert(_lastResponse)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _preview() {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    final url   = _urlCtrl.text.trim();
    return Row(
      children: [
        const CircleAvatar(child: Icon(Icons.notifications)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? '(Titre)' : title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              body.isEmpty ? '(Message)' : body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(url, style: const TextStyle(color: Colors.blueGrey)),
            ]
          ]),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      elevation: 0.5,
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
