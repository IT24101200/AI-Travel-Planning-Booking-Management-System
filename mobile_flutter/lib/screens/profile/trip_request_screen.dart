import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Trip request form screen — "Plan My Trip" with multi-agent orchestration.
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTextCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController(text: '1200');
  final _travellerCtrl = TextEditingController(text: '2');

  List<dynamic> _destinations = [];
  int? _selectedDestinationId;
  String _selectedDestinationName = 'Sigiriya';
  DateTime? _startDate;
  DateTime? _endDate;
  final String _currency = 'USD';
  bool _loading = false;
  bool _loadingDestinations = true;
  String? _error;
  String? _success;
  int? _createdTripId;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().add(const Duration(days: 7));
    _endDate = DateTime.now().add(const Duration(days: 12));
    _loadDestinations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final name = args['name']?.toString() ?? '';
      _requestTextCtrl.text =
          'I want to experience $name with guided tours, quality hotel and comfortable transit.';
      _selectedDestinationName = name;
    }
  }

  /// Load available destinations for dropdown
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

  /// Pick a date using the date picker
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now().add(const Duration(days: 7)))
        : (_endDate ?? DateTime.now().add(const Duration(days: 12)));

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
            _endDate = _startDate!.add(const Duration(days: 3));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Submit trip request to backend
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select start and end dates');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'End date must be after start date');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final result = await ApiService.createTripRequest({
        'destinationId': _selectedDestinationId,
        'rawRequestText': _requestTextCtrl.text.trim(),
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'travellerCount': int.tryParse(_travellerCtrl.text) ?? 1,
        'budgetCeiling': double.tryParse(_budgetCtrl.text) ?? 0,
        'currency': _currency,
      });

      if (!mounted) return;

      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        setState(() {
          _createdTripId = result['id'] is int ? result['id'] : int.tryParse(result['id']?.toString() ?? '');
          _success =
              'Trip request submitted! 4 AI Agents are now coordinating your itinerary, hotel & transport options.';
        });
      } else {
        setState(() {
          _error =
              result['message'] ??
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

  void _applyQuickPrompt(String prompt) {
    setState(() {
      _requestTextCtrl.text = prompt;
    });
  }

  @override
  void dispose() {
    _requestTextCtrl.dispose();
    _budgetCtrl.dispose();
    _travellerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewImage = AppDestinations.getImageForDestination(
      _selectedDestinationName,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Trip Planner')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dynamic Scenic Banner ──
            Stack(
              children: [
                AppNetworkImage(
                  imageUrl: previewImage,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        AppColors.jungle900.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.sand500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.jungle900,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Describe Your Ideal Journey',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Coordinator • Itinerary • Booking • Validation',
                              style: TextStyle(
                                color: AppColors.sand200,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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

            // ── Form Area ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status messages
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.coral500.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.coral500.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.coral500,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.coral500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_success != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.leaf50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.jungle600.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.jungle600,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Trip Planning Initiated!',
                                  style: TextStyle(
                                    color: AppColors.jungle800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _success!,
                              style: const TextStyle(
                                color: AppColors.ink2,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
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
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text('🚀 Track AI Agent Progress Live'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.jungle600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Section: Destination Selection
                    const Text(
                      'Primary Destination',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _loadingDestinations
                        ? const LinearProgressIndicator(
                            color: AppColors.jungle600,
                          )
                        : DropdownButtonFormField<int>(
                            initialValue: _selectedDestinationId,
                            decoration: const InputDecoration(
                              hintText: 'Select destination',
                              prefixIcon: Icon(
                                Icons.place_outlined,
                                color: AppColors.jungle600,
                              ),
                            ),
                            items: _destinations.map<DropdownMenuItem<int>>((
                              d,
                            ) {
                              return DropdownMenuItem<int>(
                                value: d['id'],
                                child: Text(
                                  '${d['name']} — ${d['country'] ?? 'Sri Lanka'}',
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

                    const SizedBox(height: 20),

                    // Section: Travel Dates
                    const Text(
                      'Travel Window',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isStart: true),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Departure',
                                prefixIcon: Icon(
                                  Icons.calendar_month,
                                  color: AppColors.jungle600,
                                  size: 20,
                                ),
                              ),
                              child: Text(
                                _startDate != null
                                    ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                                    : 'Select',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isStart: false),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Return',
                                prefixIcon: Icon(
                                  Icons.calendar_month,
                                  color: AppColors.jungle600,
                                  size: 20,
                                ),
                              ),
                              child: Text(
                                _endDate != null
                                    ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                    : 'Select',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Section: Party Size & Budget
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Travellers',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _travellerCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.group_outlined,
                                    color: AppColors.jungle600,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final n = int.tryParse(v);
                                  if (n == null || n < 1) return 'Min 1';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Max Budget',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _budgetCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: AppColors.jungle600,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  final n = double.tryParse(v);
                                  if (n == null || n <= 0) return 'Must be > 0';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Section: Prompt / Vision
                    const Text(
                      'Trip Preferences & Interests',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick suggestion chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPromptChip('Tea Country & Scenic Trains'),
                          _buildPromptChip('Wildlife Safari & Marine Coast'),
                          _buildPromptChip('UNESCO Heritage & Rock Forts'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _requestTextCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g., A 5-day nature and heritage vacation visiting Sigiriya and Ella with boutique stays and scenic train rides...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(
                            Icons.edit_note,
                            color: AppColors.jungle600,
                          ),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please describe your trip preferences'
                          : null,
                    ),

                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: AppColors.sand400,
                              ),
                        label: Text(
                          _loading
                              ? 'Orchestrating 4 AI Agents...'
                              : 'Plan My Trip with AI',
                          style: const TextStyle(
                            fontSize: 16,
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
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        labelStyle: const TextStyle(
          fontSize: 11,
          color: AppColors.jungle700,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: AppColors.leaf50,
        side: const BorderSide(color: AppColors.leaf100),
        onPressed: () => _applyQuickPrompt(label),
      ),
    );
  }
}
