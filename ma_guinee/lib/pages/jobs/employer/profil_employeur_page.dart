// lib/pages/jobs/employer/profil_employeur_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ma_guinee/services/employeur_service.dart';

class ProfilEmployeurPage extends StatefulWidget {
  const ProfilEmployeurPage({super.key});

  @override
  State<ProfilEmployeurPage> createState() => _ProfilEmployeurPageState();
}

class _ProfilEmployeurPageState extends State<ProfilEmployeurPage> {
  // Palette alignée avec le reste de l'app
  static const kBlue = Color(0xFF1976D2);
  static const kBg = Color(0xFFF6F7F9);

  // Bucket storage (public conseillé pour les logos)
  static const String _bucket = 'logos';

  final _svc = EmployeurService();
  final _sb = Supabase.instance.client;

  // Champs
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  final _ville = TextEditingController();
  final _commune = TextEditingController();
  final _secteur = TextEditingController();
  final _siteWeb = TextEditingController(); // si colonne existe
  final _logoUrl = TextEditingController(); // si colonne existe

  Map<String, dynamic>? _row;
  String? _employeurId;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingLogo = false;

  bool get _hasSiteWebColumn => _row?.containsKey('site_web') == true;
  bool get _hasLogoColumn => _row?.containsKey('logo_url') == true;
  bool get _hasLogo => _logoUrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _email.dispose();
    _ville.dispose();
    _commune.dispose();
    _secteur.dispose();
    _siteWeb.dispose();
    _logoUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _svc.getEmployeurRow();
      _row = r ?? {};
      _employeurId = (_row?['id'] ?? '').toString().isEmpty
          ? null
          : _row!['id'].toString();

      _nom.text = (_row?['nom'] ?? '').toString();
      _tel.text = (_row?['telephone'] ?? '').toString();
      _email.text = (_row?['email'] ?? '').toString();
      _ville.text = (_row?['ville'] ?? '').toString();
      _commune.text = (_row?['commune'] ?? '').toString();
      _secteur.text = (_row?['secteur'] ?? '').toString();

      // Ces deux champs ne seront envoyés que si la colonne existe côté BDD
      _siteWeb.text = (_row?['site_web'] ?? '').toString();
      _logoUrl.text = (_row?['logo_url'] ?? '').toString();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chargement impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final changes = <String, dynamic>{};

      void put(String key, String v) {
        final old = (_row?[key] ?? '').toString();
        if (v.trim() != old) changes[key] = v.trim();
      }

      put('nom', _nom.text);
      put('telephone', _tel.text);
      put('email', _email.text);
      put('ville', _ville.text);
      put('commune', _commune.text);
      put('secteur', _secteur.text);
      if (_hasSiteWebColumn) put('site_web', _siteWeb.text);
      if (_hasLogoColumn) put('logo_url', _logoUrl.text);

      if (changes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune modification')),
        );
      } else {
        await _svc.updateEmployeur(changes);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour')),
        );
        await _load();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Upload du logo
  Future<void> _changeLogoFromGallery() async {
    if (!_hasLogoColumn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La colonne "logo_url" est absente côté base.'),
        ),
      );
      return;
    }

    setState(() => _uploadingLogo = true);
    try {
      // 1) Choisir un fichier image (mobile/desktop/web)
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        setState(() => _uploadingLogo = false);
        return;
      }

      final file = res.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        setState(() => _uploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lire le fichier. Réessayez.')),
        );
        return;
      }

      // 2) Récupérer/assurer l’employeur_id pour ranger par dossier
      String? employeurId = _employeurId;
      if ((employeurId == null || employeurId.isEmpty)) {
        final fallbackName =
            _nom.text.trim().isEmpty ? 'Mon entreprise' : _nom.text.trim();
        employeurId = await _svc.ensureEmployeurId(nom: fallbackName);
        _employeurId = employeurId;
      }

      // 3) Deviner contentType
      String _contentTypeFor(String name) {
        final n = name.toLowerCase();
        if (n.endsWith('.png')) return 'image/png';
        if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
        if (n.endsWith('.webp')) return 'image/webp';
        if (n.endsWith('.gif')) return 'image/gif';
        return 'application/octet-stream';
      }

      // 4) Construire un chemin unique dans le bucket
      final ext = (() {
        final n = (file.name).toLowerCase();
        if (n.endsWith('.png')) return 'png';
        if (n.endsWith('.jpg')) return 'jpg';
        if (n.endsWith('.jpeg')) return 'jpeg';
        if (n.endsWith('.webp')) return 'webp';
        if (n.endsWith('.gif')) return 'gif';
        return 'bin';
      })();

      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'employeurs/$employeurId/$filename';

      // 5) Upload vers le bucket public
      await _sb.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(file.name),
            ),
          );

      // 6) URL publique (bucket public)
      final publicUrl = _sb.storage.from(_bucket).getPublicUrl(path);

      // 7) Mise à jour en base
      await _svc.updateEmployeur({'logo_url': publicUrl});

      if (!mounted) return;
      setState(() {
        _logoUrl.text = publicUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo mis à jour…')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l’upload du logo : $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    if (!_hasLogoColumn || !_hasLogo) return;
    try {
      await _svc.updateEmployeur({'logo_url': ''});
      if (!mounted) return;
      setState(() => _logoUrl.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $e')),
      );
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: Colors.white,
        filled: true,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: .5,
        title: const Text('Profil de l’entreprise'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Carte Logo + Nom
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        // Aperçu logo
                        (_hasLogo)
                            ? CircleAvatar(
                                radius: 28,
                                backgroundImage:
                                    NetworkImage(_logoUrl.text.trim()),
                              )
                            : const CircleAvatar(
                                radius: 28,
                                backgroundColor: kBlue,
                                child:
                                    Icon(Icons.business, color: Colors.white),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nom,
                            decoration: _dec('Nom de l’entreprise'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Actions logo
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _uploadingLogo ? null : _changeLogoFromGallery,
                        icon: _uploadingLogo
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_a_photo),
                        label: Text(_uploadingLogo ? 'Import…' : 'Changer le logo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBlue,
                          side: const BorderSide(color: kBlue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_hasLogo)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _removeLogo,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer le logo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // --- Autres champs
                TextField(controller: _tel, decoration: _dec('Téléphone')),
                const SizedBox(height: 10),
                TextField(controller: _email, decoration: _dec('Email')),
                const SizedBox(height: 10),
                TextField(controller: _ville, decoration: _dec('Ville')),
                const SizedBox(height: 10),
                TextField(controller: _commune, decoration: _dec('Commune')),
                const SizedBox(height: 10),
                TextField(controller: _secteur, decoration: _dec('Secteur')),
                const SizedBox(height: 10),

                // Affichés même si les colonnes n'existent pas (ne seront pas envoyés si absentes)
                TextField(
                  controller: _siteWeb,
                  decoration: _dec('Site web (https://...)'),
                ),
                const SizedBox(height: 10),

                // Logo URL (lecture seule, mis à jour après upload)
                TextField(
                  controller: _logoUrl,
                  readOnly: true,
                  decoration: _dec('Logo (URL, rempli après import)').copyWith(
                    suffixIcon: _hasLogo
                        ? IconButton(
                            onPressed: _removeLogo,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Effacer',
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
    );
  }
}
