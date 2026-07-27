import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cabeçalho visual reutilizável das principais páginas do MyShoes.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.horizontalPadding = 20,
  });

  final String title;
  final String subtitle;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 7 / 3,
              child: Image.asset(
                'assets/images/slogan.png',
                key: const ValueKey('myshoes-header-banner'),
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.dark,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.neon,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF667085),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
