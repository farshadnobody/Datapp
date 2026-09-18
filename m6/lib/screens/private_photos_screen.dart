import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../models/profile_models.dart';

// این صفحه کاملاً جدا از PhotoManagerScreen (عکس‌های پابلیک پروفایل) است —
// نه UI مشترک دارن، نه endpoint، نه پوشه‌ی ذخیره‌سازی. عمداً این‌جوریه تا کسی
// اشتباهی دکمه‌ی اشتباه رو نزنه.
class PrivatePhotosScreen extends StatefulWidget {
  const PrivatePhotosScreen({super.key});

  @override
  State<PrivatePhotosScreen> createState() => _PrivatePhotosScreenState();
}

class _PrivatePhotosScreenState extends State<PrivatePhotosScreen> {
  static const int maxPhotos = 6;
  final _picker = ImagePicker();

  List<PrivatePhoto> _photos = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final photos = await ApiClient.fetchPrivatePhotos();
      setState(() => _photos = photos);
    } catch (e) {
      setState(() => _error = 'دریافت لیست عکس‌ها با مشکل مواجه شد.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final photo = await ApiClient.uploadPrivatePhoto(bytes, picked.name);
      setState(() => _photos = [..._photos, photo]);
    } on NetworkException {
      setState(() => _error = 'ارتباط با سرور برقرار نشد. دوباره امتحان کن.');
    } on ApiException catch (e) {
      setState(() {
        switch (e.code) {
          case 'too_many_photos':
            _error = 'به حداکثر تعداد عکس خصوصی رسیدی.';
            break;
          case 'unsupported_file_type':
            _error = 'فرمت این فایل پشتیبانی نمی‌شه (jpg، png یا webp بفرست).';
            break;
          default:
            _error = 'آپلود عکس با مشکل مواجه شد.';
        }
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(PrivatePhoto photo) async {
    HapticFeedback.lightImpact();
    final previous = _photos;
    setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
    try {
      await ApiClient.deletePrivatePhoto(photo.id);
    } catch (e) {
      if (mounted) setState(() => _photos = previous);
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('انتخاب از گالری'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('گرفتن عکس با دوربین'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عکس‌های خصوصی')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'این عکس‌ها هیچ‌وقت پابلیک نمی‌شن و هیچ‌کس (حتی '
                          'کسایی که تو Discovery می‌بینت) بدون اجازه‌ی تو '
                          'نمی‌تونه ببینتشون.',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: maxPhotos,
                      itemBuilder: (context, index) {
                        if (index < _photos.length) {
                          return _buildPhotoTile(_photos[index]);
                        }
                        if (index == _photos.length) {
                          return _uploading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildAddTile();
                        }
                        return _buildEmptyTile();
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoTile(PrivatePhoto photo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            '$backendBaseUrl${photo.url}',
            headers: ApiClient.authHeaders(), // چون این عکس پشت احراز هویته
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
        Positioned(
          top: 2,
          left: 2,
          child: GestureDetector(
            onTap: () => _delete(photo),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTile() {
    return InkWell(
      onTap: _showSourcePicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyTile() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
