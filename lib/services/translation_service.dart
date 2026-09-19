import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west2');
  
  // Simple in-memory cache to avoid repeated calls during the same session
  final Map<String, String> _cache = {};

  /// Translates static server text to the target language code.
  /// Uses a combination of SharedPreferences and in-memory caching.
  Future<String> translate(String text, String targetLanguageCode) async {
    if (text.isEmpty) return text;
    if (targetLanguageCode == 'en') return text; // Assuming source is English

    final cacheKey = 'trans_${targetLanguageCode}_$text';
    
    // 1. Check in-memory cache
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 2. Check persistent cache (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    final cachedTranslation = prefs.getString(cacheKey);
    if (cachedTranslation != null) {
      _cache[cacheKey] = cachedTranslation;
      return cachedTranslation;
    }

    // 3. Call Cloud Function (Gemini AI)
    try {
      debugPrint("TRANSLATION: Fetching AI translation for '$text' to '$targetLanguageCode'");
      final result = await _functions.httpsCallable('translateToNative').call({
        'textToTranslate': text,
        'nativeLanguage': targetLanguageCode,
      });

      final translatedText = result.data['translatedText'] as String?;
      
      if (translatedText != null && translatedText.isNotEmpty) {
        // Update caches
        _cache[cacheKey] = translatedText;
        await prefs.setString(cacheKey, translatedText);
        return translatedText;
      }
    } catch (e) {
      debugPrint("TRANSLATION ERROR: $e");
    }

    return text; // Fallback to original text on error
  }

  /// Clears the translation cache.
  Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('trans_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
