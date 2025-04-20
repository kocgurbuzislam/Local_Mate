import 'package:equatable/equatable.dart';

class GuideRoutesState extends Equatable {
  final List<Map<String, dynamic>> routes;
  final bool isLoading;
  final String? error;

  const GuideRoutesState({
    this.routes = const [],
    this.isLoading = false,
    this.error,
  });

  GuideRoutesState copyWith({
    List<Map<String, dynamic>>? routes,
    bool? isLoading,
    String? error,
  }) {
    return GuideRoutesState(
      routes: routes ?? this.routes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [routes, isLoading, error];
}
