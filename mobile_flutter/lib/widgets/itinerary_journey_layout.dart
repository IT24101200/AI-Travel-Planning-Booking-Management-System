import 'dart:math' as math;

import 'package:flutter/material.dart';

class ItineraryJourneyLayout extends StatelessWidget {
  const ItineraryJourneyLayout({
    super.key,
    required this.map,
    required this.heading,
    required this.children,
  });

  final Widget map;
  final Widget heading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final mapHeight = math.min(
        MediaQuery.sizeOf(context).height * 0.4,
        constraints.maxHeight * 0.5,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const ValueKey('fixed-itinerary-map'),
              height: mapHeight,
              child: map,
            ),
            const SizedBox(height: 16),
            heading,
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                key: const ValueKey('journey-scroll'),
                padding: const EdgeInsets.only(bottom: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: children,
              ),
            ),
          ],
        ),
      );
    },
  );
}
