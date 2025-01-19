import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/welcome_page.dart';
import 'theme/app_theme.dart';
import 'providers/creator_provider.dart';

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
    // Initialize creator state at app startup
    ref.watch(creatorStateProvider);
    
    return MaterialApp(
      title: 'SuperPull',
      theme: AppTheme.light,
      home: const WelcomePage(),
    );
  }
} 