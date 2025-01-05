import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'listings_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final WalletService _walletService = WalletService();
  final AuthService _authService = AuthService();
  bool _isAuthenticating = true;
  bool _isFirstTime = true;
  bool _isAuthenticated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Check if we already have a valid JWT
      final hasJwt = await _authService.isAuthenticated();
      if (hasJwt) {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _isAuthenticated = true;
          });
          return;
        }
      }

      // Check if first time and create wallet if needed
      final isFirst = await _walletService.isFirstTime();
      if (isFirst) {
        await _walletService.createWallet();
        await _walletService.setFirstTime(false);
      }

      // Authenticate with the server
      final jwt = await _authService.authenticate();
      if (jwt == null) {
        throw Exception('Authentication failed');
      }

      if (mounted) {
        setState(() {
          _isFirstTime = isFirst;
          _isAuthenticating = false;
          _isAuthenticated = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAuthenticating = false;
        });
      }
    }
  }

  void _navigateToListings() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ListingsPage(),
      ),
    );
  }

  void _retryAuthentication() {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/runway.png',
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'we are made - to - dream',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to SuperPull',
                      style: theme.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The independent fashion marketplace where emerging designers and collectors match.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_isAuthenticating) ...[
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authenticating...',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_error != null) ...[
                      const Icon(
                        Icons.error_outline,
                        color: AppTheme.primaryColor,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authentication Error',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _retryAuthentication,
                        child: const Text('Retry'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _isAuthenticated ? _navigateToListings : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.secondaryColor,
                        ),
                        child: const Text(
                          "Let's Pull",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 