import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Serendib Verdant AI Trip Request Screen.
/// Multi-agent orchestration pipeline with destination selector, date range picker,
/// interactive traveler counter, budget slider, expedition interest chips, and custom prompt.
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTextCtrl = TextEditingController();

  List<dynamic> _destinations = [];
  int? _selectedDestinationId;
  String _selectedDestinationName = 'Sigiriya';
  DateTime? _startDate;
  DateTime? _endDate;
  int _travelers = 2;
  double _budget = 1250;
  final String _currency = 'USD';

  final Set<String> _selectedInterests = {
    'Heritage & Temples',
    'Scenic Trains & Tea',
    'Wildlife Safari',
  };

  final List<Map<String, dynamic>> _interestOptions = [
    {'name': 'Heritage & Temples', 'icon': Icons.temple_buddhist},
    {'name': 'Scenic Trains & Tea', 'icon': Icons.train},
    {'name': 'Wildlife Safari', 'icon': Icons.pets},
    {'name': 'Beaches & Surf', 'icon': Icons.surfing},
    {'name': 'Ayurveda & Wellness', 'icon': Icons.spa},
    {'name': 'Hiking & Adventure', 'icon': Icons.hiking},
    {'name': 'Street Food & Spices', 'icon': Icons.ramen_dining},
  ];

  bool _loading = false;
  bool _loadingDestinations = true;
  String? _error;
  String? _success;
  int? _createdTripId;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().add(const Duration(days: 7));
    _endDate = DateTime.now().add(const Duration(days: 13));
    _loadDestinations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final name = args['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        _requestTextCtrl.text =
            'I want to experience $name with guided tours, boutique eco-stays and comfortable private transit.';
        _selectedDestinationName = name;
      }
    }
  }

  /// Load available destinations from backend API
  Future<void> _loadDestinations() async {
    try {
      final list = await ApiService.getDestinations();
      if (mounted) {
        setState(() {
          _destinations = list;
          _loadingDestinations = false;
          if (_destinations.isNotEmpty && _selectedDestinationId == null) {
            _selectedDestinationId = _destinations.first['id'];
            _selectedDestinationName =
                _destinations.first['name'] ?? 'Sigiriya';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDestinations = false);
    }
  }

  /// Pick departure or return date
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now().add(const Duration(days: 7)))
        : (_endDate ?? DateTime.now().add(const Duration(days: 13)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.jungle600,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 6));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Submit trip request to multi-agent backend pipeline
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select travel window dates');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'Return date must be after departure date');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final promptText = _requestTextCtrl.text.trim().isEmpty
          ? 'Tailored trip to $_selectedDestinationName focusing on ${_selectedInterests.join(", ")}'
          : _requestTextCtrl.text.trim();

      final result = await ApiService.createTripRequest({
        'destinationId': _selectedDestinationId,
        'rawRequestText': promptText,
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'travellerCount': _travelers,
        'budgetCeiling': _budget,
        'currency': _currency,
      });

      if (!mounted) return;

      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        setState(() {
          _createdTripId = result['id'] is int
              ? result['id']
              : int.tryParse(result['id']?.toString() ?? '');
          _success =
              'Trip request submitted! 4 AI Agents are now synthesizing your custom itinerary, eco-stays & scenic transit.';
        });
      } else {
        setState(() {
          _error = result['message'] ??
              'Failed to submit trip request. Please try again.';
        });
      }
    } catch (_) {
      setState(
        () => _error = 'Unable to reach backend API. Check network connection.',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toggleInterest(String name) {
    setState(() {
      if (_selectedInterests.contains(name)) {
        if (_selectedInterests.length > 1) {
          _selectedInterests.remove(name);
        }
      } else {
        _selectedInterests.add(name);
      }
    });
  }

  @override
  void dispose() {
    _requestTextCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewImage = AppDestinations.getImageForDestination(
      _selectedDestinationName,
    );

    int tripDays = 7;
    if (_startDate != null && _endDate != null) {
      tripDays = _endDate!.difference(_startDate!).inDays;
      if (tripDays < 1) tripDays = 1;
    }

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: const Text('Trip Request'),
        backgroundColor: AppColors.ivory,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Block ──
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.psychology,
                              size: 20,
                              color: AppColors.jungle600,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AUTONOMOUS MULTI-AGENT SYSTEM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.sand700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI Trip Planner',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Let our 4 specialized agents craft your tailored Sri Lankan journey in real-time.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Scenic Destination Preview Banner ──
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(
                          imageUrl: previewImage,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.jungle900.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppColors.sand400, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Exploring Ceylon: $_selectedDestinationName Circuit',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Multi-Agent Real-time Status Panel ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.hub,
                                  color: AppColors.jungle600,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Multi-Agent System Pipeline',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      'Coordinated Ceylon synthesis',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.inkTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.sand100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.sand500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Running Live',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.sand700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Agent Pipeline Steps
                        _buildAgentStep(
                          icon: Icons.check_circle,
                          title: '1. Planning Agent',
                          subtitle: 'Itinerary & daily checkpoints drafted',
                          status: 'Ready',
                          statusColor: AppColors.jungle600,
                          isLast: false,
                        ),
                        _buildAgentStep(
                          icon: Icons.check_circle,
                          title: '2. Hotel Agent',
                          subtitle: 'Curated eco-villas in Sigiriya & Ella matched',
                          status: 'Ready',
                          statusColor: AppColors.jungle600,
                          isLast: false,
                        ),
                        _buildAgentStep(
                          icon: Icons.sync,
                          title: '3. Transport Agent',
                          subtitle: 'Reserving scenic train & AC hybrid vehicle',
                          status: 'Active',
                          statusColor: AppColors.sand700,
                          isActive: true,
                          isLast: false,
                        ),
                        _buildAgentStep(
                          icon: Icons.hourglass_empty,
                          title: '4. Review Agent',
                          subtitle:
                              'Validating budget (\$$budgetFormatted) and schedule feasibility',
                          status: 'Queued',
                          statusColor: AppColors.inkTertiary,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status feedback message banners
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.coral500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.coral500.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.coral500, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.coral500, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_success != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.leaf50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.leaf200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: AppColors.jungle600, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Trip Planning Initiated!',
                                style: TextStyle(
                                  color: AppColors.jungle800,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _success!,
                            style: const TextStyle(
                                color: AppColors.inkSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/trip-history',
                                  arguments: {
                                    'initialTab': 1,
                                    'openTripId': _createdTripId,
                                  },
                                );
                              },
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Track AI Agent Progress Live'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.jungle600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Form Area ──

                  // 1. Destination Input Field
                  const Text(
                    'Target Destinations (Sri Lanka Circuit)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        _loadingDestinations
                            ? const LinearProgressIndicator(
                                color: AppColors.jungle600)
                            : DropdownButtonFormField<int>(
                                initialValue: _selectedDestinationId,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  prefixIcon: Icon(
                                    Icons.location_on,
                                    color: AppColors.jungle600,
                                    size: 20,
                                  ),
                                ),
                                items: _destinations.map<DropdownMenuItem<int>>((d) {
                                  return DropdownMenuItem<int>(
                                    value: d['id'],
                                    child: Text(
                                      '${d['name']} — ${d['country'] ?? 'Sri Lanka'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedDestinationId = v;
                                    final match = _destinations.firstWhere(
                                      (d) => d['id'] == v,
                                      orElse: () => null,
                                    );
                                    if (match != null) {
                                      _selectedDestinationName =
                                          match['name'] ?? '';
                                    }
                                  });
                                },
                              ),
                        const SizedBox(height: 8),
                        // Quick destination tags
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPillTag('Sigiriya Rock'),
                              const SizedBox(width: 6),
                              _buildPillTag('Temple of the Tooth'),
                              const SizedBox(width: 6),
                              _buildPillTag('Nine Arches Bridge'),
                              const SizedBox(width: 6),
                              _buildPillTag('Galle Fort'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Date Range Picker & Travelers Counter
                  Row(
                    children: [
                      // Date Range
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TRAVEL WINDOW',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: AppColors.inkTertiary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_month,
                                      color: AppColors.jungle600,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _startDate != null
                                      ? '${_startDate!.month}/${_startDate!.day} - ${_endDate?.month}/${_endDate?.day}'
                                      : 'Select Dates',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  '$tripDays Days & ${tripDays > 1 ? tripDays - 1 : 1} Nights',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.jungle600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Travelers Counter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TRAVELERS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: AppColors.inkTertiary,
                                    ),
                                  ),
                                  Icon(
                                    Icons.group,
                                    color: AppColors.jungle600,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$_travelers ${_travelers == 1 ? "Adult" : "Adults"}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (_travelers > 1) {
                                            setState(() => _travelers--);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.leaf50,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '-',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.jungle700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () {
                                          if (_travelers < 12) {
                                            setState(() => _travelers++);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.jungle600,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '+',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Budget Preference Slider
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ESTIMATED BUDGET',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.inkTertiary,
                                  ),
                                ),
                                Text(
                                  'Per Person (excl. flights)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '\$$budgetFormatted USD',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.sand700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _budget,
                          min: 400,
                          max: 4500,
                          divisions: 41,
                          activeColor: AppColors.jungle600,
                          inactiveColor: AppColors.leaf100,
                          onChanged: (val) {
                            setState(() => _budget = val);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Budget\n\$500',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.inkTertiary,
                              ),
                            ),
                            Text(
                              'Comfort\n\$1,500',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.jungle600,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Luxury\n\$3,500+',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.sand700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Expedition Interests (Selectable chips)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expedition Interests',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Select at least 2 (${_selectedInterests.length} chosen)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestOptions.map((opt) {
                      final name = opt['name'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = _selectedInterests.contains(name);

                      return FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: isSelected
                                  ? AppColors.jungle600
                                  : AppColors.inkSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(name),
                          ],
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.jungle700
                              : AppColors.inkSecondary,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.leaf100,
                        checkmarkColor: AppColors.jungle600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.leaf200
                                : AppColors.line,
                          ),
                        ),
                        onSelected: (_) => _toggleInterest(name),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 5. Special Requests & Preferences
                  const Text(
                    'Special Requests & Preferences (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: TextFormField(
                      controller: _requestTextCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g., Prefer window seats on the Kandy to Ella scenic train, boutique eco-lodges with mountain views.',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.inkTertiary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Primary Action CTA Button
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, color: AppColors.sand400),
                    label: Text(
                      _loading
                          ? 'Orchestrating 4 AI Agents...'
                          : 'Generate AI Itinerary',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.jungle600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield, size: 14, color: AppColors.jungle600),
                      SizedBox(width: 4),
                      Text(
                        'Real-time dynamic pricing guaranteed for 24 hours',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get budgetFormatted {
    return _budget.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Widget _buildAgentStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    bool isActive = false,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? AppColors.sand100 : AppColors.leaf100,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isActive ? AppColors.sand700 : AppColors.jungle600,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
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

  Widget _buildPillTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.leaf50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.jungle700,
        ),
      ),
    );
  }
}
