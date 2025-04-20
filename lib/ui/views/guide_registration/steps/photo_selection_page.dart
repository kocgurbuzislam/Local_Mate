import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PhotoSelectionPage extends StatefulWidget {
  const PhotoSelectionPage({super.key});

  @override
  State<PhotoSelectionPage> createState() => _PhotoSelectionPageState();
}

class _PhotoSelectionPageState extends State<PhotoSelectionPage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isProcessing = true);

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        // Resmi işle
        final File processedImage = await _processImage(File(image.path));
        setState(() {
          _selectedImage = processedImage;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu')),
      );
    }
  }

  Future<File> _processImage(File imageFile) async {
    // Resmi oku
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) throw Exception('Resim okunamadı');

    // En boy oranını koru ve yeniden boyutlandır
    final minDimension = 800;
    final maxDimension = 1200;

    int width = image.width;
    int height = image.height;

    if (width > height) {
      if (width > maxDimension) {
        height = (height * maxDimension ~/ width);
        width = maxDimension;
      } else if (height < minDimension) {
        width = (width * minDimension ~/ height);
        height = minDimension;
      }
    } else {
      if (height > maxDimension) {
        width = (width * maxDimension ~/ height);
        height = maxDimension;
      } else if (width < minDimension) {
        height = (height * minDimension ~/ width);
        width = minDimension;
      }
    }

    // Resmi yeniden boyutlandır
    final resized = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    // Geçici dosya oluştur
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/processed_image.jpg';

    // Resmi kaydet
    final processedImageFile = File(tempPath);
    await processedImageFile.writeAsBytes(img.encodeJpg(resized, quality: 85));

    return processedImageFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Fotoğrafı'),
        actions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedImage);
              },
              child: const Text('Kaydet'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Profil Fotoğrafı Seç',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : _selectedImage == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 48,
                            color: Colors.grey,
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rehberlik profiliniz için bir fotoğraf seçin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Önerilen boyutlar: 800x800 piksel veya daha büyük\nİzin verilen formatlar: JPG, PNG',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotoğraf Seç'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
