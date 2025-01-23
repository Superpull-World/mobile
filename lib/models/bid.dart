class Bid {
  final String auction;
  final String address;
  final String bidder;
  final double amount;
  final int count;

  Bid({
    required this.auction,
    required this.address,
    required this.bidder,
    required this.amount,
    required this.count,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    try {
      final amount = (json['amount'] as num).toDouble();
      final count = (json['count'] as num).toInt();
      final address = json['address'] as String;
      final bidder = json['bidder'] as String;
      final auction = json['auction'] as String;
      return Bid(
        auction: auction,
        bidder: bidder,
        address: address,
        amount: amount,
        count: count,
      );
    } catch (e) {
      throw Exception('Failed to parse Bid from JSON: $e');
    }
  }
}