import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_constants.dart';
import '../services/api_service.dart';
import '../services/date_time_contract.dart';

/// Customer-facing progress and results for the latest planning attempt.
/// Detailed execution history is available in the staff web dashboard.
class AgentWorkflowCard extends StatefulWidget {
  const AgentWorkflowCard({
    super.key,
    required this.tripRequestId,
    this.initialLogs,
    this.pipelineStatus,
    this.failureReason,
    this.enablePolling = false,
    this.onLogsUpdated,
  });

  final int tripRequestId;
  final List<dynamic>? initialLogs;
  final String? pipelineStatus;
  final String? failureReason;
  final bool enablePolling;
  final ValueChanged<List<dynamic>>? onLogsUpdated;

  @override
  State<AgentWorkflowCard> createState() => _AgentWorkflowCardState();
}

class _AgentWorkflowCardState extends State<AgentWorkflowCard> {
  List<dynamic> _logs = [];
  Timer? _pollingTimer;

  static const List<Map<String, dynamic>> _agentMeta = [
    {
      'key': 'CoordinatorAgent',
      'aliases': ['coordinator', 'coordinatoragent', 'coordinatorevaluator'],
      'name': 'Coordinator Agent',
      'role': 'Trip Goals & Budget Allocation',
      'result': 'Trip goals and budget ready',
      'icon': Icons.alt_route_rounded,
      'stepNum': 1,
    },
    {
      'key': 'ItineraryAgent',
      'aliases': ['itinerary', 'itineraryagent'],
      'name': 'Itinerary Agent',
      'role': 'Daily Schedule & Non-Overlapping Route',
      'result': 'Journeys and routes scheduled',
      'icon': Icons.calendar_month_outlined,
      'stepNum': 2,
    },
    {
      'key': 'BookingAgent',
      'aliases': ['booking', 'bookingagent'],
      'name': 'Booking Agent',
      'role': 'Live Hotel & Transport Availability',
      'result': 'Hotels and transport selected',
      'icon': Icons.hotel_outlined,
      'stepNum': 3,
    },
    {
      'key': 'ValidationAgent',
      'aliases': ['validation', 'validationagent'],
      'name': 'Validation Agent',
      'role': 'Commercial Rules & Human Approval Gate',
      'result': 'Itinerary checked and ready for approval',
      'icon': Icons.shield_outlined,
      'stepNum': 4,
    },
  ];

  @override
  void initState() {
    super.initState();
    _logs = widget.initialLogs ?? [];
    if (widget.tripRequestId > 0 && _logs.isEmpty) {
      _fetchLogs();
    }
    if (widget.enablePolling) {
      _startPollingIfNeeded();
    }
  }

