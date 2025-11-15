// lib/anp/page_anp_entreprise_sites.dart

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'page_creation_anp_entreprise.dart';

class PageAnpEntrepriseSites extends StatefulWidget {
  const PageAnpEntrepriseSites({super.key});

  @override
  State<PageAnpEntrepriseSites> createState() => _PageAnpEntrepriseSitesState();
}

class _PageAnpEntrepriseSitesState extends State<PageAnpEntrepriseSites> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _erreur;

  Map<String, dynamic>? _entreprise;
  List<Map<String, dynamic>> _sites = [];

  // Palette ANP
  static const Color _primaryBlue = Color(0xFF0066FF);
  static const Color _textColor = Color(0xFF0D1724);

  // Carte
  LatLng _mapCenter = LatLng(9.6412, -13.5784); // Conakry par défaut
  double _mapZoom = 6;

  @override
  void initState() {
    super.initState();
    _loadEntrepriseEtSites();
  }

  Future<void> _loadEntrepriseEtSites() async {
    setState(() {
      _loading = true;
      _erreur = null;
    });

    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        throw Exception("Vous devez être connecté pour voir vos adresses ANP.");
      }

      // On suppose 1 entreprise par owner (tu pourras gérer plusieurs plus tard)
      final entreprises = await _sb
          .from('anp_entreprises')
          .select()
          .eq('owner_user_id', user.id)
          .eq('actif', true);

      if (entreprises.isEmpty) {
        // Pas encore d’entreprise
        setState(() {
          _entreprise = null;
          _sites = [];
        });
      } else {
        final ent = entreprises.first as Map<String, dynamic>;
        final entId = ent['id'] as String;

        final sites = await _sb
            .from('anp_entreprise_sites')
            .select()
            .eq('entreprise_id', entId)
            .order('est_principal', ascending: false)
            .order('created_at');

        List<Map<String, dynamic>> sitesList =
            (sites as List).cast<Map<String, dynamic>>();

        // Si on a au moins un site, on centre la carte dessus
        if (sitesList.isNotEmpty) {
          final s0 = sitesList.first;
          final lat = (s0['latitude'] as num).toDouble();
          final lng = (s0['longitude'] as num).toDouble();
          _mapCenter = LatLng(lat, lng);
          _mapZoom = 15;
        }

        setState(() {
          _entreprise = ent;
          _sites = sitesList;
        });
      }
    } catch (e) {
      setState(() {
        _erreur = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // Quand on tape sur un site dans la liste → recenter la carte
  void _focusSite(Map<String, dynamic> site) {
    final lat = (site['latitude'] as num).toDouble();
    final lng = (site['longitude'] as num).toDouble();
    setState(() {
      _mapCenter = LatLng(lat, lng);
      _mapZoom = 16;
    });
  }

  Future<void> _allerCreerOuAjouterAdresse() async {
    if (_entreprise == null) {
      // Pas d’entreprise → on ouvre en mode CREATION
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PageCreationAnpEntreprise(),
        ),
      );

      if (res != null && mounted) {
        // res contient { mode_ajout_adresse, entreprise, site }
        await _loadEntrepriseEtSites();
      }
    } else {
      // Entreprise existe → on ouvre en mode AJOUT D’ADRESSE
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageCreationAnpEntreprise(
            entrepriseId: _entreprise!['id'] as String,
            nomEntreprise: _entreprise!['nom'] as String,
          ),
        ),
      );

      if (res != null && mounted) {
        await _loadEntrepriseEtSites();
      }
    }
  }

  // ==========================
  //  QR CODE ENTREPRISE
  // ==========================
  void _voirQrEntreprise() {
    if (_entreprise == null) return;

    final nom = (_entreprise!['nom'] as String? ?? '').trim();
    final email = (_entreprise!['contact_email'] as String? ?? '').trim();
    final tel = (_entreprise!['contact_telephone'] as String? ?? '').trim();

    final data = [
      if (nom.isNotEmpty) 'Entreprise: $nom',
      if (email.isNotEmpty) 'Email: $email',
      if (tel.isNotEmpty) 'Téléphone: $tel',
    ].join('\n');

    if (data.isEmpty) return;

    final qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (dialogContext) {
        Future<void> _shareQr() async {
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
            final file =
                File('${tempDir.path}/anp_entreprise_qr_${nom}_share.png');
            await file.writeAsBytes(pngBytes);

            await Share.shareXFiles(
              [
                XFile(
                  file.path,
                  mimeType: 'image/png',
                  name: 'anp_entreprise_qr.png',
                ),
              ],
              text: "Voici le QR code de mon entreprise : $nom",
            );
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Impossible d'exporter le QR code."),
              ),
            );
          }
        }

        final initiales = nom.isNotEmpty
            ? nom
                .split(' ')
                .where((p) => p.isNotEmpty)
                .take(2)
                .map((p) => p.characters.first.toUpperCase())
                .join()
            : 'ANP';

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: qrKey,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primaryBlue,
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
                        // Header nom entreprise
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withOpacity(0.15),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white,
                                child: Text(
                                  initiales,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: _textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nom.isNotEmpty ? nom : "Mon entreprise",
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
                                    "QR code ANP Entreprise",
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

                        // Carte blanche avec QR
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
                                data: data,
                                version: QrVersions.auto,
                                size: 220,
                                gapless: true,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: _primaryBlue,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (email.isNotEmpty || tel.isNotEmpty)
                                Column(
                                  children: [
                                    if (email.isNotEmpty)
                                      Text(
                                        email,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: _textColor,
                                        ),
                                      ),
                                    if (tel.isNotEmpty)
                                      const SizedBox(height: 2),
                                    if (tel.isNotEmpty)
                                      Text(
                                        tel,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: _textColor,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Partagez ce QR pour envoyer facilement les coordonnées de votre entreprise.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text("Fermer"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _shareQr,
                      icon: const Icon(Icons.ios_share, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textColor,
        title: const Text(
          "Mes adresses ANP Entreprise",
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entreprise == null
                ? _buildSansEntreprise(theme)
                : _buildAvecEntreprise(theme),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _allerCreerOuAjouterAdresse,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        icon: Icon(
          _entreprise == null ? Icons.add_business : Icons.add_location_alt,
        ),
        label: Text(
          _entreprise == null
              ? "Créer mon ANP Entreprise"
              : "Ajouter une adresse",
        ),
      ),
    );
  }

  // ==============================
  //  CAS : PAS ENCORE D’ENTREPRISE
  // ==============================
  Widget _buildSansEntreprise(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ANP Entreprise",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Vous pouvez créer votre ANP Entreprise et définir votre première adresse "
            "(siège, agence principale) en appuyant sur le bouton bleu en bas.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_erreur != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _erreur!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          // Le gros bouton reste le FAB bleu en bas de l’écran
        ],
      ),
    );
  }

  // ==========================
  //  CAS : ENTREPRISE EXISTE
  // ==========================
  Widget _buildAvecEntreprise(ThemeData theme) {
    // 👉 Si aucun site n’a de code ANP, on n'affiche plus la "section ANP entreprise"
    final bool hasAnyCode = _sites.any(
      (s) => ((s['code'] as String?) ?? '').trim().isNotEmpty,
    );

    if (!hasAnyCode) {
      // On ne montre pas la carte + liste d’adresses ANP,
      // mais on laisse la possibilité de générer un QR entreprise.
      return RefreshIndicator(
        onRefresh: _loadEntrepriseEtSites,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Vous avez enregistré une entreprise, mais aucune adresse ANP n’a encore de code.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _voirQrEntreprise,
                icon: const Icon(Icons.qr_code_2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                label: const Text("QR code de l’entreprise"),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: const Text(
                  "Ajoutez au moins une adresse pour générer un code ANP de site.\n"
                  "Utilisez le bouton “Ajouter une adresse” en bas.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 👉 Ici, il y a au moins un code ANP : on affiche tout (entreprise + carte + sites)
    return RefreshIndicator(
      onRefresh: _loadEntrepriseEtSites,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          children: [
            // --------- CARTE ENTREPRISE ---------
            _buildEntrepriseHeader(theme),
            const SizedBox(height: 16),

            // --------- CARTE + MARKERS ---------
            SizedBox(
              height: 260,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _mapZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.soneya.ma_guinee',
                    ),
                    if (_sites.isNotEmpty)
                      MarkerLayer(
                        markers: _sites.map((site) {
                          final lat = (site['latitude'] as num).toDouble();
                          final lng = (site['longitude'] as num).toDouble();
                          final principal =
                              (site['est_principal'] as bool?) ?? false;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: Icon(
                              principal
                                  ? Icons.location_on
                                  : Icons.location_on_outlined,
                              size: 34,
                              color: _primaryBlue,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --------- LISTE DES SITES ---------
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Adresses de l’entreprise",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (_sites.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: const Text(
                  "Aucune adresse enregistrée.\n"
                  "Appuyez sur “Ajouter une adresse” pour ajouter un site.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final site = _sites[index];
                  final principal = (site['est_principal'] as bool?) ?? false;
                  final code = site['code'] as String?;
                  final nomSite = site['nom_site'] as String?;
                  final typeSite = site['type_site'] as String?;
                  final lat = (site['latitude'] as num).toDouble();
                  final lng = (site['longitude'] as num).toDouble();

                  return InkWell(
                    onTap: () => _focusSite(site),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            principal ? Icons.star : Icons.location_on_outlined,
                            color: principal ? Colors.orange : _primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        nomSite ?? "Site sans nom",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _textColor,
                                        ),
                                      ),
                                    ),
                                    if (principal) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          color: Colors.green.withOpacity(0.12),
                                        ),
                                        child: const Text(
                                          "Principal",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (typeSite != null && typeSite.isNotEmpty)
                                      typeSite,
                                    if (code != null && code.trim().isNotEmpty)
                                      "Code ANP : $code",
                                  ].join(" • "),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Lat : ${lat.toStringAsFixed(5)}  |  "
                                  "Lng : ${lng.toStringAsFixed(5)}",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            if (_erreur != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _erreur!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntrepriseHeader(ThemeData theme) {
    final nom = _entreprise!['nom'] as String? ?? '';
    final secteur = _entreprise!['secteur'] as String?;
    final email = _entreprise!['contact_email'] as String?;
    final tel = _entreprise!['contact_telephone'] as String?;
    final siteWeb = _entreprise!['site_web'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business, size: 32, color: _primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nom,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _voirQrEntreprise,
                      icon: const Icon(Icons.qr_code_2),
                      color: _primaryBlue,
                      tooltip: "QR entreprise",
                    ),
                  ],
                ),
                if (secteur != null && secteur.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secteur,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: theme.textTheme.bodySmall,
                  ),
                if (tel != null && tel.isNotEmpty)
                  Text(
                    tel,
                    style: theme.textTheme.bodySmall,
                  ),
                if (siteWeb != null && siteWeb.isNotEmpty)
                  Text(
                    siteWeb,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _primaryBlue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
