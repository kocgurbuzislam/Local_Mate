import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guide_routes_event.dart';
import 'guide_routes_state.dart';

class GuideRoutesBloc extends Bloc<GuideRoutesEvent, GuideRoutesState> {
  GuideRoutesBloc() : super(const GuideRoutesState()) {
    on<LoadRoutes>(_onLoadRoutes);
    on<AddRoute>(_onAddRoute);
    on<DeleteRoute>(_onDeleteRoute);
    on<SaveRoutes>(_onSaveRoutes);
  }

  Future<void> _onLoadRoutes(
      LoadRoutes event, Emitter<GuideRoutesState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data()?['routes'] != null) {
          final List<dynamic> routesData = doc.data()!['routes'];
          final List<Map<String, dynamic>> routes = routesData.map((route) {
            final Map<String, dynamic> routeMap =
                Map<String, dynamic>.from(route);
            // Places listesini String listesine dönüştür
            if (routeMap['places'] != null) {
              final List<dynamic> placesList = routeMap['places'];
              final List<String> stringPlaces = placesList
                  .map((place) => place.toString())
                  .where((place) => place.isNotEmpty)
                  .toList();
              routeMap['places'] = stringPlaces;
            }
            return routeMap;
          }).toList();

          emit(state.copyWith(
            routes: routes,
            isLoading: false,
          ));
        } else {
          emit(state.copyWith(isLoading: false));
        }
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Rotalar yüklenirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }

  Future<void> _onAddRoute(
      AddRoute event, Emitter<GuideRoutesState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final newRoute = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': event.name,
          'description': event.description,
          'duration': event.duration,
          'price': event.price,
          'places': event.places,
          'createdAt': DateTime.now().toIso8601String(),
        };

        final updatedRoutes = [...state.routes, newRoute];

        // Firestore'a kaydet
        await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .update({
          'routes': updatedRoutes,
        });

        emit(state.copyWith(
          routes: updatedRoutes,
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Rota eklenirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }

  Future<void> _onDeleteRoute(
      DeleteRoute event, Emitter<GuideRoutesState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final updatedRoutes = state.routes
            .where((route) => route['id'] != event.routeId)
            .toList();

        await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .update({
          'routes': updatedRoutes,
        });

        emit(state.copyWith(
          routes: updatedRoutes,
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Rota silinirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }

  Future<void> _onSaveRoutes(
      SaveRoutes event, Emitter<GuideRoutesState> emit) async {
    try {
      emit(state.copyWith(isLoading: true));
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('guides')
            .doc(user.uid)
            .update({
          'routes': state.routes,
        });

        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Rotalar kaydedilirken bir hata oluştu: $e',
        isLoading: false,
      ));
    }
  }
}
