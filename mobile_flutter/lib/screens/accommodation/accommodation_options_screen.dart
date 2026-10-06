import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/booked_inventory_service.dart';
import '../../services/currency_notifier.dart';
import '../../services/hotel_catalog_service.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/hotel_route_map.dart';
import '../../widgets/itinerary_journey_layout.dart';
import '../../main.dart' show currencyNotifier;

class AccommodationOptionsScreen extends StatefulWidget {
  const AccommodationOptionsScreen({
    super.key,
    this.mapBuilder = _defaultMapBuilder,
  });

  final Widget Function(Map<String, dynamic>) mapBuilder;

  static Widget _defaultMapBuilder(Map<String, dynamic> hotel) =>
      HotelRouteMap(hotel: hotel);
  @override
  State<AccommodationOptionsScreen> createState() =>
      _AccommodationOptionsScreenState();
}

class _AccommodationOptionsScreenState
    extends State<AccommodationOptionsScreen> {
  List<Map<String, dynamic>> _hotels = [];
  List<Map<String, dynamic>> _bookedHotels = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;
  String _selectedCategory = 'Available';

  @override
  void initState() {
    super.initState();
    currencyNotifier.addListener(_loadHotels);
    _loadHotels();
  }

  @override
  void dispose() {
    currencyNotifier.removeListener(_loadHotels);
    super.dispose();
  }

  int _request = 0;
  Future<void> _loadHotels() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getHotels(currency: currencyNotifier.value),
        ApiService.getMyBookings(),
      ]);
      if (!mounted || request != _request) return;
      final bookedRooms = BookedInventoryService.paidRoomItems(results[1]);
      setState(() {
        _hotels = results[0]
            .whereType<Map>()
            .map(HotelCatalogService.displayStay)
            .toList();
        _bookedHotels = bookedRooms.map(_displayBookedStay).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleHotels =>
      _selectedCategory == 'Booked' ? _bookedHotels : _hotels;

  Map<String, dynamic>? get _selected => _visibleHotels.isEmpty
      ? null
      : _visibleHotels.firstWhere(
          (h) => h['id'] == _selectedId,
          orElse: () => _visibleHotels.first,
        );

  Map<String, dynamic> _displayBookedStay(Map<String, dynamic> item) => {
    ...item,
    'id': 'booked-${item['id']}',
    'name': item['hotelName'] ?? 'Reserved hotel',
    'location': item['hotelAddress'] ?? 'Address not provided',
    'latitude': item['hotelLatitude'],
    'longitude': item['hotelLongitude'],
    'price': item['subtotal'] ?? item['unitPrice'],
    'roomType': item['roomType'],
    'image': '',
    'booked': true,
  };

  void _select(Map<String, dynamic> hotel) {
    setState(() => _selectedId = hotel['id'] as String);
    TripSelectionService.selectedHotel = hotel;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your stay'),
        actions: [
          if (selected != null)
            IconButton(
              tooltip: 'Full hotel map',
              icon: const Icon(Icons.map_outlined),
              onPressed: () {
                TripSelectionService.selectedHotel = selected;
                Navigator.pushNamed(context, '/hotel-map', arguments: selected);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ErrorMessage(message: _error!, onRetry: _loadHotels)
            : selected == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _categorySelector(),
                  Expanded(
                    child: Center(
                      child: Text(
                        _selectedCategory == 'Booked'
                            ? 'No paid hotel bookings yet.'
                            : 'No accommodation options available.',
                      ),
                    ),
                  ),
                ],
              )
            : ItineraryJourneyLayout(
                map: widget.mapBuilder(selected),
                heading: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _categorySelector(),
                    const SizedBox(height: 12),
                    Text(
                      _selectedCategory == 'Booked'
                          ? '${_bookedHotels.length} booked stays'
                          : '${_hotels.length} stays',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                children: [
                  if (_selectedCategory != 'Booked')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Published nightly from rates. Final prices, taxes, resident eligibility and availability must be confirmed with the hotel.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ..._visibleHotels.map(
                    (hotel) => _hotelCard(hotel, hotel['id'] == selected['id']),
                  ),
                  if (_selectedCategory != 'Booked') ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: selected['price'] == null
                          ? null
                          : () {
                              TripSelectionService.selectedHotel = selected;
                              Navigator.pushNamed(
                                context,
                                '/transport',
                                arguments: selected,
                              );
                            },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        'Continue with ${selected['name']}',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _categorySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Available', label: Text('Available')),
          ButtonSegment(value: 'Booked', label: Text('Booked')),
        ],
        selected: {_selectedCategory},
        onSelectionChanged: (selection) {
          setState(() {
            _selectedCategory = selection.first;
            _selectedId = null;
          });
        },
      ),
    );
  }

  Widget _hotelCard(Map<String, dynamic> hotel, bool selected) {
    final colors = Theme.of(context).colorScheme;
    final price = hotel['price'];
    final rating = int.tryParse('${hotel['starRating']}') ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? HotelRouteMap.routeColor : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _select(hotel),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  height: 100,
                  child: hotel['image'] == ''
                      ? Icon(Icons.hotel, size: 40, color: colors.primary)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            hotel['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.hotel,
                              size: 40,
                              color: colors.primary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hotel['name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${hotel['location']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (rating > 0)
                        Text(
                          '$rating-star classification',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (hotel['roomType'] != null)
                        Text(
                          '${hotel['roomType']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        hotel['booked'] == true
                            ? price == null
                                  ? 'Paid booking'
                                  : formatMoney(
                                      price,
                                      hotel['currency']?.toString() ?? 'LKR',
                                    )
                            : price == null
                            ? 'Contact hotel for rates'
                            : 'From ${formatMoney(price, hotel['currency']?.toString() ?? currencyNotifier.value)} / night',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (hotel['booked'] == true)
                        Text(
                          '${hotel['bookingReference'] ?? 'Confirmed booking'} · ${hotel['checkInDate']?.toString().split('T').first ?? 'Check-in pending'} → ${hotel['checkOutDate']?.toString().split('T').first ?? 'Check-out pending'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (selected && hotel['rateNotes'] != null)
                        Text(
                          '${hotel['rateNotes']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      Text(
                        selected
                            ? 'Selected - map updated'
                            : 'Tap to select and see directions',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
