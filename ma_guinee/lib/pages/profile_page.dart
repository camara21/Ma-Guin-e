import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/utilisateur_model.dart';
import '../providers/user_provider.dart';
import 'inscription_clinique_page.dart';
import 'inscription_hotel_page.dart';
import 'inscription_prestataire_page.dart';
import 'inscription_resto_page.dart';
import 'parametre_page.dart';
import '../routes.dart';

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

  Future<void> _pickImageAndUpload() async {
    if (_isUploading) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = context.read<UserProvider>().utilisateur!.id;
      final ext = picked.path.split('.').last.toLowerCase();
      final fileName = 'profile_photo_$userId.$ext';
      final path = 'profile-photos/$fileName';

      final bytes = await picked.readAsBytes();
      await supabase.storage
          .from('profile-photos')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('profile-photos').getPublicUrl(path);
      await supabase.from('utilisateurs').update({'photo_url': publicUrl}).eq('id', userId);

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
        SnackBar(content: Text('Erreur upload: $e')),
      );
    }
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
        title: const Text('Mon compte', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
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
                        backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? NetworkImage(_photoUrl!)
                            : const AssetImage('assets/avatar.png') as ImageProvider,
                        child: (_photoUrl == null || _photoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 40, color: Colors.grey)
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
                Text('${user.prenom} ${user.nom}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                if (user.telephone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(user.telephone, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  ),
                if (user.email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(user.email, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ),
              ],
            ),
          ),

          // 🔴 Annonces
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoutes.mesAnnonces),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Stack(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.campaign, color: Color(0xFFCE1126)),
                      title: Text('Mes annonces', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Voir / modifier / supprimer mes annonces"),
                    ),
                    Positioned(
                      right: 18,
                      top: 14,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.red.shade700,
                        child: Text(
                          annoncesCount.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🟦 Espaces
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
                      ? () => Navigator.pushNamed(context, AppRoutes.mesPrestations)
                      : null,
                  onButton: user.espacePrestataire == null
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InscriptionPrestatairePage()))
                      : null,
                  buttonLabel: user.espacePrestataire == null ? "S'inscrire" : "Modifier",
                ),
                _blocEspace(
                  color: Colors.orange.shade50,
                  icon: Icons.restaurant,
                  iconColor: Colors.orange,
                  title: 'Mes Restaurants',
                  subtitle: user.restos.isNotEmpty
                      ? "${user.restos.first['nom']} - ${user.restos.first['ville']}"
                      : "Aucun restaurant enregistré.",
                  onTap: user.restos.isNotEmpty
                      ? () => Navigator.pushNamed(context, AppRoutes.mesRestaurants)
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InscriptionRestoPage()),
                  ),
                  buttonLabel: "Ajouter",
                ),
                _blocEspace(
                  color: Colors.purple.shade50,
                  icon: Icons.hotel,
                  iconColor: Colors.purple,
                  title: 'Mes Hôtels',
                  subtitle: user.hotels.isNotEmpty
                      ? "${user.hotels.first['nom']} - ${user.hotels.first['ville']}"
                      : "Aucun hôtel enregistré.",
                  onTap: user.hotels.isNotEmpty
                      ? () => Navigator.pushNamed(context, AppRoutes.mesHotels)
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InscriptionHotelPage()),
                  ),
                  buttonLabel: "Ajouter",
                ),
                _blocEspace(
                  color: Colors.teal.shade50,
                  icon: Icons.local_hospital,
                  iconColor: Colors.teal,
                  title: 'Mes Cliniques',
                  subtitle: user.cliniques.isNotEmpty
                      ? "${user.cliniques.first['nom']} - ${user.cliniques.first['ville']}"
                      : "Aucune clinique enregistrée.",
                  onTap: user.cliniques.isNotEmpty
                      ? () => Navigator.pushNamed(
                          context,
                          AppRoutes.editClinique,
                          arguments: user.cliniques.first,
                        )
                      : null,
                  onButton: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InscriptionCliniquePage()),
                  ),
                  buttonLabel: user.cliniques.isNotEmpty ? "Modifier" : "S'inscrire",
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: onButton,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[onButton != null ? 600 : 300],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(buttonLabel),
        ),
        onTap: onTap,
      ),
    );
  }
}
