import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_colors.dart';

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.product,
    this.size = 60,
    this.borderRadius = 15,
  });

  final Product product;
  final double size;
  final double borderRadius;

  static const _defaultAsset = 'assets/images/tenis_neon4.png';

  static const Map<String, String> _brandAssets = {
    'nike': 'assets/Icones/Nike.png',
    'adidas': 'assets/Icones/Adidas.png',
    'puma': 'assets/Icones/Puma.png',
    'new balance': 'assets/Icones/NewBalance.png',
    'vans': 'assets/Icones/Vans.png',
    'lacoste': 'assets/Icones/Lacoste.png',
    'oakley': 'assets/Icones/Oakley.png',
    'converse': 'assets/Icones/Converse.png',
    'asics': 'assets/Icones/Oasics.png',
    'fila': 'assets/Icones/Fila.png',
    'reebok': 'assets/Icones/Reebok.png',
    'under armour': 'assets/Icones/under_armour.png',
    'mizuno': 'assets/Icones/Mizuno.png',
    'olympikus': 'assets/Icones/olympikus.png',
    'skechers': 'assets/Icones/skechers.png',
    'jordan': 'assets/Icones/Jordan.png',
    'vert (veja)': 'assets/Icones/Veja.png',
    'vert': 'assets/Icones/Veja.png',
    'veja': 'assets/Icones/Veja.png',
    'timberland': 'assets/Icones/Timberland.png',
    'dc shoes': 'assets/Icones/dc_shoes.png',
    'balenciaga': 'assets/Icones/balenciaga.png',
  };

  String get _brandAsset =>
      _brandAssets[product.brand.trim().toLowerCase()] ?? _defaultAsset;

  String? get _primaryThumbnailPath {
    for (final image in product.images) {
      if (image.isPrimary && image.thumbnailPath.trim().isNotEmpty) {
        return image.thumbnailPath;
      }
    }
    return null;
  }

  Widget _fallback() {
    final iconSize = size * 0.65;
    return Padding(
      padding: EdgeInsets.all(size * 0.13),
      child: Image.asset(
        _brandAsset,
        key: const ValueKey('product-thumbnail-fallback'),
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          _defaultAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.directions_run_rounded,
            color: AppColors.neon,
            size: size * 0.53,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = _primaryThumbnailPath;
    final thumbnailFile =
        thumbnailPath == null ? null : File(thumbnailPath);
    final hasValidThumbnail =
        thumbnailFile != null && thumbnailFile.existsSync();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.dark, width: 0.8),
      ),
      child: !hasValidThumbnail
          ? _fallback()
          : Image.file(
              thumbnailFile,
              key: const ValueKey('product-thumbnail-file'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              cacheHeight:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, __, ___) => _fallback(),
            ),
    );
  }
}
