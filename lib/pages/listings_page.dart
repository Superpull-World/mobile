import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../services/auction_service.dart';
import '../services/bid_service.dart';
import 'create_listing_page.dart';
import 'settings_page.dart';
import 'dart:async';

class QRButton extends StatelessWidget {
  const QRButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code),
      onPressed: () => _showQRModal(context),
    );
  }

  Future<void> _showQRModal(BuildContext context) async {
    final walletService = WalletService();
    try {
      final address = await walletService.getWalletAddress();
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _QRModal(address: address),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet address: $e')),
        );
      }
    }
  }
}

class _QRModal extends StatelessWidget {
  final String address;

  const _QRModal({required this.address});

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
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
              data: address,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyAddress(context),
                  tooltip: 'Copy address',
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key});

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  final BalanceService _balanceService = BalanceService();
  double _solBalance = 0.0;
  double _tokenBalance = 0.0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Refresh every 3 seconds
  static const Duration _refreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeBalanceService();
    _loadBalances();
  }

  Future<void> _initializeBalanceService() async {
    final keypair = await WalletService().getKeypair();
    if (keypair != null) {
      await _balanceService.initialize(keypair);
    }
  }

  Future<void> _loadBalances() async {
    try {
      final sol = await _balanceService.getSolBalance();
      final token = await _balanceService.getTokenBalance();
      setState(() {
        _solBalance = sol;
        _tokenBalance = token;
      });
    } catch (e) {
      print('Error loading balances: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _loadBalances());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icons/logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        actions: const [
          BalanceIndicators(),
          SizedBox(width: 8),
          QRButton(),
          SizedBox(width: 8),
          SettingsButton(),
        ],
      ),
      body: const ListingsView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateListingPage(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.secondaryColor,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Listing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsPage(),
          ),
        );
      },
    );
  }
}

class BalanceIndicators extends StatefulWidget {
  const BalanceIndicators({super.key});

  @override
  State<BalanceIndicators> createState() => _BalanceIndicatorsState();
}

