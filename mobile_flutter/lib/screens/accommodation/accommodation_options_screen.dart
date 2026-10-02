import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

/// Accommodation options screen matching Figma Dev Mode (08 · Accommodation Options).
class AccommodationOptionsScreen extends StatefulWidget {
  const AccommodationOptionsScreen({super.key});

  @override
  State<AccommodationOptionsScreen> createState() =>
      _AccommodationOptionsScreenState();
}

class _AccommodationOptionsScreenState
    extends State<AccommodationOptionsScreen> {
  List<dynamic> _hotels = [];
  String _selectedCategory = 'Hotel';
  int _selectedIndex = 0;

  final List<String> _categories = ['Hotel', 'Resort', 'Villa', 'Hostel'];

  // Default curated stays matching Figma
  final List<Map<String, dynamic>> _sampleStays = [
    {
      'id': '1',
      'name': 'Heritance Kandalama',
      'location': 'Dambulla · 11 km from Sigiriya',
      'amenities': 'Pool · Spa · Lake view',
      'price': 186,
      'rating': 4.9,
      'imageUrl': 'assets/photos/sigiriya-1280.jpg',
    },
    {
      'id': '2',
      'name': '98 Acres Resort',
      'location': 'Ella · Tea estate',
      'amenities': 'Breakfast · Pool · Mountain view',
      'price': 214,
      'rating': 4.8,
      'imageUrl': 'assets/photos/nuwara-eliya-1280.jpg',
    },
    {
      'id': '3',
      'name': 'The Fort Printers',
      'location': 'Galle Fort · Historic quarter',
      'amenities': 'Courtyard · Breakfast · Wi-Fi',
      'price': 142,
      'rating': 4.7,
      'imageUrl': 'assets/photos/mirissa-1280.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    try {
      final list = await ApiService.getHotels();
      if (mounted) {
        setState(() {
          _hotels = list.isNotEmpty ? list : _sampleStays;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hotels = _sampleStays;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stays = _hotels.isNotEmpty ? _hotels : _sampleStays;
    final selectedHotel = stays.isNotEmpty && _selectedIndex < stays.length
        ? stays[_selectedIndex]['name'] ?? 'Heritance Kandalama'
        : 'Heritance Kandalama';

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
                          'Choose your stay',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '12–18 Oct · 2 guests',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/trip-map'),
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
                        child: Icon(Icons.map_outlined, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Category Filter Chips ──
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

            // ── Count and Sorting Row ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '18 recommended stays',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF08201A),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Best match',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0E382C),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_downward, size: 13, color: Color(0xFF0E382C)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Stays List ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                itemCount: stays.length,
                itemBuilder: (context, index) {
                  final stay = stays[index];
                  final isSelected = index == _selectedIndex;
                  return _buildStayCard(stay, index, isSelected);
                },
              ),
            ),

            // ── Policy Mint Banner ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEFAF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9F4E7)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF13684B), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rates include taxes and free cancellation until 8 October.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0A3628),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Fixed Continue Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/transport'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Continue with $selectedHotel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildStayCard(Map<String, dynamic> stay, int index, bool isSelected) {
    final name = stay['name'] ?? 'Stay';
    final location = stay['location'] ?? stay['city'] ?? 'Sri Lanka';
    final amenities = stay['amenities'] ?? 'Pool · Spa · Wi-Fi';
    final price = stay['price'] ?? stay['pricePerNight'] ?? 180;
    final rating = (stay['rating'] ?? 4.8).toString();
    final imageUrl = stay['imageUrl'] ?? 'assets/photos/sigiriya-1280.jpg';

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Image (rounded square)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 104,
                height: 104,
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C)))
                    : Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0E382C))),
              ),
            ),
            const SizedBox(width: 14),

            // Right Info
            Expanded(
              child: SizedBox(
                height: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating & Optional Selected Tag
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFD4A346), size: 14),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF4E4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SELECTED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD4A346),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Title
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08201A),
                      ),
                    ),

                    // Location
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),

                    // Amenities (teal)
                    Text(
                      amenities,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B6B5D),
                      ),
                    ),

                    // Price & Button
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
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF08201A),
                              ),
                            ),
                            const Text(
                              'per night',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF8A9E96)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFD4A346) : const Color(0xFF0E382C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isSelected ? 'Selected' : 'Select',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
