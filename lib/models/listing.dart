class Listing {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double initialPrice;
  final DateTime saleEndDate;
  final int minimumItems;
  final String designerId;
  final String designerName;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.initialPrice,
    required this.saleEndDate,
    required this.minimumItems,
    required this.designerId,
    required this.designerName,
    required this.createdAt,
  });

  Duration get remainingTime => saleEndDate.difference(DateTime.now());
  
  bool get isActive => remainingTime.isNegative == false;
} 