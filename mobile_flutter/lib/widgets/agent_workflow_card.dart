import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../app_constants.dart';
import '../services/api_service.dart';

/// 4-Agent Multi-Agent Workflow Card
/// Displays live execution status, logs, and outputs for:
/// 1. Coordinator Agent (Goals & Budget Allocation)
/// 2. Itinerary Agent (Activity Scheduling & Route)
/// 3. Booking Agent (Hotel & Transport Availability)
/// 4. Validation Agent (Commercial Rules & Approval Gate)
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
  // Keep the workflow compact by default; users can expand any agent to view
  // its persisted server output.
  final Set<String> _expandedAgents = <String>{};

  static const List<Map<String, dynamic>> _agentMeta = [
    {
      'key': 'CoordinatorAgent',
      'aliases': ['coordinator', 'coordinatoragent', 'coordinatorevaluator'],
      'name': 'Coordinator Agent',
      'role': 'Trip Goals & Budget Allocation',
      'icon': Icons.alt_route_rounded,
      'stepNum': 1,
    },
    {
      'key': 'ItineraryAgent',
      'aliases': ['itinerary', 'itineraryagent'],
      'name': 'Itinerary Agent',
      'role': 'Daily Schedule & Non-Overlapping Route',
      'icon': Icons.calendar_month_outlined,
      'stepNum': 2,
    },
    {
      'key': 'BookingAgent',
      'aliases': ['booking', 'bookingagent'],
      'name': 'Booking Agent',
      'role': 'Live Hotel & Transport Availability',
      'icon': Icons.hotel_outlined,
      'stepNum': 3,
    },
    {
      'key': 'ValidationAgent',
      'aliases': ['validation', 'validationagent'],
      'name': 'Validation Agent',
      'role': 'Commercial Rules & Human Approval Gate',
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

  List<Map<String, dynamic>> _getLogsForAgent(Map<String, dynamic> meta) {
    final aliases = (meta['aliases'] as List<String>)
        .map((a) => a.toLowerCase())
        .toSet();
    final result = <Map<String, dynamic>>[];
    for (final raw in _logs) {
      if (raw is Map) {
        final agentName = (raw['agentName'] ?? '')
            .toString()
            .toLowerCase()
            .replaceAll(' ', '');
        if (aliases.contains(agentName)) {
          result.add(Map<String, dynamic>.from(raw));
        }
      }
    }
    return result;
  }

  String _getAgentStatus(
    Map<String, dynamic> meta,
    List<Map<String, dynamic>> agentLogs,
  ) {
    final pipelineStatus = widget.pipelineStatus?.toLowerCase() ?? '';

    if (agentLogs.any(
      (l) => (l['status'] ?? '').toString().toLowerCase().contains('failed'),
    )) {
      return 'Failed';
    }

    if (agentLogs.isNotEmpty) {
      final last = agentLogs.last;
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

  String _formatLogContent(dynamic content) {
    if (content == null) return '';
    final s = content.toString().trim();
    if (s.isEmpty || s == 'null') return '';

    try {
      final decoded = json.decode(s);
      if (decoded is Map) {
        final buffer = StringBuffer();
        decoded.forEach((key, val) {
          final cleanKey = key.toString().replaceAll('_', ' ');
          final capitalizedKey = cleanKey.isEmpty
              ? ''
              : '${cleanKey[0].toUpperCase()}${cleanKey.substring(1)}';
          if (val is Map || val is List) {
            buffer.writeln('• $capitalizedKey: ${json.encode(val)}');
          } else {
            buffer.writeln('• $capitalizedKey: $val');
          }
        });
        return buffer.toString().trim();
      } else if (decoded is List) {
        return decoded.map((e) => '• ${e.toString()}').join('\n');
      }
    } catch (_) {
      // Return as plain text
    }

    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pipelineStatus = widget.pipelineStatus ?? 'Planning';
    final hasFailure =
        widget.failureReason != null ||
        pipelineStatus.toLowerCase() == 'failed' ||
        _logs.any(
          (l) =>
              (l is Map &&
              (l['status'] ?? '').toString().toLowerCase().contains('failed')),
        );

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
                            ? 'Agent execution encountered an issue'
                            : 'Orchestrating specialized travel agents',
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
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  color: isDark ? Colors.white70 : const Color(0xFF5A7067),
                  onPressed: _fetchLogs,
                  tooltip: 'Refresh Agent Logs',
                ),
              ],
            ),
          ),

          // Global Failure Banner if failed
          if (widget.failureReason != null && widget.failureReason!.isNotEmpty)
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
                          'Agent Execution Output / Error',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.failureReason!,
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
              children: _agentMeta.map((meta) {
                final agentLogs = _getLogsForAgent(meta);
                final status = _getAgentStatus(meta, agentLogs);
                final agentKey = meta['key'] as String;
                final isExpanded = _expandedAgents.contains(agentKey);

                return _buildAgentItem(
                  meta: meta,
                  status: status,
                  logs: agentLogs,
                  isExpanded: isExpanded,
                  onToggle: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedAgents.remove(agentKey);
                      } else {
                        _expandedAgents.add(agentKey);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentItem({
    required Map<String, dynamic> meta,
    required String status,
    required List<Map<String, dynamic>> logs,
    required bool isExpanded,
    required VoidCallback onToggle,
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
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          meta['role'] as String,
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
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF6E7772),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Logs & Agent Outputs
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE5ECE8)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: logs.isEmpty
                  ? Text(
                      isRunning
                          ? 'Agent is processing trip requirements...'
                          : 'Waiting for upstream pipeline stage...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF8A969B),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: logs.map((log) {
                        final stepName =
                            log['stepName']?.toString() ?? 'Reasoning Step';
                        final outputFormatted = _formatLogContent(
                          log['output'],
                        );
                        final inputFormatted = _formatLogContent(log['input']);
                        final stepStatus =
                            log['status']?.toString() ?? 'Success';
                        final timestamp = log['timestamp']?.toString();
                        String timeStr = '';
                        if (timestamp != null) {
                          try {
                            final dt = DateTime.parse(timestamp).toLocal();
                            timeStr = DateFormat('HH:mm:ss').format(dt);
                          } catch (_) {}
                        }

                        final stepFailed = stepStatus.toLowerCase() == 'failed';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: stepFailed
                                ? const Color(0xFFFFF5F5)
                                : isDark
                                ? const Color(0xFF131F19)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: stepFailed
                                  ? const Color(0xFFFEB2B2)
                                  : isDark
                                  ? const Color(0xFF263830)
                                  : const Color(0xFFEBEFEA),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    stepFailed
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    size: 13,
                                    color: stepFailed
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF13684B),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      stepName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: stepFailed
                                            ? const Color(0xFF991B1B)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFF8A969B),
                                      ),
                                    ),
                                ],
                              ),
                              if (outputFormatted.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Output / Decisions:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5A7067),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1B2822)
                                        : const Color(0xFFF7FAF8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    outputFormatted,
                                    style: GoogleFonts.firaCode(
                                      fontSize: 10,
                                      color: isDark
                                          ? const Color(0xFFD1DCD6)
                                          : const Color(0xFF2D3748),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                              if (stepFailed && inputFormatted.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Input context:',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                                Text(
                                  inputFormatted,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9.5,
                                    color: const Color(0xFF742A2A),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
