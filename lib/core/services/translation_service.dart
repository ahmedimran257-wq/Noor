// lib/core/services/translation_service.dart
// ============================================================
// NOOR — Translation Service (Muslima Feature)
//
// Communicates with MyMemory Free Translation API.
// Requires no keys/billing. Free tier up to 1,000 words/day.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  /// Translates [text] from [sourceLang] (optional) to [targetLang] (e.g. 'ur', 'tr', 'en').
  /// Invokes the Supabase Edge Function 'translate-message' if initialized,
  /// otherwise falls back to direct call to MyMemory Free Translation API.
  Future<String?> translate({
    required String text,
    required String targetLang,
    String? sourceLang,
  }) async {
    if (text.trim().isEmpty) return null;

    if (SupabaseService.isInitialized) {
      try {
        final response = await SupabaseService.client.functions.invoke(
          'translate-message',
          body: {
            'text': text,
            'target_lang': targetLang,
            if (sourceLang != null) 'source_lang': sourceLang,
          },
        );

        if (response.data is Map) {
          final data = response.data as Map;
          final translatedText = data['translated_text'] as String?;
          if (translatedText != null && translatedText.isNotEmpty) {
            return translatedText;
          }
        }
      } catch (e) {
        debugPrint('[TranslationService] Edge Function translation failed, falling back to direct API: $e');
      }
    }

    // Direct MyMemory Free Translation API call fallback
    try {
      final langPair = sourceLang != null ? '$sourceLang|$targetLang' : 'autodetect|$targetLang';
      
      final uri = Uri.https(
        'api.mymemory.translated.net',
        '/get',
        {
          'q': text,
          'langpair': langPair,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'NoorApp/1.0 (contact@noorapp.com; matchmaking app)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final responseData = data['responseData'] as Map<String, dynamic>?;
        final translatedText = responseData?['translatedText'] as String?;
        if (translatedText != null && translatedText.isNotEmpty) {
          return translatedText;
        }
      } else {
        debugPrint('[TranslationService] Error status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[TranslationService] Translation failed: $e');
    }
    return null;
  }
}
