import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

/// AI Trip Request screen matching Figma Dev Mode (15 · AI Trip Request).
/// Allows the customer to specify destinations, dates, travelers, editable budget
/// in LKR with tier chips and slider, travel interests, pace, and special requests.
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _destinationCtrl = TextEditingController(text: 'Sigiriya, Kandy, Ella & Mirissa');
  final _specialRequestsCtrl = TextEditingController(
      text: 'Quiet stays, vegetarian meals, easy-paced mornings');

  int _travelers = 2;
  DateTime _startDate = DateTime.now().add(const Duration(days: 10));
  DateTime _endDate = DateTime.now().add(const Duration(days: 17));

  // Budget settings in LKR
  double _budgetMin = 60000;
  double _budgetMax = 150000;
  String _selectedTier = 'Standard';
  String _selectedPace = 'Balanced';

  bool _loading = false;

  final Set<String> _selectedInterests = {
    'Culture',
    'Wildlife',
    'Beaches',
  };

  final List<Map<String, dynamic>> _interestChips = [
    {'name': 'Culture', 'icon': Icons.account_balance_outlined},
    {'name': 'Wildlife', 'icon': Icons.pets_outlined},
    {'name': 'Tea country', 'icon': Icons.eco_outlined},
    {'name': 'Beaches', 'icon': Icons.waves_outlined},
    {'name': 'Food', 'icon': Icons.restaurant_outlined},
    {'name': 'Adventure', 'icon': Icons.hiking_outlined},
    {'name': 'Ayurveda', 'icon': Icons.spa_outlined},
  ];

  final List<Map<String, dynamic>> _budgetTiers = [
    {
      'label': 'Economy',
      'icon': Icons.backpack_outlined,
      'min': 30000.0,
      'max': 60000.0,
      'desc': 'Hostels & guesthouses',
    },
    {
      'label': 'Standard',
      'icon': Icons.hotel_outlined,
      'min': 60000.0,
      'max': 150000.0,
      'desc': '3-star hotels & boutique stays',
    },
    {
      'label': 'Luxury',
      'icon': Icons.diamond_outlined,
      'min': 150000.0,
      'max': 300000.0,
      'desc': '4/5-star luxury resorts',
    },
    {
      'label': 'Custom',
      'icon': Icons.tune,
      'min': 20000.0,
      'max': 500000.0,
      'desc': 'Custom slider & input',
    },
  ];

  final List<String> _quickDestinations = [
    'Sigiriya & Kandy',
    'Ella & Nuwara Eliya',
    'Galle & Mirissa',
    'Yala Safari',
    'Trincomalee',
  ];

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  /// Opens calendar picker to select trip start and end dates
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0E382C),
              onPrimary: Colors.white,
              onSurface: Color(0xFF08201A),
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

  /// Generates AI itinerary by submitting trip request to backend
  Future<void> _generateItinerary() async {
    setState(() {
      _loading = true;
    });

    try {
      await ApiService.createTripRequest({
        'destinationId': null,
        'rawRequestText':
            '${_destinationCtrl.text}. Pace: $_selectedPace. Interests: ${_selectedInterests.join(', ')}. Notes: ${_specialRequestsCtrl.text}',
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'travellerCount': _travelers,
        'budgetCeiling': _budgetMax,
        'currency': 'LKR',
      });
    } catch (_) {
      // Continue to itinerary in demo/offline mode
    }

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.pushNamed(context, '/my-itinerary');
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = _endDate.difference(_startDate).inDays;
    final dateDisplay =
        '${DateFormat('dd MMM').format(_startDate)} – ${DateFormat('dd MMM').format(_endDate)} ($durationDays days)';

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Row ──
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan with AI',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Four specialist agents, one island journey',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEDECE4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.info_outline, color: Color(0xFF1E1E1E), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Intro Green Banner
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF134035),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4A346),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tell us what your perfect trip feels like',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'We\'ll assemble a bookable itinerary in under two minutes.',
                                  style: TextStyle(
                                    color: Color(0xFFB8D3C8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Destination Field
                    const Text(
                      'Destination',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDECE4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFF8A9E96), size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _destinationCtrl,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF08201A),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter cities or regions in Sri Lanka...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Quick Destination Suggestions
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickDestinations.map((route) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_destinationCtrl.text.isEmpty) {
                                _destinationCtrl.text = route;
                              } else if (!_destinationCtrl.text.contains(route)) {
                                _destinationCtrl.text += ', $route';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEDECE4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 11, color: Color(0xFF0E382C)),
                                const SizedBox(width: 4),
                                Text(
                                  route,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0E382C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // Date Range & Travelers Row
                    Row(
                      children: [
                        // Interactive Date Range Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DATE RANGE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: _pickDateRange,
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEDECE4)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          color: Color(0xFF8A9E96), size: 17),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dateDisplay,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF08201A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Travelers Stepper
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TRAVELERS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEDECE4)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      color: const Color(0xFF8A9E96),
                                      onPressed: () {
                                        if (_travelers > 1) {
                                          setState(() => _travelers--);
                                        }
                                      },
                                    ),
                                    Text(
                                      '$_travelers',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF08201A),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      color: const Color(0xFF08201A),
                                      onPressed: () {
                                        setState(() => _travelers++);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Fully Editable Total Budget Section in LKR ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'TOTAL BUDGET (LKR)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'LKR ${NumberFormat('#,##0').format(_budgetMin)} – ${NumberFormat('#,##0').format(_budgetMax)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E382C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '~LKR ${NumberFormat('#,##0').format((_budgetMin / _travelers).round())} – ${NumberFormat('#,##0').format((_budgetMax / _travelers).round())} per person ($_travelers travelers)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A9E96),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Budget Tier Option Chips
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _budgetTiers.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final tier = _budgetTiers[index];
                          final isSel = _selectedTier == tier['label'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTier = tier['label'] as String;
                                if (_selectedTier != 'Custom') {
                                  _budgetMin = tier['min'] as double;
                                  _budgetMax = tier['max'] as double;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFD4A346) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSel ? const Color(0xFFD4A346) : const Color(0xFFEDECE4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tier['icon'] as IconData,
                                    size: 14,
                                    color: isSel ? const Color(0xFF1A1A1A) : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    tier['label'] as String,
                                    style: TextStyle(
                                      color: isSel ? const Color(0xFF1A1A1A) : const Color(0xFF08201A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Interactive Budget Range Slider
                    RangeSlider(
                      values: RangeValues(_budgetMin, _budgetMax),
                      min: 20000,
                      max: 500000,
                      divisions: 96,
                      activeColor: const Color(0xFFD4A346),
                      inactiveColor: const Color(0xFFEDECE4),
                      labels: RangeLabels(
                        'LKR ${NumberFormat('#,##0').format(_budgetMin)}',
                        'LKR ${NumberFormat('#,##0').format(_budgetMax)}',
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _budgetMin = (values.start / 1000).round() * 1000.0;
                          _budgetMax = (values.end / 1000).round() * 1000.0;
                          _selectedTier = 'Custom';
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Trip Pace Option
                    const Text(
                      'TRIP PACE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Relaxed', 'Balanced', 'Action-Packed'].map((pace) {
                        final isSel = _selectedPace == pace;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPace = pace),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF0E382C) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  pace,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : const Color(0xFF08201A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Travel Interests
                    const Text(
                      'TRAVEL INTERESTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _interestChips.map((chip) {
                        final name = chip['name'] as String;
                        final icon = chip['icon'] as IconData;
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF0E382C)),
                                const SizedBox(width: 6),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF08201A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Special Requests Field
                    const Text(
                      'Special requests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDECE4)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Color(0xFF8A9E96), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _specialRequestsCtrl,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF08201A),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Dietary preferences, accessibility, special occasions...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Generate AI Itinerary Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _generateItinerary,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome, color: Color(0xFFD4A346), size: 20),
                        label: Text(
                          _loading ? 'Generating Your Itinerary...' : 'Generate AI Itinerary',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E382C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Agent Workspace Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEDECE4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Agent workspace',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF08201A),
                                ),
                              ),
                              Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF13684B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildAgentCard(
                                icon: Icons.alt_route,
                                name: 'Planning Agent',
                                task: 'Building your route',
                                status: 'Working',
                                statusColor: const Color(0xFF1D6F8A),
                              ),
                              const SizedBox(width: 10),
                              _buildAgentCard(
                                icon: Icons.apartment_outlined,
                                name: 'Hotel Agent',
                                task: 'Matching verified stays',
                                status: 'Ready',
                                statusColor: const Color(0xFF13684B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildAgentCard(
                                icon: Icons.directions_subway_outlined,
                                name: 'Transport Agent',
                                task: 'Comparing island travel',
                                status: 'Queued',
                                statusColor: const Color(0xFFB27D26),
                              ),
                              const SizedBox(width: 10),
                              _buildAgentCard(
                                icon: Icons.verified_user_outlined,
                                name: 'Review Agent',
                                task: 'Quality & budget check',
                                status: 'Queued',
                                statusColor: const Color(0xFFB27D26),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard({
    required IconData icon,
    required String name,
    required String task,
    required String status,
    required Color statusColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF9F4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDECE4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFAF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, color: const Color(0xFF13684B), size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF08201A),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              task,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8A9E96),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
