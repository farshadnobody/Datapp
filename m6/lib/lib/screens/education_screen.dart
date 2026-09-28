import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../style/app_colors.dart';

/// صفحه‌ی «Edit School Info» — لیست مدرسه/دانشگاه‌های واردشده (فعلاً فقط
/// یکی، چون بک‌اند هم فقط یه فیلد school داره) + ردیف «Apply for Tinder U»
/// که تو این پروژه غیرفعاله (فقط تزئینیه، مثل بنر Tinder Gold).
///
/// خروجی: String? اسم مدرسه (یا '' برای حذف)، یا null یعنی بدون تغییر.
class EditSchoolInfoScreen extends StatefulWidget {
  final String? initialSchool;
  const EditSchoolInfoScreen({super.key, this.initialSchool});

  @override
  State<EditSchoolInfoScreen> createState() => _EditSchoolInfoScreenState();
}

class _EditSchoolInfoScreenState extends State<EditSchoolInfoScreen> {
  String? _school;

  @override
  void initState() {
    super.initState();
    _school = (widget.initialSchool?.isNotEmpty ?? false) ? widget.initialSchool : null;
  }

  Future<void> _addOrEditSchool() async {
    final controller = TextEditingController(text: _school ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppDark.cardAlt,
          title: const Text('مدرسه یا دانشگاه', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'اسم مدرسه یا دانشگاه',
              hintStyle: TextStyle(color: AppDark.muted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('انصراف', style: TextStyle(color: AppDark.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('ثبت', style: TextStyle(color: AppDark.accent)),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      HapticFeedback.lightImpact();
      setState(() => _school = result.isEmpty ? null : result);
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
          title: const Text('ویرایش اطلاعات تحصیلی', style: TextStyle(color: Colors.white, fontSize: 18)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_school ?? ''),
          ),
        ),
        body: ListView(
          children: [
            if (_school != null)
              ListTile(
                title: Text(_school!, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppDark.muted),
                  onPressed: () => setState(() => _school = null),
                ),
                onTap: _addOrEditSchool,
              )
            else
              ListTile(
                title: const Text('افزودن مدرسه', style: TextStyle(color: Colors.white)),
                onTap: _addOrEditSchool,
              ),
            const Divider(color: AppDark.border, height: 1),
            ListTile(
              title: const Text('درخواست Tinder U', style: TextStyle(color: AppDark.accent)),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('این قابلیت به‌زودی اضافه می‌شه.')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
