import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yerel_rehber_app/data/entity/language.dart';
import 'package:yerel_rehber_app/ui/cubit/language_cubit.dart';
import 'package:yerel_rehber_app/ui/views/guides_pages/guide_cities.dart';
import '../../../colors.dart';

class GuideLanguages extends StatefulWidget {
  @override
  _GuideLanguagesState createState() => _GuideLanguagesState();
}

class _GuideLanguagesState extends State<GuideLanguages> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LanguageCubit>().loadLanguages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dil Seçimi'),
        centerTitle: true,
      ),
      body: BlocBuilder<LanguageCubit, LanguageState>(
        builder: (context, state) {
          if (state is LanguageLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LanguageError) {
            return Center(child: Text(state.message));
          } else if (state is LanguageLoaded) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      context.read<LanguageCubit>().searchLanguages(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Dil ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                if (state.selectedLanguages.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.selectedLanguages.length,
                      itemBuilder: (context, index) {
                        final language = state.selectedLanguages[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(language.flag),
                                const SizedBox(width: 4),
                                Text(language.name),
                              ],
                            ),
                            onDeleted: () {
                              context
                                  .read<LanguageCubit>()
                                  .toggleLanguage(language);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.filteredLanguages.length,
                    itemBuilder: (context, index) {
                      final language = state.filteredLanguages[index];
                      final isSelected =
                          state.selectedLanguages.contains(language);

                      return Card(
                        child: ListTile(
                          leading: Text(
                            language.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(language.name),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: mainColor)
                              : const Icon(Icons.circle_outlined),
                          onTap: () {
                            context
                                .read<LanguageCubit>()
                                .toggleLanguage(language);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
      bottomNavigationBar: BlocBuilder<LanguageCubit, LanguageState>(
        builder: (context, state) {
          if (state is LanguageLoaded && state.selectedLanguages.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  final selectedLanguages =
                      context.read<LanguageCubit>().getSelectedLanguages();
                  if (selectedLanguages.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GuideCities(
                          selectedLanguages: selectedLanguages
                              .map((lang) => {
                                    'name': lang.name,
                                    'code': lang.code,
                                    'flag': lang.flag,
                                  })
                              .toList(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Devam Et',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
