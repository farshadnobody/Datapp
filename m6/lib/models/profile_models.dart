class Option {
  final String id;
  final String label;
  Option({required this.id, required this.label});

  factory Option.fromJson(Map<String, dynamic> json) =>
      Option(id: json['id'], label: json['label']);
}

class PromptOption {
  final String id;
  final String text;
  PromptOption({required this.id, required this.text});

  factory PromptOption.fromJson(Map<String, dynamic> json) =>
      PromptOption(id: json['id'], text: json['text']);
}

class ProfileLimits {
  final int minAge;
  final int maxAge;
  final int minInterests;
  final int maxInterests;
  final int maxPrompts;
  final int maxBioLength;
  final int maxNameLength;
  final int maxPhotos;

  ProfileLimits({
    required this.minAge,
    required this.maxAge,
    required this.minInterests,
    required this.maxInterests,
    required this.maxPrompts,
    required this.maxBioLength,
    required this.maxNameLength,
    required this.maxPhotos,
  });

  factory ProfileLimits.fromJson(Map<String, dynamic> json) => ProfileLimits(
        minAge: json['min_age'],
        maxAge: json['max_age'],
        minInterests: json['min_interests'],
        maxInterests: json['max_interests'],
        maxPrompts: json['max_prompts'],
        maxBioLength: json['max_bio_length'],
        maxNameLength: json['max_name_length'],
        maxPhotos: json['max_photos'],
      );
}

class ProfileOptions {
  final List<Option> genders;
  final List<Option> interestedIn;
  final List<Option> interests;
  final List<PromptOption> prompts;
  final ProfileLimits limits;

  ProfileOptions({
    required this.genders,
    required this.interestedIn,
    required this.interests,
    required this.prompts,
    required this.limits,
  });

  factory ProfileOptions.fromJson(Map<String, dynamic> json) => ProfileOptions(
        genders: (json['genders'] as List).map((e) => Option.fromJson(e)).toList(),
        interestedIn: (json['interested_in'] as List)
            .map((e) => Option.fromJson(e))
            .toList(),
        interests:
            (json['interests'] as List).map((e) => Option.fromJson(e)).toList(),
        prompts: (json['prompts'] as List)
            .map((e) => PromptOption.fromJson(e))
            .toList(),
        limits: ProfileLimits.fromJson(json['limits']),
      );
}

class PromptAnswer {
  final String promptId;
  final String answer;
  PromptAnswer({required this.promptId, required this.answer});

  factory PromptAnswer.fromJson(Map<String, dynamic> json) =>
      PromptAnswer(promptId: json['prompt_id'], answer: json['answer']);

  Map<String, dynamic> toJson() => {'prompt_id': promptId, 'answer': answer};
}

class ProfileInput {
  final String name;
  final String birthDate; // فرمت: YYYY-MM-DD
  final String gender;
  final String interestedIn;
  final String bio;
  final List<String> interests;
  final List<PromptAnswer> prompts;

  ProfileInput({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.interests,
    required this.prompts,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'birth_date': birthDate,
        'gender': gender,
        'interested_in': interestedIn,
        'bio': bio,
        'interests': interests,
        'prompts': prompts.map((p) => p.toJson()).toList(),
      };
}

class Photo {
  final String id;
  final String url; // مسیر نسبیه (مثلاً "/uploads/xxxx.jpg")، باید با
  // backendBaseUrl ترکیب بشه.
  final int position;

  Photo({required this.id, required this.url, required this.position});

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
        id: json['id'],
        url: json['url'],
        position: json['position'],
      );
}

// PrivatePhoto عمداً یه کلاس کاملاً جداست (نه همون Photo با یه فلگ) — چون
// عکس‌های خصوصی نه position دارن نه primary، و آدرسشون هم به یه endpoint
// احرازهویت‌شده اشاره می‌کنه، نه یه مسیر استاتیک باز.
class PrivatePhoto {
  final String id;
  final String url;

  PrivatePhoto({required this.id, required this.url});

  factory PrivatePhoto.fromJson(Map<String, dynamic> json) =>
      PrivatePhoto(id: json['id'], url: json['url']);
}

class MyProfile {
  final String name;
  final String birthDate; // YYYY-MM-DD
  final int age;
  final String gender;
  final String interestedIn;
  final String bio;
  final List<String> interests;
  final List<PromptAnswer> prompts;
  final List<Photo> photos;
  final String publicId;

  MyProfile({
    required this.name,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.photos,
    required this.publicId,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
        name: json['name'],
        birthDate: json['birth_date'],
        age: json['age'],
        gender: json['gender'],
        interestedIn: json['interested_in'],
        bio: json['bio'] ?? '',
        interests: List<String>.from(json['interests'] ?? []),
        prompts: (json['prompts'] as List? ?? [])
            .map((e) => PromptAnswer.fromJson(e))
            .toList(),
        photos: (json['photos'] as List? ?? [])
            .map((e) => Photo.fromJson(e))
            .toList(),
        publicId: json['public_id'] ?? '',
      );
}

class DiscoveryCandidate {
  final String publicId;
  final String name;
  final int age;
  final String bio;
  final List<String> interests;
  final List<PromptAnswer> prompts;
  final List<Photo> photos;
  final double? distanceKm;

  DiscoveryCandidate({
    required this.publicId,
    required this.name,
    required this.age,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.photos,
    required this.distanceKm,
  });

  factory DiscoveryCandidate.fromJson(Map<String, dynamic> json) =>
      DiscoveryCandidate(
        publicId: json['public_id'],
        name: json['name'],
        age: json['age'],
        bio: json['bio'] ?? '',
        interests: List<String>.from(json['interests'] ?? []),
        prompts: (json['prompts'] as List? ?? [])
            .map((e) => PromptAnswer.fromJson(e))
            .toList(),
        photos: (json['photos'] as List? ?? [])
            .map((e) => Photo.fromJson(e))
            .toList(),
        distanceKm: json['distance_km'] == null
            ? null
            : (json['distance_km'] as num).toDouble(),
      );
}
