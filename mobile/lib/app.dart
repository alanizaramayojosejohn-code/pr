import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

class PRApp extends ConsumerWidget {
  const PRApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'PR',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: themeMode,
    );
  }
}
