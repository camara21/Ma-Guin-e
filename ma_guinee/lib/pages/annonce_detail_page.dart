import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_guinee/models/annonce_model.dart';
import 'package:ma_guinee/pages/messages_annonce_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';


class AnnonceDetailPage extends StatefulWidget {
  final AnnonceModel annonce;

  const AnnonceDetailPage({super.key, required this.annonce});

  @override
  State<AnnonceDetailPage> createState() => _AnnonceDetailPageState();
}

class _AnnonceDetailPageState extends State<AnnonceDetailPage> {
  int _currentImageIndex = 0;
  Map<String, dynamic>? vendeur;

  final Color bleuMaGuinee = const Color(0xFF1E3FCF); // ✅ couleur personnalisée

  @override
  void initState() {
    super.initState();
    _chargerInfosVendeur();
  }

  Future<void> _chargerInfosVendeur() async {
    final data = await Supabase.instance.client
        .from('utilisateurs')
        .select()
        .eq('id', widget.annonce.userId)
        .maybeSingle();
    if (mounted) {
      setState(() => vendeur = data);
    }
  }

  void _afficherImagePleine(int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.annonce.images.length,
              pageController: PageController(initialPage: index),
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              builder: (context, i) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(widget.annonce.images[i]),
                  heroAttributes: PhotoViewHeroAttributes(tag: i),
                );
              },
            ),
            Positioned(
              top: 40,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _afficherImagePleine(_currentImageIndex),
          child: SizedBox(
            height: 250,
            child: PageView.builder(
              itemCount: widget.annonce.images.length,
              onPageChanged: (index) =>
                  setState(() => _currentImageIndex = index),
              itemBuilder: (_, i) => Image.network(
                widget.annonce.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 12,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 60,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () =>
                  Share.share('Consulte cette annonce : ${widget.annonce.titre}'),
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 12,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: Icon(
                widget.annonce.estFavori
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() =>
                    widget.annonce.estFavori = !widget.annonce.estFavori);
              },
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${widget.annonce.images.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoutonsContact() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _boutonContact(
          icon: Icons.message,
          label: 'Contacter',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MessagesAnnoncePage(
                  annonceId: widget.annonce.id,
                  annonceTitre: widget.annonce.titre,
                  receiverId: widget.annonce.userId,
                  senderId: Supabase.instance.client.auth.currentUser!.id,
                ),
              ),
            );
          },
        ),
        _boutonContact(
          icon: Icons.call,
          label: 'Appeler',
          onPressed: () =>
              launchUrl(Uri.parse("tel:${widget.annonce.telephone}")),
        ),
        _boutonContact(
          icon: FontAwesomeIcons.whatsapp,
          label: 'WhatsApp',
          onPressed: () =>
              launchUrl(Uri.parse("https://wa.me/${widget.annonce.telephone}")),
        ),
      ],
    );
  }

  Widget _boutonContact({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bleuMaGuinee,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildCarte() {
    final hasCoords =
        widget.annonce.latitude != null && widget.annonce.longitude != null;

    if (!hasCoords) return const SizedBox();

    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          center: LatLng(widget.annonce.latitude!, widget.annonce.longitude!),
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(widget.annonce.latitude!, widget.annonce.longitude!),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendeur() {
    if (vendeur == null) return const SizedBox.shrink();

    return ListTile(
      leading: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: Image.network(
                vendeur!['photo_url'] ?? 'https://via.placeholder.com/150',
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        child: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(
            vendeur!['photo_url'] ?? 'https://via.placeholder.com/150',
          ),
        ),
      ),
      title: Text("${vendeur!['prenom']} ${vendeur!['nom']}"),
      subtitle: Text(widget.annonce.ville),
    );
  }

  Widget _buildAnnoncesSimilaires() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text("Annonces similaires (à implémenter)",
          style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        children: [
          _buildImageCarousel(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.annonce.titre,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${widget.annonce.prix.toInt()} ${widget.annonce.devise} • ${widget.annonce.ville}',
                    style: const TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 16),
                Text(widget.annonce.description),
                const SizedBox(height: 16),
                _buildBoutonsContact(),
                const SizedBox(height: 24),
                const Text("Localisation", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCarte(),
                const SizedBox(height: 24),
                const Text("Vendu par", style: TextStyle(fontWeight: FontWeight.bold)),
                _buildVendeur(),
                _buildAnnoncesSimilaires(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
