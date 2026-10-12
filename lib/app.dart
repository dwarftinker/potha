import 'package:flutter/material.dart';

import 'features/library/ui/library_screen.dart';

const _seed = Color(0xFF2E6B5E);

class PothaApp extends StatelessWidget {
  const PothaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Potha',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
        darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const LibraryScreen(),
      );
}
