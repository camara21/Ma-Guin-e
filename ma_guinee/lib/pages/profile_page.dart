// lib/pages/profile_page.dart
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

// 👇 Ajouté
import 'mes_rdv_page.dart'; // Page utilisateur “Mes rendez-vous”
// 👇 NOUVEAU : hub de réservations (hôtels, restos, tourisme)
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<UserProvider>().chargerUtilisateurConnecte();
      setState(() {});
    });
  }

  /// Reconstruit le numéro sans l'exposer en clair dans l'UI
  String _waNumber() {
    // 00224620452964 -> reconstruit par morceaux
    const parts = ['002', '24', '620', '45', '29', '64'];
    return parts.join();
  }

  /// Ouvrir WhatsApp (aucun texte/numéro n'est affiché dans l'UI)
  Future<void> _openWhatsApp() async {
    String number = _waNumber().replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('00')) number = number.substring(2); // -> 224…

    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback
    final alt = Uri.parse('whatsapp://send?phone=$number');
    if (!await canLaunchUrl(alt) ||
        !await launchUrl(alt, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d’ouvrir la conversation.")),
        );
      }
    }
  }

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

      String ext = 'bin';
      if (mime.contains('jpeg')) {
        ext = 'jpg';
      } else if (mime.contains('png')) {
        ext = 'png';
      } else if (mime.contains('webp')) {
        ext = 'webp';
      } else if (mime.contains('gif')) {
        ext = 'gif';
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur upload : $e')),
      );
    }
  }

  // 👇 Ajouté : ouvre MesRdvPage
  void _openMesRdv() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MesRdvPage()),
    );
  }

  // 👇 MODIFIÉ : ouvre désormais le HUB des réservations
  void _openMesReservations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MesReservationsHubPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<UserProvider>();
    if (prov.isLoadingUser || prov.isLoadingAnnonces) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          // ---------- En-tête profil ----------
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26),
            color: Colors.grey[50],
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImageAndUpload,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(user.telephone,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 14)),
                  ),
                if (user.email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(user.email,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ),
              ],
            ),
          ),

          // ---------- RDV + Réservations ----------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: InkWell(
              onTap: _openMesRdv,
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: const ListTile(
                  leading: Icon(Icons.event_available, color: Color(0xFF009460)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: const ListTile(
                  leading: Icon(Icons.book_online, color: Color(0xFFF39C12)),
                  title: Text('Mes réservations',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Hôtels, restaurants, lieux touristiques'),
                ),
              ),
            ),
          ),

          // ---------- Mes annonces ----------
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

          // ---------- Espaces ----------
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
                      ? user.espacePrestataire!['metier'] ?? ''
                      : "Vous n'êtes pas encore inscrit comme prestataire.",
                  onTap: user.espacePrestataire != null
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesPrestations)
                      : null,
                  onButton: user.espacePrestataire == null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const InscriptionPrestatairePage() ),
                          )
                      : null,
                  buttonLabel:
                      user.espacePrestataire == null ? "S'inscrire" : "Modifier",
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
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesRestaurants)
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InscriptionRestoPage()),
                  ),
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
                      ? () => Navigator.pushNamed(context, AppRoutes.mesHotels)
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InscriptionHotelPage()),
                  ),
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
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mesCliniques)
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InscriptionCliniquePage()),
                  ),
                  buttonLabel: 'Ajouter',
                ),
                _blocEspace(
                  color: Colors.indigo.shade50,
                  icon: Icons.place,
                  iconColor: Colors.indigo,
                  title: 'Mes Lieux',
                  subtitle: user.lieux != null && user.lieux.isNotEmpty
                      ? "${user.lieux.first['nom']} - ${user.lieux.first['ville']}"
                      : 'Aucun lieu enregistré.',
                  onTap: (user.lieux != null && user.lieux.isNotEmpty)
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MesLieuxPage()),
                          )
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InscriptionLieuPage()),
                  ),
                  buttonLabel: 'Ajouter',
                ),
              ],
            ),
          ),
          const Divider(height: 30, thickness: 1),

          // ---------- Paramètres ----------
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.black),
            title: const Text('Paramètres',
                style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ParametrePage(user: user)),
              );
            },
          ),

          // ---------- Support ----------
          ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF9FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.headset_mic, color: Color(0xFF1E88E5)),
            ),
            title: const Text('Support',
                style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openWhatsApp,
          ),

          // ---------- Déconnexion ----------
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Se déconnecter',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmation'),
                  content: const Text(
                      'Voulez-vous vraiment vous déconnecter ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Se déconnecter',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/welcome', (route) => false);
                }
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
