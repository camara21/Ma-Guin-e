// lib/pages/billetterie/pro_evenements_page.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ⬇️ Ajouts: on relie les pages par redirection directe
import 'pro_ventes_page.dart';
import 'ticket_scanner_page.dart';

class ProEvenementsPage extends StatefulWidget {
  const ProEvenementsPage({super.key});

  @override
  State<ProEvenementsPage> createState() => _ProEvenementsPageState();
}

class _ProEvenementsPageState extends State<ProEvenementsPage> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  // Données
  List<Map<String, dynamic>> _events = [];

  // Organisateur
  String? _orgId;
  bool? _orgVerified; // null => pas encore déterminé
  bool _orgChecked = false; // a-t-on fini le check ?

  // Couleurs billetterie
  static const _kEventPrimary = Color(0xFF7B2CBF);
  static const _kOnPrimary = Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _rowIsVerified(Map<String, dynamic> row) => row['verifie'] == true;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        throw 'Veuillez vous connecter.';
      }

      // 1) Trouver l’organisateur (on ne lit que les colonnes existantes)
      final orgRaw = await _sb
          .from('organisateurs')
          .select('id, verifie')
          .eq('user_id', user.id)
          .limit(1);

      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) {
        // Pas d’organisateur encore créé
        _orgId = null;
        _orgVerified = null;
        _orgChecked = true;
        _events = [];
        setState(() {});
        return;
      }

      final org = orgList.first;
      _orgId = org['id'].toString();
      _orgVerified = _rowIsVerified(org);
      _orgChecked = true;

      // 2) Si pas vérifié, on n’affiche pas les events (message gate dans le build)
      if (_orgVerified != true) {
        _events = [];
        setState(() {});
        return;
      }

      // 3) Charger les événements
      final rowsRaw = await _sb
          .from('evenements')
          .select('*')
          .eq('organisateur_id', _orgId!)
          .order('date_debut', ascending: false);

      _events = (rowsRaw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateEvent() async {
    if (_orgVerified != true || _orgId == null) return;
    await showDialog(context: context, builder: (_) => const _CreateEventDialog());
    if (mounted) _load();
  }

  Future<void> _openCreateTicket(String eventId) async {
    if (_orgVerified != true) return;
    await showDialog(context: context, builder: (_) => _CreateTicketsDialog(eventId: eventId));
    if (mounted) _load();
  }

  void _openStats() {
    if (_orgVerified != true) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProVentesPage()));
  }

  void _openScanner() {
    if (_orgVerified != true) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScannerPage()));
  }

  Future<void> _confirmDeleteEvent(String eventId, String title) async {
    if (_orgVerified != true) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l’événement'),
        content: Text(
          'Voulez-vous vraiment supprimer l’événement « $title » ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Optimisme UI
    setState(() {
      _events.removeWhere((e) => e['id'].toString() == eventId);
    });

    try {
      // Supprimer d’abord les billets liés (si contrainte)
      await _sb.from('billets').delete().eq('evenement_id', eventId);
    } catch (_) {
      // ignore soft-fail
    }

    try {
      await _sb.from('evenements').delete().eq('id', eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement supprimé.')),
        );
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // État “pas de profil organisateur”
    if (_orgChecked && _orgId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _kEventPrimary,
          foregroundColor: _kOnPrimary,
          title: const Text('Mes événements'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Créez d’abord votre profil organisateur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraîchir'),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF7F7F7),
      );
    }

    // État “profil en cours de vérification”
    if (_orgChecked && _orgVerified == false) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _kEventPrimary,
          foregroundColor: _kOnPrimary,
          title: const Text('Mes événements'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, size: 56, color: Colors.amber),
                const SizedBox(height: 12),
                const Text(
                  'Votre profil est en cours de vérification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dès que votre compte sera validé, vous pourrez publier et gérer vos événements.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Vérifier à nouveau'),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF7F7F7),
      );
    }

    // Loading / erreur générique
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _kEventPrimary,
          foregroundColor: _kOnPrimary,
          title: const Text('Mes événements'),
        ),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: const Color(0xFFF7F7F7),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _kEventPrimary,
          foregroundColor: _kOnPrimary,
          title: const Text('Mes événements'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur: $_error'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF7F7F7),
      );
    }

    // Page principale (organisateur vérifié)
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Mes événements'),
        actions: [
          IconButton(
            tooltip: 'Ventes & statistiques',
            icon: const Icon(Icons.query_stats),
            onPressed: _openStats,
          ),
          IconButton(
            tooltip: 'Scanner des billets',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openScanner,
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add),
              label: const Text('Publier un événement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _kEventPrimary,
              ),
            ),
          ),
        ],
      ),
      body: _events.isEmpty
          ? const Center(child: Text('Aucun événement pour le moment.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (_, i) {
                final e = _events[i];
                final df = DateFormat('d MMM yyyy • HH:mm', 'fr_FR');
                final d1 = DateTime.parse(e['date_debut'].toString());
                final imageKey = (e['image_url'] ?? '').toString(); // key (pas URL)
                final thumb = _publicImageUrl(imageKey);
                final title = (e['titre'] ?? '').toString();
                final id = e['id'].toString();

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.secondary.withOpacity(.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (thumb != null && thumb.isNotEmpty)
                          ? Image.network(thumb, width: 64, height: 64, fit: BoxFit.cover)
                          : Container(
                              width: 64,
                              height: 64,
                              color: const Color(0xFFEFE7FF),
                              child: const Icon(Icons.event, color: Color(0xFF9A77D6)),
                            ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${e['ville'] ?? ''} • ${e['lieu'] ?? ''}\n${df.format(d1)}',
                      maxLines: 2,
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDeleteEvent(id, title),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (v) {
                            if (v == 'ticket') _openCreateTicket(id);
                            if (v == 'scanner') _openScanner();
                            if (v == 'stats') _openStats();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'ticket',
                              child: Row(
                                children: [
                                  Icon(Icons.confirmation_num_outlined),
                                  SizedBox(width: 8),
                                  Text('Ajouter / gérer les billets'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'scanner',
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_scanner),
                                  SizedBox(width: 8),
                                  Text('Scanner des billets'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'stats',
                              child: Row(
                                children: [
                                  Icon(Icons.query_stats),
                                  SizedBox(width: 8),
                                  Text('Ventes & statistiques'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _events.length,
            ),
      backgroundColor: const Color(0xFFF7F7F7),
    );
  }

  String? _publicImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _sb.storage.from('evenement-photos').getPublicUrl(path);
  }
}

///// ---------- DIALOG: CRÉER ÉVÉNEMENT (avec BILLETS obligatoires) ----------
class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _TicketRowData {
  final TextEditingController titre;
  final TextEditingController prix;
  final TextEditingController stock;
  final TextEditingController limite;
  bool actif;
  int ordre;
  final bool locked; // titre non modifiable + non supprimable

  _TicketRowData({
    required String t,
    String p = '',
    String s = '',
    String l = '',
    this.actif = true,
    required this.ordre,
    this.locked = false,
  })  : titre = TextEditingController(text: t),
        prix = TextEditingController(text: p),
        stock = TextEditingController(text: s),
        limite = TextEditingController(text: l);
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  // MAX int32 Postgres
  static const int _maxInt = 2147483647;

  // Champs
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _ville = TextEditingController(text: 'Conakry');
  final _lieu = TextEditingController();

  // Catégories
  static const _kEventPrimary = Color(0xFF7B2CBF);
  final List<String> _categories = const [
    'concert',
    'festival',
    'sport',
    'conférence',
    'kermesse',
    'théâtre',
    'party',
  ];
  String _selectedCat = 'concert';

  // Dates
  DateTime _debut = DateTime.now().add(const Duration(days: 7));
  DateTime _fin = DateTime.now().add(const Duration(days: 7, hours: 2));
  bool _publie = true;
  bool _sending = false;

  // Image
  Uint8List? _imageBytes; // preview
  String? _imageKey; // objet stocké (path)
  String? _uploadErr;

  // Inline error (au lieu de SnackBar derrière le dialog)
  String? _inlineErr;

  // Billets (obligatoires)
  final List<_TicketRowData> _tickets = [
    _TicketRowData(t: 'Standard', ordre: 1, locked: true),
    _TicketRowData(t: 'VIP', ordre: 2, locked: true),
    _TicketRowData(t: 'VVIP', ordre: 3, locked: true),
  ];

  @override
  void initState() {
    super.initState();
    for (final c in [_titre, _ville, _lieu, _desc]) {
      c.addListener(_onAnyFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_titre, _ville, _lieu, _desc]) {
      c.removeListener(_onAnyFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onAnyFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    setState(() {
      _uploadErr = null;
      _inlineErr = null;
    });
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();

      final user = _sb.auth.currentUser;
      if (user == null) {
        setState(() => _uploadErr = "Veuillez vous connecter.");
        return;
      }

      // Récup organiser id
      final orgRaw =
          await _sb.from('organisateurs').select('id').eq('user_id', user.id).limit(1);
      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) {
        setState(() => _uploadErr = "Créez d’abord un profil organisateur.");
        return;
      }
      final orgId = orgList.first['id'].toString();

      final key = await _uploadEventImage(bytes, orgId);
      if (key == null) {
        setState(() => _uploadErr = "Échec de l’upload de l’image.");
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageKey = key; // on garde le path (compat HomePage)
      });
    } catch (e) {
      setState(() => _uploadErr = "Erreur image: $e");
    }
  }

  Future<String?> _uploadEventImage(Uint8List bytes, String orgId) async {
    final mime = lookupMimeType('', headerBytes: bytes) ?? 'application/octet-stream';
    String ext = 'bin';
    if (mime.contains('jpeg')) ext = 'jpg';
    else if (mime.contains('png')) ext = 'png';
    else if (mime.contains('webp')) ext = 'webp';

    final ts = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'org/$orgId/events/$ts.$ext';

    await _sb.storage.from('evenement-photos').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        );
    // On renvoie la **clé** (path), pas l’URL publique
    return objectPath;
  }

  void _addTicketRow() {
    setState(() {
      _tickets.add(_TicketRowData(
        t: 'Autre',
        ordre: _tickets.length + 1,
        locked: false,
      ));
      _inlineErr = null;
    });
  }

  void _removeTicketRow(int index) {
    if (_tickets[index].locked) return;
    setState(() {
      _tickets.removeAt(index);
      _inlineErr = null;
    });
  }

  bool _validateTickets({bool setInlineError = true}) {
    final active = _tickets.where((t) => t.actif).toList();
    if (active.isEmpty) {
      if (setInlineError) _inlineErr = 'Ajoutez au moins un type de billet actif.';
      return false;
    }
    for (final t in active) {
      final title = t.titre.text.trim();
      if (title.isEmpty) {
        if (setInlineError) _inlineErr = 'Le titre d’un type de billet est vide.';
        return false;
      }

      // Prix avec borne supérieure (int32 Postgres)
      final prixTxt = t.prix.text.replaceAll(' ', '').trim();
      final prix = int.tryParse(prixTxt);
      if (prix == null || prix <= 0 || prix > _maxInt) {
        if (setInlineError) {
          _inlineErr = (prix != null && prix > _maxInt)
              ? 'Le prix pour "$title" est trop élevé (max 2 147 483 647 GNF).'
              : 'Renseignez un prix > 0 pour "$title".';
        }
        return false;
      }

      final stock = int.tryParse(t.stock.text);
      if (stock == null || stock <= 0) {
        if (setInlineError) _inlineErr = 'Renseignez un stock > 0 pour "$title".';
        return false;
      }
      if (t.ordre <= 0) {
        if (setInlineError) _inlineErr = 'L’ordre d’affichage doit être positif pour "$title".';
        return false;
      }
      final lim = t.limite.text.trim();
      if (lim.isNotEmpty) {
        final l = int.tryParse(lim);
        if (l == null || l < 0) {
          if (setInlineError) _inlineErr = 'La limite par utilisateur est invalide pour "$title".';
          return false;
        }
      }
    }
    return true;
  }

  bool _datesOK({bool setInlineError = true}) {
    if (!_fin.isAfter(_debut)) {
      if (setInlineError) {
        _inlineErr = 'La date de fin doit être postérieure à la date de début.';
      }
      return false;
    }
    return true;
  }

  bool _canSubmit() {
    final baseFieldsOK = _titre.text.trim().isNotEmpty &&
        _ville.text.trim().isNotEmpty &&
        _lieu.text.trim().isNotEmpty;

    final ticketsOK = _validateTickets(setInlineError: false);
    final datesOk = _datesOK(setInlineError: false);

    return baseFieldsOK && ticketsOK && datesOk && !_sending;
  }

  Future<void> _submit() async {
    _inlineErr = null;

    if (!_form.currentState!.validate()) {
      setState(() => _inlineErr = 'Veuillez compléter les champs obligatoires.');
      return;
    }
    if (!_datesOK()) {
      setState(() {}); // affiche _inlineErr
      return;
    }
    if (!_validateTickets()) {
      setState(() {}); // affiche _inlineErr
      return;
    }

    setState(() => _sending = true);
    try {
      final user = _sb.auth.currentUser;
      if (user == null) throw 'Veuillez vous connecter.';
      final orgRaw = await _sb
          .from('organisateurs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) throw 'Crée d’abord un profil organisateur.';
      final orgId = orgList.first['id'];

      // 1) Créer l'événement
      final created = await _sb.from('evenements').insert({
        'organisateur_id': orgId,
        'titre': _titre.text.trim(),
        'description': _desc.text.trim(),
        'categorie': _selectedCat,
        'ville': _ville.text.trim(),
        'lieu': _lieu.text.trim(),
        'date_debut': _debut.toIso8601String(),
        'date_fin': _fin.toIso8601String(),
        'image_url': _imageKey, // <-- path stocké
        'is_published': _publie,
        'is_cancelled': false,
      }).select('id').single();

      final String eventId = created['id'].toString();

      // 2) Insérer immédiatement les billets saisis
      final payload = <Map<String, dynamic>>[];
      for (final r in _tickets) {
        if (!r.actif) continue; // on n'enregistre pas les inactifs
        final prix = int.parse(r.prix.text.replaceAll(' ', '').trim());
        final stock = int.parse(r.stock.text);
        final lim = r.limite.text.trim().isEmpty ? null : int.parse(r.limite.text.trim());
        payload.add({
          'evenement_id': eventId,
          'titre': r.titre.text.trim(),
          'prix_gnf': prix,
          'stock_total': stock,
          'limite_par_utilisateur': lim,
          'actif': true,
          'ordre': r.ordre,
        });
      }
      if (payload.isNotEmpty) {
        await _sb.from('billets').insert(payload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Événement créé et billets enregistrés.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inlineErr = 'Erreur: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _debut : _fin;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null) return;
    setState(() {
      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (isStart) {
        _debut = dt;
        if (_fin.isBefore(_debut)) {
          _fin = _debut.add(const Duration(hours: 2));
        }
      } else {
        _fin = dt;
      }
      _inlineErr = null;
    });
  }

  Widget _ticketCard(int i, _TicketRowData r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: r.titre,
                    decoration: InputDecoration(
                      labelText: 'Titre',
                      suffixIcon: r.locked
                          ? const Tooltip(
                              message: 'Type principal',
                              child: Icon(Icons.lock, size: 18),
                            )
                          : null,
                    ),
                    readOnly: r.locked,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                    onChanged: (_) => setState(() => _inlineErr = null),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: r.locked ? null : () => _removeTicketRow(i),
                  icon: Icon(
                    r.locked ? Icons.lock_outline : Icons.delete_outline,
                    color: r.locked ? Colors.grey : Colors.red,
                  ),
                  tooltip: r.locked ? 'Type principal non supprimable' : 'Supprimer',
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: r.prix,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix (GNF) *'),
                    onChanged: (_) => setState(() => _inlineErr = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: r.stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock total *'),
                    onChanged: (_) => setState(() => _inlineErr = null),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: r.limite,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Limite par utilisateur (optionnel)',
                    ),
                    onChanged: (_) => setState(() => _inlineErr = null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: r.ordre.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ordre d’affichage'),
                    onChanged: (v) {
                      r.ordre = int.tryParse(v) ?? r.ordre;
                      setState(() => _inlineErr = null);
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              value: r.actif,
              onChanged: (v) => setState(() {
                r.actif = v;
                _inlineErr = null;
              }),
              title: const Text('Actif'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _canSubmit();

    return AlertDialog(
      title: const Text('Créer un événement'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_inlineErr != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB3B3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineErr!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Image
              Center(
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1E9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7D9FF)),
                      image: (_imageBytes != null)
                          ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo, color: _kEventPrimary),
                              SizedBox(height: 6),
                              Text('Ajouter une photo de couverture'),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              if (_uploadErr != null) ...[
                const SizedBox(height: 6),
                Text(_uploadErr!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),

              TextFormField(
                controller: _titre,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                onChanged: (_) => setState(() => _inlineErr = null),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onChanged: (_) => setState(() => _inlineErr = null),
              ),
              const SizedBox(height: 8),

              // Catégories (chips)
              const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) {
                  final selected = _selectedCat == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedCat = c;
                      _inlineErr = null;
                    }),
                    backgroundColor: const Color(0xFFF7F3FF),
                    selectedColor: _kEventPrimary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selected
                            ? _kEventPrimary
                            : _kEventPrimary.withOpacity(.25),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ville,
                      decoration: const InputDecoration(labelText: 'Ville'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                      onChanged: (_) => setState(() => _inlineErr = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lieu,
                      decoration: const InputDecoration(labelText: 'Lieu'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                      onChanged: (_) => setState(() => _inlineErr = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: _DateBox(
                      label: 'Début',
                      date: _debut,
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateBox(
                      label: 'Fin',
                      date: _fin,
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                value: _publie,
                onChanged: (v) => setState(() {
                  _publie = v;
                  _inlineErr = null;
                }),
                title: const Text('Publié'),
                activeColor: _kEventPrimary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),

              const Divider(),
              const SizedBox(height: 6),
              const Text(
                'Types de billets (obligatoires)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ..._tickets.asMap().entries.map((e) => _ticketCard(e.key, e.value)),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addTicketRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un type'),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ℹ️ Les types Standard / VIP / VVIP sont pré-ajoutés (titres verrouillés). '
                  'Renseignez au moins un type actif avec un prix et un stock strictement positifs.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: ready ? _submit : null, // ⬅️ grisé tant que pas prêt
          style: ElevatedButton.styleFrom(
            backgroundColor: _kEventPrimary,
            foregroundColor: Colors.white,
          ),
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Créer et enregistrer les billets'),
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateBox({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE7D9FF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, color: Color(0xFF9A77D6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(DateFormat('dd/MM/yyyy HH:mm').format(date)),
            ),
            const Icon(Icons.edit_calendar, color: Color(0xFF9A77D6)),
          ],
        ),
      ),
    );
  }
}

///// ---------- DIALOG: MULTI-BILLETS (post-édition) ----------
class _CreateTicketsDialog extends StatefulWidget {
  final String eventId;
  const _CreateTicketsDialog({required this.eventId});

  @override
  State<_CreateTicketsDialog> createState() => _CreateTicketsDialogState();
}

class _TicketRow {
  final TextEditingController titre;
  final TextEditingController prix;
  final TextEditingController stock;
  final TextEditingController limite;
  bool actif;
  int ordre;
  bool locked; // ⬅️ non supprimable si true

  _TicketRow({
    required String t,
    required String p,
    required String s,
    required String l,
    required this.actif,
    required this.ordre,
    this.locked = false,
  })  : titre = TextEditingController(text: t),
        prix = TextEditingController(text: p),
        stock = TextEditingController(text: s),
        limite = TextEditingController(text: l);
}

class _CreateTicketsDialogState extends State<_CreateTicketsDialog> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final List<_TicketRow> _rows = [
    _TicketRow(t: 'Standard', p: '', s: '', l: '', actif: true, ordre: 1, locked: true),
    _TicketRow(t: 'VIP',      p: '', s: '', l: '', actif: true, ordre: 2, locked: true),
    _TicketRow(t: 'VVIP',     p: '', s: '', l: '', actif: true, ordre: 3, locked: true),
  ];
  bool _sending = false;

  // MAX int32 Postgres
  static const int _maxInt = 2147483647;

  void _addRow() {
    setState(() {
      _rows.add(_TicketRow(
        t: 'Autre',
        p: '',
        s: '',
        l: '',
        actif: true,
        ordre: _rows.length + 1,
      ));
    });
  }

  void _removeRow(int index) {
    if (_rows[index].locked) return; // protégé
    setState(() => _rows.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    // Validation stricte
    final active = _rows.where((r) => r.actif).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un type de billet actif.')),
      );
      return;
    }
    for (final r in active) {
      final title = r.titre.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le titre d’un type de billet est vide.')),
        );
        return;
      }
      final prixTxt = r.prix.text.replaceAll(' ', '').trim();
      final prix = int.tryParse(prixTxt);
      if (prix == null || prix <= 0 || prix > _maxInt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (prix != null && prix > _maxInt)
                  ? 'Le prix pour "$title" est trop élevé (max 2 147 483 647 GNF).'
                  : 'Renseignez un prix > 0 pour "$title".',
            ),
          ),
        );
        return;
      }

      final stock = int.tryParse(r.stock.text);
      if (stock == null || stock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renseignez un stock > 0 pour "$title".')),
        );
        return;
      }
      final limTxt = r.limite.text.trim();
      if (limTxt.isNotEmpty) {
        final lim = int.tryParse(limTxt);
        if (lim == null || lim < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Limite invalide pour "$title".')),
          );
          return;
        }
      }
    }

    setState(() => _sending = true);
    try {
      final payload = <Map<String, dynamic>>[];
      for (final r in active) {
        final prix = int.parse(r.prix.text.replaceAll(' ', '').trim());
        final stock = int.parse(r.stock.text);
        final lim = r.limite.text.trim().isEmpty ? null : int.parse(r.limite.text.trim());
        payload.add({
          'evenement_id': widget.eventId,
          'titre': r.titre.text.trim(),
          'prix_gnf': prix,
          'stock_total': stock,
          'limite_par_utilisateur': lim,
          'actif': true,
          'ordre': r.ordre,
        });
      }
      if (payload.isNotEmpty) {
        await _sb.from('billets').insert(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter des types de billets'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              ..._rows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x22000000)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: r.titre,
                                decoration: InputDecoration(
                                  labelText: 'Titre',
                                  suffixIcon: r.locked
                                      ? const Tooltip(
                                          message: 'Type principal',
                                          child: Icon(Icons.lock, size: 18),
                                        )
                                      : null,
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                                readOnly: r.locked, // nom non modifiable si verrouillé
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: r.locked ? null : () => _removeRow(i),
                              icon: Icon(
                                r.locked ? Icons.lock_outline : Icons.delete_outline,
                                color: r.locked ? Colors.grey : Colors.red,
                              ),
                              tooltip: r.locked ? 'Type principal non supprimable' : 'Supprimer',
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: r.prix,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Prix (GNF) *'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: r.stock,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Stock total *'),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: r.limite,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Limite par utilisateur (optionnel)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: r.ordre.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Ordre d’affichage'),
                                onChanged: (v) => r.ordre = int.tryParse(v) ?? r.ordre,
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          value: r.actif,
                          onChanged: (v) => setState(() => r.actif = v),
                          title: const Text('Actif'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un type'),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ℹ️ Les types Standard / VIP / VVIP sont verrouillés par défaut. '
                  'Renseignez prix et stock (> 0) avant d’enregistrer.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B2CBF),
            foregroundColor: Colors.white,
          ),
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
