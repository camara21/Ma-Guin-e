import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import 'inscription_clinique_page.dart';
import 'inscription_hotel_page.dart';
import 'inscription_prestataire_page.dart';
import 'inscription_resto_page.dart';
import 'inscription_lieu_page.dart';
import 'mes_lieux_page.dart';
import 'parametre_page.dart';
import '../routes.dart';

// RDV utilisateur
import 'mes_rdv_page.dart';
// Hub reservations
import 'reservations/mes_reservations_hub.dart';

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
      if (mounted) setState(() {});
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

  // ----------------------------
  //   POPUP PHOTO
  // ----------------------------
  void _showPhotoPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _photoUrl != null && _photoUrl!.isNotEmpty
                    ? Image.network(_photoUrl!, height: 280, fit: BoxFit.cover)
                    : Image.asset('assets/default_avatar.png',
                        height: 280, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImageAndUpload();
                },
                icon: const Icon(Icons.edit),
                label: const Text("Modifier la photo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text("Fermer", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------
  //   UPLOAD PHOTO
  // ----------------------------
  Future<void> _pickImageAndUpload() async {
    if (_isUploading) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = context.read<UserProvider>().utilisateur!.id;

      final bytes = await picked.readAsBytes();
      final mime =
          lookupMimeType('', headerBytes: bytes) ?? 'application/octet-stream';

      String ext = 'jpg';
      if (mime.contains('png'))
        ext = 'png';
      else if (mime.contains('webp')) ext = 'webp';

      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = 'u/$userId/profile_$ts.$ext';

      await supabase.storage.from('profile-photos').uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: mime),
          );

      final publicUrl =
          supabase.storage.from('profile-photos').getPublicUrl(objectPath);

      await supabase
          .from('utilisateurs')
          .update({'photo_url': publicUrl}).eq('id', userId);

      setState(() {
        _photoUrl = publicUrl;
        _isUploading = false;
      });

      await context.read<UserProvider>().chargerUtilisateurConnecte();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour !')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
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
                        backgroundImage:
                            (_photoUrl != null && _photoUrl!.isNotEmpty)
                                ? NetworkImage(_photoUrl!)
                                : const AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                        child: (_photoUrl == null || _photoUrl!.isEmpty)
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
                if (user.telephone.isNotEmpty)
                  Text(user.telephone,
                      style: TextStyle(color: Colors.grey[700])),
                if (user.email.isNotEmpty)
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
                  subtitle: widget.user.espacePrestataire != null
                      ? widget.user.espacePrestataire!['metier'] ?? ''
                      : "Vous n'êtes pas encore inscrit comme prestataire.",
                  onTap: widget.user.espacePrestataire != null
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesPrestations)
                      : null,
                  onButton: widget.user.espacePrestataire == null
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const InscriptionPrestatairePage()))
                      : null,
                  buttonLabel: widget.user.espacePrestataire == null
                      ? "S'inscrire"
                      : "Modifier",
                ),
                _blocEspace(
                  color: Colors.orange.shade50,
                  icon: Icons.restaurant,
                  iconColor: Colors.orange,
                  title: 'Mes Restaurants',
                  subtitle: widget.user.restos.isNotEmpty
                      ? "${widget.user.restos.first['nom']} - ${widget.user.restos.first['ville']}"
                      : 'Aucun restaurant enregistré.',
                  onTap: widget.user.restos.isNotEmpty
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesRestaurants)
                      : null,
                  onButton: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InscriptionRestoPage())),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.purple.shade50,
                  icon: Icons.hotel,
                  iconColor: Colors.purple,
                  title: 'Mes Hôtels',
                  subtitle: widget.user.hotels.isNotEmpty
                      ? "${widget.user.hotels.first['nom']} - ${widget.user.hotels.first['ville']}"
                      : 'Aucun hôtel enregistré.',
                  onTap: widget.user.hotels.isNotEmpty
                      ? () => Navigator.pushNamed(context, AppRoutes.mesHotels)
                      : null,
                  onButton: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InscriptionHotelPage())),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.teal.shade50,
                  icon: Icons.local_hospital,
                  iconColor: Colors.teal,
                  title: 'Mes Cliniques',
                  subtitle: widget.user.cliniques.isNotEmpty
                      ? widget.user.cliniques
                          .map((c) => "${c['nom']} - ${c['ville']}")
                          .join(', ')
                      : 'Aucune clinique enregistrée.',
                  onTap: widget.user.cliniques.isNotEmpty
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesCliniques)
                      : null,
                  onButton: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InscriptionCliniquePage())),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.indigo.shade50,
                  icon: Icons.place,
                  iconColor: Colors.indigo,
                  title: 'Mes Lieux',
                  subtitle: widget.user.lieux.isNotEmpty
                      ? "${widget.user.lieux.first['nom']} - ${widget.user.lieux.first['ville']}"
                      : 'Aucun lieu enregistré.',
                  onTap: widget.user.lieux.isNotEmpty
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MesLieuxPage()))
                      : null,
                  onButton: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InscriptionLieuPage())),
                  buttonLabel: 'Ajouter',
                ),
              ],
            ),
          ),

          const Divider(height: 30),

          // PARAMETRES SEULEMENT (support supprimé)
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.black),
            title: const Text('Paramètres',
                style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ParametrePage(user: user)),
            ),
          ),

          // DECONNEXION
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
