import 'package:flutter/material.dart';

/// App color palette matching Serendib Trails / natural Sri Lankan landscape.
class AppColors {
  // Jungle canopy greens
  static const Color jungle900 = Color(0xFF06231B);
  static const Color jungle800 = Color(0xFF0A3628);
  static const Color jungle700 = Color(0xFF0F4A37);
  static const Color jungle600 = Color(0xFF166B4F); // Primary Brand
  static const Color jungle500 = Color(0xFF1F8C66);
  static const Color leaf400 = Color(0xFF35B183);
  static const Color leaf200 = Color(0xFFB6ECD6);
  static const Color leaf100 = Color(0xFFD9F4E7);
  static const Color leaf50 = Color(0xFFEEFAF4);

  // Ocean teals
  static const Color ocean800 = Color(0xFF073F49);
  static const Color ocean700 = Color(0xFF0B5F6B);
  static const Color ocean500 = Color(0xFF0F8F9E);
  static const Color ocean400 = Color(0xFF29AEBD);
  static const Color ocean300 = Color(0xFF7FD4DE);

  // Temple gold & sun
  static const Color sand700 = Color(0xFFA86F1F);
  static const Color sand600 = Color(0xFFC98A2E);
  static const Color sand500 = Color(0xFFE0A63F); // Accent
  static const Color sand400 = Color(0xFFF0C469);
  static const Color sand200 = Color(0xFFF8E2B4);
  static const Color sand100 = Color(0xFFFBEED3);

  // Clay & Coral
  static const Color coral500 = Color(0xFFE4694A);
  static const Color coral400 = Color(0xFFEF8A6D);
  static const Color clay600 = Color(0xFF9C4726);

  // Neutrals
  static const Color ivory = Color(0xFFFBFAF5); // Page Background
  static const Color mist = Color(0xFFF1F5F1);
  static const Color paper = Colors.white;
  static const Color ink = Color(0xFF08201A);
  static const Color ink2 = Color(0xFF3A564C);
  static const Color ink3 = Color(0xFF6B8578);
  static const Color line = Color(0xFFE2E9E3);
  static const Color lineStrong = Color(0xFFCDD9D0);
}

/// Curated destination model and data for Sri Lanka.
class DestinationItem {
  final String id;
  final String name;
  final String region;
  final String tagline;
  final String imageUrl;
  final String tags;
  final double rating;
  final double priceFrom;

  const DestinationItem({
    required this.id,
    required this.name,
    required this.region,
    required this.tagline,
    required this.imageUrl,
    required this.tags,
    this.rating = 4.9,
    this.priceFrom = 150,
  });
}

class AppDestinations {
  static const String heroSigiriya = 'assets/photos/sigiriya-1280.jpg';

  static const List<DestinationItem> featured = [
    DestinationItem(
      id: 'sigiriya',
      name: 'Sigiriya',
      region: 'Cultural Triangle',
      tagline: 'Ancient 5th-century rock fortress & water gardens',
      imageUrl: 'assets/photos/sigiriya-1280.jpg',
      tags: 'Heritage • UNESCO',
      rating: 4.9,
      priceFrom: 185,
    ),
    DestinationItem(
      id: 'ella',
      name: 'Ella',
      region: 'Hill Country',
      tagline: 'Nine Arches viaduct, mist & mountain trails',
      imageUrl: 'assets/photos/ella-1280.jpg',
      tags: 'Hiking • Rail',
      rating: 4.8,
      priceFrom: 145,
    ),
    DestinationItem(
      id: 'mirissa',
      name: 'Mirissa',
      region: 'South Coast',
      tagline: 'Golden crescent bay, whale safari & surf',
      imageUrl: 'assets/photos/mirissa-1280.jpg',
      tags: 'Beach • Safari',
      rating: 4.7,
      priceFrom: 168,
    ),
    DestinationItem(
      id: 'nuwara-eliya',
      name: 'Nuwara Eliya',
      region: 'Tea Terraces',
      tagline: 'Little England, tea estates & misty hills',
      imageUrl: 'assets/photos/nuwara-eliya-1280.jpg',
      tags: 'Tea • Scenic',
      rating: 4.8,
      priceFrom: 132,
    ),
    DestinationItem(
      id: 'yala',
      name: 'Yala',
      region: 'Deep South',
      tagline: 'World-famous leopard density & safari adventures',
      imageUrl: 'assets/photos/yala-1280.jpg',
      tags: 'Wildlife • Safari',
      rating: 4.9,
      priceFrom: 210,
    ),
    DestinationItem(
      id: 'kandy',
      name: 'Kandy',
      region: 'Central Highlands',
      tagline: 'Sacred Temple of the Tooth & royal lake',
      imageUrl: 'assets/photos/kandy-1280.jpg',
      tags: 'Culture • Temple',
      rating: 4.7,
      priceFrom: 128,
    ),
    DestinationItem(
      id: 'trincomalee',
      name: 'Trincomalee',
      region: 'East Coast',
      tagline: 'Pigeon Island reef & crystal-clear beaches',
      imageUrl: 'assets/photos/trincomalee-1280.jpg',
      tags: 'Coast • Snorkel',
      rating: 4.8,
      priceFrom: 152,
    ),
    DestinationItem(
      id: 'horton-plains',
      name: 'Horton Plains',
      region: 'Central Massif',
      tagline: 'World’s End escarpment & Baker’s Falls',
      imageUrl: 'assets/photos/horton-plains-1280.jpg',
      tags: 'Nature • Trekking',
      rating: 4.8,
      priceFrom: 140,
    ),
  ];

  /// Helper to get a scenic destination image based on search/tour name.
  static String getImageForDestination(String? name) {
    if (name == null || name.isEmpty) return heroSigiriya;
    final lower = name.toLowerCase();
    if (lower.contains('ella')) {
      return featured[1].imageUrl;
    } else if (lower.contains('mirissa') || lower.contains('whale') || lower.contains('beach')) {
      return featured[2].imageUrl;
    } else if (lower.contains('nuwara') || lower.contains('tea')) {
      return featured[3].imageUrl;
    } else if (lower.contains('yala') || lower.contains('safari') || lower.contains('leopard')) {
      return featured[4].imageUrl;
    } else if (lower.contains('kandy') || lower.contains('temple')) {
      return featured[5].imageUrl;
    } else if (lower.contains('trinco') || lower.contains('snorkel')) {
      return featured[6].imageUrl;
    } else if (lower.contains('horton') || lower.contains('world')) {
      return featured[7].imageUrl;
    }
    return heroSigiriya;
  }
}
