import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../data/repo/guide_repository.dart';

abstract class GuideState extends Equatable {
  const GuideState();

  @override
  List<Object> get props => [];
}

class GuideInitial extends GuideState {}

class GuideLoading extends GuideState {}

class GuideLoaded extends GuideState {
  final List<Map<String, dynamic>> guides;

  const GuideLoaded(this.guides);

  @override
  List<Object> get props => [guides];
}

class GuideError extends GuideState {
  final String message;

  const GuideError(this.message);

  @override
  List<Object> get props => [message];
}

class GuideCubit extends Cubit<GuideState> {
  final GuideRepository _guideRepository;
  List<Map<String, dynamic>> _allGuides = [];
  String? _selectedCity;
  String? _selectedLanguage;
  double? _minRating;

  GuideCubit(this._guideRepository) : super(GuideInitial());

  Future<void> fetchGuides() async {
    emit(GuideLoading());
    try {
      final guides = await _guideRepository.getGuides();
      _allGuides = guides;
      emit(GuideLoaded(guides));
    } catch (e) {
      emit(GuideError(e.toString()));
    }
  }

  void filterGuides({
    String? city,
    String? language,
    double? minRating,
    String? searchQuery,
  }) {
    _selectedCity = city;
    _selectedLanguage = language;
    _minRating = minRating;

    List<Map<String, dynamic>> filteredGuides = List.from(_allGuides);

    if (city != null) {
      filteredGuides = filteredGuides
          .where(
              (guide) => guide['cityName']?.toLowerCase() == city.toLowerCase())
          .toList();
    }

    if (language != null) {
      filteredGuides = filteredGuides.where((guide) {
        final languages = guide['languages'] as List?;
        return languages?.any((lang) =>
                lang['name']?.toLowerCase() == language.toLowerCase()) ??
            false;
      }).toList();
    }

    if (minRating != null) {
      filteredGuides = filteredGuides
          .where((guide) => (guide['rating'] ?? 0.0) >= minRating)
          .toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredGuides = filteredGuides.where((guide) {
        final name = guide['fullName']?.toString().toLowerCase() ?? '';
        final cityName = guide['cityName']?.toString().toLowerCase() ?? '';
        return name.contains(searchQuery.toLowerCase()) ||
            cityName.contains(searchQuery.toLowerCase());
      }).toList();
    }

    emit(GuideLoaded(filteredGuides));
  }

  void clearFilters() {
    _selectedCity = null;
    _selectedLanguage = null;
    _minRating = null;
    emit(GuideLoaded(_allGuides));
  }

  Future<DocumentReference> addReview({
    required String guideId,
    required String userId,
    required String comment,
    required int rating,
  }) async {
    try {
      DocumentReference newReview = await _guideRepository.addReview(
        guideId: guideId,
        userId: userId,
        comment: comment,
        rating: rating,
      );

      await fetchGuides();

      return newReview;
    } catch (e) {
      emit(GuideError(e.toString()));
      throw e;
    }
  }

  Future<void> deleteReview({
    required String guideId,
    required String reviewId,
  }) async {
    try {
      if (reviewId.isEmpty) {
        throw Exception("Silme işlemi başarısız: reviewId boş!");
      }

      await _guideRepository.deleteReview(
        guideId: guideId,
        reviewId: reviewId,
      );

      await fetchGuides();
    } catch (e) {
      emit(GuideError(e.toString()));
    }
  }

  Future<Map<String, dynamic>?> updateReview({
    required String guideId,
    required String reviewId,
    required String comment,
    required int rating,
  }) async {
    try {
      final updatedReview = await _guideRepository.updateReview(
        guideId: guideId,
        reviewId: reviewId,
        comment: comment,
        rating: rating,
      );

      await fetchGuides();

      return updatedReview;
    } catch (e) {
      emit(GuideError(e.toString()));
      return null;
    }
  }
}
