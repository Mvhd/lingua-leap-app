import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../services/translation_service.dart';

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool skipTranslation;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.skipTranslation = false,
  });

  @override
  Widget build(BuildContext context) {
    final localeCode = Provider.of<LocaleProvider>(context).locale.languageCode;

    // If English or skipTranslation is true, just return the text immediately
    if (localeCode == 'en' || skipTranslation) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    return FutureBuilder<String>(
      future: TranslationService().translate(text, localeCode),
      initialData: text, // Show original text while loading
      builder: (context, snapshot) {
        final displayedText = snapshot.data ?? text;
        
        return Text(
          displayedText,
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}
