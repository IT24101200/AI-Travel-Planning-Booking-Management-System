import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Trip history screen showing past trip requests with status badges.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<dynamic> _trips = [];
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load trip requests and bookings from backend
  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      _trips = await ApiService.getMyTripRequests();
      _bookings = await ApiService.getMyBookings();
    } catch (e) {
      _error = 'Failed to load trip history';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          // Quick links
          IconButton(
            icon: const Icon(Icons.hotel),
            onPressed: () => Navigator.pushNamed(context, '/accommodation'),
            tooltip: 'Hotels',
          ),
          IconButton(
            icon: const Icon(Icons.commute),
            onPressed: () => Navigator.pushNamed(context, '/transport'),
            tooltip: 'Transport',
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading trips...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadData)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _trips.isEmpty && _bookings.isEmpty
                      ? const EmptyState(
                          icon: Icons.card_travel,
                          message: 'No trips yet.\nTap "Plan a Trip" to get started!',
                        )
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            // Bookings section
                            if (_bookings.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Bookings',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              ..._bookings.map((b) => _buildBookingCard(b)),
                              const SizedBox(height: 16),
                            ],

                            // Trip requests section
                            if (_trips.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Trip Requests',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              ..._trips.map((t) => _buildTripCard(t)),
                            ],
                          ],
                        ),
                ),
    );
  }

  /// Build a booking card
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    // Convert enum int to string for status
    String status = booking['status']?.toString() ?? 'Unknown';
    if (booking['status'] is int) {
      const statusMap = {0: 'Draft', 1: 'AwaitingApproval', 2: 'Confirmed', 3: 'Rejected', 4: 'Cancelled', 5: 'Completed'};
      status = statusMap[booking['status']] ?? 'Unknown';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/booking-status', arguments: booking['id']),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    booking['bookingReference'] ?? 'Booking #${booking['id']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '\$${(booking['totalCost'] ?? 0).toStringAsFixed(2)} ${booking['currency'] ?? 'USD'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                  ),
                  const Spacer(),
                  Text(
                    booking['createdAt']?.toString().substring(0, 10) ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a trip request card
  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/itinerary'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flight, color: Color(0xFF7C5CFC)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip['destinationName'] ?? 'Trip Request #${trip['id']}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusBadge(status: trip['status'] ?? 'Pending'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${trip['startDate']?.toString().substring(0, 10) ?? ''} → ${trip['endDate']?.toString().substring(0, 10) ?? ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.group, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${trip['travellerCount'] ?? 1} travellers',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Text(
                    'Budget: \$${(trip['budgetCeiling'] ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
