// lib/core/utils/noor_compute.dart
// ============================================================
// NOOR — Background Compute / Isolate Parsers
// Offloads heavy JSON mapping/deserialization to background threads.
// ============================================================

import '../mock/mock_profiles.dart';
import '../config/app_config.dart';
import '../cubits/chat/chat_state.dart';

/// Parse a list of database profile rows into MockProfile instances in the background.
List<MockProfile> parseProfilesInBackground(List<dynamic> list) {
  return list.map((row) => mapDbRowToMockProfile(row as Map<String, dynamic>)).toList();
}

/// Parse a single database profile row in the background.
MockProfile parseSingleProfileInBackground(Map<String, dynamic> row) {
  return mapDbRowToMockProfile(row);
}

/// Map a raw Supabase DB row to a MockProfile.
MockProfile mapDbRowToMockProfile(Map<String, dynamic> row) {
  final gender = row['gender'] as String?;
  final rawPhotoPath = row['photo_url'] as String?;
  final photoCount = (row['photo_count'] as num?)?.toInt() ?? 0;
  final photoPrivacy = row['photo_privacy'] as String?;

  String? photoUrl;
  if (rawPhotoPath != null && rawPhotoPath.isNotEmpty) {
    try {
      // Direct construction of the public URL avoids accessing SupabaseClient on the isolate.
      photoUrl = '${AppConfig.supabaseUrl}/storage/v1/object/public/photos/$rawPhotoPath';
    } catch (_) {
      photoUrl = rawPhotoPath;
    }
  }

  return MockProfile(
    id: row['user_id'] as String?,
    firstName: (row['first_name'] as String?) ?? 'Noor User',
    lastNameInitial: ((row['last_name_initial'] as String?) ?? '').isNotEmpty
        ? row['last_name_initial'] as String
        : (((row['last_name'] as String?) ?? '').isNotEmpty
            ? (row['last_name'] as String)[0]
            : ''),
    age: (row['age'] as num?)?.toInt() ?? 
         (row['date_of_birth'] != null 
             ? (DateTime.now().difference(DateTime.parse(row['date_of_birth'] as String)).inDays ~/ 365) 
             : 25),
    cityName: (row['city_name'] as String?) ?? 'Unknown',
    sect: (row['sect'] as String?)?.toUpperCase() ?? 'SUNNI',
    deenLevel: (row['deen_level'] as String?) ?? 'moderate',
    photoUrl: photoUrl,
    photoCount: photoCount,
    isPhotoPrivate: photoPrivacy == 'mutual_only' || photoPrivacy == 'request_only',
    isVerified: (row['is_verified'] as bool?) ?? false,
    occupation: (row['profession'] as String?) ?? 'Professional',
    education: (row['education_level'] as String?) ?? 'Graduate',
    bio: (row['bio'] as String?) ?? '',
    languages: row['languages'] != null ? List<String>.from(row['languages'] as Iterable) : null,
    maritalStatus: (row['previously_married'] as String?) == 'no' ? 'Never Married' : ((row['previously_married'] as String?) ?? 'Never Married'),
    familyType: (row['family_type'] as String?) ?? 'Nuclear',
    interests: row['interests'] != null ? List<String>.from(row['interests'] as Iterable) : null,
    partnerAgeMin: (row['preferred_age_min'] as num?)?.toInt(),
    partnerAgeMax: (row['preferred_age_max'] as num?)?.toInt(),
    heightCm: (row['height_cm'] as num?)?.toInt(),
    complexion: (row['complexion'] as String?),
    motherTongue: (row['mother_tongue'] as String?),
    smokingHabit: (row['smoking_habit'] as String?),
    community: (row['community'] as String?),
    dietType: (row['diet_type'] as String?),
    livingExpectation: (row['living_expectation'] as String?),
    quranMemorization: (row['quran_memorization'] as String?),
    religiousEducation: (row['religious_education'] as String?),
    marriageTimeline: (row['marriage_timeline'] as String?),
    willingToRelocate: (row['willing_to_relocate'] as String?),
    gender: gender,
    hasChildren: (row['children_count'] as int? ?? 0) > 0,
    lastActiveAt: row['last_active_at'] != null ? DateTime.tryParse(row['last_active_at'] as String) : null,
    countryCode: row['country_code'] as String?,
    blurhash: row['blurhash'] as String?,
  );
}

/// Input parameter structure for parsing message lists in background
class MessagesParseInput {
  const MessagesParseInput({required this.messagesData, required this.myUserId});
  final List<dynamic> messagesData;
  final String myUserId;
}

/// Output result structure for parsing message lists in background
class MessagesParseResult {
  const MessagesParseResult({required this.chatMessages, required this.unreadCount});
  final List<ChatMessage> chatMessages;
  final int unreadCount;
}

/// Parse message rows in background isolate.
MessagesParseResult parseMessagesInBackground(MessagesParseInput input) {
  final List<ChatMessage> chatMessages = [];
  int unreadCount = 0;

  for (var msg in input.messagesData) {
    final isMe = msg['sender_id'] == input.myUserId;
    final readAt = msg['read_at'];
    final isRead = readAt != null;
    if (!isMe && !isRead) {
      unreadCount++;
    }

    final translationsMap = msg['translations'] as Map<dynamic, dynamic>? ?? {};
    final translations = translationsMap.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );

    chatMessages.add(ChatMessage(
      id: msg['id'] as String,
      text: msg['content'] as String? ?? '',
      sentAt: DateTime.parse(msg['created_at'] as String).toLocal(),
      isMe: isMe,
      status: isRead 
          ? MessageStatus.read 
          : (isMe ? MessageStatus.sent : MessageStatus.delivered),
      translations: translations,
    ));
  }
  return MessagesParseResult(chatMessages: chatMessages, unreadCount: unreadCount);
}
