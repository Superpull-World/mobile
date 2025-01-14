class Listing {
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

  Listing({
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
  });

  factory Listing.fromAuction(Map<String, dynamic> auction) {
    final basePrice = (auction['basePrice'] as num).toDouble() / 1e6;
    final priceIncrement = (auction['priceIncrement'] as num).toDouble() / 1e6;
    final currentSupply = (auction['currentSupply'] as num).toInt();
    final totalValueLocked = (auction['totalValueLocked'] as num).toDouble() / 1e6;
    
    // Calculate current price based on base price, current supply and increment
    final currentPrice = basePrice + (currentSupply * priceIncrement);

    return Listing(
      id: auction['address'],
      name: auction['name'] ?? 'Untitled Auction',
      description: auction['description'] ?? 'No description available',
      imageUrl: auction['imageUrl'] ?? 'https://assets.superpull.world/placeholder.png',
      initialPrice: basePrice,
      currentPrice: currentPrice,
      currentSupply: currentSupply,
      maxSupply: (auction['maxSupply'] as num).toInt(),
      minimumItems: (auction['minimumItems'] as num).toInt(),
      isGraduated: auction['isGraduated'] as bool,
      authority: auction['authority'] as String,
      merkleTree: auction['merkleTree'] as String,
      totalValueLocked: totalValueLocked,
    );
  }

  double get progressPercentage => minimumItems > 0 ? currentSupply / minimumItems : 0.0;
  bool get isActive => !isGraduated && currentSupply < maxSupply;
  String get status => isGraduated ? 'Graduated' : (isActive ? 'Active' : 'Ended');
} 