import 'package:equatable/equatable.dart';

abstract class GuideRoutesEvent extends Equatable {
  const GuideRoutesEvent();

  @override
  List<Object?> get props => [];
}

class LoadRoutes extends GuideRoutesEvent {}

class AddRoute extends GuideRoutesEvent {
  final String name;
  final String description;
  final int duration;
  final double price;
  final List<String> places;

  const AddRoute({
    required this.name,
    required this.description,
    required this.duration,
    required this.price,
    required this.places,
  });

  @override
  List<Object?> get props => [name, description, duration, price, places];
}

class DeleteRoute extends GuideRoutesEvent {
  final String routeId;

  const DeleteRoute(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

class SaveRoutes extends GuideRoutesEvent {}
