import 'package:flutter/material.dart';

class Language {
  final String name;
  final String code;
  bool isSelected;
  LanguageLevel level;

  Language({
    required this.name,
    required this.code,
    this.isSelected = false,
    this.level = LanguageLevel.beginner,
  });
}

enum LanguageLevel {
  beginner,
  intermediate,
  advanced,
  native;

  String get displayName {
    switch (this) {
      case LanguageLevel.beginner:
        return 'Başlangıç';
      case LanguageLevel.intermediate:
        return 'Orta';
      case LanguageLevel.advanced:
        return 'İleri';
      case LanguageLevel.native:
        return 'Anadil';
    }
  }
}

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final List<Language> _languages = [
    Language(name: 'Türkçe', code: 'tr'),
    Language(name: 'İngilizce', code: 'en'),
    Language(name: 'Almanca', code: 'de'),
    Language(name: 'Fransızca', code: 'fr'),
    Language(name: 'İspanyolca', code: 'es'),
    Language(name: 'İtalyanca', code: 'it'),
    Language(name: 'Rusça', code: 'ru'),
    Language(name: 'Arapça', code: 'ar'),
    Language(name: 'Japonca', code: 'ja'),
    Language(name: 'Çince', code: 'zh'),
  ];

  List<Language> get _selectedLanguages =>
      _languages.where((lang) => lang.isSelected).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dil Seçimi'),
        actions: [
          TextButton(
            onPressed: _selectedLanguages.isNotEmpty
                ? () {
                    Navigator.pop(context, _selectedLanguages);
                  }
                : null,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bildiğiniz Dilleri Seçin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Her dil için seviyenizi belirtin',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final language = _languages[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      title: Text(language.name),
                      value: language.isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          language.isSelected = value ?? false;
                        });
                      },
                      secondary: language.isSelected
                          ? DropdownButton<LanguageLevel>(
                              value: language.level,
                              items: LanguageLevel.values
                                  .map((level) => DropdownMenuItem(
                                        value: level,
                                        child: Text(level.displayName),
                                      ))
                                  .toList(),
                              onChanged: (LanguageLevel? newLevel) {
                                if (newLevel != null) {
                                  setState(() {
                                    language.level = newLevel;
                                  });
                                }
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Not: En az bir dil seçmelisiniz',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
