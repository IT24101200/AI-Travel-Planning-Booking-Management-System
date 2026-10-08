import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ItineraryChangeDialog extends StatefulWidget {
  const ItineraryChangeDialog({super.key, required this.itineraryId});
  final int itineraryId;

  @override
  State<ItineraryChangeDialog> createState() => _ItineraryChangeDialogState();
}

class _ItineraryChangeDialogState extends State<ItineraryChangeDialog> {
  final _notes = TextEditingController();
  final _rooms = <int, int>{};
  final _transports = <int, int>{};
  Map<String, dynamic>? _options;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _groups(String key) =>
      (_options?[key] as List? ?? [])
          .whereType<Map>()
          .map((g) => Map<String, dynamic>.from(g))
          .toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await ApiService.getItineraryChangeOptions(
        widget.itineraryId,
      );
      if (mounted) setState(() => _options = options);
    } catch (error) {
      if (mounted) setState(() => _error = ApiService.userMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(Map option) =>
      '${option['currency']} ${NumberFormat('#,##0.##').format(option['total'] ?? 0)}';

  Future<void> _submit() async {
    final hotels = _groups('hotels').where(
      (g) =>
          _rooms[g['bookingItemId']] != null &&
          _rooms[g['bookingItemId']] != g['currentRoomId'],
    );
    final transports = _groups('transports').where(
      (g) =>
          _transports[g['bookingItemId']] != null &&
          _transports[g['bookingItemId']] != g['currentTransportOptionId'],
    );
    if (hotels.isEmpty && transports.isEmpty && _notes.text.trim().isEmpty) {
      setState(() => _error = 'Select an alternative or enter instructions.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ApiService.submitItineraryChanges(
        widget.itineraryId,
        {
          'notes': _notes.text.trim(),
          'hotels': hotels
              .map(
                (g) => {
                  'bookingItemId': g['bookingItemId'],
                  'roomId': _rooms[g['bookingItemId']],
                },
              )
              .toList(),
          'transports': transports
              .map(
                (g) => {
                  'bookingItemId': g['bookingItemId'],
                  'transportOptionId': _transports[g['bookingItemId']],
                },
              )
              .toList(),
        },
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) setState(() => _error = ApiService.userMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dropdown({required Map<String, dynamic> group, required bool hotel}) {
    final itemId = group['bookingItemId'] as int;
    final current =
        group[hotel ? 'currentRoomId' : 'currentTransportOptionId'] as int;
    final selected = (hotel ? _rooms : _transports)[itemId] ?? current;
    final values = <int, String>{
      current: hotel ? 'Keep current stay' : 'Keep current transport',
    };
    for (final option in (group['options'] as List? ?? []).whereType<Map>()) {
      final id = option[hotel ? 'roomId' : 'transportOptionId'] as int;
      final details = hotel
          ? '${option['hotelName']} · ${option['roomType']} · ${option['distanceKm']} km · ${_money(option)}'
          : '${option['provider']} · ${option['type']} · ${option['departureTime'].toString().substring(11, 16)}–${option['arrivalTime'].toString().substring(11, 16)} · ${_money(option)}';
      values[id] = '${id == current ? 'Current: ' : ''}$details';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hotel
                ? group['hotelName'].toString()
                : '${group['routeFrom']} → ${group['routeTo']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            hotel
                ? '${group['checkInDate']} → ${group['checkOutDate']} · total stay price'
                : 'Same route, departure date and vehicle type · total for your party',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: ValueKey('${hotel ? 'hotel' : 'transport'}-$itemId'),
            initialValue: selected,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            selectedItemBuilder: (context) => values.values
                .map(
                  (text) =>
                      Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
                )
                .toList(),
            items: values.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(entry.value),
                    ),
                  ),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(
                        () => (hotel ? _rooms : _transports)[itemId] = value,
                      );
                    }
                  },
          ),
          if (values.length == 1)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No available alternatives for these dates.'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      title: const Text('Request itinerary changes'),
      insetPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: 620,
        child: _loading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_options != null) ...[
                      const Text(
                        'Choose hotels within 15 km by road of each current hotel, or matching transport for each journey. The agents will check availability, budget and travel times before updating your itinerary.',
                      ),
                      const SizedBox(height: 20),
                      ..._groups(
                        'hotels',
                      ).map((g) => _dropdown(group: g, hotel: true)),
                      ..._groups(
                        'transports',
                      ).map((g) => _dropdown(group: g, hotel: false)),
                      TextField(
                        key: const ValueKey('change-notes'),
                        controller: _notes,
                        enabled: !_submitting,
                        maxLength: 1000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Instructions for the agents (optional)',
                          hintText:
                              'e.g. Prefer a quieter hotel from the available choices.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your current itinerary stays available if these changes cannot be planned. The revised proposal needs approval before payment.',
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_loading && _options == null)
          TextButton(onPressed: _load, child: const Text('Retry')),
        FilledButton(
          onPressed: _loading || _options == null || _submitting
              ? null
              : _submit,
          child: Text(_submitting ? 'Sending request…' : 'Request changes'),
        ),
      ],
    ),
  );
}
