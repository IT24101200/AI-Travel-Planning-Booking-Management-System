import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

const List<String> kItineraryStatusLabels = [
  'Draft',
  'Proposed',
  'Accepted',
  'Discarded',
];

String normalizeItineraryStatus(dynamic status) {
  if (status is int) {
    return (status >= 0 && status < kItineraryStatusLabels.length)
        ? kItineraryStatusLabels[status]
        : 'Unknown';
  }
  if (status is String && status.isNotEmpty) return status;
  return 'Unknown';
}

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

  /// Prompts the customer for confirmation, then marks the itinerary as
  /// Discarded via the backend so it can be re-planned or reviewed by staff.
  Future<void> _requestChanges() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Changes?'),
        content: const Text(
          'This will mark the current itinerary as needing revision. '
          'Our team will review your trip request again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.jungle600,
            ),
            child: const Text('Yes, Request Changes'),
          ),
        ],
      ),
    );

    if (confirmed != true || _selectedItinerary == null) return;

    final itineraryId = _selectedItinerary!['id'];
    final success = await ApiService.requestItineraryChanges(itineraryId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change request submitted.')),
      );
      setState(() => _selectedItinerary = null);
      _loadItineraries();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit change request. Please try again.'),
        ),
      );
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
        title: Text(
          _selectedItinerary != null
              ? 'Day-by-Day Schedule'
              : 'My Travel Itineraries',
        ),
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
              onPressed: () => Navigator.pushNamed(
                context,
                '/trip-map',
                arguments: _selectedItinerary,
              ),
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
        message:
            'No active itineraries yet.\nSubmit a trip prompt and our AI Coordinator will build one for you.',
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
          final status = normalizeItineraryStatus(it['status']);
          final sDate = it['startDate']?.toString();
          final eDate = it['endDate']?.toString();
          final sStr = sDate != null && sDate.length >= 10 ? sDate.substring(0, 10) : (sDate ?? '');
          final eStr = eDate != null && eDate.length >= 10 ? eDate.substring(0, 10) : (eDate ?? '');
          final dates = '$sStr  →  $eStr';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
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
                          child: const Icon(
                            Icons.alt_route,
                            color: AppColors.jungle600,
                            size: 22,
                          ),
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.ink3,
                                ),
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
                            const Text(
                              'Estimated Budget',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.ink3,
                              ),
                            ),
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
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: AppColors.jungle600,
                            ),
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

  int _selectedDayTab = 1;

  /// Detail view with day-by-day timeline (Stitch Serendib Verdant design)
  Widget _buildItineraryDetail() {
    final items = _selectedItinerary!['items'] as List<dynamic>? ?? [];
    final totalCost = (_selectedItinerary!['totalEstimatedCost'] ?? 1180).toDouble();
    final currency = _selectedItinerary!['currency'] ?? 'USD';
    final itineraryTitle = _selectedItinerary!['title'] ?? '7-Day Sri Lanka Grand Explorer';

    // Group items by day number
    final Map<int, List<dynamic>> dayGroups = {};
    for (var item in items) {
      final day = item['dayNumber'] ?? 1;
      dayGroups.putIfAbsent(day, () => []);
      dayGroups[day]!.add(item);
    }

    dayGroups.forEach((day, dayItems) {
      dayItems.sort(
        (a, b) => (a['sequenceOrder'] ?? 0).compareTo(b['sequenceOrder'] ?? 0),
      );
    });

    final sortedDays = dayGroups.keys.toList()..sort();
    if (sortedDays.isEmpty) {
      sortedDays.addAll([1, 2, 3]);
    }
    if (!sortedDays.contains(_selectedDayTab)) {
      _selectedDayTab = sortedDays.first;
    }

    final currentDayItems = dayGroups[_selectedDayTab] ?? [];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sub-header & Trip Identification
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.leaf400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'CONFIRMED ROUTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.jungle600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          itineraryTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: AppColors.inkSecondary, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Itinerary link copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Trip Header & Stats Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                      // Route Badge Flow
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.leaf50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Icon(Icons.near_me, size: 16, color: AppColors.jungle600),
                              SizedBox(width: 6),
                              Text('Colombo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.ink)),
                              Icon(Icons.arrow_forward, size: 12, color: AppColors.inkTertiary),
                              SizedBox(width: 4),
                              Text('Sigiriya', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.ink)),
                              Icon(Icons.arrow_forward, size: 12, color: AppColors.inkTertiary),
                              SizedBox(width: 4),
                              Text('Kandy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.jungle600)),
                              Icon(Icons.arrow_forward, size: 12, color: AppColors.inkTertiary),
                              SizedBox(width: 4),
                              Text('Ella', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.inkSecondary)),
                              Icon(Icons.arrow_forward, size: 12, color: AppColors.inkTertiary),
                              SizedBox(width: 4),
                              Text('Galle', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.inkSecondary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCol(Icons.calendar_today, 'Duration', '${sortedDays.length}D / ${sortedDays.length > 1 ? sortedDays.length - 1 : 1}N'),
                          Container(width: 1, height: 26, color: AppColors.line),
                          _buildStatCol(Icons.group, 'Travelers', '2 Adults'),
                          Container(width: 1, height: 26, color: AppColors.line),
                          _buildStatCol(Icons.payments, 'Total Est.', '\$${totalCost.toStringAsFixed(0)}', isGold: true),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Stylized Interactive Map Route Preview
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        AppNetworkImage(
                          imageUrl: AppDestinations.getImageForDestination('Sigiriya'),
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
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
                        // Interactive destination badges
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: AppColors.leaf400),
                                SizedBox(width: 4),
                                Text('Sigiriya', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 50,
                          left: 120,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.jungle600,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.local_activity, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Kandy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        // Tap to expand 3D Route Map Button
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, '/trip-map', arguments: _selectedItinerary),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.map, size: 14, color: AppColors.jungle600),
                                  SizedBox(width: 4),
                                  Text(
                                    'Expand 3D Route Map',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.jungle700,
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
                ),

                const SizedBox(height: 16),

                // 4. Day-by-Day Horizontal Segmented Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TIMELINE NAVIGATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Day $_selectedDayTab of ${sortedDays.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.jungle600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: sortedDays.map((d) {
                      final isSelected = _selectedDayTab == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedDayTab = d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 72,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.jungle600 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.jungle600 : AppColors.line,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.jungle600.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Oct ${13 + d}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected ? AppColors.leaf200 : AppColors.inkTertiary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Day $d',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // 5. Day Detail Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.sand100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Day $_selectedDayTab Sequence',
                              style: const TextStyle(
                                color: AppColors.sand700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Row(
                            children: [
                              Icon(Icons.eco, size: 14, color: AppColors.leaf400),
                              SizedBox(width: 3),
                              Text(
                                'AI Optimized Route',
                                style: TextStyle(fontSize: 11, color: AppColors.inkTertiary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Day $_selectedDayTab — Cultural Triangle to Central Highlands',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Transitioning through scenic heritage landscapes, spice groves, and misty tea hilltops.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 6. Chronological Vertical Timeline
                if (currentDayItems.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text(
                      'No specific activities for this day yet.\nTap "Stays" or "Revise" to customize.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkTertiary, fontSize: 13),
                    ),
                  )
                else
                  ...currentDayItems.map((item) {
                    final tourName = item['tourName'] ?? 'Scenic Experience';
                    final image = AppDestinations.getImageForDestination(tourName);
                    final startTime = item['startTime'] ?? '09:00 AM';
                    final price = (item['priceAtSelection'] ?? 45).toDouble();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time circle
                            Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.leaf100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.explore, size: 18, color: AppColors.jungle700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  startTime,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.inkTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AppNetworkImage(
                                imageUrl: image,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title & Price
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
                                  const Row(
                                    children: [
                                      Icon(Icons.verified, size: 13, color: AppColors.jungle600),
                                      SizedBox(width: 3),
                                      Text(
                                        'Confirmed Expedition',
                                        style: TextStyle(fontSize: 11, color: AppColors.jungle700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${price.toStringAsFixed(0)} $currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.jungle600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 14),

                // 7. Consolidated Summary Card at Bottom
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Trip Inventory Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Icon(Icons.inventory_2, color: AppColors.leaf400, size: 18),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInventoryBadge(Icons.apartment, '3', 'Stays Booked', AppColors.jungle600),
                          _buildInventoryBadge(Icons.explore, '${items.length}', 'Excursions', AppColors.sand600),
                          _buildInventoryBadge(Icons.commute, '2', 'Transit Legs', AppColors.ocean700),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.line, height: 1),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.shield, size: 14, color: AppColors.leaf400),
                          SizedBox(width: 4),
                          Text(
                            'All local permits and conservation fees included',
                            style: TextStyle(fontSize: 11, color: AppColors.inkSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 8. Bottom Action Dock
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.line)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agents Total', style: TextStyle(fontSize: 10, color: AppColors.inkTertiary)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${totalCost.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.jungle700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text('/ 2 pax', style: TextStyle(fontSize: 11, color: AppColors.inkSecondary)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/accommodation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.jungle700,
                  side: const BorderSide(color: AppColors.lineStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                child: const Text('Stays', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _requestChanges,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral500,
                  side: const BorderSide(color: AppColors.lineStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                child: const Text('Revise', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/checkout',
                    arguments: _selectedItinerary,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Row(
                  children: [
                    Text('Checkout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCol(IconData icon, String label, String value, {bool isGold = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.inkTertiary),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkTertiary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isGold ? AppColors.sand600 : AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryBadge(IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(count, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkSecondary)),
        ],
      ),
    );
  }
}
