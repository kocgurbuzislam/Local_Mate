class PaymentModel {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final String customerId;
  final String? paymentMethodId;
  final DateTime createdAt;
  final String? description;

  PaymentModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.customerId,
    this.paymentMethodId,
    required this.createdAt,
    this.description,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      amount: (json['amount'] as int) / 100, // Stripe kuruş cinsinden gelir
      currency: json['currency'] as String,
      status: json['status'] as String,
      customerId: json['customer'] as String,
      paymentMethodId: json['payment_method'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created'] * 1000),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': (amount * 100).toInt(), // Stripe'a kuruş cinsinden gönder
      'currency': currency,
      'status': status,
      'customer': customerId,
      'payment_method': paymentMethodId,
      'created': createdAt.millisecondsSinceEpoch ~/ 1000,
      'description': description,
    };
  }
}
