import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// AI Trip Request screen matching Figma frame 15 · AI Trip Request (node 7:11285)
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _destinationCtrl =
      TextEditingController(text: 'Sigiriya, Kandy, Ella & Mirissa');
  final _specialRequestsCtrl = TextEditingController(
    text: 'Quiet stays, vegetarian meals, easy-paced mornings',
  );

  String _dateRangeText = '12–18 Oct';
  int _travelers = 2;
  final double _budget = 1800;

  final Set<String> _selectedInterests = {
    'Culture',
    'Wildlife',
    'Beaches',
  };

  final List<Map<String, dynamic>> _interestOptions = [
    {'name': 'Culture', 'icon': Icons.account_balance_outlined},
    {'name': 'Wildlife', 'icon': Icons.pets_outlined},
    {'name': 'Tea country', 'icon': Icons.eco_outlined},
    {'name': 'Beaches', 'icon': Icons.waves_outlined},
    {'name': 'Food', 'icon': Icons.restaurant_outlined},
  ];

  bool _isGenerating = false;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateItinerary() async {
    setState(() => _isGenerating = true);

    try {
      final promptText =
          'Destination: ${_destinationCtrl.text.trim()}, Interests: ${_selectedInterests.join(", ")}, Requests: ${_specialRequestsCtrl.text.trim()}';

      final start = DateTime.now().add(const Duration(days: 14));
      final end = start.add(const Duration(days: 6));

      await ApiService.createTripRequest({
        'destinationId': null,
        'rawRequestText': promptText,
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
        'travellerCount': _travelers,
        'budgetCeiling': _budget,
        'currency': 'USD',
      });
    } catch (_) {
      // Offline fallback handling
    }

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pushNamed(context, '/itinerary');
      }
    }
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Dates and Travelers Row ──
              Row(
                children: [
                  // Date Range
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
                          onTap: () async {
                            final now = DateTime.now();
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (range != null) {
                              setState(() {
                                _dateRangeText =
                                    '${range.start.day}–${range.end.day} Oct';
                              });
                            }
                          },
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
                                Text(
                                  _dateRangeText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF17211D),
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
                                child: const Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: AppColors.figmaDarkGreen,
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
                                  setState(() => _travelers++);
                                },
                                child: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.figmaDarkGreen,
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

              // ── Budget Heading & Slider ──
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
                    '\$1,400 – \$2,200',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF123F32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E7E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.figmaGold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
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

              // ── Agent Workspace Panel ──
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
                        Text(
                          'Live',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2F7057),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 2x2 Agent Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.alt_route,
                            name: 'Planning Agent',
                            desc: 'Building your route',
                            status: _isGenerating ? 'Synthesizing...' : 'Working',
                            statusColor: const Color(0xFF3676A8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.hotel_outlined,
                            name: 'Hotel Agent',
                            desc: 'Matching verified stays',
                            status: 'Ready',
                            statusColor: const Color(0xFF267A55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.train_outlined,
                            name: 'Transport Agent',
                            desc: 'Comparing island travel',
                            status: 'Queued',
                            statusColor: const Color(0xFFB36A16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildAgentCard(
                            icon: Icons.verified_outlined,
                            name: 'Review Agent',
                            desc: 'Quality & budget check',
                            status: 'Queued',
                            statusColor: const Color(0xFF6E7772),
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
        title: Text(
          'Multi-Agent Trip Engine',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.figmaDarkGreen,
          ),
        ),
        content: Text(
          'Our AI system orchestrates 4 specialized travel agents: Planning Agent maps routes, Hotel Agent books boutique stays, Transport Agent organizes vehicles, and Review Agent validates safety and budget.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
