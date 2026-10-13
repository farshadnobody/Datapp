import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import 'photo_manager_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  ProfileOptions? _options;
  MyProfile? _profile;
  String? _loadError;

  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String? _gender;
  String? _interestedIn;
  final _bioController = TextEditingController();
  final Set<String> _selectedInterests = {};
  final List<String> _selectedPromptIds = [];
  final Map<String, TextEditingController> _promptControllers = {};

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait([
        ApiClient.fetchProfileOptions(),
        ApiClient.fetchMyProfile(),
      ]);
      final options = results[0] as ProfileOptions;
      final profile = results[1] as MyProfile;

      _nameController.text = profile.name;
      _birthDate = DateTime.parse(profile.birthDate);
      _gender = profile.gender;
      _interestedIn = profile.interestedIn;
      _bioController.text = profile.bio;
      _selectedInterests
        ..clear()
        ..addAll(profile.interests);
      _selectedPromptIds
        ..clear()
        ..addAll(profile.prompts.map((p) => p.promptId));
      for (final p in profile.prompts) {
        _promptControllers[p.promptId] = TextEditingController(text: p.answer);
      }

      setState(() {
        _options = options;
        _profile = profile;
      });
    } catch (e) {
      setState(() => _loadError = 'دریافت اطلاعات پروفایل با مشکل مواجه شد.');
    }
  }

  @override
  void dispose() {
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

  bool get _canSave {
    if (_options == null) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_nameController.text.trim().length > _options!.limits.maxNameLength) return false;
    if (_birthDate == null) return false;
    if (_gender == null || _interestedIn == null) return false;
    if (_selectedInterests.length < _options!.limits.minInterests ||
        _selectedInterests.length > _options!.limits.maxInterests) {
      return false;
    }
    for (final id in _selectedPromptIds) {
      if ((_promptControllers[id]?.text.trim() ?? '').isEmpty) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    HapticFeedback.lightImpact();
    setState(() {
      _saving = true;
      _saveError = null;
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('پروفایل به‌روزرسانی شد ✅')));
      }
    } on NetworkException {
      setState(() => _saveError = 'ارتباط با سرور برقرار نشد.');
    } on ApiException {
      setState(() => _saveError = 'ذخیره‌سازی با مشکل مواجه شد. فیلدها رو چک کن.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('پروفایل من')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
            ]),
          ),
        ),
      );
    }

    if (_options == null || _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final limits = _options!.limits;

    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل من')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('مدیریت عکس‌های پروفایل'),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PhotoManagerScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            maxLength: limits.maxNameLength,
            decoration: const InputDecoration(labelText: 'اسم', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                firstDate: DateTime.now().subtract(Duration(days: 365 * (limits.maxAge + 1))),
                lastDate: DateTime.now().subtract(Duration(days: 365 * limits.minAge)),
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'تاریخ تولد', border: OutlineInputBorder()),
              child: Text(_birthDate == null
                  ? 'انتخاب کن'
                  : '${_birthDate!.year}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.day.toString().padLeft(2, '0')}  (${_calculateAge(_birthDate!)} ساله)'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('جنسیت من:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _options!.genders
                .map((g) => ChoiceChip(
                      label: Text(g.label),
                      selected: _gender == g.id,
                      onSelected: (_) => setState(() => _gender = g.id),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('به دنبال:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _options!.interestedIn
                .map((o) => ChoiceChip(
                      label: Text(o.label),
                      selected: _interestedIn == o.id,
                      onSelected: (_) => setState(() => _interestedIn = o.id),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bioController,
            maxLength: limits.maxBioLength,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'بیو', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text('علایق (${_selectedInterests.length}/${limits.maxInterests}، حداقل ${limits.minInterests})'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options!.interests.map((interest) {
              final selected = _selectedInterests.contains(interest.id);
              return FilterChip(
                label: Text(interest.label),
                selected: selected,
                onSelected: (isSelected) {
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
          const SizedBox(height: 20),
          Text('پرامپت‌ها (حداکثر ${limits.maxPrompts})'),
          const SizedBox(height: 8),
          ..._selectedPromptIds.map((id) {
            final prompt = _options!.prompts.firstWhere((p) => p.id == id);
            _promptControllers.putIfAbsent(id, () => TextEditingController());
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
                                style: const TextStyle(fontWeight: FontWeight.w600))),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _selectedPromptIds.remove(id);
                            _promptControllers[id]?.dispose();
                            _promptControllers.remove(id);
                          }),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _promptControllers[id],
                      maxLength: limits.maxBioLength,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_selectedPromptIds.length < limits.maxPrompts)
            ..._options!.prompts.where((p) => !_selectedPromptIds.contains(p.id)).map(
                  (p) => ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(p.text),
                    onTap: () => setState(() => _selectedPromptIds.add(p.id)),
                  ),
                ),
          const SizedBox(height: 16),
          if (_saveError != null) ...[
            Text(_saveError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          ElevatedButton(
            onPressed: (_canSave && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('ذخیره‌ی تغییرات'),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
