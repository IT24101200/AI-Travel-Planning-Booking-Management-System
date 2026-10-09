import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../services/date_time_contract.dart';

class TripConfirmationDetails extends StatelessWidget {
  const TripConfirmationDetails({super.key, required this.details});

  final Map<String, dynamic> details;

  List<Map> _rows(dynamic value) =>
      value is List ? value.whereType<Map>().toList() : const [];

  String _text(dynamic value, [String fallback = 'Unavailable']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _date(dynamic value) {
    final date = parseDateOnly(value);
    return date == null
        ? 'Date unavailable'
        : DateFormat('dd MMM yyyy').format(date);
  }

  String _departure(dynamic value) {
    final date = parseLocalSchedule(value);
    return date == null
        ? 'Time unavailable'
        : DateFormat('dd MMM, HH:mm').format(date);
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _entry(BuildContext context, String title, List<String> lines) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      );

  List<String> _contacts(Map item) => [
    'Phone: ${_text(item['contactPhone'], 'Not provided — contact the travel desk')}',
    'Email: ${_text(item['contactEmail'], 'Not provided — contact the travel desk')}',
  ];

  @override
  Widget build(BuildContext context) {
    final hotels = _rows(details['hotels']);
    final transports = _rows(details['transports']);
    final days = _rows(details['days']);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Text(
            'Your booked trip',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Booking ${_text(details['bookingReference'])}'),
          Text('${_date(details['startDate'])} – ${_date(details['endDate'])}'),
          Text('${_text(details['travellers'])} travellers'),
          Text(
            'Paid: ${_text(details['currency'])} ${_text(details['amountPaid'])}',
          ),
          _section(context, 'Booked hotels', [
            if (hotels.isEmpty)
              const Text('No hotel stay is included in this booking.'),
            for (final hotel in hotels)
              _entry(context, _text(hotel['name']), [
                '${_text(hotel['roomType'], 'Room')} · ${_text(hotel['rooms'])} room(s)',
                'Check-in: ${_date(hotel['checkInDate'])}',
                'Check-out: ${_date(hotel['checkOutDate'])}',
                'Address: ${_text(hotel['address'], 'Not provided')}',
                ..._contacts(hotel),
              ]),
          ]),
          _section(context, 'Booked transport', [
            if (transports.isEmpty)
              const Text('No transport is included in this booking.'),
            for (final transport in transports)
              _entry(
                context,
                '${_text(transport['from'])} → ${_text(transport['to'])}',
                [
                  '${_text(transport['type'], 'Transport')} · ${_text(transport['provider'], 'Provider unavailable')}',
                  'Departure: ${_departure(transport['departureTime'])}',
                  'Arrival: ${_departure(transport['arrivalTime'])}',
                  '${_text(transport['travellers'])} traveller(s)',
                  ..._contacts(transport),
                ],
              ),
          ]),
          _section(context, 'Full day-by-day plan', [
            if (days.isEmpty)
              const Text('Open your itinerary for the travel schedule.'),
            for (final day in days)
              _entry(
                context,
                'Day ${_text(day['dayNumber'])} · ${_date(day['date'])}',
                [
                  for (final stop in _rows(day['stops']))
                    '${_text(stop['startTime'], '')}${stop['startTime'] == null ? '' : ' · '}${_text(stop['kind'], 'Stop')}: ${_text(stop['name'])}${stop['endTime'] == null ? '' : ' (until ${stop['endTime']})'}',
                  for (final route in _rows(day['routes']))
                    '${_text(route['from'])} → ${_text(route['to'])}${route['distanceKm'] == null ? '' : ' · ${route['distanceKm']} km'}${route['travelMinutes'] == null ? '' : ' · ${route['travelMinutes']} min'}',
                  if (_rows(day['stops']).isEmpty &&
                      _rows(day['routes']).isEmpty)
                    'Free time. Check your booked transport and hotel dates above.',
                ],
              ),
          ]),
        ],
      ),
    );
  }
}

@Preview(name: 'Paid trip details', group: 'Bookings', size: Size(360, 800))
Widget paidTripDetailsPreview() => MaterialApp(
  theme: ThemeData.dark(),
  home: const Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: TripConfirmationDetails(
        details: {
          'bookingReference': 'Preview booking',
          'startDate': '2026-10-16',
          'endDate': '2026-10-17',
          'travellers': 2,
          'amountPaid': 25000,
          'currency': 'LKR',
          'hotels': [],
          'transports': [],
          'days': [],
        },
      ),
    ),
  ),
);
