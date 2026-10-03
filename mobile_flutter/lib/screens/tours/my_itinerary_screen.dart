import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_constants.dart';
import '../../services/api_service.dart';

String normalizeItineraryStatus(dynamic status) {
  const statuses = ['Draft', 'Proposed', 'Accepted', 'Discarded'];

  if (status is num) {
    final index = status.toInt();
    return index >= 0 && index < statuses.length ? statuses[index] : 'Unknown';
  }

  final value = status?.toString().trim() ?? '';
  final numericStatus = int.tryParse(value);
  if (numericStatus != null) {
    return numericStatus >= 0 && numericStatus < statuses.length
        ? statuses[numericStatus]
        : 'Unknown';
  }

  switch (value.toLowerCase()) {
    case 'draft':
      return 'Draft';
    case 'proposed':
      return 'Proposed';
    case 'accepted':
      return 'Accepted';
    case 'discarded':
      return 'Discarded';
    default:
      return value.isEmpty ? 'Unknown' : value;
  }
}

class MyItineraryScreen extends StatefulWidget {
  const MyItineraryScreen({super.key});

  @override
  State<MyItineraryScreen> createState() => _MyItineraryScreenState();
}

class _MyItineraryScreenState extends State<MyItineraryScreen> {
  List<Map<String, dynamic>> _itineraries = [];
  Map<String, dynamic>? _selectedItinerary;
  bool _loading = true;
  bool _requestingChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  Future<void> _loadItineraries() async {
    final selectedId = _selectedItinerary?['id'];
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        throw const ApiException(
          'Your session is missing a customer ID. Please sign in again.',
        );
      }

      final response = await ApiService.getMyItinerariesOrThrow();
      final itineraries = response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      Map<String, dynamic>? selected;
      if (itineraries.isNotEmpty) {
        selected = itineraries.firstWhere(
          (item) => item['id'] == selectedId,
          orElse: () => itineraries.first,
        );
      }

      if (!mounted) return;
      setState(() {
        _itineraries = itineraries;
        _selectedItinerary = selected;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _itineraries = [];
        _selectedItinerary = null;
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? 'Failed to load itineraries.' : message;
  }

  bool _isEditable(dynamic status) {
    final normalized = normalizeItineraryStatus(status);
    return normalized == 'Draft' || normalized == 'Proposed';
  }

  List<MapEntry<int, List<Map<String, dynamic>>>> _groupedItems(
    Map<String, dynamic> itinerary,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    final rawItems = itinerary['items'];
    if (rawItems is List) {
      for (final rawItem in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final dayNumber = _asInt(item['dayNumber']) ?? 1;
        grouped.putIfAbsent(dayNumber, () => []).add(item);
      }
    }

    for (final items in grouped.values) {
      items.sort((first, second) {
        final timeCompare = (first['startTime'] ?? '')
            .toString()
            .compareTo((second['startTime'] ?? '').toString());
        if (timeCompare != 0) return timeCompare;
        return (_asInt(first['sequenceOrder']) ?? 0)
            .compareTo(_asInt(second['sequenceOrder']) ?? 0);
      });
    }

    final entries = grouped.entries.toList()
      ..sort((first, second) => first.key.compareTo(second.key));
    return entries;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 5) return text.substring(0, 5);
    return text.isEmpty ? 'Time unavailable' : text;
  }

  String _formatMoney(dynamic value, String currency) {
    if (value == null) return 'Amount unavailable';
    final amount = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (amount == null) return 'Amount unavailable';
    final formatted = amount.toStringAsFixed(2);
    return currency.isEmpty ? formatted : '$currency $formatted';
  }

