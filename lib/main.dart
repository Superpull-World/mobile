import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/welcome_page.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/token_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize services by watching their providers
    ref.watch(acceptedTokensProvider);
    ref.watch(authProvider);

    return MaterialApp(
      title: 'SuperPull',
      theme: AppTheme.theme,
      home: const WelcomePage(),
    );
  }
} 