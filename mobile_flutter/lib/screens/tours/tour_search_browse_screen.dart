import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Tour search and browse screen with search bar and tour cards.
class TourSearchBrowseScreen extends StatefulWidget {
  const TourSearchBrowseScreen({super.key});

  @override
  State<TourSearchBrowseScreen> createState() => _TourSearchBrowseScreenState();
}

class _TourSearchBrowseScreenState extends State<TourSearchBrowseScreen> {
  List<dynamic> _tours = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  /// Fetch tours from the backend API
  Future<void> _loadTours({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      _tours = await ApiService.getTours(search: search);
    } catch (e) {
      _error = 'Failed to load tours';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore Tours')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search tours...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadTours();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) => _loadTours(search: value),
            ),
          ),

          // Tour list
          Expanded(
            child: _loading
                ? const LoadingIndicator(message: 'Loading tours...')
                : _error != null
                    ? ErrorMessage(message: _error!, onRetry: () => _loadTours())
                    : _tours.isEmpty
                        ? const EmptyState(
                            icon: Icons.tour,
                            message: 'No tours found',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadTours(search: _searchCtrl.text),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _tours.length,
                              itemBuilder: (context, index) {
                                final tour = _tours[index];
                                return _buildTourCard(tour);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Build a single tour card
  Widget _buildTourCard(Map<String, dynamic> tour) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pushNamed(context, '/tour-details', arguments: tour['id']);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Tour icon with category color
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.landscape, color: Color(0xFF0D9488), size: 30),
              ),
              const SizedBox(width: 16),
              // Tour details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour['name'] ?? 'Unnamed Tour',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          tour['category'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${tour['durationHours'] ?? 0}h',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${(tour['price'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                  Text(
                    tour['currency'] ?? 'USD',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
