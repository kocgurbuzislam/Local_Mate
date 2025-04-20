import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yerel_rehber_app/data/entity/route.dart' as app_route;
import 'package:yerel_rehber_app/data/repo/guide_repository.dart';
import '../../../colors.dart';

class AddRoute extends StatefulWidget {
  final String cityId;
  final String cityName;
  final List<Map<String, String>> selectedLanguages;

  const AddRoute({
    Key? key,
    required this.cityId,
    required this.cityName,
    required this.selectedLanguages,
  }) : super(key: key);

  @override
  State<AddRoute> createState() => _AddRouteState();
}

class _AddRouteState extends State<AddRoute> {
  final _formKey = GlobalKey<FormState>();
  final _routeController = TextEditingController();
  final List<String> _routes = [];

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  void _addRoute() {
    if (_routeController.text.isNotEmpty) {
      setState(() {
        _routes.add(_routeController.text);
        _routeController.clear();
      });
    }
  }

  void _removeRoute(int index) {
    setState(() {
      _routes.removeAt(index);
    });
  }

  Future<void> _saveRoutes() async {
    if (_routes.isNotEmpty) {
      try {
        final guideRepo = context.read<GuideRepository>();

        await guideRepo.saveGuideData(
          selectedLanguages: widget.selectedLanguages,
          selectedCity: {
            'id': widget.cityId,
            'name': widget.cityName,
          },
          routes: _routes,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rehber başvurunuz alındı')),
        );

        // Ana sayfaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir rota eklemelisiniz')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'selectedCity',
          child: Text('${widget.cityName} - Rota Ekle'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Hero(
              tag: 'searchBar',
              child: Material(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _routeController,
                        decoration: const InputDecoration(
                          hintText: 'Ziyaret edilecek yeri yazın',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addRoute(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addRoute,
                      icon: const Icon(Icons.add_circle),
                      color: mainColor,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Eklenmiş Rotalar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _routes.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz rota eklenmedi',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                        ),
                      )
                    : ListView.builder(
                        key: ValueKey<int>(_routes.length),
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(_routes[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeRoute(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Hero(
              tag: 'bottomButton',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRoutes,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Rotaları Kaydet'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
