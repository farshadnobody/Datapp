import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import '../style/app_colors.dart';

/// نسخه‌ی تیره‌ی PhotoManagerScreen، مخصوص صفحه‌ی «پروفایل من» — همون
/// endpoint‌ها رو صدا می‌زنه (آپلود/حذف/چیدمان) ولی ظاهرش دقیقاً مثل
/// گرید «My Photos» تیندره: هر عکس با ضربدر بالای سمت چپش حذف می‌شه، سه‌تا
/// خونه‌ی خالی برای اضافه‌کردن، و زیرش لینک «نکات عکس».
class PhotoGridEditorScreen extends StatefulWidget {
  final List<Photo> initialPhotos;
  final int maxPhotos;
  const PhotoGridEditorScreen({super.key, required this.initialPhotos, required this.maxPhotos});

  @override
  State<PhotoGridEditorScreen> createState() => _PhotoGridEditorScreenState();
}

class _PhotoGridEditorScreenState extends State<PhotoGridEditorScreen> {
  final _picker = ImagePicker();
  late List<Photo> _photos = List.of(widget.initialPhotos);
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndUpload(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
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
      setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } on ApiException catch (e) {
      setState(() {
        switch (e.code) {
          case 'too_many_photos':
            _error = 'به حداکثر تعداد عکس رسیدی.';
            break;
          case 'unsupported_file_type':
            _error = 'فرمت این فایل پشتیبانی نمی‌شه.';
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
    } catch (_) {
      if (mounted) setState(() => _photos = previous);
    }
  }

  void _showSourcePicker() {
    if (_photos.length >= widget.maxPhotos) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDark.cardAlt,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('انتخاب از گالری', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('گرفتن عکس با دوربین', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        appBar: AppBar(
          backgroundColor: AppDark.bg,
          elevation: 0,
          title: const Text('عکس‌های من', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_photos),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppDark.warning)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: widget.maxPhotos,
                  itemBuilder: (context, index) {
                    if (index < _photos.length) return _tile(_photos[index]);
                    if (index == _photos.length) {
                      return _uploading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _addTile();
                    }
                    return _emptyTile();
                  },
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {},
                child: const Text('چطور با عکس‌هات بیشتر دیده بشی',
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Photo photo) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            '$backendBaseUrl${photo.url}',
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : const ColoredBox(color: AppDark.card),
            errorBuilder: (context, error, stack) => const ColoredBox(
              color: AppDark.card,
              child: Icon(Icons.broken_image_outlined, color: AppDark.muted),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () => _delete(photo),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black87,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _showSourcePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppDark.card,
          border: Border.all(color: AppDark.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Icon(Icons.add, color: Colors.white)),
      ),
    );
  }

  Widget _emptyTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppDark.card,
        border: Border.all(color: AppDark.border),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
