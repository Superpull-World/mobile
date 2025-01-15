import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auction.dart';
import '../theme/app_theme.dart';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../services/bid_service.dart';
import '../services/token_service.dart';
import '../services/workflow_service.dart';
import '../models/token_metadata.dart';
import '../providers/auctions_provider.dart';

class AuctionCard extends ConsumerStatefulWidget {
  final Auction auction;

  const AuctionCard({super.key, required this.auction});

  @override
  ConsumerState<AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends ConsumerState<AuctionCard> with SingleTickerProviderStateMixin {
  final _balanceService = BalanceService();
  final _workflowService = WorkflowService();
  final _tokenService = TokenService(workflowService: WorkflowService());
  bool _isDragging = false;
  double _dragExtent = 0;
  static const _dragThreshold = 100.0;
  late final AnimationController _arrowAnimationController;
  late final Animation<double> _arrowAnimation;
  late final Animation<double> _fadeAnimation;
  TokenMetadata? _tokenMetadata;

  @override
  void initState() {
    super.initState();
    _initializeBalanceService();
    _loadTokenMetadata();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Simple downward motion from 0 to 24
    _arrowAnimation = Tween<double>(
      begin: 0,
      end: 24,
    ).animate(CurvedAnimation(
      parent: _arrowAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ));

    // Fade out during the downward motion
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _arrowAnimationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
  }

  Future<void> _initializeBalanceService() async {
    final keypair = await WalletService().getKeypair();
    if (keypair != null) {
      await _balanceService.initialize(keypair);
    }
  }

  Future<void> _loadTokenMetadata() async {
    try {
      final tokens = await _tokenService.getAcceptedTokens();
      final tokenMetadata = tokens.firstWhere(
        (token) => token.mint == widget.auction.tokenMint,
        orElse: () => TokenMetadata(
          mint: widget.auction.tokenMint,
          name: 'Unknown Token',
          symbol: '',
          uri: '',
          decimals: 9,
          supply: '0',
        ),
      );
      
      if (mounted) {
        setState(() {
          _tokenMetadata = tokenMetadata;
        });
      }
    } catch (e) {
      print('Error loading token metadata: $e');
    }
  }

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _showBidConfirmation() async {
    // Show modal immediately
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<double>(
        future: _balanceService.getTokenBalance(widget.auction.tokenMint),
        builder: (context, snapshot) {
          final tokenBalance = snapshot.data;
          final requiredBalance = widget.auction.currentPrice;
          // Temporarily disable balance check
          final hasEnoughBalance = true; // tokenBalance >= requiredBalance;

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
                            '${widget.auction.currentPrice.toStringAsFixed(2)} ${_tokenMetadata?.symbol ?? ''}',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Your Balance:', style: TextStyle(color: Colors.white70)),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                              ),
                            )
                          else if (snapshot.hasError)
                            Text(
                              'Error loading balance',
                              style: TextStyle(color: Colors.red),
                            )
                          else
                            Text(
                              '${tokenBalance?.toStringAsFixed(2) ?? '0.00'} ${_tokenMetadata?.symbol ?? ''}',
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
                    'You need ${(requiredBalance - (tokenBalance ?? 0)).toStringAsFixed(2)} ${_tokenMetadata?.symbol ?? ''} to place this bid.',
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
                  ElevatedButton(
                    onPressed: () async {
                      final bidService = BidService();
                      try {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(
                            child: Card(
                              color: Colors.black,
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Initializing bid...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        await bidService.startPlaceBidWorkflow(
                          auctionAddress: widget.auction.id,
                          bidAmount: widget.auction.currentPrice,
                          tokenMetadata: _tokenMetadata ?? TokenMetadata(
                            mint: widget.auction.tokenMint,
                            name: 'Unknown Token',
                            symbol: '',
                            uri: '',
                            decimals: 9,
                            supply: '0',
                          ),
                          onStatusUpdate: (status) {
                            if (!context.mounted) return;
                            
                            Navigator.of(context).pop(); // Remove previous status dialog
                            
                            if (status == 'Bid placed successfully') {
                              Navigator.of(context).pop(); // Close bid modal
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bid placed successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              
                              // Refresh the auctions
                              ref.read(auctionsProvider.notifier).refresh();
                            } else {
                              // Show new status dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Center(
                                  child: Card(
                                    color: Colors.black,
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEFC42)),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            status,
                                            style: TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close status dialog
                          Navigator.of(context).pop(); // Close bid modal
                          
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
                    ),
                    child: const Text('Place Bid'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokenSymbol = _tokenMetadata?.symbol ?? '';
    
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
                              '${widget.auction.currentPrice.toStringAsFixed(2)} ${_tokenMetadata?.symbol ?? ''}',
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
                      Text(
                        'by ${widget.auction.authority}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
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
} 