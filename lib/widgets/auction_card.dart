import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction.dart';
import '../theme/app_theme.dart';
import '../models/token_metadata.dart';
import '../models/balance_data.dart';
import '../providers/token_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auctions_provider.dart';
import '../services/bid_service.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

class AuctionCard extends ConsumerStatefulWidget {
  final Auction auction;

  const AuctionCard({super.key, required this.auction});

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
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _showBidConfirmation() async {
    if (!mounted) return;

    // Start balance refresh in the background before showing the modal
    Future.microtask(() async {
      try {
        final balanceService = ref.read(balanceServiceProvider);
        await balanceService.getBalances(forceRefresh: true);
      } catch (e) {
        print('❌ Error refreshing balance before bid: $e');
      }
    });

    final tokenMetadata = ref.read(tokenByMintProvider(widget.auction.tokenMint));
    final metadata = tokenMetadata ?? TokenMetadata(
      mint: widget.auction.tokenMint,
      name: 'Unknown Token',
      symbol: '',
      uri: '',
      decimals: widget.auction.decimals,
      supply: '0',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final balanceState = ref.watch(balanceProvider);
          final tokenMetadata = ref.watch(tokenByMintProvider(widget.auction.tokenMint));
          
          return balanceState.when(
            data: (balanceData) {
              final tokenBalance = (balanceData as BalanceData).tokenBalances[widget.auction.tokenMint] ?? 0.0;
              
              print('🔍 AuctionCard Debug:');
              print('Token Decimals: ${metadata.decimals}');
              print('Raw Current Price: ${widget.auction.rawCurrentPrice}');
              print('Current Price String: ${widget.auction.currentPrice}');
              print('Token Balance Raw: ${(tokenBalance * pow(10, metadata.decimals)).round()}');
              
              // Calculate raw values using the raw price from auction
              final rawTokenBalance = (tokenBalance * pow(10, metadata.decimals)).round();
              final hasEnoughBalance = rawTokenBalance >= widget.auction.rawCurrentPrice;

              // Calculate difference in raw values and format for display
              final rawDifference = widget.auction.rawCurrentPrice - rawTokenBalance;
              final formattedBalance = (rawTokenBalance / pow(10, metadata.decimals)).toString().replaceAll(RegExp(r'\.?0*$'), '');
              final formattedDifference = (rawDifference / pow(10, metadata.decimals)).toString().replaceAll(RegExp(r'\.?0*$'), '');
              
              print('Raw Token Balance: $rawTokenBalance');
              print('Raw Difference: $rawDifference');
              print('Formatted Balance: $formattedBalance');
              print('Formatted Difference: $formattedDifference');

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          style: TextStyle(
                            color: Color(0xFFEEFC42),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFEEFC42)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You are about to bid on:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.auction.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFEEFC42).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current Price:', style: TextStyle(color: Colors.white70)),
                              Text(
                                '${widget.auction.currentPrice} ${metadata.symbol}',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Your Balance:', style: TextStyle(color: Colors.white70)),
                              Text(
                                '$formattedBalance ${metadata.symbol}',
                                style: TextStyle(
                                  color: hasEnoughBalance ? Color(0xFFEEFC42) : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!hasEnoughBalance) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Insufficient balance',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need $formattedDifference ${metadata.symbol} to place this bid.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Top-up feature coming soon')),
                          );
                        },
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Top Up Wallet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFEEFC42),
                          foregroundColor: Colors.black,
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
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
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
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      Consumer(
                        builder: (context, ref, _) {
                          return ElevatedButton(
                            onPressed: () async {
                              try {
                                // Show loading state
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.black,
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Placing your bid...',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                final bidService = BidService(ref: ref);
                                await bidService.placeBid(widget.auction);

                                // Store refs before the async gap
                                final auctionsNotifier = ref.read(auctionsProvider.notifier);
                                final balanceNotifier = ref.read(balanceProvider.notifier);

                                if (mounted) {
                                  // First refresh the data
                                  await auctionsNotifier.refreshAfterBid();
                                  await balanceNotifier.refresh();

                                  // Then close the dialogs and show success message
                                  Navigator.pop(context); // Close loading dialog
                                  Navigator.pop(context); // Close bid confirmation modal
                                  
                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bid placed successfully')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  Navigator.pop(context); // Close loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to place bid: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFEEFC42),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Place Bid'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(child: Text('Error loading balance')),
          );
        },
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

  @override
  Widget build(BuildContext context) {
    final tokenMetadata = ref.watch(tokenByMintProvider(widget.auction.tokenMint));
    final metadata = tokenMetadata ?? TokenMetadata(
      mint: widget.auction.tokenMint,
      name: 'Unknown Token',
      symbol: '',
      uri: '',
      decimals: widget.auction.decimals,
      supply: '0',
    );
    final theme = Theme.of(context);
    
    print('🔍 AuctionCard Build Debug:');
    print('Token Decimals: ${metadata.decimals}');
    print('Raw Current Price: ${widget.auction.rawCurrentPrice}');
    print('Current Price String: ${widget.auction.currentPrice}');
    print('Token Metadata: $metadata');
    
    return GestureDetector(
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
          if (_dragExtent > _dragThreshold) _dragExtent = _dragThreshold;
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
        _arrowAnimationController.repeat(reverse: true);
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEFC42),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.auction.currentPrice} ${metadata.symbol}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'ID: ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final url = 'https://explorer.solana.com/address/${widget.auction.id}';
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  '${widget.auction.id.substring(0, 4)}...${widget.auction.id.substring(widget.auction.id.length - 4)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFEEFC42),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.open_in_new,
                                  size: 14,
                                  color: Color(0xFFEEFC42),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                      Stack(
                        children: [
                          LinearProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
                          ),
                          LinearProgressIndicator(
                            value: widget.auction.minimumItems / widget.auction.maxSupply,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                          LinearProgressIndicator(
                            value: widget.auction.currentSupply / widget.auction.maxSupply,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.auction.status == 'Graduated' 
                                ? Colors.green 
                                : const Color(0xFFEEFC42),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.auction.currentSupply}/${widget.auction.maxSupply} items',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(widget.auction.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.auction.status,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _getStatusColor(widget.auction.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Value Locked:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '${widget.auction.totalValueLocked} ${metadata.symbol}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEEFC42),
                            ),
                          ),
                        ],
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