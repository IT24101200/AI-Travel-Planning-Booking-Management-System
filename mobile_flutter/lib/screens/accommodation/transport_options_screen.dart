import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Transport options screen showing fleet, trains, buses, and private transfers across Sri Lanka.
class TransportOptionsScreen extends StatefulWidget {
  const TransportOptionsScreen({super.key});

  @override
  State<TransportOptionsScreen> createState() => _TransportOptionsScreenState();
}

class _TransportOptionsScreenState extends State<TransportOptionsScreen> {
  List<dynamic> _options = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';
  Map<String, dynamic>? _selectedOption;

  final List<String> _filters = ['All', 'Train', 'Car', 'Bus', 'Flight'];

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  Future<void> _loadTransport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getTransportOptions();
      if (mounted) {
        setState(() {
          _options = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load transit fleet options';
          _loading = false;
        });
      }
    }
  }

  IconData _getTransportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return Icons.flight_takeoff;
      case 'train':
        return Icons.train_outlined;
      case 'bus':
        return Icons.directions_bus_filled_outlined;
      case 'car':
        return Icons.directions_car_filled_outlined;
      default:
        return Icons.commute_outlined;
    }
  }

  Color _getTransportColor(String type) {
    switch (type.toLowerCase()) {
      case 'train':
        return AppColors.sand600;
      case 'flight':
        return AppColors.ocean500;
      case 'car':
        return AppColors.jungle600;
      case 'bus':
        return AppColors.coral500;
      default:
        return AppColors.jungle700;
    }
  }

  List<dynamic> get _filteredOptions {
    if (_selectedFilter == 'All') return _options;
    return _options
        .where(
          (o) =>
              (o['type'] ?? '').toString().toLowerCase() ==
              _selectedFilter.toLowerCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredOptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transit & Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View Route on Map',
            onPressed: () => Navigator.pushNamed(context, '/trip-map'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = f);
                      },
                      selectedColor: AppColors.jungle600,
                      backgroundColor: AppColors.mist,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.ink2,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.jungle600
                              : AppColors.line,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _loading
                ? const LoadingIndicator(
                    message: 'Loading verified transport fleet...',
                  )
                : _error != null
                ? ErrorMessage(message: _error!, onRetry: _loadTransport)
                : displayList.isEmpty
                ? _buildSampleTransitList()
                : RefreshIndicator(
                    color: AppColors.jungle600,
                    onRefresh: _loadTransport,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: displayList.length,
                      itemBuilder: (context, index) =>
                          _buildTransportCard(displayList[index]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedOption != null
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
                            _selectedOption!['provider'] ?? 'Transit Option',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selectedOption!['type']} • \$${_selectedOption!['price']}',
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
                      onPressed: () => Navigator.pushNamed(context, '/checkout'),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Checkout'),
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

  Widget _buildTransportCard(Map<String, dynamic> opt) {
    final type = opt['type'] ?? 'Transport';
    final provider = opt['provider'] ?? 'Standard Transit Provider';
    final routeFrom = opt['routeFrom'] ?? 'Origin';
    final routeTo = opt['routeTo'] ?? 'Destination';
    final departure = opt['departureTime'] ?? 'Scheduled Time';
    final arrival = opt['arrivalTime'] ?? 'Scheduled Time';
    final price = (opt['price'] ?? 0).toDouble();
    final currency = opt['currency'] ?? 'USD';
    final capacity = opt['capacity'] ?? 20;
    final icon = _getTransportIcon(type);
    final color = _getTransportColor(type);
    final isSelected = _selectedOption == opt;

    return InkWell(
      onTap: () {
        setState(() => _selectedOption = opt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected $provider ($type)'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.jungle600,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.leaf50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.jungle600 : AppColors.line,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type, Provider, and Price
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.jungle600 : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : icon,
                      color: isSelected ? Colors.white : color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.8,
                          ),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.jungle600,
                        ),
                      ),
                      Text(
                        currency,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Route Visualization
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.mist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Departure',
                            style: TextStyle(fontSize: 10, color: AppColors.ink3),
                          ),
                          Text(
                            routeFrom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            departure,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        color: AppColors.jungle600,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Arrival',
                            style: TextStyle(fontSize: 10, color: AppColors.ink3),
                          ),
                          Text(
                            routeTo,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            arrival,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Capacity & Availability
              Row(
                children: [
                  const Icon(
                    Icons.airline_seat_recline_normal,
                    size: 16,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Capacity: $capacity Seats',
                    style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                  ),
                  const Spacer(),
                  Text(
                    isSelected ? 'Selected Transit Option' : 'Available on Schedule',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.jungle700 : AppColors.leaf400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleTransitList() {
    final samples = [
      {
        'type': 'Train',
        'provider': 'Sri Lanka Railways (Observation Car)',
        'routeFrom': 'Kandy Central Station',
        'routeTo': 'Ella Mountain Viaduct',
        'departureTime': '08:47 AM',
        'arrivalTime': '02:30 PM',
        'price': 45,
        'currency': 'USD',
        'capacity': 48,
      },
      {
        'type': 'Car',
        'provider': 'Serendib Private Chauffeur & SUV',
        'routeFrom': 'Bandaranaike Intl (CMB)',
        'routeTo': 'Sigiriya Heritage Zone',
        'departureTime': 'On Arrival',
        'arrivalTime': '3.5 Hours Direct',
        'price': 90,
        'currency': 'USD',
        'capacity': 4,
      },
      {
        'type': 'Bus',
        'provider': 'Air-Conditioned Coastal Express',
        'routeFrom': 'Colombo Fort',
        'routeTo': 'Mirissa Beach Pier',
        'departureTime': '09:00 AM',
        'arrivalTime': '11:45 AM',
        'price': 25,
        'currency': 'USD',
        'capacity': 32,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: samples.length,
      itemBuilder: (context, index) => _buildTransportCard(samples[index]),
    );
  }
}
