abstract class GuideLanguagesEvent {}

class LoadLanguages extends GuideLanguagesEvent {}

class SearchLanguages extends GuideLanguagesEvent {
  final String query;
  SearchLanguages(this.query);
}

class ToggleLanguageSelection extends GuideLanguagesEvent {
  final String languageCode;
  ToggleLanguageSelection(this.languageCode);
}

class SaveSelectedLanguages extends GuideLanguagesEvent {}

class LoadSelectedLanguages extends GuideLanguagesEvent {}
