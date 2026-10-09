import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_flutter/services/api_service.dart';
import 'package:mobile_flutter/widgets/common_widgets.dart';

void main() {
  test('allows HTTPS catalogue images hosted outside the API server', () {
    expect(
      ApiService.resolveMediaUrl('https://www.holidify.com/image.jpg'),
      'https://www.holidify.com/image.jpg',
    );
    expect(
      ApiService.resolveMediaUrl('assets/photos/ella-1280.jpg'),
      startsWith('assets/'),
    );
  });

  test('preserves Supabase images and resolves relative uploads on a phone', () {
    const cloud =
        'https://example.supabase.co/storage/v1/object/public/catalog-images/tours/photo.webp';
    expect(ApiService.resolveMediaUrl(cloud), cloud);
    final server = ApiService.baseUrl.replaceFirst(RegExp(r'/api$'), '');
    expect(
      ApiService.resolveMediaUrl('/uploads/tours/photo.jpg'),
      '$server/uploads/tours/photo.jpg',
    );
    expect(
      ApiService.resolveMediaUrl('http://localhost:5138/uploads/photo.jpg'),
      '$server/uploads/photo.jpg',
    );
    expect(
      ApiService.resolveMediaUrl('//cdn.example.com/photo.jpg'),
      'https://cdn.example.com/photo.jpg',
    );
    expect(ApiService.resolveMediaUrl('javascript:alert(1)'), '');
    expect(ApiService.resolveMediaUrl('file:///private/photo.jpg'), '');
    expect(
      ApiService.resolveMediaUrl('https://user:password@example.com/photo.jpg'),
      '',
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
