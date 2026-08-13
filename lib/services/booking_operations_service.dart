import 'package:site_lapse/core/imports.dart';

class BookingOperationsService {
  BookingOperationsService(this._client);

  final SupabaseClient _client;

  Future<int> availableQuantity({
    required String productId,
    required DateTime pickupAt,
    required DateTime returnAt,
    String? excludedBookingId,
  }) async {
    final value = await _client.rpc(
      'product_available_quantity',
      params: {
        'target_product_id': productId,
        'starts_at': pickupAt.toIso8601String(),
        'ends_at': returnAt.toIso8601String(),
        'excluded_booking_id': excludedBookingId,
      },
    );
    return (value as num?)?.toInt() ?? 0;
  }

  Future<void> syncBookingItems({
    required String bookingId,
    required List<Map<String, dynamic>> products,
  }) async {
    final quantities = <String, int>{};
    final prices = <String, num>{};
    for (final product in products) {
      final productId = product['id'].toString();
      quantities[productId] = (quantities[productId] ?? 0) + 1;
      final price = product['project_price'] ?? product['price'];
      prices[productId] = price is num ? price : num.tryParse('$price') ?? 0;
    }

    await _client.from('booking_items').delete().eq('booking_id', bookingId);
    await _client.from('booking_items').insert([
      for (final productId in quantities.keys)
        {
          'booking_id': bookingId,
          'product_id': productId,
          'quantity': quantities[productId],
          'unit_price': prices[productId],
        },
    ]);
  }

  Future<void> recordStatus({
    required String bookingId,
    required String status,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('booking_status_history').insert({
      'booking_id': bookingId,
      'status': status,
      'changed_by': userId,
      'note': note,
    });
    await _client.from('audit_logs').insert({
      'actor_id': userId,
      'entity_type': 'booking',
      'entity_id': bookingId,
      'action': 'status_changed',
      'metadata': {'status': status, if (note != null) 'note': note},
    });
  }
}
