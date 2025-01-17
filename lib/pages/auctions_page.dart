import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auctions_provider.dart';
import '../providers/token_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/auction_card.dart';
import '../models/auction.dart';
import '../models/token_metadata.dart';
import 'settings_page.dart';
import 'create_auction_page.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' show pi;

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
  TokenMetadata? _currentTokenMetadata;
  String? _walletAddress;
  StreamSubscription? _auctionSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    _pageController.addListener(_onPageChanged);
    _loadWalletAddress();
    
    // Initialize metadata for first auction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auctionsState = ref.read(auctionsProvider);
      auctionsState.whenOrNull(
        data: (auctions) async {
          if (auctions.isNotEmpty) {
            final auction = auctions[0];
            _currentAuctionId = auction.id;
            _currentTokenMint = auction.tokenMint;
            _updateTokenMetadata(auction.tokenMint);
          }
        },
      );
    });
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  Future<void> _updateTokenMetadata(String tokenMint) async {
    if (!mounted) return;
    
    // Get token metadata from cached state
    final tokensState = ref.read(acceptedTokensProvider);
    tokensState.whenOrNull(
      data: (tokens) {
        final metadata = tokens.firstWhere(
          (token) => token.mint == tokenMint,
          orElse: () => TokenMetadata(
            mint: tokenMint,
            name: 'Unknown Token',
            symbol: '',
            uri: '',
            decimals: 9,
            supply: '0',
          ),
        );
        if (mounted) {
          setState(() {
            _currentTokenMetadata = metadata;
          });
        }
      },
    );
  }

  void _onPageChanged() {
    if (!mounted) return;
    
    final page = _pageController.page?.round() ?? 0;
    if (_currentPage != page) {
      setState(() => _currentPage = page);
      
      final auctionsState = ref.read(auctionsProvider);
      auctionsState.whenOrNull(
        data: (auctions) async {
          if (auctions.isNotEmpty && page < auctions.length) {
            final auction = auctions[page];
            _currentAuctionId = auction.id;
            
            // Update token metadata if needed
            if (_currentTokenMint != auction.tokenMint) {
              _currentTokenMint = auction.tokenMint;
              _updateTokenMetadata(auction.tokenMint);
            }
          }
        },
      );
    }
  }

  Future<void> refreshBalancesForBid() async {
    if (!mounted) return;
    
    final auctionsState = ref.read(auctionsProvider);
    await auctionsState.whenOrNull(
      data: (auctions) async {
        if (auctions.isEmpty || _currentPage >= auctions.length) return;
        
        final auction = auctions[_currentPage];
        if (_currentTokenMint != auction.tokenMint) {
          _currentTokenMint = auction.tokenMint;
          _updateTokenMetadata(auction.tokenMint);
        }
      },
    );
  }

  void _updateCurrentAuctionId() {
    final auctionsState = ref.read(auctionsProvider);
    auctionsState.whenOrNull(
      data: (auctions) {
        if (auctions.isNotEmpty && _currentPage < auctions.length) {
          _currentAuctionId = auctions[_currentPage].id;
        }
      },
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

  void _showQrCode() {
    if (_walletAddress == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

  void _updateAuctionPosition() {
    if (!mounted || _currentAuctionId == null) return;
    
    final auctionsState = ref.read(auctionsProvider);
    auctionsState.whenOrNull(
      data: (auctions) {
        if (auctions.isEmpty) return;
        
        final newIndex = auctions.indexWhere((a) => a.id == _currentAuctionId);
        if (newIndex != -1 && newIndex != _currentPage) {
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          setState(() => _currentPage = newIndex);
        }
      },
    );
  }

  void _onBidPlaced() async {
    await refreshBalancesForBid();
    await ref.read(auctionsProvider.notifier).refreshAfterBid();
    _updateAuctionPosition();
  }

  void _onNewAuctionCreated() async {
    await ref.read(auctionsProvider.notifier).refreshAfterNewAuction();
  }

  void _onBidButtonPressed() async {
    await refreshBalancesForBid();
  }

  void _onAuctionSelected() {
    _updateCurrentAuctionId();
    refreshBalancesForBid();
  }

  @override
  Widget build(BuildContext context) {
    final auctionsState = ref.watch(auctionsProvider);
    final balanceState = ref.watch(balanceProvider);
    final currentTokenBalance = balanceState.whenOrNull(
      data: (balanceData) => _currentTokenMint != null 
        ? balanceData.tokenBalances[_currentTokenMint] ?? 0.0
        : null,
    );

    // Listen to auction changes and update position
    ref.listen(auctionsProvider, (previous, next) {
      if (previous != next) {
        _updateAuctionPosition();
      }
    });

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
                child: currentTokenBalance != null && _currentTokenMetadata != null
                  ? Text(
                      '${currentTokenBalance.toStringAsFixed(2)} ${_currentTokenMetadata!.symbol}',
                      style: const TextStyle(
                        color: Color(0xFFEEFC42),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : const Text(
                      '...',
                      style: TextStyle(
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
            color: Color(0xFFEEFC42),
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
      body: auctionsState.when(
        data: (auctions) {
          if (auctions.isEmpty) {
            return Center(
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
            );
          }

          // Find index of current auction after refresh
          if (_currentAuctionId != null) {
            final currentIndex = auctions.indexWhere((a) => a.id == _currentAuctionId);
            if (currentIndex == -1) {
              // If auction is no longer in the list, reset to current page
              _currentAuctionId = auctions[_currentPage].id;
              _currentTokenMint = auctions[_currentPage].tokenMint;
              _updateTokenMetadata(auctions[_currentPage].tokenMint);
            }
          } else if (_currentTokenMint == null) {
            refreshBalancesForBid();
            _updateCurrentAuctionId();
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    auctions.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                          ? const Color(0xFFEEFC42)
                          : Colors.white24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
          ),
        ),
        error: (error, _) => Center(
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
                  ref.read(auctionsProvider.notifier).refresh();
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
      floatingActionButton: AnimatedBuilder(
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
            child: const Icon(
              Icons.auto_awesome,
              size: 24,
            ),
          ),
          label: Row(
            children: [
              const Text(
                'Dream',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Transform.rotate(
                angle: -_animationController.value * 2 * pi,
                child: const Icon(
                  Icons.star,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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