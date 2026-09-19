import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';
import '../models/topic_model.dart';

class SystemTopicLocalizer {
  /// Localizes the 5 predefined system topics using ARB keys.
  /// This bypasses AI translation to save costs.
  static String? getLocalizedTitle(BuildContext context, TopicModel topic) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;

    // 1. Try to use the key from the database if it exists
    if (topic.titleKey != null) {
      switch (topic.titleKey) {
        case 'familyFriendsTitle': return l10n.familyFriendsTitle;
        case 'foodDiningTitle': return l10n.foodDiningTitle;
        case 'greetingsMannersTitle': return l10n.greetingsMannersTitle;
        case 'schoolEducationTitle': return l10n.schoolEducationTitle;
        case 'travelDirectionsTitle': return l10n.travelDirectionsTitle;
      }
    }

    // 2. Fallback: Map the English title string to the key 
    // (Handles cases where the database might be missing the key)
    switch (topic.title) {
      case 'Family & Friends': return l10n.familyFriendsTitle;
      case 'Food & Dining': return l10n.foodDiningTitle;
      case 'Greetings & Manners': return l10n.greetingsMannersTitle;
      case 'School & Education': return l10n.schoolEducationTitle;
      case 'Travel & Directions': return l10n.travelDirectionsTitle;
    }

    return null; // Not a system topic
  }

  static String? getLocalizedSubtitle(BuildContext context, TopicModel topic) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;

    if (topic.subtitleKey != null) {
      switch (topic.subtitleKey) {
        case 'familyFriendsSubtitle': return l10n.familyFriendsSubtitle;
        case 'foodDiningSubtitle': return l10n.foodDiningSubtitle;
        case 'greetingsMannersSubtitle': return l10n.greetingsMannersSubtitle;
        case 'schoolEducationSubtitle': return l10n.schoolEducationSubtitle;
        case 'travelDirectionsSubtitle': return l10n.travelDirectionsSubtitle;
      }
    }

    switch (topic.subtitle) {
      case 'Describe your loved ones': return l10n.familyFriendsSubtitle;
      case 'Order your favorite meal': return l10n.foodDiningSubtitle;
      case 'Learn how to say hello': return l10n.greetingsMannersSubtitle;
      case 'Education, going to school & learning': return l10n.schoolEducationSubtitle;
      case 'Ask for directions': return l10n.travelDirectionsSubtitle;
    }

    return null;
  }
}
