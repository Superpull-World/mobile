import 'dart:math';

class Auction {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String initialPrice;
  final String currentPrice;
  final int currentSupply;
  final int maxSupply;
  final int minimumItems;
  final bool isGraduated;
  final String authority;
  final String merkleTree;
  final String totalValueLocked;
  final String tokenMint;
  final DateTime saleEndDate;
  final int _rawBasePrice;
  final int _rawPriceIncrement;
  final int _decimals;

  int get rawCurrentPrice => _rawBasePrice + (currentSupply * _rawPriceIncrement);

  Auction({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.initialPrice,
    required this.currentPrice,
    required this.currentSupply,
    required this.maxSupply,
    required this.minimumItems,
    required this.isGraduated,
    required this.authority,
    required this.merkleTree,
    required this.totalValueLocked,
    required this.tokenMint,
    required this.saleEndDate,
    required int rawBasePrice,
    required int rawPriceIncrement,
    required int decimals,
  }) : _rawBasePrice = rawBasePrice,
       _rawPriceIncrement = rawPriceIncrement,
       _decimals = decimals;

  factory Auction.fromJson(Map<String, dynamic> json) {
    try {
      // Get token metadata and ensure it has decimals
      final tokenMetadata = json['tokenMetadata'] as Map<String, dynamic>?;
      if (tokenMetadata == null || !tokenMetadata.containsKey('decimals')) {
        throw Exception('Missing token metadata or decimals');
      }
      
      final decimals = (tokenMetadata['decimals'] as num).toInt();
      final decimalsFactor = pow(10, decimals).toInt();
      
      // Handle potentially null numeric values with defaults
      final rawBasePrice = ((json['basePrice'] as num?) ?? 0).toInt();
      final rawPriceIncrement = ((json['priceIncrement'] as num?) ?? 0).toInt();
      final currentSupply = ((json['currentSupply'] as num?) ?? 0).toInt();
      final rawTotalValueLocked = ((json['totalValueLocked'] as num?) ?? 0).toInt();
      
      // Calculate current price based on base price, current supply and increment
      final rawCurrentPrice = rawBasePrice + (currentSupply * rawPriceIncrement);
      
      // Format prices for UI without trailing zeros
      final basePrice = (rawBasePrice / decimalsFactor).toString();
      final currentPrice = (rawCurrentPrice / decimalsFactor).toString();
      final totalValueLocked = (rawTotalValueLocked / decimalsFactor).toString();

      // Convert deadline timestamp to DateTime with fallback
      final deadline = ((json['deadline'] as num?) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000)).toInt();
      final saleEndDate = DateTime.fromMillisecondsSinceEpoch(deadline * 1000);

      return Auction(
        id: json['address'] as String? ?? '',
        name: json['name'] as String? ?? 'Unnamed Auction',
        description: json['description'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        initialPrice: basePrice,
        currentPrice: currentPrice,
        currentSupply: currentSupply,
        maxSupply: ((json['maxSupply'] as num?) ?? 0).toInt(),
        minimumItems: ((json['minimumItems'] as num?) ?? 0).toInt(),
        isGraduated: json['isGraduated'] as bool? ?? false,
        authority: json['authority'] as String? ?? '',
        merkleTree: json['merkleTree'] as String? ?? '',
        totalValueLocked: totalValueLocked,
        tokenMint: json['tokenMint'] as String? ?? '',
        saleEndDate: saleEndDate,
        rawBasePrice: rawBasePrice,
        rawPriceIncrement: rawPriceIncrement,
        decimals: decimals,
      );
    } catch (e) {
      print('Error parsing auction: $e');
      print('Raw JSON: $json');
      rethrow;
    }
  }

  double get progressPercentage => minimumItems > 0 ? currentSupply / minimumItems : 0.0;
  
  bool get isEnded => DateTime.now().isAfter(saleEndDate);
  bool get hasMetMinimumItems => currentSupply >= minimumItems;
  bool get hasReachedMaxSupply => currentSupply >= maxSupply;
  bool get isActive => !isEnded && !isGraduated && !hasReachedMaxSupply;
  
  String get status {
    if (isGraduated) return 'Graduated';
    if (isEnded) {
      return hasMetMinimumItems ? 'Graduated' : 'Cancelled';
    }
    if (hasReachedMaxSupply) return 'Sold Out';
    return 'Active';
  }
  
  int get decimals => _decimals;
} 