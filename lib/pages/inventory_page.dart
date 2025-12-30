import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/pages/product_page.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with WidgetsBindingObserver {
  // We use a unique key to force the StreamBuilder to restart when we resume the app
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Register the observer to listen to app background/foreground changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister the observer when the page is destroyed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app comes back from the background (resumed), refresh the stream
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _streamKey = UniqueKey();
      });
      debugPrint(
        "App Resumed: Refreshing Realtime Stream to avoid Code 1000 error.",
      );
    }
  }

  // Define the stream getter
  Stream<List<Map<String, dynamic>>> get _productsStream => Supabase
      .instance
      .client
      .from('products')
      .stream(primaryKey: ['id'])
      .order('name');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Inventory', showPfp: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: _streamKey,
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CustomLoader());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync_problem, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Connection lost. Pull to refresh.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _streamKey = UniqueKey()),
                      child: const Text("Retry Now"),
                    ),
                  ],
                ),
              );
            }

            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return Center(
                child: Text(
                  'No products yet.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 16,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _streamKey = UniqueKey());
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: CustomProductTile(
                      title: product['name'] ?? 'Unnamed Product',
                      price: (product['price'] as num?) ?? 0,
                      imageUrl: product['image_url'],
                      route: ProductPage(productId: product['id'].toString()),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
