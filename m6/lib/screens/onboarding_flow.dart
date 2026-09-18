import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../auth_session.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import 'auth_ui.dart'; // AuthColors, kAppName
import 'home_screen.dart';

/// رنگ‌های اختصاصیِ این فلو (تم تیره، هم‌رنگ با AuthColors.red تا برند اپ
/// یکدست بمونه — این عمداً کپیِ پالت هیچ اپ خاصی نیست).
class _OB {
  static const bg = Colors.black;
  static const card = Color(0xFF1C1C1E);
  static const border = Color(0xFF3A3A3C);
  static const muted = Color(0xFF9B9B9E);
  static const accent = AuthColors.red;
}

/// صفحه‌ی «قوانین خونه» — اولین صفحه‌ای که کاربر بعد از ثبت‌نام می‌بینه.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.favorite, color: _OB.accent, size: 40),
                const SizedBox(height: 20),
                const Text(
                  'به $kAppName خوش اومدی.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'لطفاً این قوانین رو رعایت کن.',
                  style: TextStyle(color: _OB.muted, fontSize: 15),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView(
                    children: const [
                      _RuleItem(
                        title: 'خودت باش.',
                        body:
                            'مطمئن شو عکس‌ها، سنّ و بیوت واقعاً همون چیزیه که هستی.',
                      ),
                      _RuleItem(
                        title: 'مراقب خودت باش.',
                        body:
                            'اطلاعات شخصیت رو زود به کسی نده. با احتیاط قرار حضوری بذار.',
                      ),
                      _RuleItem(
                        title: 'محترمانه رفتار کن.',
                        body:
                            'به بقیه همون‌طوری رفتار کن که دوست داری باهات رفتار بشه.',
                      ),
                      _RuleItem(
                        title: 'فعال باش.',
                        body: 'رفتار نامناسب رو همیشه گزارش بده.',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const OnboardingFlowScreen(),
                      ));
                    },
                    child: const Text('قبول دارم',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String title;
  final String body;
  const _RuleItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  color: _OB.muted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// خودِ فلوی چندمرحله‌ای: هر سؤال یه صفحه، با نوار پیشرفت بالا، دکمه‌ی
/// برگشت، و دکمه‌ی «رد کردن» برای مراحل اختیاری.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

enum _Step {
  name,
  birthday,
  gender,
  orientation,
  seeing,
  lookingFor,
  education,
  school,
  lifestyle,
  aboutYou,
  interests,
  photos,
  bio,
  prompt,
  location,
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _index = 0;
  final _steps = _Step.values;

  ProfileOptions? _serverOptions; // برای گرفتن لیست prompts/limits از بک‌اند
  bool _loadingOptions = true;

  // --- state جواب‌ها ---
  final _nameController = TextEditingController();
  DateTime _birthDate = DateTime(2000, 1, 1);
  final Set<String> _genders = {};
  bool _showGenderOnProfile = true;
  final Set<String> _orientations = {};
  bool _showOrientationOnProfile = false;
  final Set<String> _seeing = {};
  String? _lookingFor;
  String? _education;
  final _schoolController = TextEditingController();
  final Map<String, String> _lifestyle = {};
  final Map<String, String> _aboutYou = {};
  final Set<String> _interests = {};
  final List<XFile> _photos = [];
  final _bioController = TextEditingController();
  String? _selectedPromptId;
  String? _selectedPromptText;
  final _promptAnswerController = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  static const int _maxInterests = 10;
  static const int _minPhotos = 2;
  static const int _maxPhotos = 9;
  static const int _maxBioLength = 500;
  static const int _maxPromptLength = 150;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await ApiClient.fetchProfileOptions();
      setState(() {
        _serverOptions = options;
        _loadingOptions = false;
      });
    } catch (_) {
      // اگه بک‌اند هنوز این فیلدهای جدید رو نداشت، با پرامپت‌های محلی ادامه بده.
      setState(() => _loadingOptions = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _schoolController.dispose();
    _bioController.dispose();
    _promptAnswerController.dispose();
    super.dispose();
  }

  int get _age {
    final now = DateTime.now();
    int age = now.year - _birthDate.year;
    final hadBirthday = (now.month > _birthDate.month) ||
        (now.month == _birthDate.month && now.day >= _birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  bool get _currentValid {
    switch (_steps[_index]) {
      case _Step.name:
        return _nameController.text.trim().isNotEmpty;
      case _Step.birthday:
        return _age >= 18;
      case _Step.gender:
        return _genders.isNotEmpty;
      case _Step.orientation:
        return true; // اختیاریه، «رد کردن» هم داره
      case _Step.seeing:
        return _seeing.isNotEmpty;
      case _Step.lookingFor:
        return true;
      case _Step.education:
        return true;
      case _Step.school:
        return true;
      case _Step.lifestyle:
        return true;
      case _Step.aboutYou:
        return true;
      case _Step.interests:
        return true;
      case _Step.photos:
        return _photos.length >= _minPhotos;
      case _Step.bio:
        return _bioController.text.length <= _maxBioLength;
      case _Step.prompt:
        return true;
      case _Step.location:
        return true;
    }
  }

  void _goNext() async {
    if (!_currentValid) return;
    HapticFeedback.lightImpact();
    if (_steps[_index] == _Step.name) {
      final confirmed = await _showNameConfirmSheet();
      if (confirmed != true) return;
    }
    if (_index == _steps.length - 1) {
      await _finishOnboarding();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goBack() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _index--);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _skip() {
    HapticFeedback.lightImpact();
    if (_index == _steps.length - 1) {
      _finishOnboarding();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<bool?> _showNameConfirmSheet() {
    final name = _nameController.text.trim();
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: _OB.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('خوش اومدی، $name!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'کلی آدم جدید منتظرته. اول بیا پروفایلت رو کامل کنیم.',
                style: TextStyle(color: _OB.muted, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('بزن بریم'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ویرایش اسم',
                    style: TextStyle(color: _OB.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final prompts = <PromptAnswer>[];
      if (_selectedPromptId != null &&
          _promptAnswerController.text.trim().isNotEmpty) {
        prompts.add(PromptAnswer(
          promptId: _selectedPromptId!,
          answer: _promptAnswerController.text.trim(),
        ));
      }

      final input = ProfileInput(
        name: _nameController.text.trim(),
        birthDate:
            '${_birthDate.year.toString().padLeft(4, '0')}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}',
        // اگه بک‌اند هنوز چندانتخابی نداره، اولین مقدار رو به‌عنوان فیلد
        // اصلی gender/interestedIn می‌فرستیم تا با API فعلی سازگار بمونه.
        gender: _genders.isNotEmpty ? _genders.first : '',
        interestedIn: _seeing.isNotEmpty ? _seeing.first : '',
        bio: _bioController.text.trim(),
        interests: _interests.toList(),
        prompts: prompts,
        genders: _genders.toList(),
        showGenderOnProfile: _showGenderOnProfile,
        sexualOrientations: _orientations.toList(),
        showOrientationOnProfile: _showOrientationOnProfile,
        interestedInMulti: _seeing.toList(),
        lookingFor: _lookingFor,
        educationLevel: _education,
        school: _schoolController.text.trim(),
        lifestyle: _lifestyle,
        aboutYou: _aboutYou,
      );
      await ApiClient.saveProfile(input);

      for (final photo in _photos) {
        final bytes = await photo.readAsBytes();
        await ApiClient.uploadPhoto(bytes, photo.name);
      }

      await _requestLocationSilently();

      await AuthSession.setHasProfile(true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on NetworkException {
      setState(
          () => _submitError = 'ارتباط با سرور برقرار نشد. دوباره امتحان کن.');
    } on ApiException {
      setState(() =>
          _submitError = 'یه مشکلی تو اطلاعات واردشده هست. مراحل قبلی رو چک کن.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestLocationSilently() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await ApiClient.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // موقعیت اختیاریه؛ اگه نشد، اونبوردینگ رو متوقف نکن.
    }
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadingOptions) {
      return const Scaffold(
        backgroundColor: _OB.bg,
        body: Center(child: CircularProgressIndicator(color: _OB.accent)),
      );
    }

    final step = _steps[_index];
    final progress = (_index + 1) / _steps.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: Scaffold(
          backgroundColor: _OB.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(step, progress),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _steps.map(_buildStepBody).toList(),
                  ),
                ),
                _buildBottomBar(step),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSkippable(_Step step) {
    switch (step) {
      case _Step.name:
      case _Step.birthday:
      case _Step.gender:
      case _Step.seeing:
      case _Step.photos:
        return false;
      default:
        return true;
    }
  }

  Widget _buildHeader(_Step step, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _submitting ? null : _goBack,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: _OB.border,
                valueColor: const AlwaysStoppedAnimation(_OB.accent),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: _isSkippable(step)
                ? TextButton(
                    onPressed: _submitting ? null : _skip,
                    child: const Text('رد کردن',
                        style: TextStyle(color: _OB.muted)),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_Step step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_submitError != null) ...[
            Text(_submitError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _currentValid ? Colors.white : _OB.border,
                foregroundColor:
                    _currentValid ? Colors.black : _OB.muted,
                disabledBackgroundColor: _OB.border,
                disabledForegroundColor: _OB.muted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              onPressed:
                  (_currentValid && !_submitting) ? _goNext : null,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black54))
                  : Text(
                      step == _Step.location ? 'شروع کن' : 'بعدی',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(_Step step) {
    switch (step) {
      case _Step.name:
        return _stepName();
      case _Step.birthday:
        return _stepBirthday();
      case _Step.gender:
        return _stepGender();
      case _Step.orientation:
        return _stepOrientation();
      case _Step.seeing:
        return _stepSeeing();
      case _Step.lookingFor:
        return _stepLookingFor();
      case _Step.education:
        return _stepEducation();
      case _Step.school:
        return _stepSchool();
      case _Step.lifestyle:
        return _stepCategorized(
          title: 'بیا از عادت‌های زندگیت بگیم',
          subtitle: 'عادت‌هاتون بهم می‌خوره؟ اول تو بگو.',
          categories: kLifestyleCategories,
          selections: _lifestyle,
          counterLabel:
              'بعدی ${_lifestyle.length}/${kLifestyleCategories.length}',
        );
      case _Step.aboutYou:
        return _stepCategorized(
          title: 'چی تو رو، تو می‌کنه؟',
          subtitle: 'رو نگیر. اصالت جذابیت میاره.',
          categories: kAboutYouCategories,
          selections: _aboutYou,
          counterLabel:
              'بعدی ${_aboutYou.length}/${kAboutYouCategories.length}',
        );
      case _Step.interests:
        return _stepInterests();
      case _Step.photos:
        return _stepPhotos();
      case _Step.bio:
        return _stepBio();
      case _Step.prompt:
        return _stepPrompt();
      case _Step.location:
        return _stepLocation();
    }
  }

  // ------------------------- ویجت‌های عمومی -------------------------

  Widget _scrollableStep({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle,
                style: const TextStyle(
                    color: _OB.muted, fontSize: 14, height: 1.5)),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _selectableBox({
    required String label,
    String? description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? Colors.white : _OB.border, width: 1.4),
            color: selected ? Colors.white10 : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description,
                    style:
                        const TextStyle(color: _OB.muted, fontSize: 12.5, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.white : _OB.border, width: 1.2),
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _checkboxRow(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: _OB.accent,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _OB.muted, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- مراحل -------------------------

  Widget _stepName() {
    return _scrollableStep(
      title: 'اسمت چیه؟',
      subtitle: 'همینی که وارد می‌کنی تو پروفایلت نشون داده می‌شه. بعداً '
          'نمی‌تونی عوضش کنی.',
      child: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        maxLength: 40,
        decoration: const InputDecoration(
          hintText: 'اسم کوچیکت رو بنویس',
          hintStyle: TextStyle(color: _OB.muted),
          counterStyle: TextStyle(color: _OB.muted),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.border)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.accent, width: 2)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _stepBirthday() {
    return _scrollableStep(
      title: 'تولدت کِیه؟',
      subtitle: 'تو پروفایلت فقط سنّت نشون داده می‌شه، نه تاریخ تولدت.',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _birthDate,
                maximumDate: DateTime.now(),
                minimumDate: DateTime(1930, 1, 1),
                onDateTimeChanged: (d) => setState(() => _birthDate = d),
              ),
            ),
          ),
          if (_age < 18) ...[
            const SizedBox(height: 8),
            const Text('باید حداقل ۱۸ سالت باشه.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _stepGender() {
    return _scrollableStep(
      title: 'جنسیتت چیه؟',
      subtitle:
          'هرچی که با هویتت جور در میاد رو انتخاب کن. می‌تونی چندتا بزنی.',
      child: Column(
        children: [
          ...kGenderOptions.map((o) => _selectableBox(
                label: o.label,
                selected: _genders.contains(o.id),
                onTap: () => setState(() {
                  _genders.contains(o.id)
                      ? _genders.remove(o.id)
                      : _genders.add(o.id);
                }),
              )),
          const SizedBox(height: 8),
          _checkboxRow('جنسیتم تو پروفایل نشون داده بشه', _showGenderOnProfile,
              (v) => setState(() => _showGenderOnProfile = v)),
        ],
      ),
    );
  }

  Widget _stepOrientation() {
    return _scrollableStep(
      title: 'گرایش جنسیت چیه؟',
      subtitle: 'هرچی که هویتت رو نشون می‌ده انتخاب کن.',
      child: Column(
        children: [
          ...kOrientationOptions.map((o) => _selectableBox(
                label: o.label,
                description: o.description,
                selected: _orientations.contains(o.id),
                onTap: () => setState(() {
                  _orientations.contains(o.id)
                      ? _orientations.remove(o.id)
                      : _orientations.add(o.id);
                }),
              )),
          const SizedBox(height: 8),
          _checkboxRow('گرایش جنسیم تو پروفایل نشون داده بشه',
              _showOrientationOnProfile,
              (v) => setState(() => _showOrientationOnProfile = v)),
        ],
      ),
    );
  }

  Widget _stepSeeing() {
    return _scrollableStep(
      title: 'به دنبال دیدن چه کسایی هستی؟',
      subtitle: 'هرچی که مدنظرته رو انتخاب کن تا بهترین پیشنهادها رو بهت بدیم.',
      child: Column(
        children: kSeeingOptions
            .map((o) => _selectableBox(
                  label: o.label,
                  selected: _seeing.contains(o.id),
                  onTap: () => setState(() {
                    _seeing.contains(o.id)
                        ? _seeing.remove(o.id)
                        : _seeing.add(o.id);
                  }),
                ))
            .toList(),
      ),
    );
  }

  Widget _stepLookingFor() {
    return _scrollableStep(
      title: 'دنبال چه نوع رابطه‌ای هستی؟',
      subtitle: 'مشکلی نیست اگه بعداً عوض شد. یه چیزی برای همه هست.',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: kLookingForOptions.map((o) {
          final selected = _lookingFor == o.id;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _lookingFor = o.id);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Colors.white : _OB.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? Colors.white : _OB.border, width: 1.4),
              ),
              child: Text(o.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepEducation() {
    return _scrollableStep(
      title: 'میزان تحصیلاتت چیه؟',
      subtitle: 'این به بهتر شدن پیشنهادهات کمک می‌کنه.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kEducationOptions
            .map((o) => _pillChip(
                  label: o.label,
                  selected: _education == o.id,
                  onTap: () => setState(() => _education = o.id),
                ))
            .toList(),
      ),
    );
  }

  Widget _stepSchool() {
    return _scrollableStep(
      title: 'کجا درس خوندی؟',
      subtitle: 'یه حس اشتراک، راه ارتباط رو بازتر می‌کنه.',
      child: TextField(
        controller: _schoolController,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        decoration: const InputDecoration(
          hintText: 'اسم مدرسه یا دانشگاه',
          hintStyle: TextStyle(color: _OB.muted),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.border)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.accent, width: 2)),
        ),
      ),
    );
  }

  Widget _stepCategorized({
    required String title,
    required String subtitle,
    required List<OptionCategory> categories,
    required Map<String, String> selections,
    required String counterLabel,
  }) {
    return _scrollableStep(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cat.items
                      .map((item) => _pillChip(
                            label: item.label,
                            selected: selections[cat.id] == item.id,
                            onTap: () => setState(() {
                              if (selections[cat.id] == item.id) {
                                selections.remove(cat.id);
                              } else {
                                selections[cat.id] = item.id;
                              }
                            }),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepInterests() {
    return _scrollableStep(
      title: 'به چی علاقه داری؟',
      subtitle:
          'تا ۱۰ تا انتخاب کن تا با آدم‌هایی که سلیقه‌ی مشترک دارن راحت‌تر '
          'وصل بشی. (${_interests.length}/$_maxInterests)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kInterestCategories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cat.items.map((item) {
                    final selected = _interests.contains(item.id);
                    return _pillChip(
                      label: item.label,
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _interests.remove(item.id);
                        } else if (_interests.length < _maxInterests) {
                          _interests.add(item.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepPhotos() {
    return _scrollableStep(
      title: 'چندتا عکس اخیرت رو اضافه کن',
      subtitle:
          'حداقل $_minPhotos عکس آپلود کن تا شروع کنی. هرچی بیشتر باشه، '
          'پروفایلت بهتر دیده می‌شه.',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _maxPhotos,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, i) {
          if (i < _photos.length) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_photos[i].path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _photos.removeAt(i));
                    },
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black87,
                      child:
                          Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickPhoto,
            child: Container(
              decoration: BoxDecoration(
                color: _OB.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _OB.border),
              ),
              child: const Icon(Icons.add, color: Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      HapticFeedback.lightImpact();
      setState(() => _photos.add(file));
    }
  }

  Widget _stepBio() {
    return _scrollableStep(
      title: 'بیشتر راجع به خودت بگو',
      subtitle: 'یه بیوی خوب و کوتاه بنویس تا شروع مکالمه راحت‌تر بشه.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _bioController,
            style: const TextStyle(color: Colors.white),
            maxLines: 6,
            maxLength: _maxBioLength,
            decoration: const InputDecoration(
              hintText: 'مثلاً: عاشق کوه و قهوه‌ام، دنبال یکی که...',
              hintStyle: TextStyle(color: _OB.muted),
              counterStyle: TextStyle(color: _OB.muted),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _OB.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _OB.accent, width: 2)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _OB.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'بیوهای خوب کوتاه و مشخصن. از علاقه‌مندی‌ها، ارزش‌هات و اینکه '
              'دنبال چی هستی بگو.',
              style: TextStyle(color: _OB.muted, fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepPrompt() {
    final prompts = (_serverOptions?.prompts.isNotEmpty ?? false)
        ? _serverOptions!.prompts
            .map((p) => OptionItem(p.id, p.text))
            .toList()
        : kFallbackPrompts;

    if (_selectedPromptId != null) {
      return _scrollableStep(
        title: 'جواب بده',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_selectedPromptText ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _OB.muted),
                  onPressed: () => setState(() {
                    _selectedPromptId = null;
                    _selectedPromptText = null;
                    _promptAnswerController.clear();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptAnswerController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: _maxPromptLength,
              decoration: const InputDecoration(
                hintText: 'یه‌چیز باحال بنویس...',
                hintStyle: TextStyle(color: _OB.muted),
                counterStyle: TextStyle(color: _OB.muted),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _OB.border)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _OB.accent, width: 2)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );
    }

    return _scrollableStep(
      title: 'یه پرامپت انتخاب کن',
      subtitle: 'جواب دادن به یه سؤال کوتاه، مکالمه رو خیلی راحت‌تر شروع می‌کنه.',
      child: Column(
        children: prompts
            .map((p) => InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedPromptId = p.id;
                      _selectedPromptText = p.label;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _OB.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(p.label,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _stepLocation() {
    return _scrollableStep(
      title: 'اهل همین اطرافی؟',
      subtitle:
          'موقعیتت رو فعال کن تا آدم‌های نزدیکت رو ببینی. بدون این، کسی '
          'باهات مچ نمی‌شه. موقعیت دقیقت هیچ‌وقت با کسی به اشتراک گذاشته نمی‌شه.',
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.location_on, color: Colors.black, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'با زدن «شروع کن»، پروفایلت ساخته می‌شه و می‌تونی وارد اپ بشی.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _OB.muted, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
