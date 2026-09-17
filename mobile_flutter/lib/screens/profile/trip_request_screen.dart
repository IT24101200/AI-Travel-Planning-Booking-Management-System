import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Trip request form screen — "Plan My Trip".
class TripRequestScreen extends StatefulWidget {
  const TripRequestScreen({super.key});

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTextCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _travellerCtrl = TextEditingController(text: '1');

  List<dynamic> _destinations = [];
  int? _selectedDestinationId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _currency = 'USD';
  bool _loading = false;
  bool _loadingDestinations = true;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  /// Load available destinations for dropdown
  Future<void> _loadDestinations() async {
    try {
      _destinations = await ApiService.getDestinations();
    } catch (e) {
      // Non-blocking — user can still submit without destination
    }
    if (mounted) setState(() { _loadingDestinations = false; });
  }

  /// Pick a date using the date picker
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
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
      setState(() { _error = 'Please select start and end dates'; });
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() { _error = 'End date must be after start date'; });
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });

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
        setState(() { _success = 'Trip request submitted! AI is planning your trip...'; });
      } else {
        setState(() { _error = result['message'] ?? 'Failed to submit request'; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error'; });
    }
    if (mounted) setState(() { _loading = false; });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Plan My Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your dream trip',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Status messages
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
              ],
              if (_success != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_success!, style: TextStyle(color: Colors.green.shade700))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Destination dropdown
              _loadingDestinations
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<int>(
                      value: _selectedDestinationId,
                      decoration: const InputDecoration(
                        labelText: 'Destination (optional)',
                        prefixIcon: Icon(Icons.place),
                      ),
                      items: _destinations.map<DropdownMenuItem<int>>((d) {
                        return DropdownMenuItem<int>(
                          value: d['id'],
                          child: Text('${d['name']} — ${d['country']}'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() { _selectedDestinationId = v; }),
                    ),
              const SizedBox(height: 16),

              // Date pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
                              : 'Select',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                              : 'Select',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Traveller count and budget
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _travellerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Travellers',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = int.tryParse(v);
                        if (n == null || n < 1) return 'Min 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget',
                        prefixText: '\$ ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trip description
              TextFormField(
                controller: _requestTextCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe your ideal trip',
                  hintText: 'e.g., A relaxing beach holiday with cultural tours...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Please describe your trip' : null,
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.flight_takeoff),
                  label: Text(
                    _loading ? 'Planning...' : 'Plan My Trip',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
