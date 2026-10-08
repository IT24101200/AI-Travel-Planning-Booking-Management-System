import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/date_time_contract.dart';
import '../../widgets/itinerary_route_preview.dart';
import '../../widgets/itinerary_journey_layout.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/agent_workflow_card.dart';
import '../../utils/transport_leg_utils.dart';

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
  const MyItineraryScreen({
    super.key,
    this.healthLoader = ApiService.getAgentHealth,
    this.nowProvider,
  });

  final Future<Map<String, dynamic>> Function() healthLoader;
  final DateTime Function()? nowProvider;

  @override
  State<MyItineraryScreen> createState() => _MyItineraryScreenState();
}

class _MyItineraryScreenState extends State<MyItineraryScreen> {
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  String? _agentStatus;
  String? _agentFailureReason;
  Map<String, dynamic>? _agentHealth;
  String? _agentHealthError;
  bool _isCheckingAgentHealth = false;
  int _healthRequest = 0;
  bool _pending = false;
  int? _selectedItineraryId;
  Map<String, dynamic>? _itinerary;
  int? _selectedJourneyIndex;
  List<Map<String, dynamic>> _itineraries = [];
  int? _resolvedTripRequestId;
  DateTime? _tripStartDate;
  Map<String, dynamic>? _booking;
  List<dynamic> _agentLogs = [];
  StreamSubscription<AgentLogStreamEvent>? _agentStreamSubscription;
  bool _reconnectLiveUpdates = true;
  bool _refetchedFinalItinerary = false;
  bool _isRetryingAgent = false;

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
    final healthRequest = ++_healthRequest;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _agentStatus = null;
      _agentFailureReason = null;
      _agentHealth = null;
      _agentHealthError = null;
      _isCheckingAgentHealth = false;
      _pending = false;
      _itinerary = null;
      _booking = null;
      _tripStartDate = null;
      _selectedJourneyIndex = null;
    });
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      final directId = args is int
          ? _positiveId(args)
          : args is Map
          ? _positiveId(args['itineraryId']) ??
                (args.containsKey('items') ? _positiveId(args['id']) : null)
          : _selectedItineraryId;
      final tripRequestId = args is Map
          ? _positiveId(args['tripRequestId'])
          : null;
      var resolvedTripRequestId = tripRequestId;
      Map<String, dynamic>? selected;
      List<Map<String, dynamic>> choices = [];
      if (directId != null) {
        selected = await ApiService.getItinerary(directId);
      } else {
        final records = await ApiService.getMyItineraries();
        choices = records
            .map((record) => Map<String, dynamic>.from(record as Map))
            .toList();
        if (tripRequestId != null) {
          choices = choices
              .where(
                (record) =>
                    _positiveId(record['tripRequestId']) == tripRequestId,
              )
              .toList();
        }
        if (choices.isNotEmpty) {
          final id = _positiveId(choices.first['id']);
          if (id == null)
            throw const ApiException('The itinerary has no valid ID.');
          selected = await ApiService.getItinerary(id);
        }
      }

      resolvedTripRequestId ??= _positiveId(selected?['tripRequestId']);

      Map<String, dynamic>? latestTripRequest;
      if (resolvedTripRequestId == null && selected == null) {
        try {
          final requests = await ApiService.getMyTripRequests();
          final records = requests
              .whereType<Map>()
              .map((record) => Map<String, dynamic>.from(record))
              .toList();
          if (records.isNotEmpty) {
            latestTripRequest = records.first;
            resolvedTripRequestId = _positiveId(latestTripRequest['id']);
          }
        } catch (_) {}
      }

      Map<String, dynamic>? tripRequest = latestTripRequest;
      if (resolvedTripRequestId != null && tripRequest == null) {
        try {
          tripRequest = await ApiService.getTripRequest(resolvedTripRequestId);
        } catch (_) {}
      }

      String? agentStatus;
      String? agentFailureReason;
      if (resolvedTripRequestId == null) {
        agentFailureReason =
            'Agentic AI was not triggered because no trip request was found.';
      } else {
        agentStatus = tripRequest?['status']?.toString();
        final normalizedStatus = agentStatus?.toLowerCase().replaceAll(' ', '');
        if (normalizedStatus == 'failed') {
          agentFailureReason = ApiService.safeAgentFailureMessage(
            tripRequest?['failureReason']?.toString(),
          );
        } else if (normalizedStatus == 'pending') {
          agentFailureReason ??=
              'Agentic AI was not triggered for this trip request yet.';
        }
      }

      if (!mounted || healthRequest != _healthRequest) return;
      setState(() {
        _itinerary = selected;
        _itineraries = choices;
        _agentStatus = agentStatus;
        _agentFailureReason = agentFailureReason;
        _resolvedTripRequestId = resolvedTripRequestId;
        _tripStartDate = parseDateOnly(
          selected?['startDate']?.toString() ??
              tripRequest?['startDate']?.toString() ??
              '',
        );
        _pending = resolvedTripRequestId != null && selected == null;
      });
      if (resolvedTripRequestId != null) {
        unawaited(_checkAgentHealth(healthRequest));
      }
      unawaited(
        _loadAuxiliaryDetails(
          resolvedTripRequestId,
          _positiveId(selected?['id']),
        ),
      );
    } catch (error) {
      if (mounted && healthRequest == _healthRequest) {
        setState(() => _errorMessage = ApiService.userMessage(error));
      }
    } finally {
      if (mounted && healthRequest == _healthRequest) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAuxiliaryDetails(
    int? tripRequestId,
    int? itineraryId,
  ) async {
    if (!mounted) return;
    try {
      final bookings = await ApiService.getMyBookings();
      Map<String, dynamic>? booking;
      for (final b in bookings) {
        if (b is Map) {
          final bItinId = _positiveId(b['itineraryId']);
          final bTripId = _positiveId(b['tripRequestId']);
          if (itineraryId != null && bItinId == itineraryId) {
            booking = Map<String, dynamic>.from(b);
            break;
          } else if (tripRequestId != null && bTripId == tripRequestId) {
            booking = Map<String, dynamic>.from(b);
            break;
          }
        }
      }
      if (mounted && booking != null) {
        final bookingItineraryId = _positiveId(booking['itineraryId']);
        if (itineraryId == null || bookingItineraryId == itineraryId) {
          setState(() => _booking = booking);
          final bookingId = _positiveId(booking['id']);
          if (bookingItineraryId != null && bookingId != null) {
            TripSelectionService.setActiveBookingContext(
              itineraryId: bookingItineraryId,
              bookingId: bookingId,
            );
          }
        }
      } else if (itineraryId != null &&
          TripSelectionService.activeBookingItineraryId == itineraryId) {
        TripSelectionService.activeBookingId = null;
        TripSelectionService.activeBookingItineraryId = null;
      }
    } catch (_) {}

    if (tripRequestId != null && tripRequestId > 0) {
      try {
        final logs = await ApiService.getAgentLogs(tripRequestId);
        if (mounted) {
          setState(() => _agentLogs = _mergeAgentLogs(_agentLogs, logs));
          _startAgentLogStream(tripRequestId);
        }
      } catch (_) {}
    }
  }

  List<dynamic> _mergeAgentLogs(List<dynamic> current, List<dynamic> incoming) {
    final merged = <dynamic>[...current];
    final ids = <String>{
      for (final item in merged)
        if (item is Map && item['id'] != null) item['id'].toString(),
    };
    for (final item in incoming) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      if (id == null || ids.add(id)) merged.add(item);
    }
    merged.sort((a, b) {
      final at = a is Map ? parseInstant(a['timestamp']) : null;
      final bt = b is Map ? parseInstant(b['timestamp']) : null;
      return (at ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        bt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return merged;
  }

  void _startAgentLogStream(int tripRequestId) {
    _agentStreamSubscription?.cancel();
    _reconnectLiveUpdates = true;
    _agentStreamSubscription = ApiService.streamAgentLogs(tripRequestId).listen(
      (event) => _handleAgentStreamEvent(tripRequestId, event),
      onDone: ApiService.mockStreamAgentLogs == null
          ? () => _scheduleAgentReconnect(tripRequestId)
          : null,
      onError: ApiService.mockStreamAgentLogs == null
          ? (_, __) => _scheduleAgentReconnect(tripRequestId)
          : null,
      cancelOnError: true,
    );
  }

  Future<void> _handleAgentStreamEvent(
    int tripRequestId,
    AgentLogStreamEvent event,
  ) async {
    if (!mounted || !_reconnectLiveUpdates) return;
    if (event.event == 'agent-log') {
      setState(() => _agentLogs = _mergeAgentLogs(_agentLogs, [event.data]));
    } else if (event.event == 'trip-status') {
      final status = event.data['status']?.toString();
      setState(() {
        _agentStatus = status;
        _agentFailureReason = status?.toLowerCase() == 'failed'
            ? ApiService.safeAgentFailureMessage(
                event.data['failureReason']?.toString(),
              )
            : null;
        _pending =
            _resolvedTripRequestId != null &&
            _itinerary == null &&
            status != 'Failed';
      });
      if (status == 'AwaitingApproval' && !_refetchedFinalItinerary) {
        _refetchedFinalItinerary = true;
        await _refetchFinalItinerary(tripRequestId);
      }
      if (_isTerminalTripStatus(status)) {
        _reconnectLiveUpdates = false;
        await _agentStreamSubscription?.cancel();
      }
    }
  }

  Future<void> _scheduleAgentReconnect(int tripRequestId) async {
    if (mounted &&
        _reconnectLiveUpdates &&
        !_isTerminalTripStatus(_agentStatus)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_reconnectLiveUpdates) return;
      try {
        final logs = await ApiService.getAgentLogs(tripRequestId);
        if (mounted)
          setState(() => _agentLogs = _mergeAgentLogs(_agentLogs, logs));
      } catch (_) {}
      _startAgentLogStream(tripRequestId);
    }
  }

  bool _isTerminalTripStatus(String? status) => const {
    'AwaitingApproval',
    'Failed',
    'Cancelled',
    'Rejected',
    'Approved',
  }.contains(status);

  Future<void> _refetchFinalItinerary(int tripRequestId) async {
    try {
      final itineraryId = _positiveId(_itinerary?['id']);
      Map<String, dynamic>? latest;
      if (itineraryId != null) {
        latest = await ApiService.getItinerary(itineraryId);
      } else {
        final records = await ApiService.getMyItineraries();
        for (final record in records.whereType<Map>()) {
          final recordId = _positiveId(record['id']);
          if (_positiveId(record['tripRequestId']) == tripRequestId &&
              recordId != null) {
            latest = await ApiService.getItinerary(recordId);
            break;
          }
        }
      }
      if (mounted && latest != null) setState(() => _itinerary = latest);
    } catch (_) {}
  }

  Future<void> _checkAgentHealth(int request) async {
    setState(() {
      _isCheckingAgentHealth = true;
      _agentHealthError = null;
    });
    try {
      final health = await widget.healthLoader();
      if (!mounted || request != _healthRequest) return;
      setState(() {
        _agentHealth = health;
        if (health['status']?.toString().toLowerCase() != 'healthy') {
          _agentHealthError =
              'Agent server reported status: ${health['status']}.';
        }
      });
    } catch (_) {
      if (!mounted || request != _healthRequest) return;
      setState(() {
        _agentHealthError =
            'Agent connection is temporarily unavailable. Your saved itinerary is still available.';
      });
    } finally {
      if (mounted && request == _healthRequest) {
        setState(() => _isCheckingAgentHealth = false);
      }
    }
  }

  Future<void> _retryAgentPipeline() async {
    final tripRequestId = _resolvedTripRequestId;
    if (_isRetryingAgent ||
        tripRequestId == null ||
        tripRequestId <= 0 ||
        _agentStatus?.toLowerCase() != 'failed') {
      return;
    }
    setState(() => _isRetryingAgent = true);
    try {
      await ApiService.triggerAgentPipeline(tripRequestId);
      await _fetchItinerary();
    } catch (error) {
      if (mounted) {
        setState(() {
          _agentFailureReason = ApiService.userMessage(error);
          _agentStatus = 'Failed';
        });
      }
    } finally {
      if (mounted) setState(() => _isRetryingAgent = false);
    }
  }

  Future<void> _selectItinerary(Map<String, dynamic> item) async {
    final id = _positiveId(item['id']);
    if (id == null) return;
    setState(() {
      _selectedItineraryId = id;
      _selectedJourneyIndex = null;
      _isLoading = true;
      _errorMessage = null;
      _booking = null;
    });
    try {
      final selected = await ApiService.getItinerary(id);
      if (mounted) {
        setState(() {
          _itinerary = selected;
          _tripStartDate = parseDateOnly(
            selected?['startDate']?.toString() ?? '',
          );
        });
        unawaited(
          _loadAuxiliaryDetails(
            _positiveId(selected?['tripRequestId']),
            id,
          ),
        );
      }
    } catch (error) {
      if (mounted)
        setState(() => _errorMessage = ApiService.userMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Status helper utilities ──

  String _getStatusLabel(dynamic status) {
    if (status == 0 || status == '0' || status == 'Draft' || status == 'draft')
      return 'Draft';
    if (status == 1 ||
        status == '1' ||
        status == 'Proposed' ||
        status == 'proposed' ||
        status == 'Awaiting Approval' ||
        status == 'AWAITING APPROVAL')
      return 'Proposed';
    if (status == 2 ||
        status == '2' ||
        status == 'Accepted' ||
        status == 'accepted' ||
        status == 'Confirmed' ||
        status == 'CONFIRMED')
      return 'Accepted';
    if (status == 3 ||
        status == '3' ||
        status == 'Discarded' ||
        status == 'discarded' ||
        status == 'Cancelled' ||
        status == 'CANCELLED')
      return 'Discarded';
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

  @override
  void dispose() {
    _reconnectLiveUpdates = false;
    _agentStreamSubscription?.cancel();
    super.dispose();
  }

  bool _isTripCancelled() {
    final value = _agentStatus?.toLowerCase().replaceAll(' ', '');
    return value == 'cancelled' || value == 'canceled';
  }

  bool _canCancelTrip() {
    if (_resolvedTripRequestId == null || _isTripCancelled()) return false;
    final startDate = _tripStartDate;
    if (startDate == null) return false;
    final now = widget.nowProvider?.call() ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDay = DateTime(startDate.year, startDate.month, startDate.day);
    if (tripDay.isBefore(today.add(const Duration(days: 3)))) return false;
    final value = _agentStatus?.toLowerCase().replaceAll(' ', '');
    return value == 'pending' ||
        value == 'planning' ||
        value == 'planned' ||
        value == 'awaitingapproval' ||
        value == 'approved';
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
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
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
      if (!success)
        throw const ApiException('Failed to accept itinerary. Please retry.');
      if (!mounted) return;
      setState(() => _itinerary?['status'] = 'Accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Itinerary accepted! You can now proceed to checkout.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.userMessage(error)),
            action: SnackBarAction(label: 'Retry', onPressed: _acceptItinerary),
          ),
        );
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
      int? bookingId;
      final bookings = await ApiService.getMyBookings();
      for (final b in bookings) {
        if (b is Map && _positiveId(b['itineraryId']) == id) {
          bookingId = _positiveId(b['id']);
          if (bookingId != null) break;
        }
      }

      if (bookingId != null) {
        TripSelectionService.setActiveBookingContext(
          itineraryId: id,
          bookingId: bookingId,
        );
      }

      if (!mounted) return;
      if (bookingId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your booking proposal is still being prepared.'),
          ),
        );
        return;
      }
      Navigator.pushNamed(context, '/checkout', arguments: bookingId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not prepare booking for checkout: $error'),
          ),
        );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      color: Color(0xFF13684B),
                      size: 22,
                    ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A7067),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (requestError != null)
                      Text(
                        requestError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    TextFormField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Please add a guided safari tour in Yala on Day 3.',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8A9E96),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFEDECE4),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF0E382C),
                            width: 1.5,
                          ),
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
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF8A9E96),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                            final success =
                                await ApiService.requestItineraryChanges(
                                  itineraryId,
                                  comment,
                                );
                            if (!success)
                              throw const ApiException(
                                'Failed to submit changes. Please retry.',
                              );
                            if (!mounted || !dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            setState(() {
                              _itinerary?['status'] = 'Draft';
                              _itinerary?['notes'] = comment;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Changes requested successfully. Status updated to Draft.',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(
                                () => requestError = ApiService.userMessage(
                                  error,
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted)
                              setDialogState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          requestError == null ? 'Submit Request' : 'Retry',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3D36)
                              : const Color(0xFFEDECE4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
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
                            Flexible(
                              child: Text(
                                'My Itinerary',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (_itinerary != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: _buildStatusBadge(
                                  _isTripCancelled()
                                      ? 'Cancelled'
                                      : _itinerary!['status'],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getHeaderSubtitle(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF9EABA4)
                                : const Color(0xFF8A9E96),
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
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3D36)
                              : const Color(0xFFEDECE4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.refresh,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body content states (Loading / Error / Empty / Data) ──
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  String _getHeaderSubtitle() {
    if (_itinerary == null) return 'Your Travel Plan';
    final title = _booking?['tripTitle']?.toString() ??
        _itinerary!['title']?.toString();
    final startStr = _itinerary!['startDate']?.toString();
    final endStr = _itinerary!['endDate']?.toString();
    if (startStr != null && endStr != null) {
      final s = parseDateOnly(startStr);
      final e = parseDateOnly(endStr);
      if (s != null && e != null) {
        final startFmt = DateFormat('dd MMM').format(s);
        final endFmt = DateFormat('dd MMM').format(e);
        if (title != null &&
            title.isNotEmpty &&
            !title.toLowerCase().contains('badulla')) {
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
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: Color(0xFFD9534F),
              ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_itinerary == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A2F)
                        : const Color(0xFFEEFAF4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _pending ? Icons.auto_awesome_outlined : Icons.map_outlined,
                    size: 36,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF13684B),
                  ),
                ),
                const SizedBox(height: 18),
                if (_agentStatus != null || _agentFailureReason != null)
                  _buildAgentStateCard(),
                if (_pending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A2F)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF81C784),
                      ),
                    ),
                    child: Text(
                      'AI PLANNING IN PROGRESS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : const Color(0xFF1B5E20),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
                  _pending
                      ? 'Your trip request was submitted. Our 4 AI agents (Coordinator, Itinerary, Booking & Validation) are analyzing destinations and availability. Check again once planning is complete.'
                      : 'You do not have any travel itineraries yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A9E96),
                    height: 1.4,
                  ),
                ),
                if (_resolvedTripRequestId != null &&
                    _resolvedTripRequestId! > 0) ...[
                  const SizedBox(height: 16),
                  AgentWorkflowCard(
                    tripRequestId: _resolvedTripRequestId!,
                    initialLogs: _agentLogs,
                    pipelineStatus: _agentStatus,
                    failureReason: _agentFailureReason,
                    onLogsUpdated: (updatedLogs) {
                      _agentLogs = updatedLogs;
                    },
                  ),
                ],
                const SizedBox(height: 22),
                if (_pending) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/trip-history'),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View in Trip History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E382C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (_canCancelTrip()) ...[
                    const SizedBox(height: 10),
                    _buildCancelTripButton(),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _fetchItinerary,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: _fetchItinerary,
                    child: const Text('Retry'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/tour-search'),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Explore Tours'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E382C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

  Widget _buildAgentStateCard() {
    final healthStatus = _agentHealth?['status']?.toString() ?? 'unknown';
    final serviceName =
        _agentHealth?['service']?.toString() ?? 'Agentic AI service';
    final isError = _agentFailureReason != null;
    final isChecking = _isCheckingAgentHealth;
    final isWarning = !isError && (isChecking || _agentHealthError != null);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFF1F2)
            : isWarning
            ? const Color(0xFFFFF8E1)
            : const Color(0xFFEAF8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? const Color(0xFFFCA5A5)
              : isWarning
              ? const Color(0xFFD4A346)
              : const Color(0xFF9AD7B3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : isWarning
                ? Icons.info_outline
                : Icons.check_circle_outline,
            color: isError
                ? const Color(0xFFB91C1C)
                : isWarning
                ? const Color(0xFF856000)
                : const Color(0xFF18794E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isError
                      ? 'Agentic AI needs attention'
                      : isChecking
                      ? 'Checking agent connection…'
                      : isWarning
                      ? 'Agent connection unavailable'
                      : 'Agentic AI started',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isError
                        ? const Color(0xFF991B1B)
                        : isWarning
                        ? const Color(0xFF856000)
                        : const Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isError
                      ? _agentFailureReason!
                      : isChecking
                      ? 'Checking the server; retrying temporary connection failures.\nPipeline status: ${_agentStatus ?? 'unknown'}'
                      : _agentHealthError != null
                      ? '$_agentHealthError\nPipeline status: ${_agentStatus ?? 'unknown'}'
                      : 'Agent server: $healthStatus\n$serviceName\nPipeline status: ${_agentStatus ?? 'running'}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isError
                        ? const Color(0xFF991B1B)
                        : isWarning
                        ? const Color(0xFF856000)
                        : const Color(0xFF166534),
                  ),
                ),
                if (_agentHealthError != null && !isChecking)
                  TextButton(
                    onPressed: () =>
                        unawaited(_checkAgentHealth(++_healthRequest)),
                    child: const Text('Retry agent connection'),
                  ),
                if (isError && _agentStatus?.toLowerCase() == 'failed')
                  TextButton.icon(
                    onPressed: _isRetryingAgent ? null : _retryAgentPipeline,
                    icon: _isRetryingAgent
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      _isRetryingAgent ? 'Retrying...' : 'Retry planning',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryContent() {
    final itinerary = _itinerary!;
    final status = itinerary['status'];

    // Parse dates and duration
    final startStr = itinerary['startDate']?.toString();
    final endStr = itinerary['endDate']?.toString();
    DateTime? startDate = startStr != null ? parseDateOnly(startStr) : null;
    DateTime? endDate = endStr != null ? parseDateOnly(endStr) : null;

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
      final maxItemDay = items
          .map((i) => (i['dayNumber'] as int?) ?? 1)
          .reduce(max);
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

    // A persisted booking is the commercial source of truth. Before a booking
    // exists, show only the itinerary estimate and label it as such.
    final bookingTotal = _booking?['totalCost'];
    final totalCost = bookingTotal is num
        ? bookingTotal
        : itinerary['totalEstimatedCost'];
    final currency = (bookingTotal is num
            ? (_booking == null ? null : _booking!['currency'])
            : itinerary['currency'])
        ?.toString() ??
        '';
    final formattedCost = totalCost is num
        ? '$currency ${NumberFormat('#,##0').format(totalCost)}'.trim()
        : 'Cost pending';

    return ItineraryJourneyLayout(
      map: ItineraryRoutePreview(
        itinerary: itinerary,
        selectedItem:
            _selectedJourneyIndex != null &&
                _selectedJourneyIndex! < items.length
            ? items[_selectedJourneyIndex!]
            : null,
      ),
      heading: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Your journey',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
      children: [
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
            final dayNum = item['dayNumber'] is int
                ? item['dayNumber'] as int
                : 1;

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
            final subtitle =
                'LKR ${NumberFormat('#,##0').format(itemPrice)} · Tickets & activities included';

            final isSelected = idx == (_selectedJourneyIndex ?? 0);
            final dotColor = isSelected
                ? const Color(0xFF7DD3FC)
                : const Color(0xFF0E382C);
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
              selected: isSelected,
              onTap: () => setState(() => _selectedJourneyIndex = idx),
            );
          }),

        const SizedBox(height: 16),

        if (_agentStatus != null || _agentFailureReason != null)
          _buildAgentStateCard(),

        // ── 4-Agent Live Execution & Reasoning Workflow Card ──
        if (_resolvedTripRequestId != null && _resolvedTripRequestId! > 0)
          AgentWorkflowCard(
            tripRequestId: _resolvedTripRequestId!,
            initialLogs: _agentLogs,
            pipelineStatus: _agentStatus,
            failureReason: _agentFailureReason,
            onLogsUpdated: (updatedLogs) {
              _agentLogs = updatedLogs;
            },
          ),

        // ── Reserved Hotel & Transport Section (when available) ──
        _buildReservedInventorySection(),

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
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF0E382C),
                ),
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
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFD4A346),
                size: 22,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Soft Sand Summary Box ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF232D28)
                : const Color(0xFFF6EED8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ESTIMATED TOTAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Commercial Package Price Breakdown ──
        _buildPriceBreakdownSection(
          totalCost is num ? totalCost : 0,
          currency,
          hasAuthoritativeBooking: bookingTotal is num,
        ),

        const SizedBox(height: 18),

        // ── Status Action Buttons ──
        if (items.isNotEmpty || _canCancelTrip()) _buildActionButtons(status),
      ],
    );
  }

  /// Action buttons based on status:
  /// - Proposed: Accept & Request changes buttons
  /// - Draft: Request changes button
  /// - Accepted: Continue to checkout button (Accept & Request changes hidden)
  /// - Discarded: Both hidden, shows notice
  Widget _buildActionButtons(dynamic status) {
    if (_isTripCancelled()) return _buildCancelledNotice();

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
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_canCancelTrip()) ...[
            const SizedBox(height: 12),
            _buildCancelTripButton(),
          ],
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A5800),
                      height: 1.3,
                    ),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_canCancelTrip()) ...[
            const SizedBox(height: 12),
            _buildCancelTripButton(),
          ],
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0E382C),
                      fontWeight: FontWeight.w600,
                    ),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (_canCancelTrip()) ...[
            const SizedBox(height: 12),
            _buildCancelTripButton(),
          ],
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
            const Icon(
              Icons.cancel_outlined,
              color: Color(0xFFC62828),
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'This itinerary proposal was discarded.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/tour-search'),
              child: const Text(
                'Find Tours',
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCancelTripButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _isActionLoading ? null : _confirmTripCancellation,
            icon: _isActionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC62828),
                    ),
                  )
                : const Icon(Icons.cancel_outlined, size: 19),
            label: const Text('Cancel trip'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFC62828), width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cancellation is available until 3 days before departure.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF8A9E96)),
        ),
      ],
    );
  }

  Widget _buildCancelledNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFC62828), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cancelled. This trip is no longer actionable.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFB71C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTripCancellation() async {
    if (!_canCancelTrip() || _isActionLoading) return;
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: const Text(
          'Are you sure you want to cancel this trip? This action cannot be undone. '
          'Cancellation is allowed until 3 days before departure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep trip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (shouldCancel == true) await _cancelTrip();
  }

  Future<void> _cancelTrip() async {
    final tripRequestId = _resolvedTripRequestId;
    if (tripRequestId == null || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await ApiService.cancelTripRequest(tripRequestId);
      await _fetchItinerary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your trip has been cancelled.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.userMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
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
    required bool selected,
    required VoidCallback onTap,
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF7DD3FC)
                          : Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2E3D36)
                          : const Color(0xFFEDECE4),
                    ),
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
                          child: Icon(
                            icon,
                            color: const Color(0xFF13684B),
                            size: 22,
                          ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservedInventorySection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bookingCurrency = _booking?['currency']?.toString() ??
        _itinerary?['currency']?.toString() ??
        '';

    final bookingItemsRaw =
        _booking?['bookingItems'] ?? _itinerary?['bookingItems'];
    final List<Map<String, dynamic>> bookingItems = [];
    if (bookingItemsRaw is List) {
      for (var it in bookingItemsRaw) {
        if (it is Map) {
          bookingItems.add(Map<String, dynamic>.from(it));
        }
      }
    }

    Map<String, dynamic>? hotelItem;
    final transportItems = orderedTransportItems(bookingItems);

    for (final it in bookingItems) {
      final type = it['itemType']?.toString().toLowerCase() ?? '';
      if (type == 'hotel' || type == 'room' || it['hotelName'] != null) {
        hotelItem ??= it;
      }
    }

    if (hotelItem != null) {
      hotelItem['roomTypeName'] = hotelItem['roomType'] ?? 'Room type unavailable';
      hotelItem['capacity'] = hotelItem['roomCapacity'];
    }

    final hasInventory = hotelItem != null || transportItems.isNotEmpty;

    if (!hasInventory) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2620) : const Color(0xFFF4F9F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFD4E5DC),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E382C).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_outlined,
                color: Color(0xFF0E382C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Commercial Package Integration',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hotels and private transport are coordinated dynamically by our Booking Agent upon request submission.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5A7067)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Reserved Accommodations & Transport',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // Booked Hotel Card
        if (hotelItem != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2824) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD1E3D9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hotel_outlined,
                      color: Color(0xFF1B5E20),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              hotelItem['hotelName']?.toString() ??
                                  'Hotel details unavailable',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BOOKED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Room: ${hotelItem['roomTypeName'] ?? 'Room type unavailable'}${hotelItem['capacity'] != null ? ' · Up to ${hotelItem['capacity']} guests' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF5A7067),
                        ),
                      ),
                      if (hotelItem['checkInDate'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Check-in: ${hotelItem['checkInDate'].toString().split('T').first}${hotelItem['checkOutDate'] != null ? ' · Check-out: ${hotelItem['checkOutDate'].toString().split('T').first}' : ''}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF8A9E96),
                          ),
                        ),
                      ],
                      if (hotelItem['subtotal'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${bookingCurrency.isEmpty ? '' : '$bookingCurrency '}${NumberFormat('#,##0').format(hotelItem['subtotal'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E382C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Booked Transport Card
        ...transportItems.map(
          (transportItem) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2824) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD1E3D9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF0369A1),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${transportLegLabel(transportItem) != null ? '${transportLegLabel(transportItem)} · ' : ''}${transportItem['transportType'] ?? transportItem['vehicleType'] ?? 'Transport details unavailable'} Transfer',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ASSIGNED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Provider: ${transportItem['transportProvider'] ?? 'Provider unavailable'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF5A7067),
                        ),
                      ),
                      if (transportItem['routeFrom'] != null ||
                          transportItem['routeTo'] != null ||
                          transportItem['pickupLocation'] != null ||
                          transportItem['dropoffLocation'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Route: ${transportItem['routeFrom'] ?? transportItem['pickupLocation'] ?? 'Origin'} → ${transportItem['routeTo'] ?? transportItem['dropoffLocation'] ?? 'Destination'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF8A9E96),
                          ),
                        ),
                      ],
                      if (transportItem['subtotal'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${bookingCurrency.isEmpty ? '' : '$bookingCurrency '}${NumberFormat('#,##0').format(transportItem['subtotal'])}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E382C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdownSection(
    num totalCost,
    String currency, {
    required bool hasAuthoritativeBooking,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bookingItemsRaw =
        _booking?['bookingItems'] ?? _itinerary?['bookingItems'];
    num hotelCost = 0;
    num transportCost = 0;
    num tourCost = 0;

    if (bookingItemsRaw is List) {
      for (var it in bookingItemsRaw) {
        if (it is Map) {
          final type = it['itemType']?.toString().toLowerCase() ?? '';
          final p = it['subtotal'];
          if (p is num) {
            if (type == 'hotel' || type == 'room' || it['hotelName'] != null) {
              hotelCost += p;
            } else if (type == 'transport' ||
                it['vehicleType'] != null ||
                it['transportProvider'] != null) {
              transportCost += p;
            } else {
              tourCost += p;
            }
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2824) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasAuthoritativeBooking
                    ? 'COMMERCIAL BREAKDOWN'
                    : 'ESTIMATED ITINERARY COST',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF13684B),
                  letterSpacing: 0.5,
                ),
              ),
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: Color(0xFF8A9E96),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasAuthoritativeBooking) ...[
            if (bookingItemsRaw is List && bookingItemsRaw.isNotEmpty) ...[
              _buildBreakdownRow('Tours & Experiences', tourCost, currency),
              if (hotelCost > 0) ...[
                const SizedBox(height: 6),
                _buildBreakdownRow('Hotel Accommodation', hotelCost, currency),
              ],
              if (transportCost > 0) ...[
                const SizedBox(height: 6),
                _buildBreakdownRow(
                  'Private Transport & Driver',
                  transportCost,
                  currency,
                ),
              ],
            ] else
              _buildBreakdownRow(
                'Itemized booking data unavailable',
                0,
                currency,
                freeLabel: 'Review required',
              ),
            const SizedBox(height: 6),
            _buildBreakdownRow(
              'Taxes & Agent Handling',
              0,
              currency,
              freeLabel: 'Included',
            ),
          ] else
            _buildBreakdownRow('AI itinerary estimate', totalCost, currency),
          const Divider(height: 20, color: Color(0xFFE4E7E2)),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasAuthoritativeBooking
                      ? 'Total Commercial Cost'
                      : 'Estimated Total',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$currency ${NumberFormat('#,##0').format(totalCost > 0 ? totalCost : (tourCost + hotelCost + transportCost))}'
                      .trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0E382C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    num amount,
    String currency, {
    String? freeLabel,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5A7067)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            freeLabel ??
                '$currency ${NumberFormat('#,##0').format(amount)}'.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
