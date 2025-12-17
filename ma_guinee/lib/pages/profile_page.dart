// lib/pages/profile_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import '../routes.dart';

import 'inscription_clinique_page.dart';
import 'inscription_hotel_page.dart';
import 'inscription_prestataire_page.dart';
import 'inscription_resto_page.dart';
import 'inscription_lieu_page.dart';
import 'mes_lieux_page.dart';
import 'parametre_page.dart';

// RDV utilisateur
import 'mes_rdv_page.dart';
// Hub reservations
import 'reservations/mes_reservations_hub.dart';

// ✅ Compression (ton module)
import 'package:ma_guinee/utils/image_compressor/image_compressor.dart';

// ✅ AJOUT : correction déconnexion (push cleanup)
import '../services/push_service.dart';

class ProfilePage extends StatefulWidget {
  final UtilisateurModel user;
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.user.photoUrl;

    Future.microtask(() async {
      await context.read<UserProvider>().chargerUtilisateurConnecte();
      if (!mounted) return;

      // ✅ sync photo depuis provider si local vide
      final u = context.read<UserProvider>().utilisateur;
      if ((_photoUrl?.trim().isNotEmpty ?? false) == false) {
        _photoUrl = u?.photoUrl;
      }
      setState(() {});
    });
  }

  // WhatsApp number
  String _waNumber() => "00224620452964";

  Future<void> _openWhatsApp() async {
    String number = _waNumber().replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('00')) number = number.substring(2);

    final whatsappUri = Uri.parse('whatsapp://send?phone=$number');
    final webUri = Uri.parse('https://wa.me/$number');
    final intentUri = Uri.parse(
        'intent://send/?phone=$number#Intent;scheme=whatsapp;package=com.whatsapp;end');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(intentUri)) {
      await launchUrl(intentUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impossible d’ouvrir WhatsApp.")),
    );
  }

  // =========================
  // Helpers
  // =========================
  String? _avatarUrl(UtilisateurModel user) {
    final local = _photoUrl?.trim();
    if (local != null && local.isNotEmpty) return local;

    final remote = user.photoUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;

    return null;
  }

  Future<void> _refreshUser() async {
    await context.read<UserProvider>().chargerUtilisateurConnecte();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pushAndRefresh(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _refreshUser();
  }

  // =========================
  // ✅ AJOUT : SUPPRESSION PHOTO PROFIL (DB + Bucket)
  // =========================
  static const String _kProfileBucket = 'profile-photos';

  /// Convertit une URL publique Supabase Storage en "objectPath" (chemin dans le bucket).
  /// Exemple:
  /// .../storage/v1/object/public/profile-photos/u/<uid>/profile_123.jpg
  /// => u/<uid>/profile_123.jpg
  String? _extractObjectPathFromPublicUrl(String url,
      {required String bucket}) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments; // segments décodés
      final idx = seg.indexOf(bucket);
      if (idx == -1) return null;
      if (idx + 1 >= seg.length) return null;
      return seg.sublist(idx + 1).join('/');
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDeleteProfilePhoto() async {
    if (_isUploading) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content: const Text(
          'La photo sera supprimée du profil et du stockage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteProfilePhotoEverywhere();
    }
  }

  Future<void> _deleteProfilePhotoEverywhere() async {
    if (_isUploading) return;

    final prov = context.read<UserProvider>();
    final u = prov.utilisateur ?? widget.user;

    final String? avatar = _avatarUrl(u);
    if (avatar == null || avatar.trim().isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final sb = Supabase.instance.client;

      final userId = prov.utilisateur?.id ?? widget.user.id;

      // 1) supprimer le fichier dans le bucket (si on retrouve le path)
      final objectPath =
          _extractObjectPathFromPublicUrl(avatar, bucket: _kProfileBucket);

      if (objectPath != null && objectPath.isNotEmpty) {
        // Si la policy storage autorise DELETE, ceci supprime vraiment le fichier
        await sb.storage.from(_kProfileBucket).remove([objectPath]);
      }

      // 2) vider la colonne en base
      await sb
          .from('utilisateurs')
          .update({'photo_url': null}).eq('id', userId);

      // 3) UI
      if (!mounted) return;
      setState(() {
        _photoUrl = null;
        _isUploading = false;
      });

      await _refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil supprimée.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression : $e')),
      );
    }
  }

  // ----------------------------
  //   POPUP PHOTO (30% haut, bord à bord)
  // ----------------------------
  void _showPhotoPopup() {
    final prov = context.read<UserProvider>();
    final u = prov.utilisateur ?? widget.user;
    final String? avatar = _avatarUrl(u);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'photo',
      barrierColor: Colors.black.withOpacity(0.55),
      pageBuilder: (_, __, ___) {
        final h = MediaQuery.of(context).size.height * 0.50;

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Image collée en haut, bord à bord, 30% hauteur
                  SizedBox(
                    height: h,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        avatar != null
                            ? Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                              )
                            : Image.asset(
                                'assets/default_avatar.png',
                                fit: BoxFit.cover,
                              ),

                        // bouton fermer
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.black.withOpacity(0.35),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.pop(context),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ actions (Modifier + Supprimer)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _pickImageAndUpload();
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text("Modifier la photo"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (avatar == null || _isUploading)
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _confirmDeleteProfilePhoto();
                                  },
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            label: const Text(
                              "Supprimer",
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
    );
  }

  // ----------------------------
  //   UPLOAD PHOTO (compression)
  // ----------------------------
  Future<void> _pickImageAndUpload() async {
    if (_isUploading) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // ⚠️ on laisse imageQuality mais la vraie compression est faite après
      imageQuality: 100,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = context.read<UserProvider>().utilisateur!.id;

      // bytes originaux
      final Uint8List rawBytes = await picked.readAsBytes();

      // ✅ compression prod (avatar)
      final c = await ImageCompressor.compressBytes(
        rawBytes,
        maxSide: 1024,
        quality: 82,
        maxBytes: 280 * 1024, // ~280 KB
        keepPngIfTransparent: true,
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'u/$userId/profile_$ts.${c.extension}';

      await supabase.storage.from('profile-photos').uploadBinary(
            objectPath,
            c.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: c.contentType,
            ),
          );

      final publicUrl =
          supabase.storage.from('profile-photos').getPublicUrl(objectPath);

      await supabase
          .from('utilisateurs')
          .update({'photo_url': publicUrl}).eq('id', userId);

      // ✅ update local + refresh provider
      if (!mounted) return;
      setState(() {
        _photoUrl = publicUrl;
        _isUploading = false;
      });

      await _refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour !')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload : $e')),
      );
    }
  }

  // ----------------------------
  //   RDV
  // ----------------------------
  void _openMesRdv() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MesRdvPage()));
  }

  void _openMesReservations() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MesReservationsHubPage()));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    final user = prov.utilisateur ?? widget.user;

    final annoncesCount = prov.annoncesUtilisateur.length;

    // ✅ FIX NULL-SAFETY (plus d'erreur isNotEmpty sur String?)
    final String? avatar = _avatarUrl(user);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mon compte',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ----------------------------------------------------------------------
          // HEADER AVEC POPUP
          // ----------------------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26),
            color: Colors.grey[50],
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showPhotoPopup,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 37,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: avatar != null
                            ? NetworkImage(avatar)
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                        child: avatar == null
                            ? const Icon(Icons.person,
                                size: 40, color: Colors.grey)
                            : null,
                      ),
                      if (_isUploading)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('${user.prenom} ${user.nom}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 19)),
                if ((user.telephone).isNotEmpty)
                  Text(user.telephone,
                      style: TextStyle(color: Colors.grey[700])),
                if ((user.email).isNotEmpty)
                  Text(user.email, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),

          // ----------------------------------------------------------------------
          // BLOC FONCTIONNALITÉS
          // ----------------------------------------------------------------------

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: InkWell(
              onTap: _openMesRdv,
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const ListTile(
                  leading:
                      Icon(Icons.event_available, color: Color(0xFF009460)),
                  title: Text('Mes rendez-vous',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Suivre / annuler mes rendez-vous santé'),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: InkWell(
              onTap: _openMesReservations,
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const ListTile(
                  leading: Icon(Icons.book_online, color: Color(0xFFF39C12)),
                  title: Text('Mes réservations',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Hôtels, restaurants, lieux touristiques'),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoutes.mesAnnonces),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Stack(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.campaign, color: Color(0xFFCE1126)),
                      title: Text('Mes annonces',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          Text('Voir / modifier / supprimer mes annonces'),
                    ),
                    Positioned(
                      right: 18,
                      top: 14,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.red,
                        child: Text(
                          annoncesCount.toString(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ESPACES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _blocEspace(
                  color: Colors.blue.shade50,
                  icon: Icons.home_repair_service,
                  iconColor: const Color(0xFF009460),
                  title: 'Espace prestataire',
                  subtitle: user.espacePrestataire != null
                      ? (user.espacePrestataire!['metier'] ?? '').toString()
                      : "Vous n'êtes pas encore inscrit comme prestataire.",
                  onTap: user.espacePrestataire != null
                      ? () async {
                          await Navigator.pushNamed(
                              context, AppRoutes.mesPrestations);
                          await _refreshUser();
                        }
                      : null,
                  onButton: user.espacePrestataire == null
                      ? () =>
                          _pushAndRefresh(const InscriptionPrestatairePage())
                      : null,
                  buttonLabel: user.espacePrestataire == null
                      ? "S'inscrire"
                      : "Modifier",
                ),
                _blocEspace(
                  color: Colors.orange.shade50,
                  icon: Icons.restaurant,
                  iconColor: Colors.orange,
                  title: 'Mes Restaurants',
                  subtitle: user.restos.isNotEmpty
                      ? "${user.restos.first['nom']} - ${user.restos.first['ville']}"
                      : 'Aucun restaurant enregistré.',
                  onTap: user.restos.isNotEmpty
                      ? () async {
                          await Navigator.pushNamed(
                              context, AppRoutes.mesRestaurants);
                          await _refreshUser();
                        }
                      : null,
                  onButton: () => _pushAndRefresh(const InscriptionRestoPage()),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.purple.shade50,
                  icon: Icons.hotel,
                  iconColor: Colors.purple,
                  title: 'Mes Hôtels',
                  subtitle: user.hotels.isNotEmpty
                      ? "${user.hotels.first['nom']} - ${user.hotels.first['ville']}"
                      : 'Aucun hôtel enregistré.',
                  onTap: user.hotels.isNotEmpty
                      ? () async {
                          await Navigator.pushNamed(
                              context, AppRoutes.mesHotels);
                          await _refreshUser();
                        }
                      : null,
                  onButton: () => _pushAndRefresh(const InscriptionHotelPage()),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.teal.shade50,
                  icon: Icons.local_hospital,
                  iconColor: Colors.teal,
                  title: 'Mes Cliniques',
                  subtitle: user.cliniques.isNotEmpty
                      ? user.cliniques
                          .map((c) => "${c['nom']} - ${c['ville']}")
                          .join(', ')
                      : 'Aucune clinique enregistrée.',
                  onTap: user.cliniques.isNotEmpty
                      ? () async {
                          await Navigator.pushNamed(
                              context, AppRoutes.mesCliniques);
                          await _refreshUser();
                        }
                      : null,
                  onButton: () =>
                      _pushAndRefresh(const InscriptionCliniquePage()),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.indigo.shade50,
                  icon: Icons.place,
                  iconColor: Colors.indigo,
                  title: 'Mes Lieux',
                  subtitle: user.lieux.isNotEmpty
                      ? "${user.lieux.first['nom']} - ${user.lieux.first['ville']}"
                      : 'Aucun lieu enregistré.',
                  onTap: user.lieux.isNotEmpty
                      ? () async {
                          await _pushAndRefresh(const MesLieuxPage());
                        }
                      : null,
                  onButton: () => _pushAndRefresh(const InscriptionLieuPage()),
                  buttonLabel: 'Ajouter',
                ),
              ],
            ),
          ),

          const Divider(height: 30),

          // PARAMETRES
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.black),
            title: const Text('Paramètres',
                style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ParametrePage(user: user)),
              );
              await _refreshUser();
            },
          ),

          // DECONNEXION (✅ seul changement: cleanup push avant signOut)
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Se déconnecter',
                style:
                    TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmation'),
                  content:
                      const Text('Voulez-vous vraiment vous déconnecter ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Se déconnecter',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                // ✅ Correction : nettoyer/désactiver le device push AVANT le signOut
                try {
                  await PushService.instance.onLogoutCleanup();
                } catch (_) {
                  // ne bloque pas la déconnexion si le cleanup échoue
                }

                await Supabase.instance.client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/welcome', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _blocEspace({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    VoidCallback? onButton,
    required String buttonLabel,
  }) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: onButton,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[onButton != null ? 600 : 300],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(buttonLabel),
        ),
        onTap: onTap,
      ),
    );
  }
}
