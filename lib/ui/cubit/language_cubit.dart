import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yerel_rehber_app/data/entity/language.dart';
import 'package:yerel_rehber_app/data/repo/public_repo.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// States
abstract class LanguageState {}

class LanguageInitial extends LanguageState {}

class LanguageLoading extends LanguageState {}

class LanguageLoaded extends LanguageState {
  final List<Language> languages;
  final List<Language> filteredLanguages;
  final List<Language> selectedLanguages;
  final String searchQuery;

  LanguageLoaded({
    required this.languages,
    required this.filteredLanguages,
    required this.selectedLanguages,
    required this.searchQuery,
  });
}

class LanguageError extends LanguageState {
  final String message;

  LanguageError(this.message);
}

// Cubit
class LanguageCubit extends Cubit<LanguageState> {
  final List<Language> _selectedLanguages = [];
  List<Language> _allLanguages = [];
  String _searchQuery = '';

  LanguageCubit() : super(LanguageInitial());

  Future<void> loadLanguages() async {
    try {
      emit(LanguageLoading());

      final response =
          await http.get(Uri.parse('${dotenv.env["LANGUAGE_ENDPOINT"]}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Set<Map<String, String>> uniqueLanguages = {};

        for (var country in data) {
          if (country['languages'] != null) {
            (country['languages'] as Map<String, dynamic>)
                .forEach((code, name) {
              uniqueLanguages.add({
                'name': name,
                'code': code,
                'flag': country['flag'] ?? '🏳️',
              });
            });
          }
        }

        _allLanguages = uniqueLanguages
            .map((json) => Language(
                  name: json['name'] as String,
                  code: json['code'] as String,
                  flag: json['flag'] as String,
                ))
            .toList();

        // Dilleri alfabetik sıraya göre sırala
        _allLanguages.sort((a, b) => a.name.compareTo(b.name));

        _emitLoadedState();
      } else {
        emit(LanguageError('API yanıt vermedi: ${response.statusCode}'));
      }
    } catch (e) {
      emit(LanguageError('Diller yüklenirken bir hata oluştu: $e'));
    }
  }

  void searchLanguages(String query) {
    _searchQuery = query.toLowerCase();
    _emitLoadedState();
  }

  void toggleLanguage(Language language) {
    if (_selectedLanguages.contains(language)) {
      _selectedLanguages.remove(language);
    } else {
      _selectedLanguages.add(language);
    }
    _emitLoadedState();
  }

  void _emitLoadedState() {
    final filteredLanguages = _allLanguages.where((language) {
      return language.name.toLowerCase().contains(_searchQuery);
    }).toList();

    emit(LanguageLoaded(
      languages: _allLanguages,
      filteredLanguages: filteredLanguages,
      selectedLanguages: List.from(_selectedLanguages),
      searchQuery: _searchQuery,
    ));
  }

  List<Language> getSelectedLanguages() {
    return List.from(_selectedLanguages);
  }
}
