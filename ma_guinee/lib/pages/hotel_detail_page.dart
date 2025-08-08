import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../services/avis_service.dart';

class HotelDetailPage extends StatefulWidget {
  final dynamic hotelId; // UUID (String) ou autre -> stringifié
  const HotelDetailPage({super.key, required this.hotelId});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  Map<String, dynamic>? hotel;
  bool loading = true;

  int _noteUtilisateur = 0;
  final TextEditingController _avisController = TextEditingController();
  double _noteMoyenne = 0;
  List<Map<String, dynamic>> _avis = [];

  // Carrousel
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  String get _id => widget.hotelId.toString();

  @override
  void initState() {
    super.initState();
    _loadHotel();
    _loadAvis();
  }

  @override
  void dispose() {
    _avisController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHotel() async {
    setState(() => loading = true);

    final data = await Supabase.instance.client
        .from('hotels')
        .select()
        .eq('id', _id)
        .maybeSingle();

    setState(() {
      hotel = data == null ? null : Map<String, dynamic>.from(data);
      loading = false;
    });
  }

  Future<void> _loadAvis() async {
    final res = await Supabase.instance.client
        .from('avis')
        .select('note, commentaire, created_at, utilisateurs(nom, prenom, photo_url)')
        .eq('contexte', 'hotel')
        .eq('cible_id', _id)
        .order('created_at', ascending: false);

    final notes = res.map<double>((e) => (e['note'] as num).toDouble()).toList();
    setState(() {
      _avis = List<Map<String, dynamic>>.from(res);
      _noteMoyenne = notes.isNotEmpty ? notes.reduce((a, b) => a + b) / notes.length : 0.0;
    });
  }

  Future<void> _envoyerAvis() async {
    final commentaire = _avisController.text.trim();
    if (_noteUtilisateur == 0 || commentaire.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez donner une note et un avis.")),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connectez-vous pour laisser un avis.")),
      );
      return;
    }

    await AvisService().ajouterOuModifierAvis(
      contexte: 'hotel',
      cibleId: _id,
      utilisateurId: user.id,
      note: _noteUtilisateur,
      commentaire: commentaire,
    );

    _avisController.clear();
    setState(() => _noteUtilisateur = 0);
    await _loadAvis();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Merci pour votre avis !")),
    );
  }

  void _contacter() async {
    final tel = (hotel?['telephone'] ?? '').toString();
    if (tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _localiser() async {
    final lat = (hotel?['latitude'] as num?)?.toDouble();
    final lon = (hotel?['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReservationMessage() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Réservation"),
        content: const Text("Le service de réservation en ligne sera bientôt disponible."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _buildStars(int rating, {void Function(int)? onTap}) {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber),
          onPressed: onTap != null ? () => onTap(index + 1) : null,
          iconSize: 28,
          splashRadius: 20,
        );
      }),
    );
  }

  Widget _buildAvisList() {
    if (_avis.isEmpty) return const Text("Pas encore d'avis");

    return Column(
      children: _avis.map((avis) {
        final u = avis['utilisateurs'] ?? {};
        final nom = "${u['prenom'] ?? ''} ${u['nom'] ?? ''}".trim();
        final note = (avis['note'] as num?)?.toInt() ?? 0;
        final commentaire = (avis['commentaire'] ?? '').toString();
        final photo = (u['photo_url'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(i < note ? Icons.star : Icons.star_border, size: 16, color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(commentaire),
                ]),
              ),
            ],
          ),
        );
  }).toList());
  }

  // -------- images helpers ----------
  List<String> _imagesFromHotel() {
    final raw = hotel?['images'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    final p = (hotel?['photo_url'] ?? '').toString();
    return p.isNotEmpty ? [p] : [];
  }

  void _openFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        final controller = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(builder: (context, setS) {
          return Stack(
            children: [
              PhotoViewGallery.builder(
                itemCount: images.length,
                pageController: controller,
                builder: (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(images[i]),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'hotel_$i'),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                onPageChanged: (i) => setS(() => current = i),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${current + 1}/${images.length}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          );
        });
      },
    );
  }
  // -----------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading || hotel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final images = _imagesFromHotel();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          (hotel!['nom'] ?? '').toString(),
          style: const TextStyle(color: Color(0xFF113CFC), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF113CFC)),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // -------- carrousel + miniatures + compteur --------
          if (images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _openFullScreenGallery(images, index),
                        child: Hero(
                          tag: 'hotel_$index',
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (images.length > 1)
              SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isActive = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                        setState(() => _currentIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive ? const Color(0xFF113CFC) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 230,
                color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
              ),
            ),
          // -----------------------------------------------------

          const SizedBox(height: 16),

          Text("Ville : ${(hotel!['ville'] ?? 'Non précisé').toString()}",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            "Prix moyen : ${(hotel!['prix'] ?? 'Non précisé').toString()} ${(hotel!['devise'] ?? '').toString()}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text("Description :\n${(hotel!['description'] ?? 'Aucune description').toString()}"),
          const SizedBox(height: 20),

          const Text("Avis client :", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_avis.isEmpty ? "Pas d'avis" : "${_noteMoyenne.toStringAsFixed(1)} / 5"),

          const SizedBox(height: 10),
          const Text("Notez cet hôtel :", style: TextStyle(fontWeight: FontWeight.bold)),
          _buildStars(_noteUtilisateur, onTap: (val) => setState(() => _noteUtilisateur = val)),
          TextField(
            controller: _avisController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Partagez votre expérience avec cet hôtel...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _envoyerAvis,
            icon: const Icon(Icons.send),
            label: const Text("Envoyer mon avis"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFCD116),
              foregroundColor: Colors.black,
            ),
          ),

          const SizedBox(height: 20),
          _buildAvisList(),

          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _localiser,
                icon: const Icon(Icons.map),
                label: const Text("Localiser"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009460), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _contacter,
                icon: const Icon(Icons.phone),
                label: const Text("Contacter"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCE1126), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _showReservationMessage,
                icon: const Icon(Icons.calendar_today),
                label: const Text("Réserver"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 50),
        ]),
      ),
    );
  }
}
