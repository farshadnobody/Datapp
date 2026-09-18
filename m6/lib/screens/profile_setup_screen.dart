import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../auth_session.dart';
import '../models/profile_models.dart';
import 'photo_manager_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 5;

  ProfileOptions? _options;
  String? _loadError;

  // --- state فیلدهای فرم ---
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  String? _interestedIn;
  final _bioController = TextEditingController();
  final Set<String> _selectedInterests = {};
  final List<String> _selectedPromptIds = [];
  final Map<String, TextEditingController> _promptControllers = {};

  bool _submitting = false;
  String? _submitError;

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
          'دریافت اطلاعات فرم با مشکل مواجه شد. مطمئن شو به سرور وصلی و دوباره امتحان کن.');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    for (final c in _promptControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthdayThisYear = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }

  bool get _step0Valid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_options != null &&
        _nameController.text.trim().length > _options!.limits.maxNameLength) {
      return false;
    }
    if (_birthDate == null) return false;
    if (_options == null) return true;
    final age = _calculateAge(_birthDate!);
    return age >= _options!.limits.minAge && age <= _options!.limits.maxAge;
  }

  bool get _step1Valid => _gender != null && _interestedIn != null;

  bool get _step2Valid =>
      _options == null || _bioController.text.length <= _options!.limits.maxBioLength;

  bool get _step3Valid {
    if (_options == null) return _selectedInterests.isNotEmpty;
    return _selectedInterests.length >= _options!.limits.minInterests &&
        _selectedInterests.length <= _options!.limits.maxInterests;
  }

  bool get _step4Valid {
    for (final id in _selectedPromptIds) {
      final text = _promptControllers[id]?.text.trim() ?? '';
      if (text.isEmpty) return false;
    }
    return true;
  }

  bool get _currentStepValid {
    switch (_step) {
      case 0:
        return _step0Valid;
      case 1:
        return _step1Valid;
      case 2:
        return _step2Valid;
      case 3:
        return _step3Valid;
      case 4:
        return _step4Valid;
      default:
        return true;
    }
  }

  void _goNext() {
    if (!_currentStepValid) return;
    HapticFeedback.lightImpact();
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goBack() {
    if (_step == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _step--);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final input = ProfileInput(
        name: _nameController.text.trim(),
        birthDate:
            '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        gender: _gender!,
        interestedIn: _interestedIn!,
        bio: _bioController.text.trim(),
        interests: _selectedInterests.toList(),
        prompts: _selectedPromptIds
            .map((id) => PromptAnswer(
                promptId: id, answer: _promptControllers[id]!.text.trim()))
            .toList(),
      );
      await ApiClient.saveProfile(input);
      // دفعه‌ی بعد که اپ باز شد مستقیم بره صفحه‌ی اصلی، نه ساخت پروفایل.
      await AuthSession.setHasProfile(true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhotoManagerScreen()),
        (route) => false,
      );
    } on NetworkException {
      setState(() => _submitError =
          'ارتباط با سرور برقرار نشد. دوباره امتحان کن.');
    } on ApiException {
      setState(() => _submitError =
          'یه مشکلی تو اطلاعات واردشده هست. مراحل قبلی رو دوباره چک کن.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تکمیل پروفایل')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('تکمیل پروفایل')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // فقط با دکمه جابه‌جا شو
              children: [
                _buildBasicsStep(),
                _buildPreferencesStep(),
                _buildBioStep(),
                _buildInterestsStep(),
                _buildPromptsStep(),
              ],
            ),
          ),
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _stepPadding(Widget child) =>
      Padding(padding: const EdgeInsets.all(24), child: child);

  Widget _buildBasicsStep() {
    return _stepPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('بیا با چندتا اطلاعات پایه شروع کنیم',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            maxLength: _options!.limits.maxNameLength,
            decoration: const InputDecoration(
              labelText: 'اسمت چیه؟',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now()
                    .subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime.now()
                    .subtract(Duration(days: 365 * (_options!.limits.maxAge + 1))),
                lastDate: DateTime.now()
                    .subtract(Duration(days: 365 * _options!.limits.minAge)),
              );
              if (picked != null) {
                HapticFeedback.selectionClick();
                setState(() => _birthDate = picked);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'تاریخ تولد',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _birthDate == null
                    ? 'انتخاب کن'
                    : '${_birthDate!.year}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.day.toString().padLeft(2, '0')}  (${_calculateAge(_birthDate!)} ساله)',
              ),
            ),
          ),
          if (_birthDate != null &&
              _calculateAge(_birthDate!) < _options!.limits.minAge) ...[
            const SizedBox(height: 8),
            Text('باید حداقل ${_options!.limits.minAge} سالت باشه.',
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return _stepPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('جنسیت و ترجیحاتت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('جنسیت من:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _options!.genders
                .map((g) => ChoiceChip(
                      label: Text(g.label),
                      selected: _gender == g.id,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _gender = g.id);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text('به دنبال:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _options!.interestedIn
                .map((o) => ChoiceChip(
                      label: Text(o.label),
                      selected: _interestedIn == o.id,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _interestedIn = o.id);
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBioStep() {
    return _stepPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('چندجمله راجع به خودت بنویس',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('این قسمت اختیاریه، ولی پروفایل‌هایی که یه بیوی کوتاه دارن '
              'معمولاً بیشتر دیده می‌شن.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLength: _options!.limits.maxBioLength,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'مثلاً: عاشق کوه و قهوه‌ام، دنبال یکی که...',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep() {
    final limits = _options!.limits;
    return _stepPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('چندتا علاقه‌مندی انتخاب کن',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'بین ${limits.minInterests} تا ${limits.maxInterests} تا انتخاب کن (${_selectedInterests.length} انتخاب شده)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _options!.interests.map((interest) {
                  final selected = _selectedInterests.contains(interest.id);
                  return FilterChip(
                    label: Text(interest.label),
                    selected: selected,
                    onSelected: (isSelected) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          if (_selectedInterests.length < limits.maxInterests) {
                            _selectedInterests.add(interest.id);
                          }
                        } else {
                          _selectedInterests.remove(interest.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptsStep() {
    final limits = _options!.limits;
    return _stepPadding(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('چندتا سؤال کوتاه جواب بده (اختیاری)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'پروفایل‌هایی که این بخش رو پر می‌کنن، معمولاً خیلی راحت‌تر مکالمه شروع می‌شه '
            '(حداکثر ${limits.maxPrompts} تا).',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                ..._selectedPromptIds.map((id) {
                  final prompt =
                      _options!.prompts.firstWhere((p) => p.id == id);
                  _promptControllers.putIfAbsent(
                      id, () => TextEditingController());
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(prompt.text,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selectedPromptIds.remove(id);
                                    _promptControllers[id]?.dispose();
                                    _promptControllers.remove(id);
                                  });
                                },
                              ),
                            ],
                          ),
                          TextField(
                            controller: _promptControllers[id],
                            maxLength: limits.maxBioLength,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(hintText: 'جوابت...'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_selectedPromptIds.length < limits.maxPrompts)
                  ..._options!.prompts
                      .where((p) => !_selectedPromptIds.contains(p.id))
                      .map((p) => ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: Text(p.text),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedPromptIds.add(p.id));
                            },
                          )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_submitError != null) ...[
            Text(_submitError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _goBack,
                    child: const Text('قبلی'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      (_currentStepValid && !_submitting) ? _goNext : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_step == _totalSteps - 1 ? 'ثبت پروفایل' : 'بعدی'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
