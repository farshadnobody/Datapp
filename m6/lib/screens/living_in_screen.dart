import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../style/app_colors.dart';

/// صفحه‌ی «زندگی در ...» — عکس ۱۱. چون تو این پروژه پکیج geocoding نداریم
/// (فقط geolocator برای مختصات)، «نزدیک موقعیت فعلی» فقط مختصات رو می‌گیره
/// و یه برچسب عمومی («موقعیت فعلی») برمی‌گردونه؛ اگه بعداً geocoding
/// اضافه شد، همین‌جا کافیه اسم واقعی شهر رو جایگزین کنی.
///
/// خروجی: String? — اسم شهر واردشده، یا null یعنی «نمی‌خوام نشون بدم»،
/// یا بدون تغییر (pop بدون مقدار) یعنی انصراف.
class LivingInScreen extends StatefulWidget {
  final String? initialCity;
  const LivingInScreen({super.key, this.initialCity});

  @override
  State<LivingInScreen> createState() => _LivingInScreenState();
}

class _LivingInScreenState extends State<LivingInScreen> {
  late final _controller = TextEditingController(text: widget.initialCity ?? '');
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اجازه‌ی دسترسی به موقعیت مکانی داده نشد.')),
          );
        }
        return;
      }
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 8));
      if (mounted) Navigator.of(context).pop('موقعیت فعلی');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('دریافت موقعیت با مشکل مواجه شد.')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
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
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(28)),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    final city = v.trim();
                    if (city.isNotEmpty) Navigator.of(context).pop(city);
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppDark.muted),
                    hintText: 'جستجوی شهر',
                    hintStyle: TextStyle(color: AppDark.muted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: _locating
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.near_me_outlined, color: Colors.white),
              title: const Text('نزدیک موقعیت فعلی', style: TextStyle(color: Colors.white)),
              onTap: _locating ? null : _useCurrentLocation,
            ),
            const Divider(color: AppDark.border, height: 1),
            ListTile(
              leading: const Icon(Icons.location_off_outlined, color: Colors.white),
              title: const Text('نمی‌خوام شهرم نشون داده بشه', style: TextStyle(color: Colors.white)),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop('');
              },
            ),
          ],
        ),
      ),
    );
  }
}
