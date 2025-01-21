import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auctions_provider.dart';
import '../providers/token_provider.dart' as token_provider;
import '../providers/service_providers.dart';
import '../widgets/auction_card.dart';
import '../models/auction.dart';
import '../models/token_metadata.dart';
import 'settings_page.dart';
import 'create_auction_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../providers/creator_provider.dart';
import '../providers/token_tracking_provider.dart';

class AuctionsPage extends ConsumerStatefulWidget {
  const AuctionsPage({super.key});

  @override
  ConsumerState<AuctionsPage> createState() => _AuctionsPageState();
}

class _AuctionsPageState extends ConsumerState<AuctionsPage> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  int _currentPage = 0;
  String? _currentAuctionId;
  String? _currentTokenMint;
  String? _walletAddress;
  StreamSubscription? _auctionSubscription;
  String? _selectedTokenMint;
  int? _tokenDecimals;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    _loadWalletAddress();
    
    // Initialize metadata for first auction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auctionsState = ref.read(auctionsProvider);
      auctionsState.whenOrNull(
        data: (auctions) {
          if (auctions.isNotEmpty) {
            _currentAuctionId = auctions[0].id;
            _currentTokenMint = auctions[0].tokenMint;
            ref.read(token_provider.tokenStateProvider.notifier).updateCurrentAuctionToken(_currentTokenMint!);
          }
        },
      );
    });
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  void _updateForAuction(Auction auction) {
    if (!mounted) return;
    
    setState(() {
      _currentAuctionId = auction.id;
      _currentTokenMint = auction.tokenMint;
    });
    
    ref.read(token_provider.tokenStateProvider.notifier).updateCurrentAuctionToken(_currentTokenMint!);
  }

  @override
  Widget build(BuildContext context) {
    final auctionsState = ref.watch(auctionsProvider);
    final tokenState = ref.watch(token_provider.tokenStateProvider);
    
    return auctionsState.when(
      data: (auctions) {
        // Find index of current auction after refresh
        if (_currentAuctionId != null) {
          final currentIndex = auctions.indexWhere((a) => a.id == _currentAuctionId);
          if (currentIndex != -1 && currentIndex != _currentPage) {
            print('📱 Restoring auction position:');
            print('  - Current Auction ID: $_currentAuctionId');
            print('  - Found at index: $currentIndex');
            
            // Use post frame callback to avoid build phase animation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.animateToPage(
                currentIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        }

        // Get current auction and its token
        final currentAuction = auctions.isNotEmpty && _currentPage < auctions.length 
          ? auctions[_currentPage] 
          : null;
        
        if (currentAuction != null) {
          print('📱 Current auction in build:');
          print('  - Auction ID: ${currentAuction.id}');
          print('  - Token Mint: ${currentAuction.tokenMint}');
          print('  - Current Page: $_currentPage');
          print('  - Current Token Mint: $_currentTokenMint');
          
          // Track token
          ref.read(tokenTrackingProvider(currentAuction));
        }
        
        // Get current token balance
        double? currentTokenBalance;
        String? formattedBalance;
        
        // Only show balance when we have token state and current auction
        if (currentAuction != null && tokenState.tokens != null) {
          print('💰 Getting balance for token:');
          print('  - Token Mint: ${currentAuction.tokenMint}');
          print('  - Available Tokens: ${tokenState.tokens!.map((t) => t.mint).join(', ')}');
          print('  - Available Balances: ${tokenState.balances}');
          
          final token = tokenState.tokens!.firstWhere(
            (t) => t.mint == currentAuction.tokenMint,
            orElse: () {
              print('⚠️ Token not found in token state: ${currentAuction.tokenMint}');
              return TokenMetadata(
                mint: currentAuction.tokenMint,
                name: 'Unknown Token',
                symbol: '',
                uri: '',
                decimals: 0,
                supply: '0',
                balance: '0',
              );
            },
          );
          
          final balanceStr = tokenState.balances[currentAuction.tokenMint];
          print('  - Found Token: ${token.mint} (${token.symbol})');
          print('  - Balance String: $balanceStr');
          
          if (balanceStr != null) {
            final rawBalance = BigInt.tryParse(balanceStr) ?? BigInt.zero;
            final decimals = token.decimals;
            currentTokenBalance = rawBalance.toDouble() / pow(10, decimals);
            // Round to exact decimal places to avoid floating point errors
            final roundedBalance = (currentTokenBalance * pow(10, decimals)).round() / pow(10, decimals);
            formattedBalance = '${roundedBalance.toString().replaceAll(RegExp(r'\.?0*$'), '')} ${token.symbol}';
            print('  - Formatted Balance: $formattedBalance');
          }
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Image.asset(
              'assets/icons/logo.png',
              height: 32,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFC42).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: tokenState.error != null
                      ? const Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Text(
                          formattedBalance ?? '...',
                          style: const TextStyle(
                            color: Color(0xFFEEFC42),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code),
                color: const Color(0xFFEEFC42),
                onPressed: _showQrCode,
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Color(0xFFEEFC42)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
          body: auctions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_mall_outlined,
                      size: 64,
                      color: Color(0xFFEEFC42),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No auctions yet',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new items',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      print('📱 Page Changed:');
                      print('  - New Page: $page');
                      print('  - Old Page: $_currentPage');
                      
                      setState(() => _currentPage = page);
                      final auction = auctions[page];
                      print('  - New Auction ID: ${auction.id}');
                      print('  - New Token Mint: ${auction.tokenMint}');
                      _updateForAuction(auction);
                    },
                    itemCount: auctions.length,
                    itemBuilder: (context, index) {
                      final auction = auctions[index];
                      return AuctionCard(auction: auction);
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const dotWidth = 10.0;
                            const selectedDotWidth = 14.0;
                            const dotMargin = 8.0; // 4.0 on each side
                            final availableWidth = constraints.maxWidth;
                            final maxDots = ((availableWidth + dotMargin) / (selectedDotWidth + dotMargin)).floor();
                            final totalDots = auctions.length;
                            final visibleDots = min(maxDots, totalDots);
                            
                            int startIndex;
                            if (visibleDots >= totalDots) {
                              startIndex = 0;
                            } else {
                              final halfVisible = visibleDots ~/ 2;
                              startIndex = max(0, min(_currentPage - halfVisible, totalDots - visibleDots));
                            }
                            final endIndex = min(startIndex + visibleDots, totalDots);
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = startIndex; i < endIndex; i++)
                                  Container(
                                    width: i == _currentPage ? selectedDotWidth : dotWidth,
                                    height: i == _currentPage ? selectedDotWidth : dotWidth,
                                    margin: const EdgeInsets.symmetric(horizontal: dotMargin / 2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: (!auctions[i].hasReachedMaxSupply && auctions[i].isGraduated) 
                                        ? LinearGradient(
                                            colors: [
                                              auctions[i].isEnded
                                                ? Colors.red.withOpacity(i == _currentPage ? 1.0 : 0.5)
                                                : const Color(0xFFEEFC42).withOpacity(i == _currentPage ? 1.0 : 0.5),
                                              Colors.green.withOpacity(i == _currentPage ? 1.0 : 0.5),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                      color: auctions[i].hasReachedMaxSupply 
                                        ? Colors.black.withOpacity(i == _currentPage ? 1.0 : 0.5)
                                        : (!auctions[i].hasReachedMaxSupply && !auctions[i].isGraduated)
                                          ? _getDotColor(auctions[i]).withOpacity(i == _currentPage ? 1.0 : 0.5)
                                          : null,
                                    ),
                                  ),
                              ],
                            );
                          }
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          floatingActionButton: ref.watch(isAllowedCreatorProvider).when(
            data: (isCreator) => isCreator ? AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateAuctionPage()),
                  );
                },
                backgroundColor: const Color(0xFFEEFC42),
                foregroundColor: Colors.black,
                elevation: 4 + (_animationController.value * 4), // Animated elevation
                extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.5 + _animationController.value * 0.5),
                    width: 2,
                  ),
                ),
                icon: Transform.rotate(
                  angle: _animationController.value * 2 * pi,
                  child: const Icon(Icons.add),
                ),
                label: const Text(
                  'Dream',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ) : null,
            loading: () => null,
            error: (_, __) => null,
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFEEFC42),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load auctions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ref.read(auctionsOperationsProvider).refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEFC42),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDotColor(Auction auction) {
    if (auction.hasReachedMaxSupply) {
      return Colors.black;
    }
    if (auction.isGraduated) {
      return Colors.green; // This won't be used directly, gradient is used instead
    }
    switch (auction.status) {
      case 'Active':
        return const Color(0xFFEEFC42); // Yellow
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.white24;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _auctionSubscription?.cancel();
    super.dispose();
  }

  Widget _buildTokenSelector() {
    final tokenService = ref.watch(tokenServiceProvider);
    final tokens = tokenService.cachedTokens;
    
    if (tokens == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedTokenMint,
      decoration: const InputDecoration(
        labelText: 'Token',
        labelStyle: TextStyle(color: Colors.white),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEEFC42)),
        ),
      ),
      dropdownColor: Colors.black,
      style: const TextStyle(color: Colors.white),
      items: tokens.map((token) {
        return DropdownMenuItem<String>(
          value: token.mint,
          child: Text(token.mint),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedTokenMint = newValue;
            _tokenDecimals = tokens
                .firstWhere((token) => token.mint == newValue)
                .decimals;
          });
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a token';
        }
        return null;
      },
    );
  }

  void _showQrCode() {
    if (_walletAddress == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wallet Address',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: const Color(0xFFEEFC42),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _walletAddress!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEFC42).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _walletAddress!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _walletAddress!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Address copied to clipboard'),
                          backgroundColor: Colors.black,
                        ),
                      );
                    },
                    tooltip: 'Copy address',
                    color: const Color(0xFFEEFC42),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _loadWalletAddress() async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final address = await walletService.getWalletAddress();
      setState(() {
        _walletAddress = address;
      });
    } catch (e) {
      print('Error loading wallet address: $e');
    }
  }
}

class _BidStatusDialog extends StatefulWidget {
  final String initialStatus;

  const _BidStatusDialog({
    required Key key,
    required this.initialStatus,
  }) : super(key: key);

  @override
  State<_BidStatusDialog> createState() => _BidStatusDialogState();
}

class _BidStatusDialogState extends State<_BidStatusDialog> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  void updateStatus(String newStatus) {
    setState(() {
      _status = newStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 