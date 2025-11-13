// lib/pages/wontanara/pages/page_services.dart
// 👉 Version "Entraide" avec demandes d’aide + chat éphémère.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ionicons/ionicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../theme_wontanara.dart';
import '../api_wontanara.dart';
import '../models.dart';
import '../constantes.dart';
import '../realtime_wontanara.dart';

class PageServices extends StatefulWidget {
  const PageServices({super.key});

  @override
  State<PageServices> createState() => _PageServicesState();
}

class _PageServicesState extends State<PageServices> {
  // 🔹 Demandes d’aide mockées pour l’instant
  final List<_DemandeAide> _demandes = [
    const _DemandeAide(
      titre: 'Besoin de courses – secteur Kipé',
      details: 'Expire dans 6 h • réputation +15',
      localisation: 'Secteur Kipé, près du rond-point',
      photos: [],
    ),
    const _DemandeAide(
      titre: 'Accompagnement au centre de santé demain',
      details: 'Demain à 9 h • réputation +20',
      localisation: 'Centre de santé de Kipé',
      photos: ['photo1', 'photo2'], // maquette : 2 photos
    ),
    const _DemandeAide(
      titre: 'Garde d’enfant pour ce soir',
      details: 'Ce soir 18–21 h • réputation +10',
      localisation: 'Immeuble Safia, 3e étage',
      photos: ['photo1'], // maquette : 1 photo
    ),
  ];

