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

  // Curated hotel photography fallback
  final List<String> _hotelImages = [
    'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&auto=format&fit=crop&q=80',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotels & Boutique Stays')),
      body: _loading
          ? const LoadingIndicator(
              message: 'Finding luxury & heritage hotels...',
            )
          : _error != null
          ? ErrorMessage(message: _error!, onRetry: _loadHotels)
          : _hotels.isEmpty
          ? _buildSampleHotelsView()
          : RefreshIndicator(
              color: AppColors.jungle600,
              onRefresh: _loadHotels,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _hotels.length,
                itemBuilder: (context, index) =>
                    _buildHotelCard(_hotels[index], index),
              ),
            ),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel, int index) {
    final rooms = hotel['rooms'] as List<dynamic>? ?? [];
    final stars = hotel['starRating'] ?? 4;
    final name = hotel['name'] ?? 'Heritage Resort';
    final address = hotel['address'] ?? 'Scenic Province, Sri Lanka';
    final image = _hotelImages[index % _hotelImages.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AppNetworkImage(
              imageUrl: image,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  stars,
                  (_) => const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.sand500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            const Divider(color: AppColors.line),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.meeting_room_outlined,
                  size: 16,
                  color: AppColors.jungle600,
                ),
                const SizedBox(width: 6),
                Text(
                  'Available Room Types (${rooms.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.jungle800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rooms.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Standard & Deluxe options automatically coordinated by AI Booking Agent',
                    style: TextStyle(fontSize: 12, color: AppColors.ink2),
                  ),
                ),
              )
            else
              ...rooms.map<Widget>((room) => _buildRoomTile(room)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final price = (room['pricePerNight'] ?? 0).toDouble();
    final currency = room['currency'] ?? 'USD';
    final roomType = room['roomType'] ?? 'Deluxe Room';
    final capacity = room['capacity'] ?? 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.leaf50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.leaf100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bed_outlined,
              color: AppColors.jungle600,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.ink,
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
