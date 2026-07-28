import 'package:flutter/material.dart';

import '../data/settings_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_page_header.dart';
import 'about_screen.dart';
import 'factory_additionals_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.repository});

  final SettingsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const AppPageHeader(
              title: 'Configurações',
              subtitle: 'Preferências e custos do MyShoes',
              horizontalPadding: 0,
            ),
            const SizedBox(height: 20),
            _SettingsNavigationCard(
              key: const ValueKey('factory-additionals-card'),
              icon: Icons.factory_outlined,
              title: 'Adicionais da fábrica',
              subtitle: 'Configure valores de itens opcionais dos pedidos',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FactoryAdditionalsScreen(repository: repository),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SettingsNavigationCard(
              key: const ValueKey('about-app-card'),
              icon: Icons.info_outline,
              title: 'Sobre o app',
              subtitle: 'Versão, desenvolvedor e informações',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsNavigationCard extends StatelessWidget {
  const _SettingsNavigationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E5EC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _SettingsIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.dark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Color(0xFF667085)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.neon,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.dark, size: 21),
    );
  }
}
