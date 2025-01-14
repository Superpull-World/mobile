import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auctions_provider.dart';
import '../widgets/auction_card.dart';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../services/bid_service.dart';
import '../models/auction.dart';
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
  final _balanceService = BalanceService();
  double? _tokenBalance;
  String? _currentTokenMint;
  final WalletService _walletService = WalletService();
  String? _walletAddress;
  Timer? _refreshTimer;
  bool _isBidding = false;

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
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isBidding) {
        ref.read(auctionsProvider.notifier).refresh();
      }
    });
  }

  Future<void> _initializeBalanceService() async {
    final keypair = await WalletService().getKeypair();
    if (keypair != null) {
      await _balanceService.initialize(keypair);
    }
  }

  Future<void> _updateBalanceForCurrentAuction() async {
    final auctionsState = ref.read(auctionsProvider);
    
    if (!mounted) return;
    
    await auctionsState.whenOrNull(
      data: (auctions) async {
        if (auctions.isEmpty || _currentPage >= auctions.length) {
          setState(() {
            _tokenBalance = null;
            _currentTokenMint = null;
          });
          return;
        }

        final auction = auctions[_currentPage];
        if (auction.tokenMint != _currentTokenMint) {
          try {
            final balance = await _balanceService.getTokenBalance(auction.tokenMint);
            if (mounted) {
              setState(() {
                _tokenBalance = balance;
                _currentTokenMint = auction.tokenMint;
              });
            }
          } catch (e) {
            print('Error fetching balance: $e');
            if (mounted) {
              setState(() {
                _tokenBalance = null;
                _currentTokenMint = null;
              });
            }
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
    setState(() => _isBidding = true);

    // First show the confirmation modal
    final shouldBid = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confirm Bid',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFFEEFC42)),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You are about to bid on:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              auction.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEFC42).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Price:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '${auction.currentPrice.toStringAsFixed(2)} TOKEN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEFC42),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              child: const Text(
                'Place Bid',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (shouldBid != true || !context.mounted) {
      setState(() => _isBidding = false);
      return;
    }

    // Then show the bid status overlay
    try {
      final bidService = BidService();
      final statusNotifier = ValueNotifier<String>('Initializing bid...');
      
      final overlayState = Overlay.of(context);
      final overlayEntry = OverlayEntry(
        builder: (context) => Material(
          color: Colors.black54,
          child: Center(
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
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (context, status, _) => Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlayState.insert(overlayEntry);

      try {
        await bidService.startPlaceBidWorkflow(
          auctionAddress: auction.id,
          bidAmount: auction.currentPrice,
          onStatusUpdate: (status) {
            if (!context.mounted) return;
            
            statusNotifier.value = status;
            
            if (status == 'Bid placed successfully') {
              overlayEntry.remove();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bid placed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              setState(() => _isBidding = false);
              ref.read(auctionsProvider.notifier).refresh();
            }
          },
        );
      } catch (e) {
        overlayEntry.remove();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to place bid: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isBidding = false);
        }
      } finally {
        statusNotifier.dispose();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place bid: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isBidding = false);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
                child: _tokenBalance != null
                  ? Text(
                      '${_tokenBalance!.toStringAsFixed(2)} TOKEN',
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

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: auctions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: AuctionCard(
                      auction: auctions[index],
                    ),
                  );
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
        error: (error, stack) => Center(
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