  Future<void> _requestChanges(Map<String, dynamic> itinerary) async {
    final itineraryId = _asInt(itinerary['id']);
    if (itineraryId == null) {
      _showMessage('This itinerary has no valid ID.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request changes?'),
        content: const Text(
          'This will mark the itinerary as discarded so your travel agent can revise it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Request Changes'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _requestingChanges = true);

    try {
      final succeeded = await ApiService.requestItineraryChanges(itineraryId);
      if (!mounted) return;
      if (!succeeded) {
        _showMessage('Unable to request changes. Please try again.');
        return;
      }

      _showMessage('Changes requested successfully.');
      await _loadItineraries();
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _requestingChanges = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.figmaSurface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.figmaDarkGreen),
        ),
      );
    }

    if (_error != null) {
      return _buildStateScaffold(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        action: ElevatedButton(
          onPressed: _loadItineraries,
          child: const Text('Retry'),
        ),
      );
    }

    if (_itineraries.isEmpty || _selectedItinerary == null) {
      return _buildStateScaffold(
        icon: Icons.route_outlined,
        message: 'No itineraries yet. Plan a trip to get one.',
      );
    }

    final itinerary = _selectedItinerary!;
    final status = normalizeItineraryStatus(itinerary['status']);
    final currency = itinerary['currency']?.toString().trim() ?? '';
    final groupedItems = _groupedItems(itinerary);

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      appBar: AppBar(
        backgroundColor: AppColors.figmaSurface,
        foregroundColor: AppColors.figmaDarkGreen,
        iconTheme: const IconThemeData(color: AppColors.figmaDarkGreen),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.figmaDarkGreen,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
        title: const Text('My Itinerary'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadItineraries,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_itineraries.length > 1) ...[
              _buildItinerarySelector(),
              const SizedBox(height: 14),
            ],
            _buildHeader(itinerary, status),
            const SizedBox(height: 22),
            Text(
              'Your journey',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.figmaDarkGreen,
              ),
            ),
            const SizedBox(height: 14),
            if (groupedItems.isEmpty)
              _buildEmptyItems()
            else
              ...groupedItems.map(
                (day) => _buildDaySection(day.key, day.value, currency),
              ),
            const SizedBox(height: 12),
            _buildTotal(itinerary, currency),
            if (_isEditable(itinerary['status'])) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _requestingChanges
                    ? null
                    : () => _requestChanges(itinerary),
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(
                  _requestingChanges ? 'Requesting...' : 'Request Changes',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9B2C2C),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (status != 'Discarded')
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/checkout',
                  arguments: itinerary,
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Continue to Checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.figmaDarkGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateScaffold({
    required IconData icon,
    required String message,
    Widget? action,
  }) {
    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      appBar: AppBar(
        backgroundColor: AppColors.figmaSurface,
        foregroundColor: AppColors.figmaDarkGreen,
        iconTheme: const IconThemeData(color: AppColors.figmaDarkGreen),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.figmaDarkGreen,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
        title: const Text('My Itinerary'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.figmaDarkGreen),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItinerarySelector() {
    return DropdownButtonFormField<int>(
      initialValue: _asInt(_selectedItinerary?['id']),
      decoration: const InputDecoration(labelText: 'Itinerary'),
      items: _itineraries.map((itinerary) {
        final id = _asInt(itinerary['id'])!;
        final status = normalizeItineraryStatus(itinerary['status']);
        return DropdownMenuItem(
          value: id,
          child: Text('Itinerary #$id - $status'),
        );
      }).toList(),
      onChanged: (id) {
        if (id == null) return;
        setState(() {
          _selectedItinerary = _itineraries.firstWhere(
            (itinerary) => _asInt(itinerary['id']) == id,
          );
        });
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> itinerary, String status) {
    final id = itinerary['id'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.figmaDarkGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Itinerary #$id',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildStatusPill(status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatDate(itinerary['startDate'])} - ${_formatDate(itinerary['endDate'])}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final color = switch (status) {
      'Accepted' => const Color(0xFFDCFCE7),
      'Discarded' => const Color(0xFFFEE2E2),
      'Proposed' => const Color(0xFFFEF3C7),
      _ => const Color(0xFFE5E7EB),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Text(
        status,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF1F2937),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildEmptyItems() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.figmaCardBorder),
      ),
      child: const Text('No activities have been added to this itinerary yet.'),
    );
  }

  Widget _buildDaySection(
    int dayNumber,
    List<Map<String, dynamic>> items,
    String currency,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day $dayNumber',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildItemCard(item, currency)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String currency) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.figmaCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.place_outlined, color: AppColors.figmaDarkGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['tourName']?.toString() ?? 'Unnamed tour',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppColors.figmaDarkGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatTime(item['startTime'])} - ${_formatTime(item['endTime'])}',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatMoney(item['priceAtSelection'], currency),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotal(Map<String, dynamic> itinerary, String currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Estimated total',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          Text(
            _formatMoney(itinerary['totalEstimatedCost'], currency),
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
