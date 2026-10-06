import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

/// Transport options screen matching Figma Dev Mode (09 · Transport Options).
class TransportOptionsScreen extends StatefulWidget {
  const TransportOptionsScreen({super.key});

  @override
  State<TransportOptionsScreen> createState() => _TransportOptionsScreenState();
}

class _TransportOptionsScreenState extends State<TransportOptionsScreen> {
  List<dynamic> _options = [];
  String _selectedCategory = 'Car Rental';
  int _selectedIndex = 0;

  final List<String> _categories = ['Car Rental', 'Train', 'Bus', 'Tuk-Tuk'];

  final List<Map<String, dynamic>> _sampleVehicles = [
    {
      'id': '1',
      'tag': 'BEST MATCH',
      'name': 'Private Hybrid Sedan',
      'provider': 'Serendib Mobility · 4.9',
      'capacity': '3 guests · 2 bags',
      'features': 'A/C · English-speaking driver · Flexible stops',
      'price': 118,
      'buttonLabel': 'Book Car',
      'imageUrl': 'assets/photos/nuwara-eliya-1280.jpg',
    },
    {
      'id': '2',
      'tag': 'MORE SPACE',
      'name': 'Premium Safari Van',
      'provider': 'Ceylon Routes · 4.8',
      'capacity': '6 guests · 5 bags',
      'features': 'A/C · Wi-Fi · Child seat available',
      'price': 164,
      'buttonLabel': 'Select Van',
      'imageUrl': 'assets/photos/kandy-1280.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  Future<void> _loadTransport() async {
    try {
      final list = await ApiService.getTransportOptions();
      if (mounted) {
        setState(() {
          _options = list.isNotEmpty ? list : _sampleVehicles;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _options = _sampleVehicles;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _options.isNotEmpty ? _options : _sampleVehicles;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transport',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Compare verified island travel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEDECE4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.help_outline, color: Color(0xFF1E1E1E), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Category Filter Pills ──
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Route Dark Green Banner ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF134035),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR ROUTE · 12 OCTOBER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD4A346),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CMB',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Colombo Airport',
                              style: TextStyle(color: Color(0xFFB8D3C8), fontSize: 11),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward, color: Color(0xFFD4A346), size: 20),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'SIG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Sigiriya · 3h 40m',
                              style: TextStyle(color: Color(0xFFB8D3C8), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Vehicles List ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final vehicle = displayList[index];
                  final isSelected = index == _selectedIndex;
                  return _buildVehicleCard(vehicle, index, isSelected);
                },
              ),
            ),

            // ── Bottom Train Note Banner (Soft Sand) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/checkout'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EED8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_subway_outlined, color: Color(0xFFB27D26), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ella leg? Reserved scenic train seats are available from \$24.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF08201A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFFB27D26), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> item, int index, bool isSelected) {
    final tag = item['tag'] ?? 'BEST MATCH';
    final name = item['name'] ?? 'Private Hybrid Sedan';
    final provider = item['provider'] ?? 'Serendib Mobility · 4.9';
    final capacity = item['capacity'] ?? '3 guests · 2 bags';
    final features = item['features'] ?? 'A/C · English-speaking driver';
    final price = item['price'] ?? 118;
    final btnLabel = item['buttonLabel'] ?? 'Book Car';
    final imageUrl = item['imageUrl'] ?? 'assets/photos/nuwara-eliya-1280.jpg';

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4A346) : const Color(0xFFEDECE4),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 104,
                    height: 78,
                    child: imageUrl.startsWith('http')
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C)))
                        : Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C))),
                  ),
                ),
                const SizedBox(width: 14),

                // Vehicle Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD4A346),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF08201A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E96)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people_alt, size: 12, color: Color(0xFF4B5563)),
                          const SizedBox(width: 4),
                          Text(
                            capacity,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(
              features,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B6B5D),
              ),
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFEDECE4)),
            const SizedBox(height: 12),

            // Price & Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$$price',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    const Text(
                      'total · all inclusive',
                      style: TextStyle(fontSize: 10, color: Color(0xFF8A9E96)),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/checkout'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E382C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      btnLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
