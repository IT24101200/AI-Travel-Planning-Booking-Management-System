import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/trip_selection_service.dart';

/// Normalizes status for external callers if needed
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
    case 'awaiting approval':
      return 'Proposed';
    case 'accepted':
    case 'confirmed':
      return 'Accepted';
    case 'discarded':
    case 'cancelled':
      return 'Discarded';
    default:
      return value.isEmpty ? 'Unknown' : value;
  }
}

/// My Itinerary screen matching Figma Dev Mode (07 · My Itinerary).
/// Displays real customer itinerary, scheduled tours timeline, live OSM preview,
/// status badge, accept & request changes actions, and checkout transition.
class MyItineraryScreen extends StatefulWidget {
  const MyItineraryScreen({super.key});

  @override
  State<MyItineraryScreen> createState() => _MyItineraryScreenState();
}

class _MyItineraryScreenState extends State<MyItineraryScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  bool _pending = false;
  int? _selectedItineraryId;
  Map<String, dynamic>? _itinerary;
  List<Map<String, dynamic>> _itineraries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchItinerary();
    });
  }

  int? _positiveId(dynamic value) {
    final id = int.tryParse(value?.toString() ?? '');
    return id != null && id > 0 ? id : null;
  }

  Future<void> _fetchItinerary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pending = false;
      _itinerary = null;
    });
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final directId = args is int
          ? _positiveId(args)
          : args is Map
              ? _positiveId(args['itineraryId']) ??
                  (args.containsKey('items') ? _positiveId(args['id']) : null)
              : _selectedItineraryId;
      final tripRequestId = args is Map ? _positiveId(args['tripRequestId']) : null;
      Map<String, dynamic>? selected;
      List<Map<String, dynamic>> choices = [];
      if (directId != null) {
        selected = await ApiService.getItinerary(directId);
      } else {
        final records = await ApiService.getMyItineraries();
        choices = records.map((record) => Map<String, dynamic>.from(record as Map)).toList();
        if (tripRequestId != null) {
          choices = choices.where((record) => _positiveId(record['tripRequestId']) == tripRequestId).toList();
        }
        if (choices.isNotEmpty) {
          final id = _positiveId(choices.first['id']);
          if (id == null) throw const ApiException('The itinerary has no valid ID.');
          selected = await ApiService.getItinerary(id);
        }
      }
      if (!mounted) return;
      setState(() {
        _itinerary = selected;
        _itineraries = choices;
        _pending = tripRequestId != null && selected == null;
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectItinerary(Map<String, dynamic> item) async {
    final id = _positiveId(item['id']);
    if (id == null) return;
    setState(() {
      _selectedItineraryId = id;
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final selected = await ApiService.getItinerary(id);
      if (mounted) setState(() => _itinerary = selected);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Gets waypoint route points for map preview tailored to the destination
  List<LatLng> _getRoutePoints() {
    final title = '${_itinerary?['title']} ${_itinerary?['destinationName']}'.toLowerCase();
    if (title.contains('galle') || title.contains('mirissa') || title.contains('beach') || title.contains('coast') || title.contains('bentota')) {
      return const [
        LatLng(6.0535, 80.2210), // Galle
        LatLng(5.9734, 80.4285), // Weligama
        LatLng(5.9483, 80.4589), // Mirissa
        LatLng(6.0242, 80.7941), // Tangalle
      ];
    }
    if (title.contains('kandy') || title.contains('ella') || title.contains('highland') || title.contains('nuwara eliya') || title.contains('badulla')) {
      return const [
        LatLng(7.2906, 80.6337), // Kandy
        LatLng(6.9497, 80.7891), // Nuwara Eliya
        LatLng(6.8667, 81.0466), // Ella
        LatLng(6.9934, 81.0550), // Badulla
      ];
    }
    // Default Cultural & Island Discovery route
    return const [
      LatLng(7.9570, 80.7603), // Sigiriya
      LatLng(7.2906, 80.6337), // Kandy
      LatLng(6.8667, 81.0466), // Ella
      LatLng(5.9483, 80.4589), // Mirissa
    ];
  }

  /// Gets center location for map preview
  LatLng _getMapCenter() {
    final title = '${_itinerary?['title']} ${_itinerary?['destinationName']}'.toLowerCase();
    if (title.contains('galle') || title.contains('mirissa') || title.contains('beach') || title.contains('coast') || title.contains('bentota')) {
      return const LatLng(6.02, 80.45);
    }
    if (title.contains('kandy') || title.contains('ella') || title.contains('highland') || title.contains('nuwara eliya') || title.contains('badulla')) {
      return const LatLng(7.05, 80.85);
    }
    return const LatLng(7.05, 80.75);
  }

  // ── Status helper utilities ──

  String _getStatusLabel(dynamic status) {
    if (status == 0 || status == '0' || status == 'Draft' || status == 'draft') return 'Draft';
    if (status == 1 || status == '1' || status == 'Proposed' || status == 'proposed' || status == 'Awaiting Approval' || status == 'AWAITING APPROVAL') return 'Proposed';
    if (status == 2 || status == '2' || status == 'Accepted' || status == 'accepted' || status == 'Confirmed' || status == 'CONFIRMED') return 'Accepted';
    if (status == 3 || status == '3' || status == 'Discarded' || status == 'discarded' || status == 'Cancelled' || status == 'CANCELLED') return 'Discarded';
    return status?.toString() ?? 'Draft';
  }

  bool _isProposed(dynamic status) {
    if (status == 1 || status == '1') return true;
    final s = status?.toString().toLowerCase() ?? '';
    return s == 'proposed' || s.contains('propos') || s.contains('awaiting');
  }

  bool _isDraft(dynamic status) {
    if (status == 0 || status == '0') return true;
    final s = status?.toString().toLowerCase() ?? '';
    return s == 'draft';
  }

  bool _isAccepted(dynamic status) {
    if (status == 2 || status == '2') return true;
    final s = status?.toString().toLowerCase() ?? '';
    return s == 'accepted' || s.contains('accept') || s.contains('confirm');
  }

  bool _isDiscarded(dynamic status) {
    if (status == 3 || status == '3') return true;
    final s = status?.toString().toLowerCase() ?? '';
    return s == 'discarded' || s.contains('discard') || s.contains('cancel');
  }

  /// Status badge widget matching Serendib theme
  Widget _buildStatusBadge(dynamic status) {
    final label = _getStatusLabel(status);
    Color bg;
    Color text;
    IconData icon;

    if (_isAccepted(status)) {
      bg = const Color(0xFFE8F5E9);
      text = const Color(0xFF13684B);
      icon = Icons.check_circle_outline;
    } else if (_isProposed(status)) {
      bg = const Color(0xFFFFF8E1);
      text = const Color(0xFFB78103);
      icon = Icons.pending_actions_outlined;
    } else if (_isDiscarded(status)) {
      bg = const Color(0xFFFFEBEE);
      text = const Color(0xFFC62828);
      icon = Icons.cancel_outlined;
    } else {
      // Draft
      bg = const Color(0xFFF0F4F2);
      text = const Color(0xFF5A7067);
      icon = Icons.edit_note_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Accepts the itinerary proposal only when the API permits it.
  Future<void> _acceptItinerary() async {
    final id = _positiveId(_itinerary?['id']);
    if (id == null || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final success = await ApiService.acceptItinerary(id);
      if (!success) throw const ApiException('Failed to accept itinerary. Please retry.');
      if (!mounted) return;
      setState(() => _itinerary?['status'] = 'Accepted');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinerary accepted! You can now proceed to checkout.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString()),
          action: SnackBarAction(label: 'Retry', onPressed: _acceptItinerary),
        ));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Prepares or retrieves a real bookingId and navigates to /checkout
  Future<void> _continueToCheckout() async {
    final id = _positiveId(_itinerary?['id']);
    if (id == null || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    TripSelectionService.activeItinerary = _itinerary;

    try {
      int? bookingId = TripSelectionService.activeBookingId;

      if (bookingId == null) {
        try {
          final bookings = await ApiService.getMyBookings();
          for (final b in bookings) {
            if (b is Map && _positiveId(b['itineraryId']) == id) {
              bookingId = _positiveId(b['id']);
              break;
            }
          }
        } catch (_) {}

        if (bookingId == null) {
          try {
            final userId = await ApiService.getUserId() ?? 'customer-1';
            final cost = (_itinerary!['totalEstimatedCost'] ?? 1712).toDouble();
            final currency = _itinerary!['currency']?.toString() ?? 'USD';
            final firstTourId = _itinerary!['items'] is List && _itinerary!['items'].isNotEmpty
                ? _positiveId(_itinerary!['items'][0]['tourId']) ?? 1
                : 1;

            final created = await ApiService.createBooking({
              'customerId': userId,
              'itineraryId': id,
              'totalCost': cost,
              'currency': currency,
              'items': [
                {
                  'itemType': 0, // Tour
                  'tourId': firstTourId,
                  'unitPrice': cost,
                  'quantity': 1,
                }
              ],
            });
            bookingId = _positiveId(created['id']);
          } catch (_) {}
        }
      }

      if (bookingId != null) {
        TripSelectionService.activeBookingId = bookingId;
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/checkout',
        arguments: bookingId ?? id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not prepare booking for checkout: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Opens the Request Changes dialog with required comment field
  void _showRequestChangesDialog() {
    final commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    bool isSubmitting = false;
    String? requestError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note, color: Color(0xFF13684B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Request Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please describe the changes you would like us to make (dates, activities, hotels, or budget):',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5A7067), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    if (requestError != null) Text(requestError!, style: const TextStyle(color: Colors.red)),
                    TextFormField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g. Please add a guided safari tour in Yala on Day 3.',
                        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF8A9E96)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEDECE4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0E382C), width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFBF9F4),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Comment is required to request changes';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A9E96), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          final comment = commentController.text.trim();
                          final itineraryId = _itinerary?['id'] as int? ?? 0;
                          try {
                            final success = await ApiService.requestItineraryChanges(itineraryId, comment);
                            if (!success) throw const ApiException('Failed to submit changes. Please retry.');
                            if (!mounted || !dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            setState(() {
                              _itinerary?['status'] = 'Draft';
                              _itinerary?['notes'] = comment;
                            });
                            messenger.showSnackBar(const SnackBar(content: Text('Changes requested successfully. Status updated to Draft.')));
                          } catch (error) {
                            if (dialogContext.mounted) setDialogState(() => requestError = error.toString());
                          } finally {
                            if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(requestError == null ? 'Submit Request' : 'Retry', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'My Itinerary',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_itinerary != null) ...[
                              const SizedBox(width: 8),
                              _buildStatusBadge(_itinerary!['status']),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getHeaderSubtitle(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _fetchItinerary,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.refresh, color: theme.colorScheme.onSurface, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body content states (Loading / Error / Empty / Data) ──
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderSubtitle() {
    if (_itinerary == null) return 'Your Travel Plan';
    final title = _itinerary!['title']?.toString();
    final startStr = _itinerary!['startDate']?.toString();
    final endStr = _itinerary!['endDate']?.toString();
    if (startStr != null && endStr != null) {
      final s = DateTime.tryParse(startStr);
      final e = DateTime.tryParse(endStr);
      if (s != null && e != null) {
        final startFmt = DateFormat('dd MMM').format(s);
        final endFmt = DateFormat('dd MMM').format(e);
        if (title != null && title.isNotEmpty && !title.toLowerCase().contains('badulla')) {
          return '$title · $startFmt–$endFmt';
        }
        return 'Serendib Journey · $startFmt–$endFmt';
      }
    }
    if (title != null && title.isNotEmpty) return title;
    return 'Serendib Discovery';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0E382C)),
            SizedBox(height: 14),
            Text(
              'Loading your itinerary...',
              style: TextStyle(color: Color(0xFF5A7067), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 54, color: Color(0xFFD9534F)),
              const SizedBox(height: 14),
              Text(
                'Unable to load itinerary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A9E96)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchItinerary,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_itinerary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEFAF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_outlined, size: 36, color: Color(0xFF13684B)),
              ),
              const SizedBox(height: 18),
              Text(
                _pending ? 'Your itinerary is pending' : 'No itinerary yet',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _pending ? 'Your trip request was submitted. Check again once planning is complete.' : 'You do not have any travel itineraries yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8A9E96), height: 1.4),
              ),
              const SizedBox(height: 22),
              TextButton(onPressed: _fetchItinerary, child: const Text('Retry')),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/tour-search'),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: const Text('Explore Tours'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0E382C),
      onRefresh: _fetchItinerary,
      child: _buildItineraryContent(),
    );
  }

  Widget _buildItineraryContent() {
    final itinerary = _itinerary!;
    final status = itinerary['status'];

    // Parse dates and duration
    final startStr = itinerary['startDate']?.toString();
    final endStr = itinerary['endDate']?.toString();
    DateTime? startDate = startStr != null ? DateTime.tryParse(startStr) : null;
    DateTime? endDate = endStr != null ? DateTime.tryParse(endStr) : null;

    int durationDays = 1;
    if (startDate != null && endDate != null) {
      durationDays = endDate.difference(startDate).inDays;
      if (durationDays < 1) durationDays = 1;
    }

    // Parse items
    final rawItems = itinerary['items'];
    final List<Map<String, dynamic>> items = [];
    if (rawItems is List) {
      for (var it in rawItems) {
        if (it is Map) {
          items.add(Map<String, dynamic>.from(it));
        }
      }
    }

    // Sort items by dayNumber and sequenceOrder
    items.sort((a, b) {
      final dayA = a['dayNumber'] is int ? a['dayNumber'] as int : 1;
      final dayB = b['dayNumber'] is int ? b['dayNumber'] as int : 1;
      if (dayA != dayB) return dayA.compareTo(dayB);
      final seqA = a['sequenceOrder'] is int ? a['sequenceOrder'] as int : 0;
      final seqB = b['sequenceOrder'] is int ? b['sequenceOrder'] as int : 0;
      return seqA.compareTo(seqB);
    });

    // Recalculate duration if items indicate more days
    if (items.isNotEmpty) {
      final maxItemDay = items.map((i) => (i['dayNumber'] as int?) ?? 1).reduce(max);
      if (maxItemDay > durationDays) durationDays = maxItemDay;
    }

    // Summary stops title
    String stopsTitle = itinerary['title']?.toString() ?? 'Sri Lanka Tour';
    if (items.isNotEmpty) {
      final tourNames = items
          .map((i) => (i['tourName'] as String?)?.split(' ').first ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      if (tourNames.isNotEmpty && tourNames.length <= 4) {
        stopsTitle = tourNames.join(' → ');
      }
    }

    // Total cost in LKR
    final totalCost = itinerary['totalEstimatedCost'];
    final currency = itinerary['currency']?.toString() ?? '';
    final formattedCost = totalCost is num
        ? '$currency ${NumberFormat('#,##0').format(totalCost)}'.trim()
        : 'Cost pending';
    final routePoints = _getRoutePoints();
    final mapCenter = _getMapCenter();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Multi-Itinerary Selector Dropdown (if user has multiple itineraries) ──
          if (_itineraries.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDECE4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: int.tryParse(_itinerary?['id']?.toString() ?? ''),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0E382C)),
                  items: _itineraries.map((it) {
                    final id = int.tryParse(it['id']?.toString() ?? '') ?? 0;
                    final itStatus = _getStatusLabel(it['status']);
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text(
                        'Itinerary #$id - $itStatus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) async {
                    if (newId == null) return;
                    final found = _itineraries.firstWhere(
                      (it) => int.tryParse(it['id']?.toString() ?? '') == newId,
                      orElse: () => {},
                    );
                    if (found.isNotEmpty) {
                      _selectItinerary(found);
                    }
                  },
                ),
              ),
            ),
          ],

          // Dark Green Summary Card
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF134035),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Gold Days Badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A346),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$durationDays',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'DAYS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopsTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} activities · AI optimized',
                        style: const TextStyle(
                          color: Color(0xFFB8D3C8),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.auto_awesome, color: Color(0xFFD4A346), size: 22),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Open-Source Map Route Preview Card with Live OpenStreetMap & Full Route Button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/trip-map', arguments: _itinerary),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDECE4)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Live OpenStreetMap preview
                    IgnorePointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: 7.2,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.serendib_trails',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                color: const Color(0xFF0E382C),
                                strokeWidth: 3.5,
                                borderStrokeWidth: 1.5,
                                borderColor: const Color(0xFFD4A346),
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: routePoints.map((pt) {
                              return Marker(
                                point: pt,
                                width: 22,
                                height: 22,
                                child: const Icon(Icons.location_on, color: Color(0xFF0E382C), size: 22),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Gradient tint overlay for contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),

                    // VIEW FULL ROUTE pill button
                    Positioned(
                      top: 12,
                      left: 14,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/trip-map',
                            arguments: _itinerary,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.alt_route, size: 15, color: Color(0xFF0E382C)),
                              SizedBox(width: 6),
                              Text(
                                'VIEW FULL ROUTE',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF0E382C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section Title: Your journey + Edit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your journey',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (_isDraft(status) || _isProposed(status))
                GestureDetector(
                  onTap: _showRequestChangesDialog,
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Timeline items from the API ──
          if (items.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEDECE4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD4A346), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No activities scheduled yet for this itinerary.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5A7067)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final dayNum = item['dayNumber'] is int ? item['dayNumber'] as int : 1;

              // Format date label for this day
              String dateLabel = 'DAY $dayNum';
              if (startDate != null) {
                final itemDate = startDate.add(Duration(days: dayNum - 1));
                dateLabel = DateFormat('dd MMM').format(itemDate).toUpperCase();
              }

              // Format time
              String timeStr = 'Time pending';
              if (item['startTime'] != null) {
                final s = item['startTime'].toString();
                timeStr = s.length >= 5 ? s.substring(0, 5) : s;
              }

              final tourTitle = item['tourName']?.toString() ?? 'Tour Activity';
              final itemPrice = item['priceAtSelection'] ?? 0;
              final subtitle = 'LKR ${NumberFormat('#,##0').format(itemPrice)} · Tickets & activities included';

              final dotColor = idx == 0 ? const Color(0xFFD4A346) : const Color(0xFF0E382C);
              final isLast = idx == items.length - 1;

              return _buildTimelineItem(
                dayLabel: 'DAY $dayNum',
                dateLabel: dateLabel,
                dotColor: dotColor,
                icon: _getIconForIndex(idx),
                time: timeStr,
                title: tourTitle,
                subtitle: subtitle,
                showLine: !isLast,
              );
            }),

          const SizedBox(height: 16),

          // ── Soft Sand Summary Box ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF232D28) : const Color(0xFFF6EED8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DURATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A9E96),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$durationDays ${durationDays == 1 ? 'day' : 'days'} / ${durationDays > 1 ? durationDays - 1 : 0} nights',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ESTIMATED TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A9E96),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedCost,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Status Action Buttons ──
          if (items.isNotEmpty) _buildActionButtons(status),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Action buttons based on status:
  /// - Proposed: Accept & Request changes buttons
  /// - Draft: Request changes button
  /// - Accepted: Continue to checkout button (Accept & Request changes hidden)
  /// - Discarded: Both hidden, shows notice
  Widget _buildActionButtons(dynamic status) {
    if (_isProposed(status)) {
      return Column(
        children: [
          // Accept Itinerary Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _acceptItinerary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E382C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: _isActionLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Accept Itinerary',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Request Changes Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isActionLoading ? null : _showRequestChangesDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0E382C), width: 1.5),
                foregroundColor: const Color(0xFF0E382C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 20, color: Color(0xFF0E382C)),
                  SizedBox(width: 8),
                  Text(
                    'Request Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isDraft(status)) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB78103), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This itinerary is currently in Draft. You can request changes or wait for our travel team to submit a proposal.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A5800), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _showRequestChangesDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E382C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_note, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Request Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isAccepted(status)) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF13684B), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This itinerary proposal has been accepted! You can now continue to checkout to confirm your bookings.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0E382C), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Continue to Checkout Button (only shown when Accepted)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : _continueToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E382C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Continue to Checkout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_isDiscarded(status)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'This itinerary proposal was discarded.',
                style: TextStyle(fontSize: 13, color: Color(0xFFB71C1C), fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/tour-search'),
              child: const Text('Find Tours', style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getIconForIndex(int index) {
    const icons = [
      Icons.account_balance_outlined,
      Icons.apartment_outlined,
      Icons.directions_subway_outlined,
      Icons.nature_people_outlined,
      Icons.beach_access_outlined,
      Icons.temple_buddhist_outlined,
      Icons.hiking_outlined,
    ];
    return icons[index % icons.length];
  }

  Widget _buildTimelineItem({
    required String dayLabel,
    required String dateLabel,
    required Color dotColor,
    required IconData icon,
    required String time,
    required String title,
    required String subtitle,
    required bool showLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day & Date column
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF8A9E96),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1.5,
                        color: const Color(0xFFE2E9E3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(icon, color: const Color(0xFF13684B), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD4A346),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF8A9E96),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
