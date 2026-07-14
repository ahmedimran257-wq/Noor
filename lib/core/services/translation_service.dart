// lib/core/services/translation_service.dart
// ============================================================
// SILARAH — Translation Service (Muslima Feature)
//
// Communicates only with the Supabase translate-message Edge Function so
// private chat text never leaves the server-controlled boundary from Flutter.
// ============================================================

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  /// Translates [text] from [sourceLang] (optional) to [targetLang] (e.g. 'ur', 'tr', 'en').
  /// Invokes the Supabase Edge Function 'translate-message'.
  Future<String?> translate({
    required String text,
    required String targetLang,
    String? sourceLang,
  }) async {
    if (text.trim().isEmpty) return null;
    if (!SupabaseService.isInitialized) return null;

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
      debugPrint('[TranslationService] Edge Function translation failed: $e');
    }
    return null;
  }
}
