import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/welcome_page.dart';
import 'theme/app_theme.dart';
// Remove the import for creator_provider.dart since we won't use it here
// import 'providers/creator_provider.dart';

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
    // Remove this line - don't initialize creator state at app startup
    // ref.watch(creatorStateProvider);
    
    return MaterialApp(
      title: 'SuperPull',
      theme: AppTheme.light,
      home: const WelcomePage(),
    );
  }
} 