/// Transport booking-item helpers shared by booking, itinerary, and history
/// views. The backend's nullable leg index is authoritative for new bookings;
/// null remains a valid legacy value and is sorted after indexed legs.
List<Map<String, dynamic>> orderedTransportItems(Iterable<dynamic> rawItems) {
  final items = rawItems
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where(isTransportBookingItem)
      .toList();

  items.sort((left, right) {
    final leftIndex = transportLegIndex(left);
    final rightIndex = transportLegIndex(right);
    if (leftIndex == null && rightIndex != null) return 1;
    if (leftIndex != null && rightIndex == null) return -1;
    if (leftIndex != null && rightIndex != null) {
      final comparison = leftIndex.compareTo(rightIndex);
      if (comparison != 0) return comparison;
    }
    return _itemId(left).compareTo(_itemId(right));
  });
  return items;
}

bool isTransportBookingItem(Map<String, dynamic> item) {
  final type = item['itemType'];
  final normalized = type?.toString().toLowerCase() ?? '';
  return type == 2 ||
      normalized == '2' ||
      normalized == 'transport' ||
      item['transportOptionId'] != null ||
      item['transportType'] != null ||
      item['vehicleType'] != null;
}

int? transportLegIndex(Map<String, dynamic> item) {
  final value = item['transportLegIndex'] ?? item['legIndex'];
  if (value is num) return value.toInt() >= 0 ? value.toInt() : null;
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 0 ? parsed : null;
}

String? transportLegLabel(Map<String, dynamic> item) {
  final index = transportLegIndex(item);
  return index == null ? null : 'Leg ${index + 1}';
}

int _itemId(Map<String, dynamic> item) {
  final value = item['id'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
