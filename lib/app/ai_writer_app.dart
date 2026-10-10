import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/library/library_page.dart';

/// App shell themed per DESIGN.md (iA Writer direction).
class AiWriterApp extends StatelessWidget {
  const AiWriterApp({super.key});

  static const Color primary = Color(0xFF1C1C1C);
  static const Color secondary = Color(0xFF6B6B6B);
  static const Color tertiary = Color(0xFF2F6F5E);
  static const Color neutral = Color(0xFFF4F1EA);
  static const Color surface = Color(0xFFFFFEFB);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: neutral,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        onPrimary: surface,
        onSecondary: surface,
        onSurface: primary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: neutral,
        foregroundColor: primary,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1A1C1C1C), space: 1),
    );

    return ProviderScope(
      child: MaterialApp(
        title: 'AI Writer',
        debugShowCheckedModeBanner: false,
        theme: base,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: const LibraryPage(),
      ),
    );
  }
}
