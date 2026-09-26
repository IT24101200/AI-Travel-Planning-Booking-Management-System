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
  bool _isFavorite = false;
  int _activeTab = 0; // 0: Included, 1: Excluded

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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Tour Details & Highlights')),
        body: const LoadingIndicator(message: 'Loading experience...'),
      );
    }

    if (_error != null || _tour == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Tour Details & Highlights')),
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
    final uploadedImage = ApiService.resolveMediaUrl(
      _tour!['imageUrl']?.toString(),
    );
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);
    final price = (_tour!['price'] ?? 85).toDouble();
    final duration = _tour!['durationHours'] ?? 8;
    final location = _tour!['location'] ?? 'Cultural Triangle, Sri Lanka';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Gallery Media Section with Gradient & Badges ──
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.jungle900,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? AppColors.coral500 : AppColors.jungle800,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isFavorite = !_isFavorite);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isFavorite ? 'Saved to Wishlist' : 'Removed from Wishlist'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  // Dark jungle gradient
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.jungle900.withValues(alpha: 0.95),
                          AppColors.jungle900.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // UNESCO Badge top left inside hero
                  Positioned(
                    top: 85,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sand500.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium, size: 14, color: AppColors.jungle900),
                          SizedBox(width: 4),
                          Text(
                            'UNESCO World Heritage',
                            style: TextStyle(
                              color: AppColors.jungle900,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Hero Content Overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.star, size: 14, color: AppColors.sand600),
                                  SizedBox(width: 3),
                                  Text(
                                    '4.9',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: AppColors.jungle800,
                                    ),
                                  ),
                                  Text(
                                    ' (128 reviews)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.leaf100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Top Rated',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tourName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppColors.leaf100),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  color: AppColors.leaf100,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Detailed Sections Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Pricing Value Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STANDARD PRICE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.jungle700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '/ person',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.leaf50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppColors.leaf400),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'All Entrance Tickets & Government Taxes Included',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.jungle600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Quick Stats Matrix (2x2)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStatCell(
                          icon: Icons.schedule,
                          label: 'Duration',
                          value: 'Full Day (${duration}h)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickStatCell(
                          icon: Icons.groups,
                          label: 'Group Size',
                          value: 'Small Group (Max 6)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStatCell(
                          icon: Icons.hiking,
                          label: 'Difficulty',
                          value: 'Moderate (1,200 Steps)',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickStatCell(
                          icon: Icons.translate,
                          label: 'Languages',
                          value: 'EN, SI, FR',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Tour Highlights (5 Key Stops)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
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
                                Icon(Icons.explore, size: 20, color: AppColors.sand500),
                                SizedBox(width: 6),
                                Text(
                                  'Expedition Highlights',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.leaf100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '5 Key Stops',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildHighlightStop('01', 'Early Sunrise Sky Fortress Ascent', 'Beat midday tropical heat and summit the 5th-century rock palace with jungle panoramas.'),
                        const SizedBox(height: 12),
                        _buildHighlightStop('02', 'Hydraulic Water Gardens & Mirror Wall', 'Walk through ancient landscaped pools and read 8th-century visitor graffiti poetry.'),
                        const SizedBox(height: 12),
                        _buildHighlightStop('03', 'Frescoes of Celestial Maidens', 'Admire vibrant 1,500-year-old pigment paintings preserved in sheltered stone crevices.'),
                        const SizedBox(height: 12),
                        _buildHighlightStop('04', 'Authentic Village Culinary Feast', 'Savor hand-ground curries simmered in clay pots, served fresh on woven lotus leaves.'),
                        const SizedBox(height: 12),
                        _buildHighlightStop('05', 'Dambulla Golden Rock Cave Complex', 'Explore 5 sanctuary caverns containing 153 gilded Buddha statues and murals.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Certified Guide Spotlight
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.jungle800, AppColors.jungle900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.jungle900.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: AppColors.sand400),
                            SizedBox(width: 6),
                            Text(
                              'SLTDA LICENSED NATIONAL GUIDE',
                              style: TextStyle(
                                color: AppColors.sand200,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.sand400,
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.jungle700,
                                    child: const Text(
                                      'KJ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.leaf400,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.jungle900, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kavinda Jayasuriya',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '12 Yrs Guiding • Ceylon History Scholar',
                                    style: TextStyle(
                                      color: AppColors.leaf200,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.star, size: 12, color: AppColors.sand400),
                                      SizedBox(width: 3),
                                      Text(
                                        '4.98',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        ' (410+ tours)',
                                        style: TextStyle(
                                          color: AppColors.leaf200,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Chat with Kavinda initialized!')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.leaf100,
                                foregroundColor: AppColors.jungle900,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat, size: 14),
                                  SizedBox(width: 4),
                                  Text('Ask', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Native Sinhala • Fluent French & English',
                              style: TextStyle(color: AppColors.leaf100, fontSize: 11),
                            ),
                            Text(
                              '100% Response Rate',
                              style: TextStyle(color: AppColors.sand400, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Included vs Excluded Toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.mist,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() => _activeTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 0 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _activeTab == 0
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "What's Included",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _activeTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                        color: _activeTab == 0 ? AppColors.jungle700 : AppColors.inkTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() => _activeTab = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _activeTab == 1 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _activeTab == 1
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Not Included',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                        color: _activeTab == 1 ? AppColors.jungle700 : AppColors.inkTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_activeTab == 0) ...[
                          _buildInclusionItem(Icons.check_circle, 'Sigiriya Rock Fortress admission ticket (\$36 value)', AppColors.leaf400),
                          _buildInclusionItem(Icons.check_circle, 'Dambulla Royal Cave Temple conservation entry pass', AppColors.leaf400),
                          _buildInclusionItem(Icons.check_circle, 'Private air-conditioned luxury transport with fuel', AppColors.leaf400),
                          _buildInclusionItem(Icons.check_circle, 'Habarana village buffet lunch & fresh king coconut', AppColors.leaf400),
                          _buildInclusionItem(Icons.check_circle, 'Chilled mineral bottled water throughout the trek', AppColors.leaf400),
                        ] else ...[
                          _buildInclusionItem(Icons.cancel, 'Personal souvenir shopping & handloom textiles', AppColors.coral500),
                          _buildInclusionItem(Icons.cancel, 'Alcoholic beverages and imported refreshments', AppColors.coral500),
                          _buildInclusionItem(Icons.cancel, 'Driver & trekker gratuities (optional but appreciated)', AppColors.coral500),
                          _buildInclusionItem(Icons.cancel, 'Travel insurance coverage for mountain trekking', AppColors.coral500),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Temple Etiquette Reminder Callout
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.leaf200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info, size: 20, color: AppColors.jungle600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temple Etiquette Reminder',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Shoulders and knees must be respectfully covered inside Dambulla Cave Temple sanctuaries. Slip-on footwear is recommended.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkSecondary,
                                  height: 1.4,
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
            ),
          ),
        ],
      ),

      // ── Sticky Bottom Reservation Bar ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.line)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL PER TRAVELER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.jungle700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'USD',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/trip-request',
                      arguments: _tour,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.jungle600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Book This Tour',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.leaf100),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.jungle600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.inkTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightStop(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.sand100,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.sand700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInclusionItem(IconData icon, String text, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
