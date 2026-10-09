import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../app_constants.dart';

class TripPlanningSummary extends StatelessWidget {
  const TripPlanningSummary({
    super.key,
    required this.destinations,
    required this.dateRangeLabel,
    required this.tripDays,
    required this.budgetLabel,
    this.starter,
    this.airportCode,
    this.arrivalTime,
  });

  final List<String> destinations;
  final String dateRangeLabel;
  final int tripDays;
  final String budgetLabel;
  final String? starter;
  final String? airportCode;
  final String? arrivalTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.dark
        ? AppColors.leaf400
        : AppColors.jungle600;
    final remaining = destinations
        .where((name) => name.toLowerCase() != starter?.toLowerCase())
        .toList();

    Widget step(IconData icon, String title, String description) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );

    return DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: theme.colorScheme.onSurface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          Text(
            'How we’ll plan your trip',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          if (airportCode != null)
            step(
              Icons.flight_land_outlined,
              'Arrive at $airportCode airport',
              'Arrival: $arrivalTime · allow time for pickup before the transfer.',
            ),
          step(
            Icons.trip_origin,
            starter == null
                ? 'AI chooses the first destination'
                : 'First destination: $starter',
            starter == null
                ? airportCode == null
                      ? 'We’ll choose an efficient starting point and destination order.'
                      : 'We’ll choose an efficient destination order from the airport.'
                : airportCode == null
                ? 'Your trip starts here. The remaining destination order is optimized.'
                : 'Airport → $starter, then the remaining destinations in an optimized order.',
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              starter == null
                  ? 'Destinations to optimize'
                  : 'Remaining destinations to optimize',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in remaining)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(name),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Visit order will be confirmed after planning.'),
          ],
          step(
            Icons.route_outlined,
            'Efficient travel between stops',
            'We check road distances, travel times and available transport while including every selected destination.',
          ),
          if (airportCode != null)
            step(
              Icons.hotel_outlined,
              'Rest before journeys when needed',
              'If a journey won’t fit on arrival day, we plan a hotel stay before starting journeys, subject to transfer and hotel availability.',
            ),
          step(
            Icons.calendar_month_outlined,
            '$tripDays days · ${tripDays - 1} nights',
            '$dateRangeLabel\nBudget: $budgetLabel',
          ),
          const SizedBox(height: 8),
          const Text(
            'Journeys, transfers, hotel nights and breaks must fit your dates and budget. Free time between journeys is available for meals, rest or leisure.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Your generated itinerary will show the final route, daily schedule, stays and transport for review.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Airport and starter',
  group: 'Trip planning',
  size: Size(360, 850),
)
Widget airportStarterPlanningPreview() => MaterialApp(
  theme: ThemeData.dark(),
  home: const Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: TripPlanningSummary(
        destinations: ['Colombo', 'Bentota', 'Yala', 'Arugam Bay'],
        starter: 'Colombo',
        airportCode: 'CMB',
        arrivalTime: '16:00',
        dateRangeLabel: '17–23 Oct 2026',
        tripDays: 7,
        budgetLabel: 'LKR 175,000–250,000',
      ),
    ),
  ),
);