  @override
  void didUpdateWidget(covariant AgentWorkflowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLogs != null &&
        widget.initialLogs != oldWidget.initialLogs) {
      setState(() => _logs = widget.initialLogs!);
    }
    if (widget.tripRequestId != oldWidget.tripRequestId &&
        widget.tripRequestId > 0) {
      _fetchLogs();
    }
    if (widget.enablePolling) {
      _startPollingIfNeeded();
    } else {
      _pollingTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPollingIfNeeded() {
    if (!widget.enablePolling) return;
    final status = widget.pipelineStatus?.toLowerCase() ?? '';
    final isRunning =
        status == 'planning' || status == 'pending' || status == 'started';

    if (isRunning) {
      if (_pollingTimer == null || !_pollingTimer!.isActive) {
        _pollingTimer = Timer.periodic(
          const Duration(milliseconds: 3000),
          (_) => _fetchLogs(),
        );
      }
    } else {
      _pollingTimer?.cancel();
    }
  }

  Future<void> _fetchLogs() async {
    if (widget.tripRequestId <= 0) return;
    try {
      final fetched = await ApiService.getAgentLogs(widget.tripRequestId);
      if (mounted) {
        setState(() {
          _logs = fetched;
        });
        widget.onLogsUpdated?.call(fetched);
      }
    } catch (_) {
      // Keep existing logs on temporary network hiccup
    }
  }

  bool get _hasFailureReason =>
      widget.failureReason?.trim().isNotEmpty ?? false;

  bool get _hasSuccessfulPlan =>
      !_hasFailureReason &&
      const {
        'awaitingapproval',
        'approved',
      }.contains(widget.pipelineStatus?.toLowerCase());

  List<Map<String, dynamic>> _latestAttemptLogs() {
    // REST snapshots and live events can arrive out of order. Use timestamps
    // with original order as a tie-breaker for legacy/missing timestamps.
    final ordered = _logs.indexed
        .where((entry) => entry.$2 is Map)
        .map((entry) => (entry.$1, Map<String, dynamic>.from(entry.$2 as Map)))
        .toList();
    ordered.sort((a, b) {
      final at = parseInstant(a.$2['timestamp']);
      final bt = parseInstant(b.$2['timestamp']);
      final byTime = (at ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        bt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    var start = 0;
    for (var i = 0; i < ordered.length; i++) {
      final step = ordered[i].$2['stepName']?.toString().toLowerCase();
      if (step == 'initializepipeline' ||
          step == 'requested hotel and transport changes' ||
          step == 'decomposeandallocatebudget' ||
          step == 'triggerretryoptimization') {
        start = i;
      }
    }
    return ordered.skip(start).map((entry) => entry.$2).toList();
  }

  List<Map<String, dynamic>> _getLogsForAgent(
    Map<String, dynamic> meta,
    List<Map<String, dynamic>> latestLogs,
  ) {
    final aliases = (meta['aliases'] as List<String>)
        .map((a) => a.toLowerCase())
        .toSet();
    final result = <Map<String, dynamic>>[];
    for (final raw in latestLogs) {
      final agentName = (raw['agentName'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(' ', '');
      if (aliases.contains(agentName)) {
        result.add(raw);
      }
    }
    return result;
  }

  Map<String, dynamic>? _decodeLogOutput(Map<String, dynamic> log) {
    final raw = log['output'] ?? log['outputData'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  bool _isAgentOutcomeFailure(Map<String, dynamic> log) {
    final status = (log['status'] ?? '').toString().toLowerCase();
    if (status.contains('failed')) return true;

    final output = _decodeLogOutput(log);
    if (output == null) return false;
    final outcome = (output['agent_outcome'] ?? output['agentOutcome'] ?? '')
        .toString()
        .toLowerCase();
    if (outcome == 'failed' || outcome == 'failure') return true;

    final errorCode = (output['error_code'] ?? output['errorCode'] ?? '')
        .toString()
        .toUpperCase();
    if (errorCode.startsWith('TRANSPORT_CATALOGUE_') ||
        errorCode == 'NO_VALID_ROOM' ||
        errorCode == 'TRANSPORT_SEARCH_INCOMPLETE') {
      return true;
    }

    // Compatibility with older logs written before BookingAgent emitted a
    // separate outcome row: a successful tool call with zero candidates is
    // not a successful agent result.
    final stepName = (log['stepName'] ?? '').toString().toLowerCase();
    if (stepName.contains('checked transport availability') &&
        output['available_transports'] is num &&
        (output['available_transports'] as num) <= 0) {
      return true;
    }
    if (stepName.contains('checked hotel availability') &&
        output['available_rooms'] is num &&
        (output['available_rooms'] as num) <= 0) {
      return true;
    }
    return false;
  }

  String _getAgentStatus(
    Map<String, dynamic> meta,
    List<Map<String, dynamic>> agentLogs,
  ) {
    final pipelineStatus = widget.pipelineStatus?.toLowerCase() ?? '';

    // A persisted proposal passed validation. It can arrive before its final
    // log snapshot, so historical failures must not override that result.
    // Failed revisions restore the old proposal with a failure reason and are
    // deliberately excluded here.
    if (_hasSuccessfulPlan) return 'Success';

    if (agentLogs.isNotEmpty) {
      final last = agentLogs.last;
      if (_isAgentOutcomeFailure(last)) return 'Failed';
      final status = (last['status'] ?? '').toString();
      if (status.toLowerCase() == 'success' ||
          status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'awaitingapproval') {
        return 'Success';
      }
      return status.isNotEmpty ? status : 'Success';
    }

    if (pipelineStatus == 'failed') {
      return 'NotStarted';
    }

    if (pipelineStatus == 'planning' || pipelineStatus == 'pending') {
      final stepNum = meta['stepNum'] as int;
      // If previous step finished, current is Running
      return stepNum == 1 ? 'Running' : 'NotStarted';
    }

    return 'NotStarted';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final latestLogs = _latestAttemptLogs();
    final statuses = [
      for (final meta in _agentMeta)
        _getAgentStatus(meta, _getLogsForAgent(meta, latestLogs)),
    ];
    final hasFailure =
        _hasFailureReason ||
        widget.pipelineStatus?.toLowerCase() == 'failed' ||
        statuses.contains('Failed');
    final isComplete = statuses.every((status) => status == 'Success');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16211C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasFailure
              ? const Color(0xFFFCA5A5)
              : isDark
              ? const Color(0xFF2E3D36)
              : const Color(0xFFE2E8E4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasFailure
                  ? const Color(0xFFFFF1F2)
                  : isDark
                  ? const Color(0xFF1E2D27)
                  : const Color(0xFFF5FAF7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hasFailure
                        ? const Color(0xFFFEE2E2)
                        : isDark
                        ? const Color(0xFF263C33)
                        : const Color(0xFFE2F3EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasFailure
                        ? Icons.error_outline_rounded
                        : Icons.psychology_outlined,
                    color: hasFailure
                        ? const Color(0xFFDC2626)
                        : AppColors.figmaDarkGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AI Planning Engine',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: hasFailure
                                    ? const Color(0xFF991B1B)
                                    : isDark
                                    ? Colors.white
                                    : const Color(0xFF123F32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFD4A346,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '4 AGENTS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF966C15),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFailure
                            ? 'We couldn’t complete the latest request'
                            : isComplete
                            ? 'Your latest itinerary is ready'
                            : 'Planning your journey',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: hasFailure
                              ? const Color(0xFFB91C1C)
                              : isDark
                              ? const Color(0xFF9EABA4)
                              : const Color(0xFF5A7067),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Global Failure Banner if failed
          if (_hasFailureReason)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planning update',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ApiService.safeAgentFailureMessage(
                            widget.failureReason,
                          ),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFFB91C1C),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // The 4 Agent Step Cards
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < _agentMeta.length; i++)
                  _buildAgentItem(meta: _agentMeta[i], status: statuses[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentItem({
    required Map<String, dynamic> meta,
    required String status,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuccess =
        status.toLowerCase() == 'success' ||
        status.toLowerCase() == 'completed' ||
        status.toLowerCase() == 'awaitingapproval';
    final isFailed = status.toLowerCase() == 'failed';
    final isRunning =
        status.toLowerCase() == 'running' ||
        status.toLowerCase() == 'started' ||
        status.toLowerCase() == 'in progress';

    Color badgeBg;
    Color badgeText;
    IconData statusIcon;

    if (isSuccess) {
      badgeBg = const Color(0xFFE2F3EB);
      badgeText = const Color(0xFF13684B);
      statusIcon = Icons.check_circle_rounded;
    } else if (isFailed) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFFDC2626);
      statusIcon = Icons.cancel_rounded;
    } else if (isRunning) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFB45309);
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      badgeBg = isDark ? const Color(0xFF26322D) : const Color(0xFFF1F4F2);
      badgeText = const Color(0xFF6B7280);
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2923) : const Color(0xFFFAFCFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFailed
              ? const Color(0xFFFCA5A5)
              : isSuccess
              ? const Color(0xFFA7E0C6)
              : isDark
              ? const Color(0xFF2E3D36)
              : const Color(0xFFE5ECE8),
        ),
      ),
      child: Column(
        children: [
          // Agent Row Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    meta['icon'] as IconData,
                    size: 16,
                    color: badgeText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Agent ${meta['stepNum']}: ${meta['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        (isSuccess ? meta['result'] : meta['role']) as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: const Color(0xFF6E7772),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 11, color: badgeText),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                status == 'NotStarted'
                                    ? 'NOT STARTED'
                                    : status.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: badgeText,
                                  letterSpacing: 0.3,
                                ),
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
          ),
        ],
      ),
    );
  }
}
