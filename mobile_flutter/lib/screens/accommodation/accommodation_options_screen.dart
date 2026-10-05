import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../services/currency_notifier.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/common_widgets.dart';
import '../../main.dart' show currencyNotifier;

/// Accommodation options screen matching Figma frame 08 · Accommodation Options (node 7:10737)
class AccommodationOptionsScreen extends StatefulWidget {
  const AccommodationOptionsScreen({super.key});

  @override
  State<AccommodationOptionsScreen> createState() =>
      _AccommodationOptionsScreenState();
}

class _AccommodationOptionsScreenState
    extends State<AccommodationOptionsScreen> {
  List<dynamic> _hotels = [];
  bool _loading = true;
  String? _error;

  String _selectedCategory = 'Hotel';
  final List<String> _categories = ['Hotel', 'Resort', 'Villa', 'Hostel'];

  // Default curated stays matching Figma
  final List<Map<String, dynamic>> _curatedStays = [
    {
      'id': 'heritance',
      'name': 'Heritance Kandalama',
      'location': 'Dambulla · 11 km from Sigiriya',
      'amenities': 'Pool · Spa · Lake view',
      'rating': 4.9,
      'price': 186,
      'image':
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': '98acres',
      'name': '98 Acres Resort',
      'location': 'Ella · Tea estate',
      'amenities': 'Breakfast · Pool · Mountain view',
      'rating': 4.8,
      'price': 214,
      'image':
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': 'fortprinters',
      'name': 'The Fort Printers',
      'location': 'Galle Fort · Historic quarter',
      'amenities': 'Courtyard · Breakfast · Wi-Fi',
      'rating': 4.7,
      'price': 142,
      'image':
          'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600&auto=format&fit=crop&q=80',
    },
  ];

  late String _selectedStayId;

  @override
  void initState() {
    super.initState();
    _selectedStayId = _curatedStays.first['id'];
    TripSelectionService.selectedHotel = _curatedStays.first;
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getHotels(currency: currencyNotifier.value);
      if (mounted) {
        setState(() {
          _hotels = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Keep curated fallback on error
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_error != null && _hotels.isEmpty && _curatedStays.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.figmaDarkGreen),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Choose your stay',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ErrorMessage(message: _error!, onRetry: _loadHotels),
      );
    }

    // Merge backend hotels if available
    final List<Map<String, dynamic>> displayStays = _hotels.isNotEmpty
        ? _hotels.map((h) {
            return {
              'id': h['id'].toString(),
              'name': h['name'] ?? 'Boutique Hotel',
              'location': h['city'] != null
                  ? '${h['city']} · Central Province'
                  : 'Sri Lanka',
              'amenities': h['amenities'] ?? 'Wi-Fi · Breakfast · AC',
              'rating': 4.8,
              'price': (h['pricePerNight'] ?? 150).toInt(),
              'image': (h['imageUrl'] != null &&
                      h['imageUrl'].toString().isNotEmpty)
                  ? ApiService.resolveMediaUrl(h['imageUrl'])
                  : 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&auto=format&fit=crop&q=80',
            };
          }).toList()
        : _curatedStays;

    final selectedStay = displayStays.firstWhere(
      (s) => s['id'] == _selectedStayId,
      orElse: () => displayStays.first,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  // Title & Guests
                  Column(
                    children: [
                      Text(
                        'Choose your stay',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '12–18 Oct · 2 guests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Map Icon Button
                  GestureDetector(
                    onTap: () {
                      TripSelectionService.selectedHotel = selectedStay;
                      Navigator.pushNamed(context, '/trip-map');
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Category Pills Filter Row ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A2F) : AppColors.figmaDarkGreen)
                                : theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                                  : (isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder),
                            ),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              // ── Recommended Stays Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayStays.length} recommended stays',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Best match',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.leaf400 : const Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: isDark ? AppColors.leaf400 : const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Stay Cards List ──
              ...displayStays.map((stay) {
                final isSelected = stay['id'] == _selectedStayId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.figmaGold
                          : (isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          stay['image'] as String,
                          width: 110,
                          height: 125,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 110,
                            height: 125,
                            color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                            child: const Icon(
                              Icons.hotel,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Rating & Selected pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.figmaGold,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${stay['rating']}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C261A) : const Color(0xFFFBF4E4),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'SELECTED',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.figmaGold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Name
                            Text(
                              stay['name'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Location
                            Text(
                              stay['location'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            // Amenities
                            Text(
                              stay['amenities'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark ? AppColors.leaf400 : const Color(0xFF0F766E),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Price & Action Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatMoney(stay['price'], stay['currency']?.toString() ?? currencyNotifier.value),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                      ),
                                    ),
                                    Text(
                                      'per night',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStayId = stay['id'] as String;
                                      TripSelectionService.selectedHotel = stay;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.figmaGold
                                          : (isDark ? const Color(0xFF1E3A2F) : AppColors.figmaDarkGreen),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isSelected ? 'Selected' : 'Select',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 10),

              // ── Policy Box ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFEAF2EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF0F766E),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rates include taxes and free cancellation until 8 October.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Continue Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    TripSelectionService.selectedHotel = selectedStay;
                    Navigator.pushNamed(
                      context,
                      '/transport',
                      arguments: selectedStay,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.figmaDarkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Continue with ${selectedStay['name']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
