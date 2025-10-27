import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProEvenementsPage extends StatefulWidget {
  const ProEvenementsPage({super.key});

  @override
  State<ProEvenementsPage> createState() => _ProEvenementsPageState();
}

class _ProEvenementsPageState extends State<ProEvenementsPage> {
  final _sb = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _sb.auth.currentUser;
      if (user == null) throw 'Veuillez vous connecter.';

      // Récupère l’id organisateur
      final orgRaw = await _sb
          .from('organisateurs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);
      final orgList = (orgRaw as List).cast<Map<String, dynamic>>();
      if (orgList.isEmpty) throw 'Crée d’abord un profil organisateur.';
      final String orgId = orgList.first['id'].toString();

      final rowsRaw = await _sb
          .from('evenements')
          .select('*')
          .eq('organisateur_id', orgId)
          .order('date_debut', ascending: false);
      _events = (rowsRaw as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateEvent() async {
    await showDialog(context: context, builder: (_) => const _CreateEventDialog());
    if (mounted) _load();
  }

  Future<void> _openCreateTicket(String eventId) async {
    await showDialog(context: context, builder: (_) => _CreateTicketDialog(eventId: eventId));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: const Text('Mes événements'),
        actions: [
          IconButton(onPressed: _openCreateEvent, icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _events.isEmpty
                  ? const Center(child: Text('Aucun événement pour le moment.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (_, i) {
                        final e = _events[i];
                        final df = DateFormat('d MMM yyyy • HH:mm', 'fr_FR');
                        final d1 = DateTime.parse(e['date_debut'].toString());
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
                            title: Text(
                              (e['titre'] ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${e['ville'] ?? ''} • ${e['lieu'] ?? ''}\n${df.format(d1)}',
                              maxLines: 2,
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'ticket') _openCreateTicket(e['id'].toString());
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'ticket',
                                  child: Text('Ajouter un type de billet'),
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
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _cat = TextEditingController(text: 'concert');
  final _ville = TextEditingController(text: 'Conakry');
  final _lieu = TextEditingController();
  DateTime _debut = DateTime.now().add(const Duration(days: 7));
  DateTime _fin = DateTime.now().add(const Duration(days: 7, hours: 2));
  bool _publie = true;
  bool _sending = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
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

      await _sb.from('evenements').insert({
        'organisateur_id': orgId,
        'titre': _titre.text.trim(),
        'description': _desc.text.trim(),
        'categorie': _cat.text.trim(),
        'ville': _ville.text.trim(),
        'lieu': _lieu.text.trim(),
        'date_debut': _debut.toIso8601String(),
        'date_fin': _fin.toIso8601String(),
        'is_published': _publie,
      });
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
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Créer un événement'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _titre,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              TextFormField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextFormField(
                controller: _cat,
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
              TextFormField(
                controller: _ville,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              TextFormField(
                controller: _lieu,
                decoration: const InputDecoration(labelText: 'Lieu'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          'Début: ${DateFormat('dd/MM/yyyy HH:mm').format(_debut)}')),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        initialDate: _debut,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_debut),
                      );
                      if (t == null) return;
                      setState(() =>
                          _debut = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    },
                    child: const Text('Changer'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                      child:
                          Text('Fin: ${DateFormat('dd/MM/yyyy HH:mm').format(_fin)}')),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        initialDate: _fin,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_fin),
                      );
                      if (t == null) return;
                      setState(() =>
                          _fin = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    },
                    child: const Text('Changer'),
                  ),
                ],
              ),
              SwitchListTile(
                value: _publie,
                onChanged: (v) => setState(() => _publie = v),
                title: const Text('Publié'),
                activeColor: cs.primary,
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
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }
}

class _CreateTicketDialog extends StatefulWidget {
  final String eventId;
  const _CreateTicketDialog({required this.eventId});

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final _sb = Supabase.instance.client;
  final _form = GlobalKey<FormState>();
  final _titre = TextEditingController(text: 'Standard');
  final _desc = TextEditingController();
  final _prix = TextEditingController(text: '150000');
  final _stock = TextEditingController(text: '100');
  final _limite = TextEditingController(text: '4');
  bool _actif = true;
  bool _sending = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await _sb.from('billets').insert({
        'evenement_id': widget.eventId,
        'titre': _titre.text.trim(),
        'description': _desc.text.trim(),
        'prix_gnf': int.parse(_prix.text.replaceAll(' ', '')),
        'stock_total': int.parse(_stock.text),
        'limite_par_utilisateur': int.tryParse(_limite.text),
        'actif': _actif,
        'ordre': 1,
      });
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
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Ajouter un type de billet'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                  controller: _titre,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (v) => v!.isEmpty ? 'Requis' : null),
              TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2),
              TextFormField(
                  controller: _prix,
                  decoration: const InputDecoration(labelText: 'Prix (GNF)'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _stock,
                  decoration: const InputDecoration(labelText: 'Stock total'),
                  keyboardType: TextInputType.number),
              TextFormField(
                  controller: _limite,
                  decoration:
                      const InputDecoration(labelText: 'Limite par utilisateur'),
                  keyboardType: TextInputType.number),
              SwitchListTile(
                  value: _actif,
                  onChanged: (v) => setState(() => _actif = v),
                  title: const Text('Actif')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}
