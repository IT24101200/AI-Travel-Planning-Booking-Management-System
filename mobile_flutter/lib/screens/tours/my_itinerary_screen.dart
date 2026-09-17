import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// My Itinerary screen showing day-by-day timeline of scheduled tours and activities.
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getMyItineraries();
      if (mounted) {
        setState(() {
          _itineraries = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load itineraries';
          _loading = false;
        });
      }
    }
  }

  /// Load a single itinerary with items
  Future<void> _loadItineraryDetail(int id) async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getItinerary(id);
      if (mounted) {
        setState(() {
          _selectedItinerary = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load itinerary details';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedItinerary != null ? 'Day-by-Day Schedule' : 'My Travel Itineraries'),
        leading: _selectedItinerary != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedItinerary = null),
              )
            : null,
        actions: [
          if (_selectedItinerary != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View Trip Map',
              onPressed: () => Navigator.pushNamed(context, '/trip-map', arguments: _selectedItinerary),
            ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading itinerary schedule...')
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
      return EmptyState(
        icon: Icons.calendar_today_outlined,
        message: 'No active itineraries yet.\nSubmit a trip prompt and our AI Coordinator will build one for you.',
        actionLabel: 'Plan Trip Now',
        onAction: () => Navigator.pushNamed(context, '/trip-request'),
      );
    }

    return RefreshIndicator(
      color: AppColors.jungle600,
      onRefresh: _loadItineraries,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _itineraries.length,
        itemBuilder: (context, index) {
          final it = _itineraries[index];
          final total = (it['totalEstimatedCost'] ?? 0).toDouble();
          final currency = it['currency'] ?? 'USD';
          final status = it['status']?.toString() ?? 'Proposed';
          final dates =
              '${it['startDate']?.toString().substring(0, 10) ?? ''}  →  ${it['endDate']?.toString().substring(0, 10) ?? ''}';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _loadItineraryDetail(it['id']),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.leaf50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.alt_route, color: AppColors.jungle600, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Itinerary #${it['id']} • Sri Lanka',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                dates,
                                style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: status),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.line),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Budget', style: TextStyle(fontSize: 11, color: AppColors.ink3)),
                            Text(
                              '\$${total.toStringAsFixed(0)} $currency',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.jungle600,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'View Timeline',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.jungle600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.jungle600),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Detail view with day-by-day timeline
  Widget _buildItineraryDetail() {
    final items = _selectedItinerary!['items'] as List<dynamic>? ?? [];
    final totalCost = (_selectedItinerary!['totalEstimatedCost'] ?? 0).toDouble();
    final currency = _selectedItinerary!['currency'] ?? 'USD';

    // Group items by day number
    final Map<int, List<dynamic>> dayGroups = {};
    for (var item in items) {
      final day = item['dayNumber'] ?? 1;
      dayGroups.putIfAbsent(day, () => []);
      dayGroups[day]!.add(item);
    }

    dayGroups.forEach((day, dayItems) {
      dayItems.sort((a, b) => (a['sequenceOrder'] ?? 0).compareTo(b['sequenceOrder'] ?? 0));
    });

    final sortedDays = dayGroups.keys.toList()..sort();

    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.event_note,
                  message: 'No activities scheduled for this itinerary yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Total', style: TextStyle(fontSize: 11, color: AppColors.ink3)),
                  Text(
                    '\$${totalCost.toStringAsFixed(0)} $currency',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.jungle600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/checkout', arguments: _selectedItinerary);
                },
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('Proceed to Checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDaySection(int day, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Banner Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.jungle700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'DAY $day',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Items for that day
        ...items.map((item) {
          final tourName = item['tourName'] ?? 'Scenic Excursion';
          final image = AppDestinations.getImageForDestination(tourName);
          final startTime = item['startTime'] ?? '09:00 AM';
          final endTime = item['endTime'] ?? '12:00 PM';
          final price = (item['priceAtSelection'] ?? 0).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 10, left: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkImage(
                    imageUrl: image,
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tourName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 13, color: AppColors.ink3),
                          const SizedBox(width: 4),
                          Text(
                            '$startTime – $endTime',
                            style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.jungle600,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
