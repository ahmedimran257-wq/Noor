import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/subscription_service.dart';

void main() {
  test('whole store prices drop zero minor units', () {
    expect(wholePriceLabel('₹299.00'), '₹299');
    expect(wholePriceLabel('₹749.00'), '₹749');
    expect(wholePriceLabel('₹1,000.00'), '₹1,000');
    expect(wholePriceLabel('299,00 €'), '299 €');
  });

  test('real minor units and unusual formats are untouched', () {
    expect(wholePriceLabel('₹299.50'), '₹299.50');
    expect(wholePriceLabel('\$9.99'), '\$9.99');
    expect(wholePriceLabel('₹299'), '₹299');
  });
}