  void _ouvrirChat(_DemandeAide d) {
    // 🔑 on génère une clé de room éphémère à partir du titre + type
    final roomKey = 'EPHEMERE_${d.type}_${d.titre.hashCode}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageChatEphemere(
          titre: d.titre,
          type: d.type,
          roomId: roomKey,
        ),
      ),
    );
  }

  void _ouvrirFormDemande() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _PageDemandeAideForm(),
      ),
    );
    // plus tard : recharger depuis Supabase
  }

  void _ouvrirPhotos(_DemandeAide d, int index) {
    if (d.photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotosViewerPage(
          photos: d.photos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Entraide',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Demandes d’aide proches'),
          const SizedBox(height: 8),
          if (_demandes.isEmpty)
            const Text(
              'Aucune demande d’aide pour l’instant.',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._demandes.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DemandeCard(
                  demande: d,
                  onAider: () => _ouvrirChat(d),
                  onPhotoTap: (i) => _ouvrirPhotos(d, i),
                ),
              ),
            ),
          const SizedBox(height: 80), // espace sous la liste
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormDemande,
        backgroundColor: ThemeWontanara.vertPetrole,
        foregroundColor: Colors.white,
        icon: const Icon(Ionicons.help_circle_outline),
        label: const Text(
          'Demander aide',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/* ============================================================
 *  Demandes d’aide
 * ==========================================================*/

class _DemandeAide {
  final String titre;
  final String details;
  final String localisation;
  final List<String> photos; // max 2 (maquette)
  final String type; // pour l’instant toujours 'entraide'

  const _DemandeAide({
    required this.titre,
    required this.details,
    required this.localisation,
    this.photos = const [],
    this.type = 'entraide',
  });
}

class _DemandeCard extends StatelessWidget {
  final _DemandeAide demande;
  final VoidCallback onAider;
  final void Function(int index)? onPhotoTap;

  const _DemandeCard({
    required this.demande,
    required this.onAider,
    this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardBox,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ThemeWontanara.menthe,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: ThemeWontanara.vertPetrole,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      demande.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      demande.details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeWontanara.texte2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: ThemeWontanara.vertPetrole,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            demande.localisation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ThemeWontanara.texte2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAider,
                style: TextButton.styleFrom(
                  foregroundColor: ThemeWontanara.vertPetrole,
                ),
                child: const Text(
                  'Je peux aider',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (demande.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                demande.photos.length,
                (i) => Padding(
                  padding: EdgeInsets.only(
                    right: i == demande.photos.length - 1 ? 0 : 8,
                  ),
                  child: _PhotoThumb(
                    index: i,
                    onTap: () => onPhotoTap?.call(i),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Miniature de photo (maquette)
class _PhotoThumb extends StatelessWidget {
  final int index;
  final VoidCallback? onTap;

  const _PhotoThumb({required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: ThemeWontanara.menthe,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_rounded,
          color: ThemeWontanara.vertPetrole,
        ),
      ),
    );
  }
}

/* ============================================================
 *  FORMULAIRE : Nouvelle demande d’aide
 * ==========================================================*/

class _PageDemandeAideForm extends StatefulWidget {
  const _PageDemandeAideForm({super.key});

  @override
  State<_PageDemandeAideForm> createState() => _PageDemandeAideFormState();
}

class _PageDemandeAideFormState extends State<_PageDemandeAideForm> {
  final _titreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  int _photoCount = 0; // 0 → 2

  Position? _position;
  bool _locLoading = false;
  String? _locError;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locError = "Activez la localisation sur votre téléphone.";
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _locError = "Autorisation localisation refusée.";
      });
      return false;
    }

    setState(() => _locError = null);
    return true;
  }

  Future<void> _onLocate() async {
    if (_locLoading) return;

    final ok = await _ensureLocationPermission();
    if (!ok) return;

    try {
      setState(() {
        _locLoading = true;
      });
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
        _locLoading = false;
        _locCtrl.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      setState(() {
        _locLoading = false;
        _locError = "Impossible de récupérer la position.";
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    }
  }

  void _addPhoto() {
    setState(() {
      if (_photoCount < 2) _photoCount++;
    });
    // plus tard : ouvrir galerie + stocker le fichier
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    // TODO : envoyer la demande d’aide vers Supabase (avec _position)
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: const Text(
          'Nouvelle demande d’aide',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Détails de la demande'),
              const SizedBox(height: 8),
              _Field(
                controller: _titreCtrl,
                label: 'Titre',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Titre obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _descCtrl,
                label: 'Description',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Localisation précise'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locCtrl,
                      readOnly: true,
                      validator: (_) => _position == null
                          ? 'La localisation est obligatoire'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Position GPS',
                        hintText: 'Appuyez sur "Se localiser"',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: ThemeWontanara.vertPetrole,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _locLoading ? null : _onLocate,
                      icon: _locLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text(
                        'Se localiser',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeWontanara.vertPetrole,
                        side: const BorderSide(
                            color: ThemeWontanara.vertPetrole, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_locError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _locError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionTitle('Photos (max. 2)'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _photoCount; i++)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _PhotoSlot(hasImage: true),
                      ),
                    if (_photoCount < 2)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PhotoSlot(
                          isAddButton: true,
                          onTap: _addPhoto,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeWontanara.vertPetrole,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Publier ma demande d’aide',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ThemeWontanara.vertPetrole, width: 1.2),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final bool hasImage;
  final bool isAddButton;
  final VoidCallback? onTap;

  const _PhotoSlot({
    this.hasImage = false,
    this.isAddButton = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 80.0;

    Widget child;
    if (isAddButton) {
      child = const Icon(
        Icons.add_a_photo_rounded,
        color: ThemeWontanara.vertPetrole,
      );
    } else if (hasImage) {
      child = const Icon(
        Icons.image_rounded,
        color: ThemeWontanara.vertPetrole,
      );
    } else {
      child = const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/* ============================================================
 *  Viewer plein écran des photos (swipe)
 * ==========================================================*/

class _PhotosViewerPage extends StatefulWidget {
  final List<String> photos; // pour l’instant simples identifiants
  final int initialIndex;

  const _PhotosViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<_PhotosViewerPage> createState() => _PhotosViewerPageState();
}

class _PhotosViewerPageState extends State<_PhotosViewerPage> {
  late PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _index = widget.initialIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_index + 1}/${widget.photos.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          // plus tard : afficher la vraie image (Network/Image.file…)
          return Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_rounded,
                size: 120,
                color: Colors.white70,
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ============================================================
 *  Chat éphémère (48 h côté backend) — BRANCHÉ
 * ==========================================================*/

class PageChatEphemere extends StatefulWidget {
  final String titre;
  final String type; // 'entraide' ou 'service'
  final String roomId; // clé de room éphémère

  const PageChatEphemere({
    super.key,
    required this.titre,
    required this.type,
    required this.roomId,
  });

  @override
  State<PageChatEphemere> createState() => _PageChatEphemereState();
}

class _PageChatEphemereState extends State<PageChatEphemere> {
  final TextEditingController _msg = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<Message> _messages = [];
  RealtimeChannel? _channel;

  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _roomKey => widget.roomId; // alias pour la lisibilité

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msg.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _loadMessages();
    await _listenRealtime();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // 🧩 on réutilise le même endpoint que le chat de quartier
      final res = await ApiChat.listerMessages(_roomKey);

      if (!mounted) return;
      setState(() {
        _messages = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible de charger les messages.";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement messages : $e")),
      );
    }
  }

  Future<void> _listenRealtime() async {
    try {
      _channel = await RealtimeWontanara.abonnMessagesZone(
        _roomKey,
        (row) {
          final m = Message.fromMap(row);
          if (!mounted) return;

          setState(() {
            _messages.insert(0, m); // ListView.reverse = true
          });
          _scrollToLatest();
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur abonnement temps réel : $e")),
      );
    }
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final txt = _msg.text.trim();
    if (txt.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    _msg.clear();

    setState(() => _sending = true);

    try {
      // Le realtime ajoutera le message (évite les doublons)
      await ApiChat.envoyerMessageZone(_roomKey, txt);
    } catch (e) {
      if (!mounted) return;
      _msg.text = txt;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur envoi message : $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.type == 'service' ? 'service' : 'entraide';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: ThemeWontanara.texte,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.titre,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Chat éphémère de $suffix (48 h)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesArea()),
          const Divider(height: 0),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Ionicons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Aucun message pour l’instant.\nDémarrez la discussion 👋",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, index) {
        final m = _messages[index];
        // Pour l’instant on n’a pas la notion "fromMe" → tout à gauche
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(m.contenu),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msg,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Écrire un message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Ionicons.send),
              color: ThemeWontanara.vertPetrole,
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 *  Helpers UI
 * ==========================================================*/

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ThemeWontanara.vertPetrole,
      ),
    );
  }
}

final _cardBox = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);
