import 'package:flutter/material.dart';

import 'theme.dart';
import 'storage.dart';
import 'screens/accueil_screen.dart';
import 'screens/ajouter_screen.dart';
import 'screens/reglages_screen.dart';

void main() {
  runApp(const MemoTackApp());
}

class MemoTackApp extends StatefulWidget {
  const MemoTackApp({super.key});

  @override
  State<MemoTackApp> createState() => _MemoTackAppState();
}

class _MemoTackAppState extends State<MemoTackApp> {
  final AppState appState = AppState();

  @override
  void initState() {
    super.initState();
    appState.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MémoTack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (!appState.isLoaded) {
            return const Scaffold(
              backgroundColor: Color(0xFF1E1B22),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return RootScreen(appState: appState);
        },
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  final AppState appState;
  const RootScreen({super.key, required this.appState});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      AccueilScreen(appState: widget.appState),
      AjouterScreen(appState: widget.appState),
      ReglagesScreen(appState: widget.appState),
    ];

    return Scaffold(
      body: IndexedStack(index: tabIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) => setState(() => tabIndex = i),
        backgroundColor: AppColors.inkLight,
        indicatorColor: AppColors.corail.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Ajouter',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}
