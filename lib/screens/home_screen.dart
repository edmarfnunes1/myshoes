import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../pages/financial/financial_dashboard_page.dart';
import '../pages/orders/order_list_page.dart';
import '../pages/production/production_batch_page.dart';
import 'settings_screen.dart';
import 'product_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _ordersRefreshToken = 0;
  int _factoryRefreshToken = 0;
  int _financialRefreshToken = 0;

  List<Widget> get _pages => [
        const ProductListScreen(),
        OrderListPage(refreshToken: _ordersRefreshToken),
        ProductionBatchPage(
          refreshToken: _factoryRefreshToken,
          onBatchCreated: () {
            setState(() => _ordersRefreshToken++);
          },
        ),
        FinancialDashboardPage(refreshToken: _financialRefreshToken),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.dark,
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                if (index == 2) {
                  _factoryRefreshToken++;
                } else if (index == 3) {
                  _financialRefreshToken++;
                }
              });
            },
            destinations: [
              _imageDestination(
                index: 0,
                assetPath: 'assets/images/tenis_neon4.png',
                label: 'Tênis',
              ),
              _destination(
                index: 1,
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Pedidos',
              ),
              _destination(
                index: 2,
                icon: Icons.factory_outlined,
                selectedIcon: Icons.factory,
                label: 'Fábrica',
              ),
              _destination(
                index: 3,
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet,
                label: 'Financeiro',
              ),
              _destination(
                index: 4,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Configurações',
              ),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _imageDestination({
    required int index,
    required String assetPath,
    required String label,
  }) {
    final selected = _selectedIndex == index;

    return NavigationDestination(
      icon: _NavigationAssetIcon(
        assetPath: assetPath,
        selected: false,
      ),
      selectedIcon: _NavigationAssetIcon(
        assetPath: assetPath,
        selected: selected,
      ),
      label: label,
    );
  }

  NavigationDestination _destination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _selectedIndex == index;

    return NavigationDestination(
      icon: _NavigationIcon(icon: icon, selected: false),
      selectedIcon: _NavigationIcon(icon: selectedIcon, selected: selected),
      label: label,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selected ? 36 : 0,
          height: 3,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.neon,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Icon(icon),
      ],
    );
  }
}

class _NavigationAssetIcon extends StatelessWidget {
  const _NavigationAssetIcon({
    required this.assetPath,
    required this.selected,
  });

  final String assetPath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selected ? 36 : 0,
          height: 3,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppColors.neon,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Image.asset(
          assetPath,
          width: 27,
          height: 27,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined),
        ),
      ],
    );
  }
}

