class BalanceData {
  final Map<String, double> tokenBalances;
  final double solBalance;

  BalanceData({
    required this.tokenBalances,
    required this.solBalance,
  });

  factory BalanceData.fromJson(Map<String, dynamic> json) {
    return BalanceData(
      tokenBalances: Map<String, double>.from(json['tokenBalances'] ?? {}),
      solBalance: (json['solBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'tokenBalances': tokenBalances,
    'solBalance': solBalance,
  };
} 