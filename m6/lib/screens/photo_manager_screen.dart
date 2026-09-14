import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import 'home_screen.dart';

class PhotoManagerScreen extends StatefulWidget {
  const PhotoManagerScreen({super.key});

  @override
  State<PhotoManagerScreen> createState() => _PhotoManagerScreenState();
}

class _PhotoManagerScreenState extends State<PhotoManagerScreen> {
  final _picker = ImagePicker();

  ProfileOptions? _options; // فقط برای گرفتن max_photos از منبع واحد بک‌اند
  String? _loadError;

  List<Photo> _photos = [];
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await ApiClient.fetchProfileOptions();
      setState(() => _options = options);
    } catch (e) {
      setState(() => _loadError =
          'دریافت اطلاعات با مشکل مواجه شد. مطمئن شو به سرور وصلی و دوباره امتحان کن.');
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85, // فشرده‌سازی قبل از ارسال، برای آپلود سریع‌تر
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final photo = await ApiClient.uploadPhoto(bytes, picked.name);
      setState(() => _photos = [..._photos, photo]);
    } on NetworkException {
      setState(() => _error = 'ارتباط با سرور برقرار نشد. دوباره امتحان کن.');
    } on ApiException catch (e) {
      setState(() {
        switch (e.code) {
          case 'too_many_photos':
            _error = 'به حداکثر تعداد عکس رسیدی.';
            break;
          case 'unsupported_file_type':
            _error = 'فرمت این فایل پشتیبانی نمی‌شه (jpg، png یا webp بفرست).';
            break;
          case 'file_too_large':
            _error = 'حجم فایل زیاده.';
            break;
          default:
            _error = 'آپلود عکس با مشکل مواجه شد.';
        }
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(Photo photo) async {
    HapticFeedback.lightImpact();
    final previous = _photos;
    setState(() => _photos = _photos.where((p) => p.id != photo.id).toList());
    try {
      await ApiClient.deletePhoto(photo.id);
    } catch (e) {
      // اگه حذف سمت سرور شکست خورد، وضعیت قبلی رو برگردون.
      if (mounted) setState(() => _photos = previous);
    }
  }

  Future<void> _makePrimary(Photo photo) async {
    HapticFeedback.lightImpact();
    final order = [
      photo.id,
      ..._photos.where((p) => p.id != photo.id).map((p) => p.id),
    ];
    try {
      final updated = await ApiClient.reorderPhotos(order);
      if (mounted) setState(() => _photos = updated);
    } catch (e) {
      // بی‌خیال؛ دفعه‌ی بعد که چیزی تغییر کنه دوباره امتحان می‌شه.
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

  void _continue() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('عکس‌های پروفایل')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _loadOptions();
                  },
                  child: const Text('تلاش دوباره'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_options == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final maxPhotos = _options!.limits.maxPhotos;

    return Scaffold(
      appBar: AppBar(title: const Text('عکس‌های پروفایل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'حداقل یه عکس اضافه کن. اولین عکس، عکس اصلی پروفایلته — بعداً '
              'می‌تونی با زدن ⭐ روی هر عکس، اون رو عکس اصلی کنی.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: maxPhotos,
                itemBuilder: (context, index) {
                  if (index < _photos.length) {
                    return _buildPhotoTile(_photos[index], index == 0);
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _photos.isEmpty ? null : _continue,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('ادامه', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(Photo photo, bool isPrimary) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            '$backendBaseUrl${photo.url}',
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
        if (isPrimary)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.pink,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('اصلی',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
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
        if (!isPrimary)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _makePrimary(photo),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.star_outline, size: 14, color: Colors.white),
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
