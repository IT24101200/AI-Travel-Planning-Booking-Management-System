import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Tour details screen with immersive photography, key highlights, and direct booking actions.
class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({super.key});

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  Map<String, dynamic>? _tour;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tourId = ModalRoute.of(context)?.settings.arguments as int?;
    if (tourId != null && _tour == null) {
      _loadTour(tourId);
    }
  }

  /// Fetch tour details from backend
  Future<void> _loadTour(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getTour(id);
      if (mounted) {
        setState(() {
          _tour = data;
          if (_tour == null) _error = 'Tour details not found';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tour details';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Details')),
        body: const LoadingIndicator(message: 'Loading experience...'),
      );
    }

    if (_error != null || _tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tour Details')),
        body: ErrorMessage(
          message: _error ?? 'Tour not found',
          onRetry: () {
            final tourId = ModalRoute.of(context)?.settings.arguments as int?;
            if (tourId != null) _loadTour(tourId);
          },
        ),
      );
    }

    final tourName = _tour!['name'] ?? 'Scenic Excursion';
    final uploadedImage = ApiService.resolveMediaUrl(_tour!['imageUrl']?.toString());
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);
    final price = (_tour!['price'] ?? 0).toDouble();
    final currency = _tour!['currency'] ?? 'USD';
    final duration = _tour!['durationHours'] ?? 2;
    final startTime = _tour!['defaultStartTime'] ?? '08:00 AM';
    final category = _tour!['category'] ?? 'Excursion';
    final status = _tour!['status'] ?? 'Active';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero Image with SliverAppBar ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.jungle800,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.sand500,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.jungle900,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tourName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Key Stats Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.attach_money, 'Price', '\$${price.toStringAsFixed(0)} $currency'),
                        _buildDivider(),
                        _buildStatItem(Icons.timer_outlined, 'Duration', '${duration}h'),
                        _buildDivider(),
                        _buildStatItem(Icons.schedule, 'Start', startTime),
                        _buildDivider(),
                        _buildStatItem(Icons.check_circle_outline, 'Status', status),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Overview / Story
                  const Text(
                    'Experience Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tour!['description'] ??
                        'Immerse yourself in authentic Sri Lankan sights, sounds, and traditions with dedicated local travel experts.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.ink2,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Location Card
                  if (_tour!['latitude'] != null && _tour!['longitude'] != null) ...[
                    const Text(
                      'Geographic Coordinates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.leaf50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.jungle600, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            'Lat: ${_tour!['latitude']} • Lng: ${_tour!['longitude']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.jungle700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // AI Integration Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.jungle700.withOpacity(0.08), AppColors.ocean700.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.leaf100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.jungle600, size: 28),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Multi-Agent Trip Integration',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.jungle800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'This tour can be directly incorporated into your AI trip itinerary with hotel & transit recommendations.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total From',
                  style: TextStyle(fontSize: 11, color: AppColors.ink3),
                ),
                Text(
                  '\$${price.toStringAsFixed(0)} $currency',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.jungle600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/trip-request',
                    arguments: _tour,
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.sand400),
                label: const Text('Add to AI Trip Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.jungle600),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.ink3),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppColors.line,
    );
  }
}
