import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Tour details screen showing full tour information.
class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({super.key});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  Map<String, dynamic>? _tour;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tourId = ModalRoute.of(context)?.settings.arguments as int?;
    if (tourId != null && _tour == null) {
      _loadTour(tourId);
    }
  }

  /// Fetch tour details from backend
  Future<void> _loadTour(int id) async {
    setState(() { _loading = true; _error = null; });
    try {
      _tour = await ApiService.getTour(id);
      if (_tour == null) _error = 'Tour not found';
    } catch (e) {
      _error = 'Failed to load tour details';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tour Details')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading tour...')
          : _error != null
              ? ErrorMessage(message: _error!)
              : _tour == null
                  ? const EmptyState(message: 'Tour not found')
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tour image placeholder
                          Container(
                            width: double.infinity,
                            height: 200,
                            color: const Color(0xFF0D9488).withOpacity(0.15),
                            child: const Center(
                              child: Icon(Icons.landscape, size: 80, color: Color(0xFF0D9488)),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tour name
                                Text(
                                  _tour!['name'] ?? 'Unnamed Tour',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),

                                // Category + status
                                Row(
                                  children: [
                                    StatusBadge(status: _tour!['category'] ?? ''),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: _tour!['status'] ?? 'Active'),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Description
                                if (_tour!['description'] != null) ...[
                                  const Text(
                                    'Description',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tour!['description'],
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Price breakdown card
                                Card(
                                  color: Colors.teal.shade50,
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _infoRow(Icons.attach_money, 'Price',
                                            '\$${(_tour!['price'] ?? 0).toStringAsFixed(2)} ${_tour!['currency'] ?? 'USD'}'),
                                        const Divider(),
                                        _infoRow(Icons.access_time, 'Duration',
                                            '${_tour!['durationHours'] ?? 0} hours'),
                                        const Divider(),
                                        _infoRow(Icons.schedule, 'Start Time',
                                            _tour!['defaultStartTime'] ?? 'N/A'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Coordinates
                                if (_tour!['latitude'] != null && _tour!['longitude'] != null) ...[
                                  const Text(
                                    'Location',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      leading: const Icon(Icons.location_on, color: Color(0xFF0D9488)),
                                      title: Text('Lat: ${_tour!['latitude']}, Lng: ${_tour!['longitude']}'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  /// Helper widget for info rows
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0D9488)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
