import 'package:flutter/material.dart';
import 'pages/files_page.dart';
import 'pages/filament_page.dart';
import 'pages/home_page.dart';
import 'pages/models_page.dart';
import 'pages/profile_page.dart';
import 'state.dart';
import 'theme.dart';

void main() => runApp(const FilamentHubApp());

class FilamentHubApp extends StatefulWidget {
  const FilamentHubApp({super.key});
  @override
  State<FilamentHubApp> createState() => _FilamentHubAppState();
}

class _FilamentHubAppState extends State<FilamentHubApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.load();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: state.themeNotifier,
          builder: (context, mode, _) => MaterialApp(
            title: 'Filament Hub',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: mode,
            home: const Shell(),
          ),
        ),
      );
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: st.tab,
          children: const [DevicesPage(), FilamentPage(), ModelsPage(), FilesPage(), ProfilePage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: st.tab,
        onDestinationSelected: st.setTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: 'Принтер'),
          NavigationDestination(icon: Icon(Icons.album_outlined), selectedIcon: Icon(Icons.album), label: 'Филамент'),
          NavigationDestination(icon: Icon(Icons.view_in_ar_outlined), selectedIcon: Icon(Icons.view_in_ar), label: 'Модели'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Файлы'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Я'),
        ],
      ),
    );
  }
}
