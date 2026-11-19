import 'package:flutter/material.dart';

void main() => runApp(const MyVaultApp());

const cream = Color(0xFFF5F0E5);
const charcoal = Color(0xFF222420);
const forest = Color(0xFF254F43);
const terracotta = Color(0xFFCF6248);

class MyVaultApp extends StatefulWidget {
  const MyVaultApp({super.key});

  @override
  State<MyVaultApp> createState() => _MyVaultAppState();
}

class _MyVaultAppState extends State<MyVaultApp> {
  Locale _locale = const Locale('en');

  void toggleLanguage() {
    setState(() => _locale =
        _locale.languageCode == 'en' ? const Locale('ar') : const Locale('en'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Vault',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: forest,
          primary: forest,
          secondary: terracotta,
          surface: cream,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: charcoal,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      locale: _locale,
      home: VaultShell(
        isArabic: _locale.languageCode == 'ar',
        onToggleLanguage: toggleLanguage,
      ),
    );
  }
}

class VaultShell extends StatefulWidget {
  const VaultShell({
    super.key,
    required this.isArabic,
    required this.onToggleLanguage,
  });

  final bool isArabic;
  final VoidCallback onToggleLanguage;

  @override
  State<VaultShell> createState() => _VaultShellState();
}

class _VaultShellState extends State<VaultShell> {
  int selected = 0;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(isArabic: widget.isArabic, onNavigate: (i) => setState(() => selected = i)),
      SimplePage(title: t('My Vault', 'خزنتي'), subtitle: t('Your saved accounts will appear here.', 'ستظهر حساباتك المحفوظة هنا.'), icon: Icons.lock_outline),
      SimplePage(title: t('Authenticator', 'المصادقة الثنائية'), subtitle: t('Your 2FA codes will appear here after secure setup.', 'ستظهر رموز المصادقة هنا بعد إعداد التخزين الآمن.'), icon: Icons.phonelink_lock),
      SimplePage(title: t('Security', 'الأمان'), subtitle: t('Security checks and backup options will be added here.', 'ستضاف هنا فحوصات الأمان وخيارات النسخ الاحتياطي.'), icon: Icons.shield_outlined),
      SimplePage(title: t('Settings', 'الإعدادات'), subtitle: t('App preferences and account settings.', 'تفضيلات التطبيق وإعدادات الحساب.'), icon: Icons.settings_outlined),
    ];
    final labels = [
      t('Home', 'الرئيسية'),
      t('Vault', 'الخزنة'),
      t('Authenticator', 'المصادقة'),
      t('Security', 'الأمان'),
      t('Settings', 'الإعدادات'),
    ];
    final icons = [Icons.dashboard_outlined, Icons.lock_outline, Icons.phonelink_lock, Icons.shield_outlined, Icons.settings_outlined];
    final wide = MediaQuery.sizeOf(context).width >= 850;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Vault', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            TextButton.icon(
              onPressed: widget.onToggleLanguage,
              icon: const Icon(Icons.language),
              label: Text(t('العربية', 'English')),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])),
                ],
              ),
            Expanded(child: pages[selected]),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
                ],
              ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.isArabic, required this.onNavigate});
  final bool isArabic;
  final ValueChanged<int> onNavigate;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(t('Your digital life, safely stored.', 'حياتك الرقمية، محفوظة بأمان.'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: charcoal)),
        const SizedBox(height: 8),
        Text(t('A private space for your accounts and security tools.', 'مساحة خاصة لحساباتك وأدوات الحماية.'),
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _StatCard(title: t('Saved accounts', 'الحسابات'), value: '0', icon: Icons.key),
          _StatCard(title: t('2FA entries', 'رموز 2FA'), value: '0', icon: Icons.phonelink_lock),
          _StatCard(title: t('Security status', 'حالة الأمان'), value: t('Setup needed', 'يحتاج إعداد'), icon: Icons.shield_outlined),
        ]),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.phonelink_lock, color: forest),
                const SizedBox(width: 10),
                Expanded(child: Text(t('Authenticator', 'المصادقة الثنائية'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                TextButton(onPressed: () => onNavigate(2), child: Text(t('Open', 'فتح'))),
              ]),
              const SizedBox(height: 8),
              Text(t('Manage your two-factor authentication entries in a dedicated space.', 'أدر بيانات المصادقة الثنائية من صفحة مستقلة.')),
              const SizedBox(height: 12),
              const Text('No authenticator entries yet.', style: TextStyle(color: Colors.black54)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: terracotta),
              const SizedBox(width: 12),
              Expanded(child: Text(t(
                'Starter interface only. Secure local storage, encryption, sign-in, sync and code generation are not implemented yet.',
                'هذه واجهة أولية فقط. التخزين المحلي الآمن والتشفير وتسجيل الدخول والمزامنة وتوليد الرموز لم تُنفذ بعد.',
              ))),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: forest),
        const SizedBox(height: 14),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: charcoal)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.black54)),
      ]),
    )),
  );
}

class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: forest),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: charcoal)),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 18),
            const Chip(label: Text('Coming in the next development phase')),
          ]),
        )),
      ),
    ),
  );
}
