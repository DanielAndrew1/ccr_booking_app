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
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      setState(() => _streamKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: 'Inventory', showPfp: true),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _streamKey = UniqueKey()),
        color: AppColors.primary,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: _streamKey,
          stream: Supabase.instance.client
              .from('products')
              .stream(primaryKey: ['id'])
              .order('name'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CustomLoader());
            if (snapshot.hasError)
              return const Center(child: Text("Error loading inventory."));
            final products = snapshot.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CustomProductTile(
                    title: p['name'],
                    price: (p['price'] as num).toDouble(),
                    imageUrl: p['image_url'],
                    route: ProductPage(productId: p['id'].toString()),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
