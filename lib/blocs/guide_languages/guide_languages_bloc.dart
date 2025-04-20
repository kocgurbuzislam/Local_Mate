import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guide_languages_event.dart';
import 'guide_languages_state.dart';

class GuideLanguagesBloc
    extends Bloc<GuideLanguagesEvent, GuideLanguagesState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GuideLanguagesBloc() : super(const GuideLanguagesState()) {
    on<LoadLanguages>(_onLoadLanguages);
    on<SearchLanguages>(_onSearchLanguages);
    on<ToggleLanguageSelection>(_onToggleLanguageSelection);
    on<SaveSelectedLanguages>(_onSaveSelectedLanguages);
    on<LoadSelectedLanguages>(_onLoadSelectedLanguages);
  }

  Future<void> _onLoadLanguages(
    LoadLanguages event,
    Emitter<GuideLanguagesState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      final response = await http.get(
        Uri.parse('https://restcountries.com/v3.1/all'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> countries = json.decode(response.body);
        final List<Map<String, dynamic>> languages = [];

        for (var country in countries) {
          if (country['languages'] != null) {
            final Map<String, dynamic> langs = country['languages'];
            langs.forEach((code, name) {
              if (!languages.any((lang) => lang['code'] == code)) {
                languages.add({
                  'code': code,
                  'name': name,
                  'flag': country['flags']['png'],
                });
              }
            });
          }
        }

        emit(state.copyWith(
          languages: languages,
          filteredLanguages: languages,
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Diller yüklenirken hata oluştu: $e',
      ));
    }
  }

  void _onSearchLanguages(
    SearchLanguages event,
    Emitter<GuideLanguagesState> emit,
  ) {
    final query = event.query.toLowerCase();
    final filteredLanguages = state.languages
        .where((language) =>
            language['name'].toString().toLowerCase().contains(query))
        .toList();

    emit(state.copyWith(filteredLanguages: filteredLanguages));
  }

  void _onToggleLanguageSelection(
    ToggleLanguageSelection event,
    Emitter<GuideLanguagesState> emit,
  ) {
    final newSelectedLanguages = Set<String>.from(state.selectedLanguages);
    if (newSelectedLanguages.contains(event.languageCode)) {
      newSelectedLanguages.remove(event.languageCode);
    } else {
      newSelectedLanguages.add(event.languageCode);
    }

    emit(state.copyWith(selectedLanguages: newSelectedLanguages));
  }

  Future<void> _onSaveSelectedLanguages(
    SaveSelectedLanguages event,
    Emitter<GuideLanguagesState> emit,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final List<Map<String, dynamic>> selectedLanguageDetails = state.languages
          .where((lang) => state.selectedLanguages.contains(lang['code']))
          .map((lang) => {
                'code': lang['code'],
                'name': lang['name'],
                'flag': lang['flag'],
              })
          .toList();

      await _firestore.collection('guides').doc(userId).update({
        'languages': selectedLanguageDetails,
      });
    } catch (e) {
      emit(state.copyWith(
        error: 'Diller kaydedilirken hata oluştu: $e',
      ));
    }
  }

  Future<void> _onLoadSelectedLanguages(
    LoadSelectedLanguages event,
    Emitter<GuideLanguagesState> emit,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('guides').doc(userId).get();
      if (doc.exists && doc.data()?['languages'] != null) {
        final List<dynamic> languages = doc.data()?['languages'];
        final selectedCodes =
            languages.map((lang) => lang['code'] as String).toSet();
        emit(state.copyWith(selectedLanguages: selectedCodes));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Diller yüklenirken hata oluştu: $e',
      ));
    }
  }
}
