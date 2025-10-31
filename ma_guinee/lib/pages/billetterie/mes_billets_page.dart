// lib/pages/billetterie/mes_billets_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/billetterie_service.dart';
import 'billet_view_page.dart';

const _kEventPrimary = Color(0xFF0175C2);
const _kOnPrimary = Colors.white;

class MesBilletsPage extends StatefulWidget {
  const MesBilletsPage({super.key});
  @override
  State<MesBilletsPage> createState() => _MesBilletsPageState();
}

class _MesBilletsPageState extends State<MesBilletsPage> {
  final _svc = BilletterieService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _svc.listMesReservations();
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _kEventPrimary,
        foregroundColor: _kOnPrimary,
        title: const Text('Mes billets'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _items.isEmpty
                  ? const Center(child: Text('Aucune réservation.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _BilletCard(
                        data: _items[i],
                        onTapOpenPreview: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BilletViewPage(data: _items[i])),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _BilletCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTapOpenPreview;
  const _BilletCard({
    required this.data,
    required this.onTapOpenPreview,
  });

  Color _statusBg(String s) {
    switch (s) {
      case 'utilise':
        return const Color(0xFF2E7D32).withOpacity(.12);
      case 'annule':
        return const Color(0xFFB00020).withOpacity(.12);
      default:
        return _kEventPrimary.withOpacity(.12);
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'utilise':
        return const Color(0xFF2E7D32);
      case 'annule':
        return const Color(0xFFB00020);
      default:
        return _kEventPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ev = (data['evenements'] is Map) ? Map<String, dynamic>.from(data['evenements'] as Map) : null;
    final bi = (data['billets'] is Map) ? Map<String, dynamic>.from(data['billets'] as Map) : null;

    final posterUrl = (ev?['photo_url'] ?? ev?['cover_url'] ?? '').toString();
    final qty = (data['quantite'] ?? 1).toString();

    DateTime? date;
    final rawDate = ev?['date_debut']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) date = DateTime.tryParse(rawDate);
    final dateTxt = (date != null) ? DateFormat('EEE d MMM • HH:mm', 'fr_FR').format(date!) : '';

    final statut = (data['statut'] ?? '').toString();

    return InkWell(
      onTap: onTapOpenPreview,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.secondary.withOpacity(.10)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: posterUrl.isEmpty
                    ? Container(
                        width: 86,
                        height: 86,
                        color: _kEventPrimary.withOpacity(.08),
                        child: const Icon(Icons.event, color: _kEventPrimary),
                      )
                    : Image.network(posterUrl, width: 86, height: 86, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev?['titre']?.toString() ?? 'Événement',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('${bi?['titre'] ?? 'Billet'} • x$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${ev?['lieu'] ?? ''} • ${ev?['ville'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                    if (dateTxt.isNotEmpty) Text(dateTxt, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _statusBg(statut), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            statut.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusFg(statut)),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: _kEventPrimary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
