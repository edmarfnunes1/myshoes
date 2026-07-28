import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/app_page_header.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<String> _appVersionFuture;

  @override
  void initState() {
    super.initState();
    _appVersionFuture = _loadAppVersion();
  }


  Future<String> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final versionMatch = RegExp(
        r'^version:\s*([^+\s]+)(?:\+\S+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      return versionMatch?.group(1) ?? 'Não informada';
    } catch (_) {
      return 'Não informada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const AppPageHeader(
              title: 'Sobre o app',
              subtitle: 'Informações e recursos do MyShoes',
              horizontalPadding: 0,
            ),
            const SizedBox(height: 20),
            _InfoCard(
              icon: Icons.info_outline,
              title: 'Informações',
              children: [
                FutureBuilder<String>(
                  future: _appVersionFuture,
                  builder: (context, snapshot) {
                    return _InfoRow(
                      label: 'Versão',
                      value: snapshot.data ?? 'Carregando...',
                    );
                  },
                ),
                const Divider(height: 24),
                const _InfoRow(
                  label: 'Desenvolvido por',
                  value: 'Innova QaSolutions',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _InfoCard(
              icon: Icons.phone_android_outlined,
              title: 'Sobre o MyShoes',
              children: [
                Text(
                  'Aplicativo desenvolvido para auxiliar vendedores de '
                  'calçados no cadastro de produtos, controle de pedidos e '
                  'organização de lotes para a fábrica.',
                  style: TextStyle(
                    color: Color(0xFF4B5565),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _InfoCard(
              icon: Icons.check_circle_outline,
              title: 'Principais recursos',
              children: [
                _FeatureRow(text: 'Cadastro e consulta de produtos'),
                _FeatureRow(text: 'Registro e acompanhamento de pedidos'),
                _FeatureRow(text: 'Consolidação de lotes para a fábrica'),
                _FeatureRow(text: 'Compartilhamento por texto e PDF'),
                _FeatureRow(text: 'Funcionamento offline'),
              ],
            ),
            const SizedBox(height: 14),
            const _InfoCard(
              icon: Icons.lock_outline,
              title: 'Privacidade',
              children: [
                Text(
                  'Os dados cadastrados são armazenados localmente no '
                  'dispositivo. O MyShoes não exige conexão com a internet '
                  'para suas funções principais.',
                  style: TextStyle(
                    color: Color(0xFF4B5565),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '© 2026 Innova QaSolutions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Campo Mourão - PR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;


  Future<String> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final versionMatch = RegExp(
        r'^version:\s*([^+\s]+)(?:\+\S+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      return versionMatch?.group(1) ?? 'Não informada';
    } catch (_) {
      return 'Não informada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.neon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.dark, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;


  Future<String> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final versionMatch = RegExp(
        r'^version:\s*([^+\s]+)(?:\+\S+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      return versionMatch?.group(1) ?? 'Não informada';
    } catch (_) {
      return 'Não informada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.dark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;


  Future<String> _loadAppVersion() async {
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final versionMatch = RegExp(
        r'^version:\s*([^+\s]+)(?:\+\S+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      return versionMatch?.group(1) ?? 'Não informada';
    } catch (_) {
      return 'Não informada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.dark,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF4B5565),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
