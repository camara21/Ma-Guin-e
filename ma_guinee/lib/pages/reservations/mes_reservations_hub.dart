import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../hotel_detail_page.dart';
import '../resto_detail_page.dart';
import '../tourisme_detail_page.dart';
import 'reservations_hotels_page.dart';
import 'reservations_restaurants_page.dart';
import 'reservations_tourisme_page.dart';

class MesReservationsHubPage extends StatelessWidget {
  const MesReservationsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _HubTile(
        icon: Icons.hotel,
        title: 'Hôtels',
        subtitle: 'Vos réservations d’hôtels',
        color: const Color(0xFF264653),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReservationsHotelsPage()),
        ),
      ),
      _HubTile(
        icon: Icons.restaurant,
        title: 'Restaurants',
        subtitle: 'Vos réservations de restaurants',
        color: const Color(0xFFE76F51),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReservationsRestaurantsPage()),
        ),
      ),
      _HubTile(
        icon: Icons.place,
        title: 'Lieux touristiques',
        subtitle: 'Vos réservations de visites',
        color: const Color(0xFFDAA520),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReservationsTourismePage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.6,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
