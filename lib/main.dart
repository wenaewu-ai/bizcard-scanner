// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/scan_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const BizCardApp());
}

class BizCardApp extends StatelessWidget {
  const BizCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '名片掃描器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a1a1a),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAF8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAFAF8),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600,
            color: Color(0xFF1a1a1a),
          ),
          iconTheme: IconThemeData(color: Color(0xFF1a1a1a)),
        ),
        dividerColor: const Color(0xFFE8E6DF),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  final _screens = const [ScanScreen(), ContactsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        backgroundColor: const Color(0xFFFAFAF8),
        indicatorColor: const Color(0xFFE8E6DF),
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), label: '掃描'),
          NavigationDestination(icon: Icon(Icons.contacts_outlined), label: '聯絡人'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: '設定'),
        ],
      ),
    );
  }
}
