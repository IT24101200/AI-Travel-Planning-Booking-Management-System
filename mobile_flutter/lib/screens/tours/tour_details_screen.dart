import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app_constants.dart';
import '../../services/api_service.dart';

class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({super.key});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  Map<String, dynamic>? _tour;
  bool _loading = true;
  bool _didLoad = false;
  bool _isFavorite = false;
  bool _addingToItinerary = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;

    final tourId = ModalRoute.of(context)?.settings.arguments;
    if (tourId is int) {
      _loadTour(tourId);
    } else {
      setState(() {
        _loading = false;
        _error = 'A valid tour ID was not provided.';
      });
    }
  }

  Future<void> _loadTour(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getTourOrThrow(id);
      if (!mounted) return;
      setState(() {
        _tour = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tour = null;
        _error = error.toString();
        _loading = false;
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatHours(double? value) {
    if (value == null) return 'Unavailable';
    return value == value.roundToDouble()
        ? '${value.toInt()} hours'
        : '${value.toStringAsFixed(1)} hours';
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : 'Unavailable';
  }

  String _formatPrice(dynamic value, String currency) {
    final amount = _asDouble(value);
    if (amount == null) return 'Price unavailable';
    final formatted = amount.toStringAsFixed(2);
    return currency.isEmpty ? formatted : '$currency $formatted';
  }

  String _normalizedStatus(dynamic value) {
    const statuses = ['Draft', 'Proposed', 'Accepted', 'Discarded'];
    final numeric = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    if (numeric != null && numeric >= 0 && numeric < statuses.length) {
      return statuses[numeric];
    }

    final text = value?.toString().trim().toLowerCase() ?? '';
    for (final status in statuses) {
      if (status.toLowerCase() == text) return status;
    }
    return text;
  }

  bool _isEditableItinerary(Map<String, dynamic> itinerary) {
    final status = _normalizedStatus(itinerary['status']);
    return status == 'Draft' || status == 'Proposed';
  }

  int _itineraryDayCount(Map<String, dynamic> itinerary) {
    final start = DateTime.tryParse(itinerary['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(itinerary['endDate']?.toString() ?? '');
    if (start == null || end == null || end.isBefore(start)) return 1;
    return end.difference(start).inDays + 1;
  }

  int? _timeInMinutes(dynamic value) {
    final parts = value?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return (hours * 60) + minutes;
  }

  String _timeFromMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${remainingMinutes.toString().padLeft(2, '0')}:00';
  }

  Future<void> _addToItinerary() async {
    final tour = _tour;
    final tourId = _asInt(tour?['id']);
    final durationHours = _asDouble(tour?['durationHours']);
    final startMinutes = _timeInMinutes(tour?['defaultStartTime']);

    if (tour == null || tourId == null) {
      _showMessage('This tour has no valid ID.');
      return;
    }
    if (durationHours == null || startMinutes == null) {
      _showMessage('This tour is missing its duration or default start time.');
      return;
    }

    final endMinutes = startMinutes + (durationHours * 60).round();
    if (endMinutes >= 24 * 60) {
      _showMessage('This tour extends past midnight and cannot be scheduled on one day.');
      return;
    }

    setState(() => _addingToItinerary = true);
    try {
      final response = await ApiService.getMyItinerariesOrThrow();
      final editable = response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(_isEditableItinerary)
          .where((item) => _asInt(item['id']) != null)
          .toList();

      if (!mounted) return;
      if (editable.isEmpty) {
        _showMessage('No draft itinerary yet. Submit an AI trip request first.');
        return;
      }

      await _showItineraryPicker(
        editable,
        tourId: tourId,
        startTime: _timeFromMinutes(startMinutes),
        endTime: _timeFromMinutes(endMinutes),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _addingToItinerary = false);
    }
  }

  Future<void> _showItineraryPicker(
    List<Map<String, dynamic>> itineraries, {
    required int tourId,
    required String startTime,
    required String endTime,
  }) async {
    var selectedItinerary = itineraries.first;
    var selectedDay = 1;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final dayCount = _itineraryDayCount(selectedItinerary);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add to Itinerary',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.figmaDarkGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _asInt(selectedItinerary['id']),
                    decoration: const InputDecoration(labelText: 'Itinerary'),
                    items: itineraries.map((itinerary) {
                      final id = _asInt(itinerary['id'])!;
                      final status = _normalizedStatus(itinerary['status']);
                      return DropdownMenuItem(
                        value: id,
                        child: Text('Itinerary #$id - $status'),
                      );
                    }).toList(),
                    onChanged: submitting
                        ? null
                        : (id) {
                            if (id == null) return;
                            setSheetState(() {
                              selectedItinerary = itineraries.firstWhere(
                                (item) => _asInt(item['id']) == id,
                              );
                              selectedDay = 1;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    key: ValueKey('${selectedItinerary['id']}-$dayCount'),
                    initialValue: selectedDay,
                    decoration: const InputDecoration(labelText: 'Day number'),
                    items: List.generate(
                      dayCount,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('Day ${index + 1}'),
                      ),
                    ),
                    onChanged: submitting
                        ? null
                        : (day) {
                            if (day != null) {
                              setSheetState(() => selectedDay = day);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setSheetState(() => submitting = true);
                            try {
                              await ApiService.addItineraryItem(
                                _asInt(selectedItinerary['id'])!,
                                tourId,
                                selectedDay,
                                startTime,
                                endTime,
                              );
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              await _loadTour(tourId);
                              if (mounted) {
                                _showMessage('Tour added to your itinerary.');
                              }
                            } catch (error) {
                              if (mounted) _showMessage(error.toString());
                              if (sheetContext.mounted) {
                                setSheetState(() => submitting = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.figmaDarkGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(submitting ? 'Adding...' : 'Add Tour'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

    if (_error != null || _tour == null) {
      final tourId = ModalRoute.of(context)?.settings.arguments;
      return Scaffold(
        backgroundColor: AppColors.figmaSurface,
        appBar: AppBar(
          backgroundColor: AppColors.figmaSurface,
          foregroundColor: AppColors.figmaDarkGreen,
          title: const Text('Tour Details'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Tour not found', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (tourId is int)
                  ElevatedButton(
                    onPressed: () => _loadTour(tourId),
                    child: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final tour = _tour!;
    final name = tour['name']?.toString() ?? 'Unnamed tour';
    final category = tour['category']?.toString() ?? 'Uncategorized';
    final description = tour['description']?.toString().trim();
    final imageUrl = ApiService.resolveMediaUrl(tour['imageUrl']?.toString());
    final durationHours = _asDouble(tour['durationHours']);
    final currency = tour['currency']?.toString().trim() ?? '';
    final destinationName = tour['destinationName'] as String?;
    final destination = destinationName != null && destinationName.isNotEmpty
        ? destinationName
        : 'Unknown destination';

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            backgroundColor: AppColors.figmaDarkGreen,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Favorite',
                onPressed: () => setState(() => _isFavorite = !_isFavorite),
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.figmaGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.figmaDarkGreen,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.figmaCardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStat(
                            Icons.access_time,
                            _formatHours(durationHours),
                            'Duration',
                          ),
                        ),
                        Expanded(
                          child: _buildStat(
                            Icons.schedule,
                            _formatTime(tour['defaultStartTime']),
                            'Start time',
                          ),
                        ),
                        Expanded(
                          child: _buildStat(
                            Icons.payments_outlined,
                            currency.isEmpty ? 'Unavailable' : currency,
                            'Currency',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'About this experience',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.figmaDarkGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description?.isNotEmpty == true
                        ? description!
                        : 'No description is available for this tour.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: AppColors.figmaSurface,
            border: Border(top: BorderSide(color: AppColors.figmaCardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'per traveler',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatPrice(tour['price'], currency),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.figmaDarkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/trip-request',
                  arguments: tour,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.figmaDarkGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Book This Tour'),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    tooltip: 'Add to Itinerary',
                    onPressed: _addingToItinerary ? null : _addToItinerary,
                    icon: _addingToItinerary
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calendar_month_outlined),
                  ),
                  Text(
                    'Add to Itinerary',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7280),
                      fontSize: 9,
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFF374151),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 60),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: AppColors.figmaDarkGreen, size: 21),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B7280),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
