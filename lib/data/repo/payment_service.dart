import 'dart:convert';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentService {
  static const _storage = FlutterSecureStorage();
  static const String _baseUrl = 'https://api.stripe.com/v1';

  static Future<void> initializeStripe() async {
    try {
      Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
      await Stripe.instance.applySettings();

      // Test modu için konfigürasyon
      await Stripe.instance.dangerouslyUpdateCardDetails(
        CardDetails(
          cvc: '123',
          expirationMonth: 12,
          expirationYear: 2025,
          number: '4242424242424242',
        ),
      );
    } catch (e) {
      print('Stripe başlatma hatası: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String customerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET_KEY']}',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Stripe-Version': '2023-10-16', // En son API versiyonu
        },
        body: {
          'amount': (amount * 100).toInt().toString(),
          'currency': currency,
          'customer': customerId,
          'payment_method_types[]': 'card',
          'description': 'Test ödeme',
          'setup_future_usage': 'off_session',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Ödeme niyeti oluşturulamadı: ${response.body}');
      }
    } catch (e) {
      print('Ödeme niyeti oluşturma hatası: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createCustomer({
    required String email,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customers'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET_KEY']}',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Stripe-Version': '2023-10-16',
        },
        body: {
          'email': email,
          'name': name,
          'description': 'Test müşteri',
        },
      );

      if (response.statusCode == 200) {
        final customerData = json.decode(response.body);
        await _storage.write(
          key: 'stripe_customer_id',
          value: customerData['id'],
        );
        return customerData;
      } else {
        throw Exception('Müşteri oluşturulamadı: ${response.body}');
      }
    } catch (e) {
      print('Müşteri oluşturma hatası: $e');
      rethrow;
    }
  }

  static Future<void> processPayment({
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    try {
      // Önce payment intent'i al
      final response = await http.get(
        Uri.parse('$_baseUrl/payment_intents/$paymentIntentId'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET_KEY']}',
          'Stripe-Version': '2023-10-16',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Ödeme bilgileri alınamadı: ${response.body}');
      }

      final paymentIntent = json.decode(response.body);
      final clientSecret = paymentIntent['client_secret'];

      // Ödemeyi onayla
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(),
          ),
        ),
      );
    } catch (e) {
      print('Ödeme işlemi hatası: $e');
      rethrow;
    }
  }

  static Future<String?> getStoredCustomerId() async {
    return await _storage.read(key: 'stripe_customer_id');
  }

  static Future<void> clearStoredCustomerId() async {
    await _storage.delete(key: 'stripe_customer_id');
  }
}
