// lib/pages/logement/logement_edit_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/logement_service.dart';
import '../../models/logement_models.dart';

class LogementEditPage extends StatefulWidget {
  const LogementEditPage({super.key, this.existing});
  final LogementModel? existing;

  @override
  State<LogementEditPage> createState() => _LogementEditPageState();
}

class _LogementEditPageState extends State<LogementEditPage> {
  final _form = GlobalKey<FormState>();
  final _svc = LogementService();

  // ---------- Palette "Action Logement" ----------
  Color get _primary => const Color(0xFF0B3A6A); // bleu profond (header)
  Color get _accent  => const Color(0xFFE1005A); // fuchsia (CTA)
  bool  get _isDark  => Theme.of(context).brightness == Brightness.dark;
  Color get _bg      => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _fieldFill => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF6F7FB);
  Color get _chipBg  => _isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);

  // Champs
  late TextEditingController _titre;
  late TextEditingController _desc;
  late TextEditingController _prix;
  late TextEditingController _ville;
  late TextEditingController _commune;
  late TextEditingController _adresse;
  late TextEditingController _surface;

  // Téléphone de contact (obligatoire)
  late TextEditingController _phone;

  int _chambres = 0;
  LogementMode _mode = LogementMode.location;
  LogementCategorie _cat = LogementCategorie.autres;

  // Photos (max 10)
  static const _kMaxPhotos = 10;
  final List<_PhotoItem> _photos = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titre    = TextEditingController(text: e?.titre ?? '');
    _desc     = TextEditingController(text: e?.description ?? '');
    _prix     = TextEditingController(text: e?.prixGnf?.toString() ?? '');
    _ville    = TextEditingController(text: e?.ville ?? '');
    _commune  = TextEditingController(text: e?.commune ?? '');
    _adresse  = TextEditingController(text: e?.adresse ?? '');
    _surface  = TextEditingController(text: e?.superficieM2?.toString() ?? '');
    // Si ton modèle a contactTelephone, remplace null par e?.contactTelephone
    _phone    = TextEditingController(/* text: e?.contactTelephone ?? '' */);

    _chambres = e?.chambres ?? 0;
    _mode     = e?.mode ?? LogementMode.location;
    _cat      = e?.categorie ?? LogementCategorie.autres;

    // Photos existantes -> items "url"
    for (final u in e?.photos ?? const <String>[]) {
      if (u.trim().isNotEmpty) _photos.add(_PhotoItem(url: u.trim()));
    }
  }

  @override
  void dispose() {
    _titre.dispose();
    _desc.dispose();
    _prix.dispose();
    _ville.dispose();
    _commune.dispose();
    _adresse.dispose();
    _surface.dispose();
    _phone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: _fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  // ─────────────────────────── UI ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(isEdit ? "Modifier le bien" : "Publier un bien"),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  TextFormField(
                    controller: _titre,
                    decoration: _dec("Titre *"),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Obligatoire" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 6,
                    decoration: _dec("Description"),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<LogementMode>(
                          value: _mode,
                          items: const [
                            DropdownMenuItem(value: LogementMode.location, child: Text("Location")),
                            DropdownMenuItem(value: LogementMode.achat, child: Text("Achat")),
                          ],
                          onChanged: (v) => setState(() => _mode = v ?? LogementMode.location),
                          decoration: _dec("Type d’opération *"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<LogementCategorie>(
                          value: _cat,
                          items: const [
                            DropdownMenuItem(value: LogementCategorie.maison, child: Text("Maison")),
                            DropdownMenuItem(value: LogementCategorie.appartement, child: Text("Appartement")),
                            DropdownMenuItem(value: LogementCategorie.studio, child: Text("Studio")),
                            DropdownMenuItem(value: LogementCategorie.terrain, child: Text("Terrain")),
                            DropdownMenuItem(value: LogementCategorie.autres, child: Text("Autres")),
                          ],
                          onChanged: (v) => setState(() => _cat = v ?? LogementCategorie.autres),
                          decoration: _dec("Catégorie *"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prix,
                          keyboardType: TextInputType.number,
                          decoration: _dec(_mode == LogementMode.achat ? "Prix (GNF)" : "Loyer mensuel (GNF)"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _surface,
                          keyboardType: TextInputType.number,
                          decoration: _dec("Superficie (m²)"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<int>(
                    value: _chambres,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text("Chambres (peu importe)")),
                      DropdownMenuItem(value: 1, child: Text("1")),
                      DropdownMenuItem(value: 2, child: Text("2")),
                      DropdownMenuItem(value: 3, child: Text("3")),
                      DropdownMenuItem(value: 4, child: Text("4")),
                      DropdownMenuItem(value: 5, child: Text("5+")),
                    ],
                    onChanged: (v) => setState(() => _chambres = v ?? 0),
                    decoration: _dec("Chambres"),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ville,
                          decoration: _dec("Ville"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _commune,
                          decoration: _dec("Commune / Quartier"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _adresse,
                    decoration: _dec("Adresse (optionnelle)"),
                  ),
                  const SizedBox(height: 10),

                  // Téléphone de contact (obligatoire)
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: _dec("Téléphone de contact *", hint: "+224 6x xx xx xx"),
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return "Numéro requis";
                      final ok = RegExp(r'^[0-9 +()\-]{6,20}$').hasMatch(val);
                      if (!ok) return "Numéro invalide";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _photosSection(),

                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? "Enregistrement..." : "Enregistrer"),
                  ),
                ],
              ),
            ),

            if (_saving)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x44000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Photos", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text("(${_photos.length}/$_kMaxPhotos)", style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            _addPhotoMenu(),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _photos.length + (_photos.length < _kMaxPhotos ? 1 : 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) => (i < _photos.length) ? _photoTile(i) : _addTile(),
        ),
        const SizedBox(height: 6),
        const Text(
          "Ajoute jusqu’à 10 photos. L’ordre affiché = ordre d’enregistrement.",
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _addPhotoMenu() {
    return PopupMenuButton<String>(
      tooltip: "Ajouter",
      onSelected: (v) {
        if (v == 'galerie') _pickFromGallery();
        if (v == 'url') _addUrlDialog();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'galerie', child: Text('Depuis la galerie')),
        PopupMenuItem(value: 'url', child: Text('Ajouter par URL')),
      ],
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _accent),
          foregroundColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Ajouter"),
        onPressed: null, // géré par PopupMenuButton
      ),
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _pickFromGallery,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(Icons.add, size: 36, color: _accent),
      ),
    );
  }

  Widget _photoTile(int index) {
    final p = _photos[index];
    final img = p.bytes != null
        ? Image.memory(p.bytes!, fit: BoxFit.cover)
        : Image.network(p.url!, fit: BoxFit.cover);

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(color: Colors.grey.shade200, child: img),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.black54,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            icon: const Icon(Icons.close, size: 18, color: Colors.white),
            onPressed: () => setState(() => _photos.removeAt(index)),
            tooltip: "Supprimer",
          ),
        ),
      ],
    );
  }

  // ─────────────────────── Ajout de photos ───────────────────────

  Future<void> _pickFromGallery() async {
    if (_photos.length >= _kMaxPhotos) return;
    final left = _kMaxPhotos - _photos.length;

    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    for (final f in files.take(left)) {
      final bytes = await f.readAsBytes();
      _photos.add(_PhotoItem(bytes: bytes, name: f.name));
    }
    setState(() {});
  }

  Future<void> _addUrlDialog() async {
    if (_photos.length >= _kMaxPhotos) return;
    final c = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter une photo par URL"),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: "https://...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text("Ajouter")),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      setState(() => _photos.add(_PhotoItem(url: url)));
    }
  }

  // ─────────────────────── Enregistrement ───────────────────────

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final model = LogementModel(
        id: widget.existing?.id ?? 'new',
        userId: widget.existing?.userId ?? '',
        titre: _titre.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        mode: _mode,
        categorie: _cat,
        prixGnf: _prix.text.trim().isEmpty ? null : num.tryParse(_prix.text.trim()),
        ville: _ville.text.trim().isEmpty ? null : _ville.text.trim(),
        commune: _commune.text.trim().isEmpty ? null : _commune.text.trim(),
        adresse: _adresse.text.trim().isEmpty ? null : _adresse.text.trim(),
        superficieM2: _surface.text.trim().isEmpty ? null : num.tryParse(_surface.text.trim()),
        chambres: _chambres == 0 ? null : _chambres,
        lat: widget.existing?.lat,
        lng: widget.existing?.lng,
        photos: const [], // remplacées après upload
        creeLe: widget.existing?.creeLe ?? DateTime.now(),
      );

      // 1) créer / mettre à jour la ligne logement
      String id;
      if (widget.existing == null) {
        id = await _svc.create(model);
      } else {
        id = widget.existing!.id;
        await _svc.updateFromModel(id, model);
      }

      // 1-bis) pousser le téléphone (colonne: contact_telephone)
      final tel = _phone.text.trim();
      await _svc.update(id, {'contact_telephone': tel});

      // 2) uploader les nouvelles photos
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p.url != null) {
          urls.add(p.url!);
        } else if (p.bytes != null) {
          final name = p.name ?? 'photo_$i.jpg';
          final res = await _svc.uploadPhoto(
            bytes: p.bytes!,
            filename: name,
            logementId: id,
          );
          urls.add(res.publicUrl);
        }
      }

      // 3) sauver l’ordre
      await _svc.setPhotos(id, urls);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existing == null ? "Annonce créée" : "Annonce mise à jour")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─────────────────────────── Types internes ───────────────────────────

class _PhotoItem {
  _PhotoItem({this.bytes, this.url, this.name});
  final Uint8List? bytes;  // photo locale à uploader
  final String? url;       // photo déjà en ligne
  final String? name;      // nom de fichier pour l’upload
}
