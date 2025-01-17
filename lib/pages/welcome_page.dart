import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../providers/app_init_provider.dart';
import 'auctions_page.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
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
      final authService = AuthService();
      final walletService = WalletService();

      // Check if we already have a valid JWT
      final hasJwt = await authService.isAuthenticated();
      String? jwt;
      
      if (!hasJwt) {
        // Check if first time and create wallet if needed
        final isFirst = await walletService.isFirstTime();
        if (isFirst) {
          await walletService.createWallet();
          await walletService.setFirstTime(false);
        }

        // Authenticate with the server
        jwt = await authService.authenticate();
        if (jwt == null) {
          throw Exception('Authentication failed');
        }
      }

      if (mounted) {
        setState(() {
          _isFirstTime = !hasJwt;
          _isAuthenticating = false;
          _isAuthenticated = true;
        });
        
        // Start loading app data in the background only once after authentication
        ref.read(appInitProvider.future).catchError((error) {
          if (mounted) {
            setState(() {
              _error = 'Failed to initialize: $error';
              _isAuthenticated = false;
            });
          }
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

  void _navigateToAuctions() {
    // Data should already be initialized, just navigate
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuctionsPage(),
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
      backgroundColor: Colors.black,
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
                    color: const Color(0xFF1A1A1A),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Color(0xFFEEFC42),
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
                        color: const Color(0xFFEEFC42),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to SuperPull',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontSize: 36,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The independent fashion marketplace where emerging designers and collectors match.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        fontSize: 18,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_isAuthenticating) ...[
                      Center(
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authenticating...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_error != null) ...[
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEEFC42),
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Authentication Error',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                          fontSize: 18,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _retryAuthentication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFC42),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFFEEFC42).withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _isAuthenticated ? _navigateToAuctions : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFC42),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFFEEFC42).withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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