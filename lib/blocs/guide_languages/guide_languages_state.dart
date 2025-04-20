import 'package:equatable/equatable.dart';

class GuideLanguagesState extends Equatable {
  final List<Map<String, dynamic>> languages;
  final List<Map<String, dynamic>> filteredLanguages;
  final Set<String> selectedLanguages;
  final bool isLoading;
  final String? error;

  const GuideLanguagesState({
    this.languages = const [],
    this.filteredLanguages = const [],
    this.selectedLanguages = const {},
    this.isLoading = false,
    this.error,
  });

  GuideLanguagesState copyWith({
    List<Map<String, dynamic>>? languages,
    List<Map<String, dynamic>>? filteredLanguages,
    Set<String>? selectedLanguages,
    bool? isLoading,
    String? error,
  }) {
    return GuideLanguagesState(
      languages: languages ?? this.languages,
      filteredLanguages: filteredLanguages ?? this.filteredLanguages,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [languages, filteredLanguages, selectedLanguages, isLoading, error];
}
