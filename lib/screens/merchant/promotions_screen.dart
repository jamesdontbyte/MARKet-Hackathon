import 'package:flutter/material.dart';
import '../../models/business.dart';
import 'catalog_screen.dart';

/// MSME Merchant Promotions Catalog Screen
/// Aliases to MerchantCatalogScreen with initialTab: 1 for unified header, navigation, and state.
class MerchantPromotionsScreen extends StatelessWidget {
  final Business? business;

  const MerchantPromotionsScreen({
    super.key,
    this.business,
  });

  @override
  Widget build(BuildContext context) {
    return MerchantCatalogScreen(
      business: business,
      initialTab: 1,
    );
  }
}
