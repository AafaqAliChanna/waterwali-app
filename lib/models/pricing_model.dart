import 'order_model.dart';

class TankerPricing {
  final Map<String, double> pricesBySize;
  final String? effectiveDate;

  TankerPricing({required this.pricesBySize, this.effectiveDate});

  factory TankerPricing.fromJson(Map<String, dynamic> json) {
    final prices = <String, double>{};
    for (final key in ['SIZE_1000L', 'SIZE_2000L', 'SIZE_3000L', 'SIZE_5000L']) {
      final value = json[key];
      if (value != null) prices[key] = (value as num).toDouble();
    }
    return TankerPricing(
      pricesBySize: prices,
      effectiveDate: json['effectiveDate']?.toString(),
    );
  }

  double? priceFor(TankerSize size) => pricesBySize[size.apiValue];
}