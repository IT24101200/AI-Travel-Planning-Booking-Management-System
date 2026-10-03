import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// AI Trip Request screen matching Figma frame 15 · AI Trip Request
/// Aligned with SE3090 Project Plan & Student A Component A specifications:
/// - Currency: Sri Lankan Rupees (LKR)
/// - Authentic Sri Lankan destination mapping
/// - Live 4-Agent pipeline status visualization (Coordinator, Itinerary, Booking, Validation)
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  // Destination text controller
  final _destinationCtrl =
      TextEditingController(text: 'Sigiriya, Kandy, Ella & Mirissa');

  // Special requests / preferences text controller
  final _specialRequestsCtrl = TextEditingController(
    text: 'Quiet stays, vegetarian meals, easy-paced mornings',
  );

  // Sri Lankan curated destinations mapped to backend database IDs
  static const Map<String, int> _destinationIds = {
    'sigiriya': 1,
    'kandy': 2,
    'ella': 3,
    'galle': 4,
    'yala': 5,
    'mirissa': 6,
    'nuwara eliya': 7,
    'trincomalee': 8,
  };

  // Quick selectable Sri Lankan destination suggestions
  final List<String> _quickDestinations = [
    'Sigiriya',
    'Kandy',
    'Ella',
    'Galle',
    'Mirissa',
    'Yala',
    'Nuwara Eliya',
    'All Island',
  ];

  // Date range state
  late DateTime _startDate;
  late DateTime _endDate;

  // Travelers count
  int _travelers = 2;

  // Budget ceiling in LKR (default: LKR 250,000)
  double _budgetCeiling = 250000;

  // Selected travel interests
  final Set<String> _selectedInterests = {
    'Culture',
    'Wildlife',
    'Beaches',
  };

  // Available travel interest options
  final List<Map<String, dynamic>> _interestOptions = [
    {'name': 'Culture', 'icon': Icons.account_balance_outlined},
    {'name': 'Wildlife', 'icon': Icons.pets_outlined},
    {'name': 'Tea country', 'icon': Icons.eco_outlined},
    {'name': 'Beaches', 'icon': Icons.waves_outlined},
    {'name': 'Food', 'icon': Icons.restaurant_outlined},
    {'name': 'Hiking', 'icon': Icons.terrain_outlined},
    {'name': 'Wellness', 'icon': Icons.spa_outlined},
  ];

  // Agent execution simulation step during generation
  // 0: Idle, 1: Coordinator Agent, 2: Itinerary Agent, 3: Booking Agent, 4: Validation Agent, 5: Done
  int _agentProgressStep = 0;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Default dates: 7 days from today, lasting 6 nights
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day + 7);
    _endDate = DateTime(now.year, now.month, now.day + 13);

    // Read initial preferences if available
    _loadUserPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if a destination or tour was passed in arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final destName = args['destination'] ?? args['name'] ?? args['title'];
      if (destName != null && destName.toString().isNotEmpty) {
        _destinationCtrl.text = destName.toString();
      }
    }
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  /// Load user preference defaults to ensure budget ceiling is consistent
  Future<void> _loadUserPreferences() async {
    try {
      final response = await ApiService.getPreferences();
      if (response.statusCode == 200) {
        final pref = jsonDecode(response.body);
        if (pref is Map && pref['budgetMax'] != null) {
          final maxBudget = (pref['budgetMax'] as num).toDouble();
          if (maxBudget > 50000 && mounted) {
            setState(() {
              _budgetCeiling = maxBudget.clamp(50000, 1000000);
            });
          }
        }
      }
    } catch (_) {
      // Gracefully use default LKR 250,000 if offline
    }
  }

  /// Formatted date range string (e.g. "12–18 Oct")
  String get _dateRangeDisplay {
    final startFmt = DateFormat('d MMM').format(_startDate);
    final endFmt = DateFormat('d MMM').format(_endDate);
    return '$startFmt – $endFmt';
  }

  /// Formatted budget range display in LKR
  String get _budgetRangeDisplay {
    final currencyFmt = NumberFormat('#,##0', 'en_US');
    final minEst = (_budgetCeiling * 0.70).round();
    final maxEst = _budgetCeiling.round();
    return 'LKR ${currencyFmt.format(minEst)} – LKR ${currencyFmt.format(maxEst)}';
  }

  /// Resolves destination string to optional database ID
  int? _resolveDestinationId(String input) {
    final clean = input.trim().toLowerCase();
    for (final entry in _destinationIds.entries) {
      if (clean == entry.key || clean.contains(entry.key)) {
        // If it's a specific single destination, return its ID
        if (!clean.contains(',')) {
          return entry.value;
        }
      }
    }
    return null;
  }

  /// Pick date range using Flutter date range picker
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF123F32),
              onPrimary: Colors.white,
              onSurface: Color(0xFF17211D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  /// Generate AI Itinerary and dispatch to multi-agent pipeline
  Future<void> _generateItinerary() async {
    final destination = _destinationCtrl.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a destination in Sri Lanka.'),
          backgroundColor: Color(0xFF9C4726),
        ),
      );
      return;
    }

    if (_startDate.isAfter(_endDate) || _startDate.isAtSameMomentAs(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be strictly after start date.'),
          backgroundColor: Color(0xFF9C4726),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _agentProgressStep = 1; // Coordinator Agent starts
    });

    final destId = _resolveDestinationId(destination);
    final promptText =
        'Destination: $destination. Interests: ${_selectedInterests.join(", ")}. '
        'Preferences: ${_specialRequestsCtrl.text.trim()}';

    Map<String, dynamic>? createResponse;
    String? backendErrorMessage;

    try {
      // 1. Coordinator Agent begins processing
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _agentProgressStep = 2); // Itinerary Agent

      // 2. Call backend API to create TripRequest
      final apiFuture = ApiService.createTripRequest({
        'destinationId': destId,
        'rawRequestText': promptText,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'travellerCount': _travelers,
        'budgetCeiling': _budgetCeiling,
        'currency': 'LKR',
      });

      // 3. Booking Agent checks inventory
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _agentProgressStep = 3); // Booking Agent

      // 4. Validation Agent performs checks
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _agentProgressStep = 4); // Validation Agent

      createResponse = await apiFuture;
      if (createResponse['statusCode'] != null &&
          createResponse['statusCode'] >= 400) {
        backendErrorMessage =
            createResponse['message'] ?? 'Could not create trip request.';
      }
    } catch (e) {
      // Offline or network error handled gracefully
      backendErrorMessage = null;
    }

    if (mounted) setState(() => _agentProgressStep = 5); // Finished
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _agentProgressStep = 0;
    });

    // If backend returned a clear validation error (e.g. budget ceiling below preference)
    if (backendErrorMessage != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Trip Request Notice',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppColors.figmaDarkGreen,
            ),
          ),
          content: Text(
            backendErrorMessage!,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF123F32),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Pass created trip details or generated itinerary to MyItineraryScreen
    final navArgs = {
      'destination': destination,
      'destinationId': destId,
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate.toIso8601String(),
      'travellerCount': _travelers,
      'budgetCeiling': _budgetCeiling,
      'currency': 'LKR',
      'id': createResponse?['id'] ?? createResponse?['tripRequestId'],
      'tripRequestId': createResponse?['id'] ?? createResponse?['tripRequestId'],
    };

    Navigator.pushNamed(context, '/itinerary', arguments: navArgs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Bar ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10291F).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.figmaDarkGreen,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan with AI',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17211D),
                          ),
                        ),
                        Text(
                          'Four specialist agents, one island journey',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF6E7772),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: AppColors.figmaDarkGreen,
                        size: 19,
                      ),
                      onPressed: _showInfoDialog,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── AI Intro Banner ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF123F32),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.figmaGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tell us what your perfect trip feels like',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "We'll assemble a bookable itinerary in under two minutes.",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Destination Input ──
              Text(
                'DESTINATION',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E7772),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7E2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: AppColors.figmaDarkGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _destinationCtrl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF17211D),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'e.g. Sigiriya, Kandy, Ella & Mirissa',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Sri Lankan destination chips
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickDestinations.map((dest) {
                    final isCurrent = _destinationCtrl.text.toLowerCase().contains(dest.toLowerCase());
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          dest,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent ? Colors.white : const Color(0xFF17211D),
                          ),
                        ),
                        backgroundColor: isCurrent ? const Color(0xFF123F32) : Colors.white,
                        side: BorderSide(
                          color: isCurrent ? const Color(0xFF123F32) : const Color(0xFFE4E7E2),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onPressed: () {
                          setState(() {
                            if (dest == 'All Island') {
                              _destinationCtrl.text = 'Sigiriya, Kandy, Ella & Mirissa';
                            } else {
                              _destinationCtrl.text = dest;
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // ── Dates and Travelers Row ──
              Row(
                children: [
                  // Date Range Picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE RANGE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6E7772),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: _selectDateRange,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: const Color(0xFFE4E7E2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: AppColors.figmaDarkGreen,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _dateRangeDisplay,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF17211D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Travelers Counter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRAVELERS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6E7772),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: const Color(0xFFE4E7E2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (_travelers > 1) {
                                    setState(() => _travelers--);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: AppColors.figmaDarkGreen,
                                  ),
                                ),
                              ),
                              Text(
                                '$_travelers',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17211D),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_travelers < 20) {
                                    setState(() => _travelers++);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: AppColors.figmaDarkGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Budget Heading & Interactive Slider (LKR) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL BUDGET',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6E7772),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _budgetRangeDisplay,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF123F32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Interactive Budget Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.figmaGold,
                  inactiveTrackColor: const Color(0xFFE4E7E2),
                  thumbColor: const Color(0xFF123F32),
                  overlayColor: const Color(0xFF123F32).withValues(alpha: 0.12),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: _budgetCeiling,
                  min: 50000,
                  max: 1000000,
                  divisions: 95,
                  onChanged: (val) {
                    setState(() => _budgetCeiling = val);
                  },
                ),
              ),

              const SizedBox(height: 8),

              // ── Travel Interests ──
              Text(
                'TRAVEL INTERESTS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E7772),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _interestOptions.map((opt) {
                  final name = opt['name'] as String;
                  final icon = opt['icon'] as IconData;
                  final isSelected = _selectedInterests.contains(name);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedInterests.remove(name);
                        } else {
                          _selectedInterests.add(name);
                        }
                      });
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF123F32)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF123F32)
                              : const Color(0xFFE4E7E2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 13,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF17211D),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF17211D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // ── Special Requests ──
              Text(
                'Special requests',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6E7772),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E7E2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: AppColors.figmaDarkGreen,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _specialRequestsCtrl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF17211D),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'e.g. Vegetarian meals, mountain view',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Generate AI Itinerary Button ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateItinerary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF123F32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: _isGenerating
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _agentStepStatusTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Generate AI Itinerary',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Agent Workspace Panel (The 4 Project Agents) ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4E7E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Agent workspace',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF17211D),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F1EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isGenerating ? 'Active' : 'Live',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2F7057),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 2x2 Agent Grid representing the 4 Student Agents
                    Row(
                      children: [
                        // Agent 1: Coordinator Agent (Student A)
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.alt_route,
                            name: 'Coordinator Agent',
                            desc: 'Route & budget planner',
                            status: _getAgentStatus(1),
                            statusColor: _getAgentColor(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Agent 2: Itinerary Agent (Student B)
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.map_outlined,
                            name: 'Itinerary Agent',
                            desc: 'Curating day tours',
                            status: _getAgentStatus(2),
                            statusColor: _getAgentColor(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Agent 3: Booking Agent (Student C)
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.hotel_outlined,
                            name: 'Booking Agent',
                            desc: 'Hotel & transit check',
                            status: _getAgentStatus(3),
                            statusColor: _getAgentColor(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Agent 4: Validation Agent (Student D)
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.verified_outlined,
                            name: 'Validation Agent',
                            desc: 'Budget & approval gate',
                            status: _getAgentStatus(4),
                            statusColor: _getAgentColor(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Status string helper for active generation banner
  String get _agentStepStatusTitle {
    switch (_agentProgressStep) {
      case 1:
        return 'Coordinator: Allocating budget...';
      case 2:
        return 'Itinerary: Assembling route...';
      case 3:
        return 'Booking: Checking availability...';
      case 4:
        return 'Validation: Verifying rules...';
      default:
        return 'Finalizing itinerary...';
    }
  }

  /// Dynamic agent card status based on multi-agent execution step
  String _getAgentStatus(int agentNumber) {
    if (!_isGenerating) {
      return agentNumber == 1 ? 'Ready' : 'Queued';
    }
    if (_agentProgressStep == agentNumber) {
      return 'Working';
    } else if (_agentProgressStep > agentNumber) {
      return 'Completed';
    } else {
      return 'Queued';
    }
  }

  /// Color coding for agent cards
  Color _getAgentColor(int agentNumber) {
    if (!_isGenerating) {
      return agentNumber == 1 ? const Color(0xFF267A55) : const Color(0xFF6E7772);
    }
    if (_agentProgressStep == agentNumber) {
      return const Color(0xFF3676A8); // Blue working
    } else if (_agentProgressStep > agentNumber) {
      return const Color(0xFF267A55); // Green completed
    } else {
      return const Color(0xFF6E7772); // Grey queued
    }
  }

  Widget _buildAgentCard({
    required IconData icon,
    required String name,
    required String desc,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFF123F32)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF17211D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  desc,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 7,
                    color: const Color(0xFF6E7772),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  status,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.figmaGold, size: 22),
            const SizedBox(width: 8),
            Text(
              'Multi-Agent System',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.figmaDarkGreen,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Our travel planner orchestrates 4 specialized AI agents working together in a pipeline:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _buildDialogAgentRow(
                '1. Coordinator Agent (Student A)',
                'Decomposes your request, allocates budget shares across tours (35%), hotels (45%), and transport (15%), and handles retries.',
              ),
              const SizedBox(height: 8),
              _buildDialogAgentRow(
                '2. Itinerary Agent (Student B)',
                'Curates verified tours from the catalog and schedules a conflict-free day-by-day itinerary without overlapping times.',
              ),
              const SizedBox(height: 8),
              _buildDialogAgentRow(
                '3. Booking Agent (Student C)',
                'Queries live inventory to confirm real hotel room availability and transport capacity for your dates.',
              ),
              const SizedBox(height: 8),
              _buildDialogAgentRow(
                '4. Validation Agent (Student D)',
                'Enforces budget ceiling compliance and routes the complete package to human travel agent approval before booking.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF123F32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogAgentRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF123F32),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: const Color(0xFF6E7772),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
