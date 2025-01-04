import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/wallet_service.dart';
import 'services/chain_service.dart';
import 'pages/settings_page.dart';
import 'pages/listings_page.dart';
import 'pages/create_listing_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChainService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperPull Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEEFC42),
          primary: const Color(0xFFEEFC42),
          secondary: Colors.black,
          background: Colors.white,
          onPrimary: Colors.black,
          onSecondary: Colors.white,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEEFC42),
            foregroundColor: Colors.black,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFEEFC42),
          foregroundColor: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEEFC42),
          foregroundColor: Colors.black,
        ),
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final WalletService _walletService = WalletService();
  bool _isLoading = true;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final isFirst = await _walletService.isFirstTime();
    if (isFirst) {
      await _createWallet();
    }
    setState(() {
      _isFirstTime = isFirst;
      _isLoading = false;
    });
  }

  Future<void> _createWallet() async {
    await _walletService.createWallet();
    await _walletService.setFirstTime(false);
  }

  void _navigateToListings() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ListingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Welcome to SuperPull',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'The independent fashion marketplace where emerging designers and collectors match.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isFirstTime) ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Your Solana wallet has been created!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You can view your secret recovery phrase in the Settings page.',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _navigateToListings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListingsPage extends StatelessWidget {
  const ListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperPull'),
        actions: [
          Consumer<ChainService>(
            builder: (context, chainService, child) {
              return DropdownButton<BlockchainType>(
                value: chainService.selectedChain,
                underline: Container(),
                icon: const Icon(Icons.arrow_drop_down),
                selectedItemBuilder: (BuildContext context) {
                  return BlockchainType.values.map((BlockchainType chain) {
                    return Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        chain.displayName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: BlockchainType.values.map((BlockchainType chain) {
                  return DropdownMenuItem<BlockchainType>(
                    value: chain,
                    child: Text(chain.displayName),
                  );
                }).toList(),
                onChanged: (BlockchainType? newValue) {
                  if (newValue != null) {
                    chainService.setSelectedChain(newValue);
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateListingPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      // ... rest of the ListingsPage implementation ...
    );
  }
} 