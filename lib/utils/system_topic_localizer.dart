import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/topic_model.dart';

class SystemTopicLocalizer {
  /// Localizes the 5 predefined system topics using ARB keys.
  /// This bypasses AI translation to save costs.
  static String? getLocalizedTitle(BuildContext context, TopicModel topic) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;

    // Check by key (primary) or English title (secondary fallback)
    final String activeKey = topic.titleKey ?? _mapTitleToKey(topic.title);

    switch (activeKey) {
      case 'familyFriendsTitle': return l10n.familyFriendsTitle;
      case 'foodDiningTitle': return l10n.foodDiningTitle;
      case 'greetingsMannersTitle': return l10n.greetingsMannersTitle;
      case 'schoolEducationTitle': return l10n.schoolEducationTitle;
      case 'travelDirectionsTitle': return l10n.travelDirectionsTitle;
      default: return null;
    }
  }

  static String? getLocalizedSubtitle(BuildContext context, TopicModel topic) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;

    final String activeKey = topic.subtitleKey ?? _mapSubtitleToKey(topic.subtitle);

    switch (activeKey) {
      case 'familyFriendsSubtitle': return l10n.familyFriendsSubtitle;
      case 'foodDiningSubtitle': return l10n.foodDiningSubtitle;
      case 'greetingsMannersSubtitle': return l10n.greetingsMannersSubtitle;
      case 'schoolEducationSubtitle': return l10n.schoolEducationSubtitle;
      case 'travelDirectionsSubtitle': return l10n.travelDirectionsSubtitle;
      default: return null;
    }
  }

  static IconData? getIcon(TopicModel topic) {
    final String activeKey = topic.titleKey ?? _mapTitleToKey(topic.title);

    switch (activeKey) {
      case 'familyFriendsTitle':
        return LucideIcons.heart;
      case 'foodDiningTitle':
        return LucideIcons.utensils;
      case 'greetingsMannersTitle':
        return LucideIcons.handshake;
      case 'schoolEducationTitle':
        return LucideIcons.graduationCap;
      case 'travelDirectionsTitle':
        return LucideIcons.plane;
      default:
        return null;
    }
  }

  static String _mapTitleToKey(String title) {
    // Check if the title itself is the key string
    if (title == 'familyFriendsTitle') return 'familyFriendsTitle';
    if (title == 'foodDiningTitle') return 'foodDiningTitle';
    if (title == 'greetingsMannersTitle') return 'greetingsMannersTitle';
    if (title == 'schoolEducationTitle') return 'schoolEducationTitle';
    if (title == 'travelDirectionsTitle') return 'travelDirectionsTitle';

    switch (title) {
      case 'Family & Friends': return 'familyFriendsTitle';
      case 'Food & Dining': return 'foodDiningTitle';
      case 'Greetings & Manners': return 'greetingsMannersTitle';
      case 'School & Education': return 'schoolEducationTitle';
      case 'Travel & Directions': return 'travelDirectionsTitle';
      default: return '';
    }
  }

  static String _mapSubtitleToKey(String subtitle) {
    if (subtitle == 'familyFriendsSubtitle') return 'familyFriendsSubtitle';
    if (subtitle == 'foodDiningSubtitle') return 'foodDiningSubtitle';
    if (subtitle == 'greetingsMannersSubtitle') return 'greetingsMannersSubtitle';
    if (subtitle == 'schoolEducationSubtitle') return 'schoolEducationSubtitle';
    if (subtitle == 'travelDirectionsSubtitle') return 'travelDirectionsSubtitle';

    switch (subtitle) {
      case 'Describe your loved ones': return 'familyFriendsSubtitle';
      case 'Order your favorite meal': return 'foodDiningSubtitle';
      case 'Learn how to say hello': return 'greetingsMannersSubtitle';
      case 'Education, going to school & learning': return 'schoolEducationSubtitle';
      case 'Ask for directions': return 'travelDirectionsSubtitle';
      default: return '';
    }
  }
}
