import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// My Itinerary screen showing day-by-day timeline of scheduled tours.
class MyItineraryScreen extends StatefulWidget {
  const MyItineraryScreen({super.key});

  @override
  State<MyItineraryScreen> createState() => _MyItineraryScreenState();
}

class _MyItineraryScreenState extends State<MyItineraryScreen> {
  List<dynamic> _itineraries = [];
  Map<String, dynamic>? _selectedItinerary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  /// Fetch customer itineraries from the backend
  Future<void> _loadItineraries() async {
    setState(() { _loading = true; _error = null; });
    try {
      _itineraries = await ApiService.getMyItineraries();
    } catch (e) {
      _error = 'Failed to load itineraries';
    }
    if (mounted) setState(() { _loading = false; });
  }

  /// Load a single itinerary with items
  Future<void> _loadItineraryDetail(int id) async {
    setState(() { _loading = true; });
    try {
      _selectedItinerary = await ApiService.getItinerary(id);
    } catch (e) {
      _error = 'Failed to load itinerary details';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedItinerary != null ? 'Itinerary Details' : 'My Itineraries'),
        leading: _selectedItinerary != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _selectedItinerary = null; }),
              )
            : null,
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadItineraries)
              : _selectedItinerary != null
                  ? _buildItineraryDetail()
                  : _buildItineraryList(),
    );
  }

  /// List of itineraries
  Widget _buildItineraryList() {
    if (_itineraries.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_today,
        message: 'No itineraries yet.\nSubmit a trip request to get started!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _itineraries.length,
      itemBuilder: (context, index) {
        final it = _itineraries[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.route, color: Color(0xFF0D9488)),
            title: Text('Itinerary #${it['id']}'),
            subtitle: Text(
              '${it['startDate']?.toString().substring(0, 10) ?? ''} – ${it['endDate']?.toString().substring(0, 10) ?? ''}',
            ),
            trailing: StatusBadge(status: it['status']?.toString() ?? 'Draft'),
            onTap: () => _loadItineraryDetail(it['id']),
          ),
        );
      },
    );
  }

  /// Detail view with day-by-day timeline
  Widget _buildItineraryDetail() {
    final items = _selectedItinerary!['items'] as List<dynamic>? ?? [];
    final totalCost = _selectedItinerary!['totalEstimatedCost'] ?? 0;
    final currency = _selectedItinerary!['currency'] ?? 'USD';

    // Group items by day number
    final Map<int, List<dynamic>> dayGroups = {};
    for (var item in items) {
      final day = item['dayNumber'] ?? 1;
      dayGroups.putIfAbsent(day, () => []);
      dayGroups[day]!.add(item);
    }

    // Sort each day's items by sequence order
    dayGroups.forEach((day, dayItems) {
      dayItems.sort((a, b) => (a['sequenceOrder'] ?? 0).compareTo(b['sequenceOrder'] ?? 0));
    });

    final sortedDays = dayGroups.keys.toList()..sort();

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const EmptyState(icon: Icons.event_note, message: 'No items in this itinerary')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDays.length,
                  itemBuilder: (context, index) {
                    final day = sortedDays[index];
                    final dayItems = dayGroups[day]!;
                    return _buildDaySection(day, dayItems);
                  },
                ),
        ),
        // Bottom bar with total cost and proceed button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Estimated Cost', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '\$${totalCost.toStringAsFixed(2)} $currency',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/checkout', arguments: _selectedItinerary);
                },
                child: const Text('Proceed to Booking'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a section for one day
  Widget _buildDaySection(int day, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Day $day',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
          ),
        ),
        ...items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8, left: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${item['sequenceOrder'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C5CFC)),
                    ),
                  ),
                ),
                title: Text(item['tourName'] ?? 'Tour'),
                subtitle: Text(
                  '${item['startTime'] ?? ''} – ${item['endTime'] ?? ''}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: Text(
                  '\$${(item['priceAtSelection'] ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D9488)),
                ),
              ),
            )),
        const Divider(height: 24),
      ],
    );
  }
}
