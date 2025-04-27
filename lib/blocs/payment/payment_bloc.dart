import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repo/payment_service.dart';
import '../../data/entity/payment_model.dart';

// Events
abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

class InitializePayment extends PaymentEvent {
  final String email;
  final String name;

  const InitializePayment({required this.email, required this.name});

  @override
  List<Object?> get props => [email, name];
}

class ProcessPayment extends PaymentEvent {
  final double amount;
  final String currency;
  final String description;

  const ProcessPayment({
    required this.amount,
    required this.currency,
    required this.description,
  });

  @override
  List<Object?> get props => [amount, currency, description];
}

// States
abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentSuccess extends PaymentState {
  final PaymentModel payment;

  const PaymentSuccess(this.payment);

  @override
  List<Object?> get props => [payment];
}

class PaymentError extends PaymentState {
  final String message;

  const PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc() : super(PaymentInitial()) {
    on<InitializePayment>(_onInitializePayment);
    on<ProcessPayment>(_onProcessPayment);
  }

  Future<void> _onInitializePayment(
    InitializePayment event,
    Emitter<PaymentState> emit,
  ) async {
    try {
      emit(PaymentLoading());

      // Önce mevcut müşteri ID'sini kontrol et
      String? customerId = await PaymentService.getStoredCustomerId();

      if (customerId == null) {
        // Yeni müşteri oluştur
        final customerData = await PaymentService.createCustomer(
          email: event.email,
          name: event.name,
        );
        customerId = customerData['id'];
      }

      emit(PaymentSuccess(PaymentModel(
        id: '',
        amount: 0,
        currency: 'try',
        status: 'initialized',
        customerId: customerId ?? '',
        createdAt: DateTime.now(),
      )));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onProcessPayment(
    ProcessPayment event,
    Emitter<PaymentState> emit,
  ) async {
    try {
      emit(PaymentLoading());

      final customerId = await PaymentService.getStoredCustomerId();
      if (customerId == null) {
        throw Exception('Müşteri bulunamadı');
      }

      // Ödeme niyeti oluştur
      final paymentIntent = await PaymentService.createPaymentIntent(
        amount: event.amount,
        currency: event.currency,
        customerId: customerId,
      );

      // Ödemeyi işle
      await PaymentService.processPayment(
        paymentIntentId: paymentIntent['id'],
        paymentMethodId: paymentIntent['payment_method'],
      );

      emit(PaymentSuccess(PaymentModel.fromJson(paymentIntent)));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }
}
