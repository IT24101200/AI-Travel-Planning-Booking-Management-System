import 'package:flutter/material.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/hotel_route_map.dart';

class HotelMapScreen extends StatelessWidget {
  const HotelMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final hotel = arguments is Map<String, dynamic>
        ? arguments
        : TripSelectionService.selectedHotel;
    return Scaffold(
      appBar: AppBar(
        title: Text(hotel?['name']?.toString() ?? 'Hotel directions'),
      ),
      body: hotel == null
          ? const Center(child: Text('Select a hotel to see directions.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: HotelRouteMap(hotel: hotel),
            ),
    );
  }
}
