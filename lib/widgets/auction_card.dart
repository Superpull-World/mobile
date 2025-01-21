import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../models/auction.dart';
import '../providers/token_provider.dart';
import '../providers/auctions_provider.dart';
import '../services/bid_service.dart';
import '../services/wallet_service.dart';
import '../providers/wallet_provider.dart';
import '../services/withdraw_service.dart';
import '../providers/withdraw_provider.dart';
import '../services/auth_service.dart';

class SupplyPainter extends CustomPainter {
  final int currentSupply;
  final int minSupply;
  final int maxSupply;

  SupplyPainter({
    required this.currentSupply,
    required this.minSupply,
    required this.maxSupply,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background (max supply)
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawArc(rect, -pi/2, 2 * pi, true, bgPaint);

    // Draw minimum target section in green
    if (currentSupply < minSupply) {
      final minPaint = Paint()
        ..color = Colors.green.withOpacity(0.24)
        ..style = PaintingStyle.fill;
      final minSweep = (minSupply / maxSupply) * 2 * pi;
      canvas.drawArc(rect, -pi/2, minSweep, true, minPaint);
    }

    // Draw current supply in yellow
    if (currentSupply > 0) {
      final currentPaint = Paint()
        ..color = const Color(0xFFEEFC42)
        ..style = PaintingStyle.fill;
      final currentSweep = (currentSupply / maxSupply) * 2 * pi;
      canvas.drawArc(rect, -pi/2, currentSweep, true, currentPaint);
    }

    // Draw center hole
    final holePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, holePaint);
  }

  @override
  bool shouldRepaint(SupplyPainter oldDelegate) {
    return oldDelegate.currentSupply != currentSupply ||
           oldDelegate.minSupply != minSupply ||
           oldDelegate.maxSupply != maxSupply;
  }
}

class AuctionCard extends ConsumerStatefulWidget {
  final Auction auction;

  const AuctionCard({
    super.key,
    required this.auction,
  });

  @override
  ConsumerState<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends ConsumerState<AuctionCard> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  double _dragExtent = 0;
  static const _dragThreshold = 100.0;
  late final AnimationController _arrowAnimationController;
  late final Animation<double> _arrowAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isLoading = false;
  String? _currentWalletAddress;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _arrowAnimation = Tween<double>(
      begin: 0,
      end: 24,
    ).animate(CurvedAnimation(
      parent: _arrowAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _arrowAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _loadWalletAddress();
  }

  Future<void> _loadWalletAddress() async {
    try {
      final walletService = ref.read(walletProvider);
      final address = await walletService.getWalletAddress();
      if (mounted) {
        setState(() {
          _currentWalletAddress = address;
        });
      }
    } catch (e) {
      print('Error loading wallet address: $e');
    }
  }

  bool get _isAuthorityAndGraduated {
    return widget.auction.isGraduated && 
           _currentWalletAddress != null && 
           widget.auction.authority == _currentWalletAddress &&
           double.parse(widget.auction.totalValueLocked) > 0;
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _showBidConfirmation() async {
    if (!mounted) return;

    final token = ref.read(tokenByMintProvider(widget.auction.tokenMint));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final token = ref.watch(tokenByMintProvider(widget.auction.tokenMint));
          final rawTokenBalance = BigInt.tryParse(token.balance) ?? BigInt.zero;
          final hasEnoughBalance = rawTokenBalance >= BigInt.parse(widget.auction.rawCurrentPrice.toString());

          // Calculate difference in raw values and format for display
          final rawDifference = BigInt.parse(widget.auction.rawCurrentPrice.toString()) - rawTokenBalance;
          final formattedBalance = (rawTokenBalance.toDouble() / pow(10, token.decimals)).toString().replaceAll(RegExp(r'\.?0*$'), '');
          final formattedDifference = (rawDifference.toDouble() / pow(10, token.decimals)).toString().replaceAll(RegExp(r'\.?0*$'), '');
          
          print('🔍 AuctionCard Debug:');
          print('Token Decimals: ${token.decimals}');
          print('Raw Current Price: ${widget.auction.rawCurrentPrice}');
          print('Current Price String: ${widget.auction.currentPrice}');
          print('Raw Token Balance: $rawTokenBalance');
          print('Raw Difference: $rawDifference');
          print('Formatted Balance: $formattedBalance');
          print('Formatted Difference: $formattedDifference');

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ready to Dream?',
                      style: TextStyle(
                        color: Color(0xFFEEFC42),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEFC42).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price & Balance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Price',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.auction.currentPrice} ${token.symbol}',
                            style: const TextStyle(
                              color: Color(0xFFEEFC42),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$formattedBalance ${token.symbol}',
                            style: TextStyle(
                              color: hasEnoughBalance ? const Color(0xFFEEFC42) : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Post-Bid Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${((BigInt.tryParse(token.balance) ?? BigInt.zero) - BigInt.parse(widget.auction.rawCurrentPrice.toString())).toDouble() / pow(10, token.decimals)} ${token.symbol}',
                            style: TextStyle(
                              color: hasEnoughBalance ? Colors.white70 : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!hasEnoughBalance) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Insufficient Balance',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You need $formattedDifference ${token.symbol} more to place this bid.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Top-up feature coming soon')),
                      );
                    },
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Top Up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEFC42),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else if (widget.auction.currentSupply >= widget.auction.maxSupply) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Maximum Supply Reached',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This item has reached its maximum supply of ${widget.auction.maxSupply} items.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      try {
                        setState(() {
                          _isLoading = true;
                        });
                        
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: Card(
                              color: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Making it Real...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        
                        final bidService = BidService(ref: ref);
                        await bidService.placeBid(widget.auction);
                        
                        if (!mounted) return;
                        
                        // Close loading dialog
                        Navigator.pop(context);
                        
                        // Close bid confirmation dialog immediately
                        Navigator.pop(context);
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Bid placed successfully!')),
                        );
                        
