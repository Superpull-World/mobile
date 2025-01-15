import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auctions_provider.dart';
import '../widgets/auction_card.dart';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../services/bid_service.dart';
import '../services/token_service.dart';
import '../services/workflow_service.dart';
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
  final _balanceService = BalanceService();
  final _workflowService = WorkflowService();
  late final _tokenService = TokenService(workflowService: _workflowService);
  double? _tokenBalance;
  String? _currentTokenMint;
  TokenMetadata? _currentTokenMetadata;
  final WalletService _walletService = WalletService();
  String? _walletAddress;
  Timer? _refreshTimer;
  Timer? _balanceUpdateTimer;

  // Refresh every 3 seconds
  static const Duration _refreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        _updateCurrentAuctionId();
        _updateBalanceForCurrentAuction();
      }
    });
    _initializeBalanceService();
    _loadWalletAddress();
    _startPeriodicRefresh();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Start periodic balance refresh with proper cleanup
    _balanceUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateBalanceForCurrentAuction();
      }
    });
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

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      ref.read(auctionsProvider.notifier).refresh();
    });
  }

  Future<void> _initializeBalanceService() async {
    final keypair = await WalletService().getKeypair();
    if (keypair != null) {
      await _balanceService.initialize(keypair);
    }
  }

  Future<void> _updateBalanceForCurrentAuction() async {
    if (!mounted) return;
    
    final auctionsState = ref.read(auctionsProvider);
    
    await auctionsState.whenOrNull(
      data: (auctions) async {
        if (!mounted) return;
        
        if (auctions.isEmpty || _currentPage >= auctions.length) {
          setState(() {
            _tokenBalance = null;
            _currentTokenMint = null;
            _currentTokenMetadata = null;
          });
          return;
        }

        final auction = auctions[_currentPage];
        try {
          final balance = await _balanceService.getTokenBalance(auction.tokenMint);
          if (!mounted) return;
          
          final tokens = await _tokenService.getAcceptedTokens();
          if (!mounted) return;
          
          final tokenMetadata = tokens.firstWhere(
            (token) => token.mint == auction.tokenMint,
            orElse: () => const TokenMetadata(
              mint: '',
              name: 'Unknown Token',
              symbol: '',
              uri: '',
              decimals: 9,
              supply: '0',
            ),
          );
          
          if (mounted) {
            setState(() {
              _tokenBalance = balance;
              _currentTokenMint = auction.tokenMint;
              _currentTokenMetadata = tokenMetadata;
            });
          }
        } catch (e) {
          print('Error fetching balance or token metadata: $e');
          if (mounted) {
            setState(() {
              _tokenBalance = null;
              _currentTokenMint = null;
              _currentTokenMetadata = null;
            });
          }
        }
      },
    );
  }

  Future<void> _loadWalletAddress() async {
    try {
      final address = await _walletService.getWalletAddress();
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

  Future<void> _showBidConfirmation(BuildContext context, Auction auction) async {
    try {
      final bidService = BidService();
      final tokenService = TokenService(workflowService: _workflowService);
      
      // Get token metadata
      final tokens = await tokenService.getAcceptedTokens();
      final tokenMetadata = tokens.firstWhere(
        (token) => token.mint == auction.tokenMint,
        orElse: () => TokenMetadata(
          mint: auction.tokenMint,
          name: 'Unknown Token',
          symbol: '',
          uri: '',
          decimals: 9,
          supply: '0',
        ),
      );
      
      // Create a GlobalKey to access the dialog's state
      final statusDialogKey = GlobalKey<_BidStatusDialogState>();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BidStatusDialog(
          key: statusDialogKey,
          initialStatus: 'Initializing bid...',
        ),
      );

      await bidService.startPlaceBidWorkflow(
        auctionAddress: auction.id,
        bidAmount: auction.currentPrice,
        tokenMetadata: tokenMetadata,
        onStatusUpdate: (status) {
          if (!context.mounted) return;
          
          // Update the existing dialog's status
          statusDialogKey.currentState?.updateStatus(status);
          
          if (status == 'Bid placed successfully') {
            Navigator.of(context).pop(); // Close status dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bid placed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            ref.read(auctionsProvider.notifier).refresh();
            // Add delay before updating balance to ensure blockchain state is updated
            Future.delayed(const Duration(seconds: 1), () {
              _updateBalanceForCurrentAuction();
            });
          }
        },
      );

      // Update balance after workflow completes successfully
      _updateBalanceForCurrentAuction();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close status dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place bid: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _balanceUpdateTimer?.cancel();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auctionsState = ref.watch(auctionsProvider);

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
                child: _tokenBalance != null && _currentTokenMint != null
                  ? FutureBuilder<List<TokenMetadata>>(
                      future: _tokenService.getAcceptedTokens(),
                      builder: (context, snapshot) {
                        String symbol = '';
                        if (snapshot.hasData) {
                          final tokenMetadata = snapshot.data!.firstWhere(
                            (token) => token.mint == _currentTokenMint,
                            orElse: () => TokenMetadata(
                              mint: _currentTokenMint!,
                              name: 'Unknown Token',
                              symbol: '',
                              uri: '',
                              decimals: 9,
                              supply: '0',
                            ),
                          );
                          symbol = tokenMetadata.symbol;
                        }
                        return Text(
                          '${_tokenBalance!.toStringAsFixed(2)} $symbol',
                          style: const TextStyle(
                            color: Color(0xFFEEFC42),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
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
            if (currentIndex != -1 && currentIndex != _currentPage) {
              // Update page without animation if position changed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _pageController.jumpToPage(currentIndex);
                setState(() => _currentPage = currentIndex);
              });
            }
          } else if (_currentTokenMint == null) {
            _updateBalanceForCurrentAuction();
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