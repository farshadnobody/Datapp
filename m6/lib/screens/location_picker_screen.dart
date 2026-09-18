import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../api_client.dart';

// انتخاب دستی موقعیت رو نقشه — برای وقتی GPS در دسترس نیست، دقیق نیست، یا
// کاربر ترجیح می‌ده موقعیت تقریبی نشون بده. از OpenStreetMap استفاده می‌کنیم
// (نه Google Maps) چون نیازی به API key یا صورت‌حساب نداره.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();

  // تهران به‌عنوان مرکز پیش‌فرض، تا وقتی موقعیت واقعی (اگه در دسترس بود) پیدا بشه.
  static const _defaultCenter = ll.LatLng(35.6892, 51.3890);

  bool _saving = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryCenterOnCurrentLocation();
  }

  Future<void> _tryCenterOnCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 8));
      _mapController.move(ll.LatLng(position.latitude, position.longitude), 15);
    } catch (_) {
      // بی‌خیال؛ همون مرکز فعلی می‌مونه، کاربر خودش نقشه رو جابه‌جا می‌کنه.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    HapticFeedback.lightImpact();
    // موقعیت لحظه‌ی تأیید رو مستقیم از خود کنترلر نقشه می‌خونیم — نیازی به
    // ردیابی زنده‌ی جابه‌جایی نداریم.
    final center = _mapController.camera.center;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ApiClient.updateLocation(center.latitude, center.longitude);
      if (mounted) Navigator.pop(context, true);
    } on NetworkException {
      setState(() => _error = 'ارتباط با سرور برقرار نشد.');
    } catch (e) {
      setState(() => _error = 'ذخیره‌ی موقعیت با مشکل مواجه شد.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انتخاب موقعیت رو نقشه')),
      floatingActionButton: FloatingActionButton(
        onPressed: _locating
            ? null
            : () {
                HapticFeedback.lightImpact();
                _tryCenterOnCurrentLocation();
              },
        child: _locating
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.my_location),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dating_app',
              ),
            ],
          ),
          // پین ثابت وسط صفحه — کاربر نقشه رو زیرش جابه‌جا می‌کنه، نه پین رو.
          Center(
            child: Transform.translate(
              offset: const Offset(0, -20), // نوک پین دقیقاً رو مرکز واقعی بیفته
              child: const Icon(Icons.location_pin, size: 40, color: Colors.pink),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 8),
                ],
                ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('تأیید این موقعیت'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
