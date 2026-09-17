import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Transport options screen showing available transport choices.
class TransportOptionsScreen extends StatefulWidget {
  const TransportOptionsScreen({super.key});

  @override
  State<TransportOptionsScreen> createState() => _TransportOptionsScreenState();
}

class _TransportOptionsScreenState extends State<TransportOptionsScreen> {
  List<dynamic> _options = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  /// Fetch transport options from backend
  Future<void> _loadTransport() async {
    setState(() { _loading = true; _error = null; });
    try {
      _options = await ApiService.getTransportOptions();
    } catch (e) {
      _error = 'Failed to load transport options';
    }
    if (mounted) setState(() { _loading = false; });
  }

  /// Get icon for transport type
  IconData _getTransportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return Icons.flight;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.commute;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Options')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading transport...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadTransport)
              : _options.isEmpty
                  ? const EmptyState(icon: Icons.commute, message: 'No transport options available')
                  : RefreshIndicator(
                      onRefresh: _loadTransport,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _options.length,
                        itemBuilder: (context, index) => _buildTransportCard(_options[index]),
                      ),
                    ),
    );
  }

  /// Build a transport option card
  Widget _buildTransportCard(Map<String, dynamic> option) {
    final type = option['type'] ?? 'Unknown';
    final departure = option['departureTime']?.toString().substring(0, 16) ?? '';
    final arrival = option['arrivalTime']?.toString().substring(0, 16) ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Transport type icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getTransportIcon(type), color: const Color(0xFF7C5CFC)),
                ),
                const SizedBox(width: 16),
                // Route info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${option['routeFrom'] ?? ''} → ${option['routeTo'] ?? ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${option['provider'] ?? ''} · $type',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(option['price'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    StatusBadge(status: option['status'] ?? 'Active'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Departure and arrival times
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Depart: $departure', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                Icon(Icons.flight_land, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Arrive: $arrival', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            // Capacity info
            Row(
              children: [
                Icon(Icons.event_seat, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Capacity: ${option['capacity'] ?? 0} seats',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
