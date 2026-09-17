import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Accommodation options screen showing hotels and rooms.
class AccommodationOptionsScreen extends StatefulWidget {
  const AccommodationOptionsScreen({super.key});

  @override
  State<AccommodationOptionsScreen> createState() => _AccommodationOptionsScreenState();
}

class _AccommodationOptionsScreenState extends State<AccommodationOptionsScreen> {
  List<dynamic> _hotels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  /// Fetch hotels from backend
  Future<void> _loadHotels() async {
    setState(() { _loading = true; _error = null; });
    try {
      _hotels = await ApiService.getHotels();
    } catch (e) {
      _error = 'Failed to load hotels';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accommodation')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading hotels...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadHotels)
              : _hotels.isEmpty
                  ? const EmptyState(icon: Icons.hotel, message: 'No hotels available')
                  : RefreshIndicator(
                      onRefresh: _loadHotels,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _hotels.length,
                        itemBuilder: (context, index) => _buildHotelCard(_hotels[index]),
                      ),
                    ),
    );
  }

  /// Build a hotel card with expandable room list
  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    final rooms = hotel['rooms'] as List<dynamic>? ?? [];
    final stars = hotel['starRating'] ?? 0;

    return Card(
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.hotel, color: Colors.amber),
        ),
        title: Text(
          hotel['name'] ?? 'Hotel',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Star rating
            Row(
              children: List.generate(
                stars,
                (_) => const Icon(Icons.star, size: 14, color: Colors.amber),
              ),
            ),
            if (hotel['address'] != null)
              Text(
                hotel['address'],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        // Room list when expanded
        children: rooms.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No rooms listed', style: TextStyle(color: Colors.grey)),
                )
              ]
            : rooms.map<Widget>((room) => _buildRoomTile(room)).toList(),
      ),
    );
  }

  /// Build a single room tile
  Widget _buildRoomTile(Map<String, dynamic> room) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(Icons.bed, color: Colors.teal.shade300),
      title: Text(room['roomType'] ?? 'Room'),
      subtitle: Text('Capacity: ${room['capacity'] ?? 0} guests'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '\$${(room['pricePerNight'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
          ),
          Text('/night', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
