// lib/anp/page_mon_anp.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'; // 👈 pour RenderRepaintBoundary
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';

// 🌍 Carte réelle
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'page_creation_anp_localisation.dart';

class PageMonAnp extends StatefulWidget {
  const PageMonAnp({super.key});

  @override
  State<PageMonAnp> createState() => _PageMonAnpState();
}

class _PageMonAnpState extends State<PageMonAnp> {
  final _supabase = Supabase.instance.client;

  bool _chargement = true;
  String? _erreur;
  Map<String, dynamic>? _anp;

  // 🔹 Infos utilisateur pour le QR (nom + photo comme le profil)
  String? _nomCompletUtilisateur;
  String? _photoProfilUrl;

  static const Color _bleuPrincipal = Color(0xFF0066FF);
  static const Color _bleuClair = Color(0xFFEAF3FF);
  static const Color _couleurTexte = Color(0xFF0D1724);

  // Palette pour un rendu plus moderne
  static const Color _fondPrincipal = Color(0xFFF2F4F8);
  static const Color _carteFond = Colors.white;
  static const Color _accentSoft = Color(0xFFEDF2FF);

  @override
  void initState() {
    super.initState();
    _chargerAnp();
  }

  Future<void> _chargerAnp() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _erreur = "Vous devez être connecté pour voir votre ANP.";
        });
        return;
      }

      // 1) ANP perso
      final Map<String, dynamic>? existant = await _supabase
          .from('anp_adresses')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // 2) Profil utilisateur (comme ProfilePage)
      final Map<String, dynamic>? profil = await _supabase
          .from('utilisateurs')
          .select('prenom, nom, photo_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      String? nomComplet;
      String? photoUrl;

      if (profil != null) {
        final prenom = (profil['prenom'] ?? '').toString().trim();
        final nom = (profil['nom'] ?? '').toString().trim();
        final full = [prenom, nom].where((e) => e.isNotEmpty).join(' ').trim();

        if (full.isNotEmpty) {
          nomComplet = full;
        }
        final p = (profil['photo_url'] as String?)?.trim();
        if (p != null && p.isNotEmpty) {
          photoUrl = p;
        }
      }

      setState(() {
        _anp = existant;
        _nomCompletUtilisateur = nomComplet;
        _photoProfilUrl = photoUrl;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur =
            "Impossible de récupérer votre ANP pour le moment. Réessayez.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _chargement = false;
        });
      }
    }
  }

  String? _formatDateMaj(Map<String, dynamic> row) {
    try {
      final raw = row['updated_at'] ?? row['created_at'];
      if (raw == null) return null;
      final dt = DateTime.parse(raw.toString());
      final fmtDate = DateFormat.yMMMMd('fr_FR').format(dt);
      final fmtHeure = DateFormat.Hm('fr_FR').format(dt);
      return "Mise à jour le $fmtDate à $fmtHeure";
    } catch (_) {
      return null;
    }
  }

  Future<void> _copierCode() async {
    final code = _anp?['code']?.toString();
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Code ANP copié dans le presse-papiers.")),
    );
  }

  Future<void> _partagerCode() async {
    final code = _anp?['code']?.toString();
    if (code == null) return;
    await Share.share("Voici mon Adresse Numérique Personnelle (ANP) : $code");
  }

  // ---------- NOM + INITIALES UTILISATEUR POUR LE DESIGN ----------
  String _nomUtilisateur() {
    // 🔹 Priorité : nom/prénom depuis la table `utilisateurs`
    if (_nomCompletUtilisateur != null &&
        _nomCompletUtilisateur!.trim().isNotEmpty) {
      return _nomCompletUtilisateur!.trim();
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return "Mon ANP";

    final meta = user.userMetadata ?? {};

    final prenom = (meta['prenom'] ?? meta['first_name']) as String?;
    final nom = (meta['nom'] ?? meta['last_name']) as String?;
    final full = [prenom, nom]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' ');

    if (full.isNotEmpty) return full;

    final fullName = (meta['full_name'] ?? meta['name']) as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }

    // ❗ On NE retourne plus l'email pour ne jamais l’utiliser dans le QR
    return "Mon ANP";
  }

  String _initialesUtilisateur() {
    final name = _nomUtilisateur();
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return "A";
    if (parts.length == 1) {
      return parts.first.isNotEmpty
          ? parts.first.characters.first.toUpperCase()
          : "A";
    }
    final first = parts.first.characters.isNotEmpty
        ? parts.first.characters.first.toUpperCase()
        : "";
    final last = parts.last.characters.isNotEmpty
        ? parts.last.characters.first.toUpperCase()
        : "";
    final res = (first + last).trim();
    return res.isEmpty ? "A" : res;
  }

  /// 👉 Affiche le QR code du code ANP dans une popup + partage image
  void _voirQrCode() {
    final code = _anp?['code']?.toString();
    if (code == null || code.isEmpty) return;

    final qrKey = GlobalKey();
    final nom = _nomUtilisateur();
    final initiales = _initialesUtilisateur();

    // ✅ Le QR encode NOM + ANP (pas l’email)
    final String qrData = "Nom: $nom\nANP: $code";

    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<void> _partagerQrEnImage() async {
          try {
            final renderObject = qrKey.currentContext?.findRenderObject();

            if (renderObject is! RenderRepaintBoundary) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Impossible de générer l'image du QR code."),
                ),
              );
              return;
            }

            final boundary = renderObject;
            final ui.Image image =
                await boundary.toImage(pixelRatio: 3.0); // haute résolution
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Erreur lors de la génération du QR code."),
                ),
              );
              return;
            }

            final pngBytes = byteData.buffer.asUint8List();

            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/anp_qr_$code.png');
            await file.writeAsBytes(pngBytes);

            await Share.shareXFiles(
              [
                XFile(
                  file.path,
                  mimeType: 'image/png',
                  name: 'anp_qr_$code.png',
                ),
              ],
              text: "Voici le QR code personnalisé de mon ANP : $code",
            );
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Impossible d'exporter le QR code."),
              ),
            );
          }
        }

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🧩 Visuel complet à capturer (RepaintBoundary)
                RepaintBoundary(
                  key: qrKey,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _bleuPrincipal,
                          Color(0xFF00B4FF),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header avec avatar + nom (photo comme profil)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                backgroundImage: (_photoProfilUrl != null &&
                                        _photoProfilUrl!.isNotEmpty)
                                    ? NetworkImage(_photoProfilUrl!)
                                    : null,
                                child: (_photoProfilUrl == null ||
                                        _photoProfilUrl!.isEmpty)
                                    ? Text(
                                        initiales,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: _couleurTexte,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Mon Adresse Numérique Personnelle",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Carte blanche contenant le QR
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              QrImageView(
                                data: qrData, // ✅ nom + ANP dans le QR
                                version: QrVersions.auto,
                                size: 220,
                                gapless: true,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: _bleuPrincipal,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: _couleurTexte,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                code,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _couleurTexte,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Scannez ce QR pour obtenir directement mon ANP.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 🔘 Boutons (dans la même popup)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text("Fermer"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _partagerQrEnImage,
                      icon: const Icon(Icons.ios_share, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bleuPrincipal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      label: const Text(
                        "Partager le QR",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Utilisé pour "Créer mon ANP" ET "Mettre à jour mon emplacement"
  Future<void> _lancerFluxCreationOuMiseAJour() async {
    final codeAnp = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const PageCreationAnpLocalisation(),
      ),
    );

    if (codeAnp != null) {
      await _chargerAnp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Votre nouvelle adresse a bien été enregistrée."),
        ),
      );
    }
  }

  Future<void> _mettreAJourEmplacement() async {
    await _lancerFluxCreationOuMiseAJour();
  }

  Future<void> _creerMonAnpIci() async {
    await _lancerFluxCreationOuMiseAJour();
  }

  @override
  Widget build(BuildContext context) {
    final anp = _anp;
    final code = anp?['code']?.toString();

    // 🌍 récupération des coordonnées pour afficher la vraie carte
    final double? lat =
        (anp?['latitude'] is num) ? (anp!['latitude'] as num).toDouble() : null;
    final double? lng = (anp?['longitude'] is num)
        ? (anp!['longitude'] as num).toDouble()
        : null;

    return Scaffold(
      backgroundColor: _fondPrincipal,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _couleurTexte,
        centerTitle: true,
        title: Column(
          children: const [
            Text(
              "Mon ANP",
              style: TextStyle(
                color: _couleurTexte,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Adresse Numérique Personnelle",
              style: TextStyle(
                color: Colors.black45,
                fontSize: 11,
              ),
            )
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _chargement
              ? const Center(child: CircularProgressIndicator())
              : _erreur != null
                  ? Center(
                      child: Text(
                        _erreur!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : anp == null
                      ? _buildSansAnp()
                      : _buildAvecAnp(code, lat, lng),
        ),
      ),
    );
  }

  // ------------------ UI : PAS ENCORE D'ANP ------------------

  Widget _buildSansAnp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mon Adresse Numérique",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _couleurTexte,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Vous n’avez pas encore d’Adresse Numérique Personnelle (ANP).\n\n"
          "Créez votre ANP pour obtenir un code unique en Guinée et être trouvé facilement.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE3EEFF),
                Color(0xFFD0E4FF),
              ],
            ),
          ),
          child: Row(
            children: const [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.location_searching,
                  color: _bleuPrincipal,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "L’ANP est basée sur la localisation de votre téléphone. "
                  "Vous devrez activer le GPS pour créer votre adresse.",
                  style: TextStyle(
                    color: _couleurTexte,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _creerMonAnpIci,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleuPrincipal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 6,
              shadowColor: _bleuPrincipal.withOpacity(0.3),
            ),
            child: const Text(
              "Créer mon ANP",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------ UI : ANP EXISTANTE ------------------

  Widget _buildAvecAnp(String? code, double? lat, double? lng) {
    final anp = _anp!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mon Adresse Numérique",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _couleurTexte,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Votre ANP est unique et personnelle. Partagez-la pour inviter quelqu’un chez vous.",
          style: TextStyle(
            fontSize: 15,
            color: Colors.black54,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 24),

        // Carte principale ANP (card premium)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _carteFond,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header carte
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.house_rounded,
                      color: _bleuPrincipal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Adresse principale",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _couleurTexte,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bleuClair,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.satellite_alt,
                            size: 14, color: _bleuPrincipal),
                        SizedBox(width: 4),
                        Text(
                          "Vue satellite",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _bleuPrincipal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Code ANP (responsive, ne déborde jamais)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        code ?? "—",
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: _bleuPrincipal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      "ANP active",
                      style: TextStyle(
                        fontSize: 11,
                        color: _bleuPrincipal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Boutons Copier / Partager / QR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BoutonActionAnp(
                    libelle: "Copier",
                    onTap: _copierCode,
                  ),
                  _BoutonActionAnp(
                    libelle: "Partager",
                    onTap: _partagerCode,
                  ),
                  _BoutonActionAnp(
                    libelle: "Voir le code QR",
                    onTap: _voirQrCode,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🌍 Carte stylée
              if (lat != null && lng != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 18,
                            minZoom: 3,
                            maxZoom: 18, // évite l’écran gris
                          ),
                          children: [
                            // 🛰 Vue satellite (ArcGIS World Imagery)
                            TileLayer(
                              urlTemplate:
                                  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                              userAgentPackageName: 'ma.guinee.anp',
                              maxNativeZoom: 18,
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: 60,
                                  height: 60,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: _bleuPrincipal,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // petit gradient en bas pour lisibilité
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.35),
                                  Colors.black.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // fallback si pas de lat/lng
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _bleuClair,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.location_off,
                        color: _bleuPrincipal,
                        size: 40,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Aucune localisation disponible pour cette ANP",
                        style: TextStyle(
                          color: _couleurTexte,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              if (_formatDateMaj(anp) != null)
                Text(
                  _formatDateMaj(anp)!,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),

        const Spacer(),

        // 👉 Bouton principal : J’ai déménagé
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _mettreAJourEmplacement,
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleuPrincipal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 6,
              shadowColor: _bleuPrincipal.withOpacity(0.3),
            ),
            child: const Text(
              "J’ai déménagé",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoutonActionAnp extends StatelessWidget {
  final String libelle;
  final VoidCallback onTap;

  const _BoutonActionAnp({
    required this.libelle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            libelle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1724),
            ),
          ),
        ),
      ),
    );
  }
}
