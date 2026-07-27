import 'package:flutter/material.dart';

import '../pages/product_image_gallery_page.dart';

@Deprecated('Use ProductImageGalleryPage with Navigator.push instead.')
class ProductGalleryViewer extends StatelessWidget {
  const ProductGalleryViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.productName = 'Fotos do tênis',
  }) : assert(imagePaths.length > 0);

  final List<String> imagePaths;
  final int initialIndex;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return ProductImageGalleryPage(
      images: imagePaths,
      initialIndex: initialIndex,
      productName: productName,
    );
  }
}
