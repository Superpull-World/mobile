import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../providers/app_init_provider.dart';
import '../providers/service_providers.dart';
import 'auctions_page.dart';
import '../providers/creator_provider.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _isAuthenticating = true;
  bool _isFirstTime = true;
  bool _isAuthenticated = false;
  bool _hasCompletedFirstInit = false;
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
      } else {
        // If we already have a valid JWT, fetch it for initialization
        jwt = await authService.getStoredJwt();
      }

      // Ensure we have a valid JWT before proceeding
      if (jwt == null) {
        throw Exception('Authentication failed: No JWT available');
      }
      
      // Update authentication status in the provider
      ref.read(isAuthenticatedProvider.notifier).state = true;
      
      // Important: Make sure creator provider is initialized after we have a valid JWT
      // This will prevent the race condition
      if (mounted) {
        ref.read(creatorStateProvider.notifier).initialize();
      }

      // Update state
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
          _isFirstTime = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAuthenticating = false;
          
          // Ensure authentication status is set to false
          ref.read(isAuthenticatedProvider.notifier).state = false;
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

  void _retryAuthentication() async {
    // Reset authentication state
    ref.read(isAuthenticatedProvider.notifier).state = false;
    
    // Reset the app init provider to force it to retry
    ref.invalidate(appInitProvider);
    
    // Reset local state
    setState(() {
      _isAuthenticating = true;
      _error = null;
      _hasCompletedFirstInit = false;
    });
    
    try {
      // Use force reauthentication for a more thorough retry
      final authService = AuthService();
      final jwt = await authService.forceReauthenticate();
      
      if (jwt == null) {
        throw Exception('Retry authentication failed');
      }
      
      // Update authentication status in the provider
      ref.read(isAuthenticatedProvider.notifier).state = true;
      
      // Initialize creator service
      ref.read(creatorStateProvider.notifier).initialize();
      
      // Update state
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
          _isFirstTime = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Retry failed: ${e.toString()}';
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appInit = ref.watch(appInitProvider);
    final tokenService = ref.watch(tokenServiceProvider);

    // Check if initialization is complete
    final tokens = tokenService.cachedTokens;
    final isInitialized = _isAuthenticated && !_isAuthenticating && (_hasCompletedFirstInit || appInit.whenOrNull(
      data: (_) {
        if (!_hasCompletedFirstInit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasCompletedFirstInit = true;
              });
            }
          });
        }
        return true;
      },
      loading: () => false,
      error: (error, _) {
        if (mounted && _error == null && error is! AsyncLoading) {
          setState(() {
            _error = 'Failed to initialize app: $error';
            _isAuthenticated = false;
          });
        }
        return false;
      },
    ) == true);

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
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Experience the future of fashion.\nBid on exclusive drops from your favorite creators.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retryAuthentication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFC42),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ] else if (_isAuthenticating) ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connecting to the runway...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (!isInitialized) ...[
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(seconds: 2),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparing your exclusive experience...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _navigateToAuctions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFC42),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(200, 48),
                          textStyle: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text("Let's Pull"),
                      ),
                    ],
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