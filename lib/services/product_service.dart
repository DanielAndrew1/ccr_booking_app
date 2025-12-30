import 'package:ccr_booking/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> fetchProducts() async {
    final response = await _client
        .from('products')
        .select('id, name, image')
        .order('name');

    return (response as List).map((e) => Product.fromMap(e)).toList();
  }
}
