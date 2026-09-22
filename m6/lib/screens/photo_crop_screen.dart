import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../style/app_colors.dart';

/// صفحه‌ی «تنظیم قاب عکس» — قبل از آپلود باز می‌شه تا کاربر با جابه‌جا کردن
/// و زوم، انتخاب کنه کدوم بخش از عکس داخل قاب بیفته.
///
/// چون پکیج جدا (مثل image_cropper) تو این محیط قابل نصب نیست (دسترسی به
/// pub.dev نداریم)، این پیاده‌سازی فقط با ابزارهای خودِ Flutter ساخته شده:
/// عکس رو تو یه InteractiveViewer قابل جابه‌جایی/زوم می‌ذاریم، و وقتی کاربر
/// تأیید کرد، همون قابِ دیده‌شده رو با RepaintBoundary.toImage() می‌گیریم و
/// به‌صورت PNG برمی‌گردونیم.
class PhotoCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  /// نسبت ابعاد قاب (عرض/ارتفاع) — پیش‌فرض ۴:۵ مثل عکس‌های تیندر.
  final double aspectRatio;

  const PhotoCropScreen({super.key, required this.imageBytes, this.aspectRatio = 4 / 5});

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _boundaryKey = GlobalKey();
  final _transformController = TransformationController();
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      // یه فریم صبر می‌کنیم تا مطمئن بشیم آخرین حالت pan/zoom رندر شده.
      await Future.delayed(const Duration(milliseconds: 20));
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('capture failed');
      if (mounted) Navigator.of(context).pop(byteData.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تنظیم قاب با مشکل مواجه شد. دوباره امتحان کن.')));
      }
    }
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
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('تنظیم قاب عکس', style: TextStyle(color: Colors.white, fontSize: 17)),
          actions: [
            TextButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تأیید', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text('با دو انگشت زوم کن و عکس رو جابه‌جا کن تا بخش موردنظرت داخل قاب بیفته.',
                  style: TextStyle(color: AppDark.muted, fontSize: 13)),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: ColoredBox(
                        color: Colors.black,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1,
                          maxScale: 4,
                          child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
