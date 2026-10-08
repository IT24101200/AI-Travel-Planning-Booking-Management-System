import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/itinerary_flow_utils.dart';

class ItineraryStopDetails extends StatelessWidget {
  const ItineraryStopDetails({
    super.key,
    required this.item,
    required this.itinerary,
    this.booking,
  });
  final Map<String, dynamic> item;
  final Map<String, dynamic> itinerary;
  final Map<String, dynamic>? booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = int.tryParse('${item['dayNumber']}') ?? 1;
    final transports = itineraryDayTransports(itinerary, booking, day);
    final direction = itineraryDayDirection(itinerary, day);
    final stay = item['hotelStay'];
    String time(Object? raw) {
      final value = raw?.toString() ?? '';
      return value.length >= 16 ? value.substring(11, 16) : 'Time pending';
    }

    return Container(
      key: ValueKey('stop-details-${item['id']}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stay is Map) ...[
              Text(
                '${stay['isPlanned'] == true ? 'Planned stay' : 'Hotel stay'} · ${stay['hotelName'] ?? 'Hotel'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${stay['checkInDate'].toString().split('T').first} → ${stay['checkOutDate'].toString().split('T').first}',
              ),
              if (stay['roomType'] != null) Text('Room: ${stay['roomType']}'),
              const SizedBox(height: 8),
            ],
            Text(
              'Day $day travel',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (direction.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(direction),
            ],
            if (transports.isEmpty) ...[
              const SizedBox(height: 4),
              const Text(
                'Local travel · No separate transport reservation for this day.',
              ),
            ] else
              ...transports.map((transport) {
                final subtotal = transport['subtotal'];
                final currency =
                    transport['currency'] ??
                    booking?['currency'] ??
                    itinerary['currency'] ??
                    '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${transport['transportType'] ?? transport['vehicleType'] ?? 'Transport'} · ${transport['transportProvider'] ?? 'Provider pending'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${transport['routeFrom'] ?? 'Origin'} → ${transport['routeTo'] ?? 'Destination'}',
                      ),
                      Text(
                        '${time(transport['departureTime'])}–${time(transport['arrivalTime'])}',
                      ),
                      if (subtotal is num)
                        Text(
                          '$currency ${NumberFormat('#,##0.##').format(subtotal)} · Booked total',
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 6),
            Text(
              'Selected day is light red on the map; arrows show travel direction.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