                        // Force refresh both providers
                        await Future.wait([
                          ref.read(auctionsOperationsProvider).refresh(),
                          ref.read(tokenStateProvider.notifier).refresh(),
                        ]);
                      } catch (e) {
                        if (!mounted) return;
                        
                        // Close loading dialog if open
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error placing bid: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEFC42),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Make it Real'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWithdrawConfirmation() async {
    if (!mounted) return;

    final token = ref.read(tokenByMintProvider(widget.auction.tokenMint));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Withdraw Auction',
                  style: TextStyle(
                    color: Color(0xFFEEFC42),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEFC42).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auction Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Name',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.auction.name,
                        style: const TextStyle(
                          color: Color(0xFFEEFC42),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Value Locked',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.auction.totalValueLocked} ${token.symbol}',
                        style: const TextStyle(
                          color: Color(0xFFEEFC42),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: Card(
                        color: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Processing Withdrawal...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  // Execute withdraw workflow
                  final withdrawService = ref.read(withdrawServiceProvider(ref));
                  final authService = AuthService();
                  final jwt = await authService.getStoredJwt();
                  if (jwt == null) throw Exception('Please authenticate first');
                  await withdrawService.withdrawAuction(widget.auction, jwt);

                  if (!mounted) return;

                  // Close loading dialog
                  Navigator.pop(context);
                  // Close confirmation dialog
                  Navigator.pop(context);

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Auction withdrawn successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Force refresh providers
                  await Future.wait([
                    ref.read(auctionsOperationsProvider).refresh(),
                    ref.read(tokenStateProvider.notifier).refresh(),
                  ]);
                } catch (e) {
                  if (!mounted) return;

                  // Close loading dialog if open
                  Navigator.pop(context);
                  // Close confirmation dialog
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error processing withdrawal: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEFC42),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Confirm Withdrawal'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Graduated':
        return Colors.green;
      case 'Active':
        return const Color(0xFFEEFC42);
      default:
        return Colors.red;
    }
  }

  double _getTimeProgress() {
    final now = DateTime.now();
    final end = widget.auction.saleEndDate;
    final duration = end.difference(now);
    
    // If past deadline, return 1.0 (100%)
    if (duration.isNegative) return 1.0;
    
    // Calculate progress based on a 24-hour window
    const totalDuration = Duration(hours: 24);
    final progress = 1.0 - (duration.inMilliseconds / totalDuration.inMilliseconds);
    
    // Clamp between 0 and 1
    return progress.clamp(0.0, 1.0);
  }

  String _formatTimeRemaining() {
    final now = DateTime.now();
    final end = widget.auction.saleEndDate;
    final duration = end.difference(now);
    
    if (duration.isNegative) return 'Ended';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    } else if (minutes > 0) {
      return '${minutes}m left';
    } else {
      return 'Ending soon';
    }
  }

  Widget _buildSupplyIndicator(double size) {
    final currentSupply = widget.auction.currentSupply;
    final minSupply = widget.auction.minimumItems;
    final maxSupply = widget.auction.maxSupply;
    final token = ref.watch(tokenByMintProvider(widget.auction.tokenMint));

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: SupplyPainter(
            currentSupply: currentSupply,
            minSupply: minSupply,
            maxSupply: maxSupply,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.auction.status,
              style: TextStyle(
                color: _getStatusColor(widget.auction.status),
                fontSize: size * 0.09,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: size * 0.02),
            Text(
              '$currentSupply/$maxSupply',
              style: TextStyle(
                color: Colors.white54,
                fontSize: size * 0.07,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(tokenByMintProvider(widget.auction.tokenMint));
    final theme = Theme.of(context);
    
    print('🎯 AuctionCard build:');
    print('  - Auction ID: ${widget.auction.id}');
    print('  - Token Mint: ${widget.auction.tokenMint}');
    print('  - Found Token: ${token.symbol}');
    
    return GestureDetector(
      onTap: _showBidConfirmation,
      onVerticalDragStart: (_) {
        setState(() {
          _isDragging = true;
          _dragExtent = 0;
        });
        _arrowAnimationController.stop();
      },
      onVerticalDragUpdate: (details) {
        if (!_isDragging) return;
        setState(() {
          _dragExtent += details.primaryDelta ?? 0;
          if (_dragExtent < 0) _dragExtent = 0;
        });
      },
      onVerticalDragEnd: (_) {
        if (_dragExtent >= _dragThreshold) {
          _showBidConfirmation();
        }
        setState(() {
          _isDragging = false;
          _dragExtent = 0;
        });
        _arrowAnimationController.repeat();
      },
      child: Stack(
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            clipBehavior: Clip.antiAlias,
            color: const Color(0xFF1A1A1A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      if (widget.auction.imageUrl.isEmpty)
                        Container(
                          color: const Color(0xFFEEFC42).withOpacity(0.1),
                          child: const Center(
                            child: Text(
                              '🛍️',
                              style: TextStyle(
                                fontSize: 64,
                              ),
                            ),
                          ),
                        )
                      else
                        Image.network(
                          widget.auction.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFEEFC42).withOpacity(0.1),
                              child: const Center(
                                child: Text(
                                  '🛍️',
                                  style: TextStyle(
                                    fontSize: 64,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      if (_isAuthorityAndGraduated)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: GestureDetector(
                            onTap: _showWithdrawConfirmation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Withdraw Now',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFC42),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${widget.auction.currentPrice} ${token.symbol}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.auction.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          final url = 'https://explorer.solana.com/address/${widget.auction.id}';
                          launchUrl(Uri.parse(url));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link,
                              size: 16,
                              color: Color(0xFFEEFC42),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.auction.id.substring(0, 4)}...${widget.auction.id.substring(widget.auction.id.length - 4)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFEEFC42),
                                decoration: TextDecoration.underline,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Color(0xFFEEFC42),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.auction.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Min/Max/Current indicators in compact form
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Base price row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'BASE: ${(widget.auction.rawBasePrice / pow(10, token.decimals)).toStringAsFixed(2)} ${token.symbol}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Min/Current/Max row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Min indicator
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MIN',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      ((widget.auction.minimumItems * widget.auction.rawBasePrice + 
                                          (widget.auction.rawPriceIncrement * (widget.auction.minimumItems * (widget.auction.minimumItems - 1)) / 2)) / 
                                          pow(10, token.decimals)).toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // Current indicator
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        color: Color(0xFFEEFC42),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      ((widget.auction.currentSupply * widget.auction.rawBasePrice + 
                                          (widget.auction.rawPriceIncrement * (widget.auction.currentSupply * (widget.auction.currentSupply - 1)) / 2)) / 
                                          pow(10, token.decimals)).toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Color(0xFFEEFC42),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                // Max indicator
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'MAX',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      ((widget.auction.maxSupply * widget.auction.rawBasePrice + 
                                          (widget.auction.rawPriceIncrement * (widget.auction.maxSupply * (widget.auction.maxSupply - 1)) / 2)) / 
                                          pow(10, token.decimals)).toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxWidth * 0.7;
                          return Center(
                            child: SizedBox(
                              height: size,
                              width: size,
                              child: _buildSupplyIndicator(size),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Deadline progress indicator
                      Stack(
                        children: [
                          LinearProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
                          ),
                          LinearProgressIndicator(
                            value: _getTimeProgress(),
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getTimeProgress() >= 0.75 ? Colors.red : const Color(0xFFEEFC42),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTimeRemaining(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getTimeProgress() >= 0.75 ? Colors.red : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!_isDragging)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AnimatedBuilder(
                      animation: _arrowAnimationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _arrowAnimation.value),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 24,
                                  color: Color(0xFFEEFC42),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Pull',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFEEFC42),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(
                  (_dragExtent / _dragThreshold * 0.5).clamp(0.0, 0.5),
                ),
                child: Center(
                  child: Text(
                    'Pull to bid',
                    style: TextStyle(
                      color: Colors.white.withOpacity(
                        (_dragExtent / _dragThreshold).clamp(0.0, 1.0),
                      ),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 