class _BalanceIndicatorsState extends State<BalanceIndicators> {
  final BalanceService _balanceService = BalanceService();
  double _tokenBalance = 0.0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Refresh every 3 seconds
  static const Duration _refreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeBalanceService();
    _loadBalances();
    _startPeriodicRefresh();
  }

  Future<void> _initializeBalanceService() async {
    final keypair = await WalletService().getKeypair();
    if (keypair != null) {
      await _balanceService.initialize(keypair);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _loadBalances());
  }

  Future<void> _loadBalances() async {
    try {
      final token = await _balanceService.getTokenBalance();
      if (mounted) {
        setState(() {
          _tokenBalance = token;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading balances: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return _BalanceChip(
      amount: _tokenBalance,
      symbol: 'Token',
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final double amount;
  final String symbol;

  const _BalanceChip({
    required this.amount,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/${symbol.toLowerCase()}.png',
            width: 16,
            height: 16,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.circle,
                size: 16,
                color: AppTheme.primaryColor,
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            '${amount.toStringAsFixed(2)} $symbol',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ListingsView extends StatefulWidget {
  const ListingsView({super.key});

  @override
  State<ListingsView> createState() => _ListingsViewState();
}

class _ListingsViewState extends State<ListingsView> {
  final AuctionService _auctionService = AuctionService();
  List<Listing> _listings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _noMoreItems = false;
  String? _error;
  int _currentPage = 0;
  static const int _pageSize = 5;
  final PageController _pageController = PageController();
  String? _currentWorkflowId;
  Timer? _pollingTimer;
  Timer? _refreshTimer;
  
  // Refresh every 3 seconds
  static const Duration _refreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadListings();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_isLoading && !_isLoadingMore) {
        _loadListings();
      }
    });
  }

  Future<void> _loadListings() async {
    try {
      // Store current page index before refresh
      final currentPage = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
      print('Storing current page: $currentPage'); // Debug log
      
      // Don't set loading state during periodic refresh to prevent UI flicker
      final isPeriodicRefresh = !_isLoading;
      if (!isPeriodicRefresh) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      // Start the workflow
      final workflowResult = await _auctionService.startGetAuctionsWorkflow(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      _currentWorkflowId = workflowResult['id'] as String;

      // Start polling for workflow status
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkWorkflowStatus(currentPage);
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkWorkflowStatus(int preservedPage) async {
    if (_currentWorkflowId == null) return;

    try {
      final status = await _auctionService.getWorkflowStatus(_currentWorkflowId!);
      
      if (status.isCompleted) {
        _pollingTimer?.cancel();
        
        // Fetch the workflow result
        final listings = await _auctionService.getWorkflowResult(_currentWorkflowId!);
        
        if (mounted) {
          // Get the current page before updating state
          final currentPage = _pageController.hasClients ? _pageController.page?.round() ?? preservedPage : preservedPage;
          print('Current page before update: $currentPage'); // Debug log
          
          setState(() {
            // Sort listings with deterministic order
            _listings = listings..sort((a, b) {
              // First, prioritize non-graduated items
              if (a.status != 'Graduated' && b.status == 'Graduated') return -1;
              if (a.status == 'Graduated' && b.status != 'Graduated') return 1;
              
              // Then sort by progress towards graduation (closer to minimum items first)
              final aProgress = (a.minimumItems - a.currentSupply).abs();
              final bProgress = (b.minimumItems - b.currentSupply).abs();
              if (aProgress != bProgress) {
                return aProgress.compareTo(bProgress);
              }
              
              // Then sort by remaining capacity (less remaining spots first)
              final aRemaining = a.maxSupply - a.currentSupply;
              final bRemaining = b.maxSupply - b.currentSupply;
              if (aRemaining != bRemaining) {
                return aRemaining.compareTo(bRemaining);
              }
              
              // Finally sort by ID for complete determinism
              return a.id.compareTo(b.id);
            });
            _isLoading = false;
            _error = null;
          });

          // Only restore page position if it's a periodic refresh
          if (!_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                // Ensure the current page is within bounds
                final targetPage = currentPage.clamp(0, _listings.length - 1);
                print('Restoring to page: $targetPage'); // Debug log
                _pageController.jumpToPage(targetPage);
              }
            });
          }
        }
      } else if (status.isFailed) {
        _pollingTimer?.cancel();
        if (mounted) {
          setState(() {
            _error = status.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreListings() async {
    if (_listings.length < _pageSize || _isLoadingMore || _noMoreItems) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final nextPage = _currentPage + 1;
      final currentIndex = _pageController.hasClients ? _pageController.page?.round() ?? 0 : 0;
      
      final workflowResult = await _auctionService.startGetAuctionsWorkflow(
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      final workflowId = workflowResult['id'] as String;
      
      bool isComplete = false;
      while (!isComplete) {
        try {
          final status = await _auctionService.getWorkflowStatus(workflowId);
          
          if (status.isCompleted) {
            final newListings = await _auctionService.getWorkflowResult(workflowId);

            if (mounted) {
              if (newListings.isEmpty) {
                setState(() {
                  _noMoreItems = true;
                  _isLoadingMore = false;
                });
                
                // Stay on current page when no more items
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(currentIndex);
                }
              } else {
                setState(() {
                  _listings.addAll(newListings);
                  _currentPage = nextPage;
                  _isLoadingMore = false;
                });
              }
            }
            isComplete = true;
          } else if (status.isFailed) {
            if (mounted) {
              setState(() {
                _isLoadingMore = false;
                // Stay on current page on failure
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(currentIndex);
                }
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load more auctions: ${status.message}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            isComplete = true;
          } else {
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('Error checking workflow status: $e');
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
              // Stay on current page on error
              if (_pageController.hasClients) {
                _pageController.jumpToPage(currentIndex);
              }
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to load more auctions'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          isComplete = true;
        }
      }
    } catch (e) {
      print('Error starting pagination workflow: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Stay on current page on error
          if (_pageController.hasClients) {
            final currentIndex = _pageController.page?.round() ?? (_listings.length - 1);
            _pageController.jumpToPage(currentIndex);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load more auctions'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadListings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return const Center(
        child: Text(
          'No auctions available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _listings.length + (_isLoadingMore ? 1 : 0),
      onPageChanged: (index) {
        if (index == _listings.length - 1) {
          _loadMoreListings();
        }
      },
      itemBuilder: (context, index) {
        if (index == _listings.length) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoadingMore && !_noMoreItems)
                    ...[
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading more auctions...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ]
                  else if (_noMoreItems)
                    ...[
                      const Icon(
                        Icons.check_circle_outline,
                        size: 32,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'You\'ve seen all auctions',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                ],
              ),
            ),
          );
        }

        final listing = _listings[index];
        return ListingCard(listing: listing);
      },
    );
  }
}

class ListingCard extends StatefulWidget {
  final Listing listing;

  const ListingCard({super.key, required this.listing});

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> with SingleTickerProviderStateMixin {
  final _balanceService = BalanceService();
  bool _isDragging = false;
  double _dragExtent = 0;
  static const _dragThreshold = 100.0;
  late final AnimationController _arrowAnimationController;
  late final Animation<double> _arrowAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeBalanceService();
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

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    super.dispose();
  }

  Future<void> _showBidConfirmation() async {
    try {
      final tokenBalance = await _balanceService.getTokenBalance();
      final requiredBalance = widget.listing.currentPrice;
      // Temporarily disable balance check
      final hasEnoughBalance = true; // tokenBalance >= requiredBalance;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'You are about to bid on:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.listing.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Price:'),
                        Text(
                          '${widget.listing.currentPrice.toStringAsFixed(2)} TOKEN',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Balance:'),
                        Text(
                          '${tokenBalance.toStringAsFixed(2)} TOKEN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasEnoughBalance ? Colors.green : Colors.red,
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need ${(requiredBalance - tokenBalance).toStringAsFixed(2)} more TOKEN to place this bid.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement top-up flow
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Top-up feature coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Top Up Wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.secondaryColor,
                  ),
                ),
              ] else if (widget.listing.currentSupply >= widget.listing.maxSupply) ...[
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This item has reached its maximum supply of ${widget.listing.maxSupply} items.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade700,
                        ),
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
                        builder: (context) => const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Initializing bid...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );

                      await bidService.startPlaceBidWorkflow(
                        auctionAddress: widget.listing.id,
                        bidAmount: widget.listing.currentPrice,
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
                            
                            // Find and refresh the ListingsView
                            final listingsViewState = context.findAncestorStateOfType<_ListingsViewState>();
                            if (listingsViewState != null) {
                              listingsViewState._loadListings();
                            }
                          } else {
                            // Show new status dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Center(
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(status),
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
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Place Bid'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error showing bid confirmation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Image.network(
                        widget.listing.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
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
                              widget.listing.name,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.listing.currentPrice.toStringAsFixed(2)} TOKEN',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'by ${widget.listing.authority}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.listing.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        children: [
                          LinearProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                          ),
                          LinearProgressIndicator(
                            value: widget.listing.minimumItems / widget.listing.maxSupply,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                          LinearProgressIndicator(
                            value: widget.listing.currentSupply / widget.listing.maxSupply,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.listing.status == 'Graduated' 
                                ? Colors.green 
                                : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.listing.currentSupply}/${widget.listing.maxSupply} items',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
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
                                  color: _getStatusColor(widget.listing.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.listing.status,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _getStatusColor(widget.listing.status),
                                  ),
                                ),
                              ),
                            ],
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
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Pull',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
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
        return AppTheme.primaryColor;
      default:
        return Colors.red;
    }
  }
} 