import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/widgets/common_widgets.dart';

void main() {
  test('rejects third-party media URLs before a browser request', () {
    expect(
      ApiService.resolveMediaUrl('https://www.holidify.com/image.jpg'),
      '',
    );
    expect(
      ApiService.resolveMediaUrl('assets/photos/ella-1280.jpg'),
      startsWith('assets/'),
    );
  });

  testWidgets('renders local fallback when an image URL is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(const AppNetworkImage(imageUrl: ''));
    expect(find.byType(AppNetworkImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
