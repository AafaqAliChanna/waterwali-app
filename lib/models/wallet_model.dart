class Wallet {
  final double balance;
  final bool isOnline;

  Wallet({required this.balance, required this.isOnline});

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      balance: (json['balance'] as num).toDouble(),
      isOnline: json['isOnline'] ?? false,
    );
  }
}