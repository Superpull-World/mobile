import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/listing.dart';
import '../theme/app_theme.dart';
import '../services/balance_service.dart';
import '../services/wallet_service.dart';
import '../services/auction_service.dart';
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

class ListingsPage extends StatelessWidget {
  const ListingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icons/logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
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
  double _solBalance = 0.0;
  double _usdcBalance = 0.0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Refresh every 3 seconds
  static const Duration _refreshInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _loadBalances();
    _startPeriodicRefresh();
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
      final sol = await _balanceService.getSolBalance();
      final usdc = await _balanceService.getUsdcBalance();
      if (mounted) {
        setState(() {
          _solBalance = sol;
          _usdcBalance = usdc;
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BalanceChip(
          amount: _solBalance,
          symbol: 'SOL',
        ),
        const SizedBox(width: 8),
        _BalanceChip(
          amount: _usdcBalance,
          symbol: 'USDC',
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Start the workflow
      final workflowResult = await _auctionService.startGetAuctionsWorkflow(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      _currentWorkflowId = workflowResult['id'] as String;

      // Start polling for workflow status
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkWorkflowStatus();
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkWorkflowStatus() async {
    if (_currentWorkflowId == null) return;

    try {
      final status = await _auctionService.getWorkflowStatus(_currentWorkflowId!);
      
      if (status.isCompleted) {
        _pollingTimer?.cancel();
        
        // Fetch the workflow result
        final listings = await _auctionService.getWorkflowResult(_currentWorkflowId!);
        
        if (mounted) {
          setState(() {
            _listings = listings;
            _isLoading = false;
            _error = null;
          });
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
      // If not completed or failed, continue polling
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
    if (_listings.length < _pageSize || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final nextPage = _currentPage + 1;
      
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
                  _isLoadingMore = true;
                  _noMoreItems = true;
                });
                
                await Future.delayed(const Duration(milliseconds: 1500));
                
                if (mounted) {
                  setState(() {
                    _isLoadingMore = false;
                    _noMoreItems = false;
                  });
                  
                  _pageController.animateToPage(
                    _listings.length - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              } else {
                setState(() {
                  _isLoadingMore = false;
                  _noMoreItems = false;
                  _listings.addAll(newListings);
                  _currentPage = nextPage;
                });
              }
            }
            isComplete = true;
          } else if (status.isFailed) {
            if (mounted) {
              setState(() {
                _isLoadingMore = false;
                // Animate back to the previous page
                _pageController.animateToPage(
                  _listings.length - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to load more auctions: ${status.message}'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
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
              // Animate back to the previous page
              _pageController.animateToPage(
                _listings.length - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load more auctions'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            });
          }
          isComplete = true;
        }
      }
    } catch (e) {
      print('Error starting pagination workflow: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Animate back to the previous page
          _pageController.animateToPage(
            _listings.length - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load more auctions'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
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

class ListingCard extends StatelessWidget {
  final Listing listing;

  const ListingCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              listing.imageUrl,
              fit: BoxFit.cover,
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
                        listing.name,
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
                        '${listing.currentPrice.toStringAsFixed(2)} SOL',
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
                  'by ${listing.authority}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  listing.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: listing.progressPercentage,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    listing.isGraduated ? Colors.green : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${listing.currentSupply}/${listing.minimumItems} items',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(listing.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(listing.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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