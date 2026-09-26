import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Accommodation options screen showing verified Sri Lankan hotels and room categories.
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
  Map<String, dynamic>? _selectedRoom;
  String _selectedHotelName = '';

  // Curated hotel photography using bundled local assets
  final List<String> _hotelImages = [
    'assets/photos/nuwara-eliya-1280.jpg',
    'assets/photos/kandy-1280.jpg',
    'assets/photos/mirissa-1280.jpg',
    'assets/photos/sigiriya-1280.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getHotels();
      if (mounted) {
        setState(() {
          _hotels = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load accommodation catalog';
          _loading = false;
        });
      }
    }
  }

  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Boutique Eco-Lodge',
    'Heritage Manor',
    'Hill Country Tea Estate',
    'Luxury Resort',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accommodation & Stays'),
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.jungle600),
            tooltip: 'View on Interactive Map',
            onPressed: () => Navigator.pushNamed(context, '/trip-map'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(
              message: 'Finding luxury & heritage eco-lodges...',
            )
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadHotels)
              : RefreshIndicator(
                  color: AppColors.jungle600,
                  onRefresh: _loadHotels,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      // Header Intro & Editorial Framing
                      const Row(
                        children: [
                          Icon(Icons.eco, size: 16, color: AppColors.jungle600),
                          SizedBox(width: 4),
                          Text(
                            'CEYLON SANCTUM COLLECTION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.jungle600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Curated Stays & Eco-Lodges',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hand-picked eco-villas, boutique hotels and heritage stays in Central Province & Southern Coast.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search & Date Selection Strip
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.location_on, size: 18, color: AppColors.jungle600),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('PROVINCE HUB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.inkTertiary)),
                                              Text('Sigiriya & Central', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.leaf50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: AppColors.jungle600),
                                      SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('DATES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.jungle600)),
                                          Text('Oct 14 - Oct 20', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Category Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.map((cat) {
                                  final isSelected = _selectedCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () => setState(() => _selectedCategory = cat),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.jungle600 : AppColors.surfaceContainer,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            color: isSelected ? Colors.white : AppColors.inkSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Hotel Listings
                      if (_hotels.isEmpty)
                        _buildSampleHotelsView()
                      else
                        ..._hotels.asMap().entries.map((entry) => _buildHotelCard(entry.value, entry.key)),
                    ],
                  ),
                ),
      bottomNavigationBar: _selectedRoom != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.line)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedHotelName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selectedRoom!['roomType']} • \$${_selectedRoom!['pricePerNight']}/night',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.jungle600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/trip-map'),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.jungle600,
                        side: const BorderSide(color: AppColors.jungle600),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/transport'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Transit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.jungle600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel, int index) {
    final rooms = hotel['rooms'] as List<dynamic>? ?? [];
    final name = hotel['name'] ?? 'Heritage Resort';
    final address = hotel['address'] ?? 'Scenic Province, Sri Lanka';
    final image = _hotelImages[index % _hotelImages.length];
    final isSelectedHotel = _selectedHotelName == name;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelectedHotel ? AppColors.jungle600 : AppColors.line,
          width: isSelectedHotel ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media with Overlays
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AppNetworkImage(
                  imageUrl: image,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.jungle900.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Certification Badge Top Left
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.leaf100.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium, size: 14, color: AppColors.jungle700),
                      SizedBox(width: 4),
                      Text(
                        'Sustainable Gold Certified',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.jungle700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Price corner bottom right
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '\$140',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '/night',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Content Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.near_me, size: 12, color: AppColors.inkTertiary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(fontSize: 11, color: AppColors.inkTertiary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sand100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.sand600),
                          SizedBox(width: 3),
                          Text('4.9', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.sand700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Deluxe Treehouse Suite with private open-air verandah facing ancient sanctum forest.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 10),
                // Eco & Luxury Amenities Chips
                const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _AmenityTag(icon: Icons.restaurant, label: 'Farm-to-Table'),
                    _AmenityTag(icon: Icons.pool, label: 'Infinity Pool'),
                    _AmenityTag(icon: Icons.spa, label: 'Ayurveda Spa'),
                    _AmenityTag(icon: Icons.wifi, label: 'Free Wi-Fi'),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.line, height: 1),
                const SizedBox(height: 10),
                // Rooms Expansion Section
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    initiallyExpanded: index == 0,
                    title: Text(
                      'View Available Suites & Rates (${rooms.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.jungle700,
                      ),
                    ),
                    children: rooms.isEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.mist,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'Standard & Deluxe options coordinated by AI Agent',
                                  style: TextStyle(fontSize: 11, color: AppColors.inkSecondary),
                                ),
                              ),
                            ),
                          ]
                        : rooms.map<Widget>((room) => _buildRoomTile(room, name)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRoomTile(Map<String, dynamic> room, String hotelName) {
    final price = (room['pricePerNight'] ?? 0).toDouble();
    final currency = room['currency'] ?? 'USD';
    final roomType = room['roomType'] ?? 'Deluxe Room';
    final capacity = room['capacity'] ?? 2;
    final isSelected = _selectedRoom == room;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRoom = room;
          _selectedHotelName = hotelName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected $roomType at $hotelName'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.jungle600,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.leaf50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.jungle600 : AppColors.line,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.jungle600 : AppColors.leaf50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.bed_outlined,
                color: isSelected ? Colors.white : AppColors.jungle600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomType,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? AppColors.jungle700 : AppColors.ink,
                    ),
                  ),
                  Text(
                    'Capacity: $capacity Guests',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.jungle600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$currency / night',
                  style: const TextStyle(fontSize: 10, color: AppColors.ink3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleHotelsView() {
    final samples = [
      {
        'name': 'Heritance Kandalama',
        'address': 'Dambulla / Sigiriya, Cultural Triangle',
        'starRating': 5,
        'rooms': [
          {
            'roomType': 'Superior Panoramic Room',
            'capacity': 2,
            'pricePerNight': 195,
            'currency': 'USD',
          },
          {
            'roomType': 'Luxury Suite with Jacuzzi',
            'capacity': 3,
            'pricePerNight': 285,
            'currency': 'USD',
          },
        ],
      },
      {
        'name': '98 Acres Resort & Spa',
        'address': 'Greenland Estate, Ella',
        'starRating': 5,
        'rooms': [
          {
            'roomType': 'Standard Chalet',
            'capacity': 2,
            'pricePerNight': 210,
            'currency': 'USD',
          },
          {
            'roomType': 'Greenland Executive Suite',
            'capacity': 4,
            'pricePerNight': 340,
            'currency': 'USD',
          },
        ],
      },
      {
        'name': 'Cinnamon Wild Yala',
        'address': 'Kirinda, Deep South Wildlife Reserve',
        'starRating': 4,
        'rooms': [
          {
            'roomType': 'Jungle Chalet',
            'capacity': 2,
            'pricePerNight': 175,
            'currency': 'USD',
          },
          {
            'roomType': 'Beach Chalet',
            'capacity': 2,
            'pricePerNight': 225,
            'currency': 'USD',
          },
        ],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: samples.length,
      itemBuilder: (context, index) => _buildHotelCard(samples[index], index),
    );
  }
}

class _AmenityTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AmenityTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.jungle600),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
