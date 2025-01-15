import 'dart:math';

class Auction {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double initialPrice;
  final double currentPrice;
  final int currentSupply;
  final int maxSupply;
  final int minimumItems;
  final bool isGraduated;
  final String authority;
  final String merkleTree;
  final double totalValueLocked;
  final String tokenMint;
  final DateTime saleEndDate;

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
  });

  factory Auction.fromJson(Map<String, dynamic> json) {
    try {
      // Get decimals from token metadata
      final decimals = pow(10, (json['decimals'] as num).toInt());
      
      final basePrice = (json['basePrice'] as num).toDouble() / decimals;
      final priceIncrement = (json['priceIncrement'] as num).toDouble() / decimals;
      final currentSupply = (json['currentSupply'] as num).toInt();
      final totalValueLocked = (json['totalValueLocked'] as num).toDouble() / decimals;
      
      // Calculate current price based on base price, current supply and increment
      final currentPrice = basePrice + (currentSupply * priceIncrement);

      // Convert deadline timestamp to DateTime
      final deadline = (json['deadline'] as num).toInt();
      final saleEndDate = DateTime.fromMillisecondsSinceEpoch(deadline * 1000);

      return Auction(
        id: json['address'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        imageUrl: json['imageUrl'] as String,
        initialPrice: basePrice,
        currentPrice: currentPrice,
        currentSupply: currentSupply,
        maxSupply: (json['maxSupply'] as num).toInt(),
        minimumItems: (json['minimumItems'] as num).toInt(),
        isGraduated: json['isGraduated'] as bool,
        authority: json['authority'] as String,
        merkleTree: json['merkleTree'] as String,
        totalValueLocked: totalValueLocked,
        tokenMint: json['tokenMint'] as String,
        saleEndDate: saleEndDate,
      );
    } catch (e) {
      print('Error parsing auction: $e');
      rethrow;
    }
  }

  double get progressPercentage => minimumItems > 0 ? currentSupply / minimumItems : 0.0;
  bool get isActive => !isGraduated && currentSupply < maxSupply;
  String get status => isGraduated ? 'Graduated' : (isActive ? 'Active' : 'Ended');
} 