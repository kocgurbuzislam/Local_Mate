import 'package:flutter/material.dart';

class BiographyPage extends StatefulWidget {
  const BiographyPage({super.key});

  @override
  State<BiographyPage> createState() => _BiographyPageState();
}

class _BiographyPageState extends State<BiographyPage> {
  final TextEditingController _bioController = TextEditingController();
  final int _maxLength = 500;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biyografi'),
        actions: [
          TextButton(
            onPressed: _bioController.text.isNotEmpty
                ? () {
                    Navigator.pop(context, _bioController.text);
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
              'Kendinizi Tanıtın',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rehberlik deneyiminizi ve ilgi alanlarınızı paylaşın',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _bioController,
                maxLength: _maxLength,
                maxLines: 8,
                onChanged: (value) => setState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'Örneğin: 5 yıldır profesyonel rehberlik yapıyorum. Tarihi yerler ve yerel lezzetler konusunda uzmanım...',
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'İpucu: Detaylı bir biyografi, ziyaretçilerin sizi seçme olasılığını artırır.',
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
