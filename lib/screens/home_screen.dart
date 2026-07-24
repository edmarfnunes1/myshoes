import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../pages/orders/order_list_page.dart';
import '../pages/production/production_batch_page.dart';
import 'product_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _factoryRefreshToken = 0;

  List<Widget> get _pages => [
        const ProductListScreen(),
        const OrderListPage(),
        ProductionBatchPage(refreshToken: _factoryRefreshToken),
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
                }
              });
            },
            destinations: [
              _destination(
                index: 0,
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2,
                label: 'Produtos',
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
            ],
          ),
        ),
      ),
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
