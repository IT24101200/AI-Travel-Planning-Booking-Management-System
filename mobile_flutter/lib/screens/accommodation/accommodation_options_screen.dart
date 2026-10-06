import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/currency_notifier.dart';
import '../../services/hotel_catalog_service.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/hotel_route_map.dart';
import '../../widgets/itinerary_journey_layout.dart';
import '../../main.dart' show currencyNotifier;

class AccommodationOptionsScreen extends StatefulWidget {
  const AccommodationOptionsScreen({super.key});
  @override
  State<AccommodationOptionsScreen> createState() =>
      _AccommodationOptionsScreenState();
}

class _AccommodationOptionsScreenState
    extends State<AccommodationOptionsScreen> {
  List<Map<String, dynamic>> _hotels = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

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
      final data = await ApiService.getHotels(currency: currencyNotifier.value);
      if (!mounted || request != _request) return;
      setState(() {
        _hotels = data
            .whereType<Map>()
            .map(HotelCatalogService.displayStay)
            .toList();
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

  Map<String, dynamic>? get _selected => _hotels.isEmpty
      ? null
      : _hotels.firstWhere(
          (h) => h['id'] == _selectedId,
          orElse: () => _hotels.first,
        );

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
            ? const Center(child: Text('No accommodation options available.'))
            : ItineraryJourneyLayout(
                map: HotelRouteMap(hotel: selected),
                heading: Text(
                  '${_hotels.length} stays',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Published nightly from rates. Final prices, taxes, resident eligibility and availability must be confirmed with the hotel.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  ..._hotels.map(
                    (hotel) => _hotelCard(hotel, hotel['id'] == selected['id']),
                  ),
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
              ),
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
                        price == null
                            ? 'Contact hotel for rates'
                            : 'From ${formatMoney(price, hotel['currency']?.toString() ?? currencyNotifier.value)} / night',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
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
