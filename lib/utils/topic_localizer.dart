import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

class TopicLocalizer {
  static String localizeTitle(BuildContext context, String? key, String fallback) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;

    // Use key if provided
    final String activeKey = key ?? _mapTitleToKey(fallback);

    switch (activeKey) {
      case 'shoppingGroceriesTitle':
        return l10n.shoppingGroceriesTitle;
      case 'restaurantDiningTitle':
        return l10n.restaurantDiningTitle;
      case 'drivingTrafficTitle':
        return l10n.drivingTrafficTitle;
      case 'atAirportTitle':
        return l10n.atAirportTitle;
      case 'weddingsEventsTitle':
        return l10n.weddingsEventsTitle;
      case 'meetingNewPeopleTitle':
        return l10n.meetingNewPeopleTitle;
      case 'bankingFinanceTitle':
        return l10n.bankingFinanceTitle;
      case 'insuranceServicesTitle':
        return l10n.insuranceServicesTitle;
      case 'healthFitnessTitle':
        return l10n.healthFitnessTitle;
      case 'emergencyServicesTitle':
        return l10n.emergencyServicesTitle;
      default:
        return fallback;
    }
  }

  static String localizeSubtitle(BuildContext context, String? key, String fallback) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;

    final String activeKey = key ?? _mapSubtitleToKey(fallback);

    switch (activeKey) {
      case 'shoppingGroceriesSubtitle':
        return l10n.shoppingGroceriesSubtitle;
      case 'restaurantDiningSubtitle':
        return l10n.restaurantDiningSubtitle;
      case 'drivingTrafficSubtitle':
        return l10n.drivingTrafficSubtitle;
      case 'atAirportSubtitle':
        return l10n.atAirportSubtitle;
      case 'weddingsEventsSubtitle':
        return l10n.weddingsEventsSubtitle;
      case 'meetingNewPeopleSubtitle':
        return l10n.meetingNewPeopleSubtitle;
      case 'bankingFinanceSubtitle':
        return l10n.bankingFinanceSubtitle;
      case 'insuranceServicesSubtitle':
        return l10n.insuranceServicesSubtitle;
      case 'healthFitnessSubtitle':
        return l10n.healthFitnessSubtitle;
      case 'emergencyServicesSubtitle':
        return l10n.emergencyServicesSubtitle;
      default:
        return fallback;
    }
  }

  static String _mapTitleToKey(String title) {
    // Check if the title itself is the key string
    if (title == 'shoppingGroceriesTitle') return 'shoppingGroceriesTitle';
    if (title == 'restaurantDiningTitle') return 'restaurantDiningTitle';
    if (title == 'drivingTrafficTitle') return 'drivingTrafficTitle';
    if (title == 'atAirportTitle') return 'atAirportTitle';
    if (title == 'weddingsEventsTitle') return 'weddingsEventsTitle';
    if (title == 'meetingNewPeopleTitle') return 'meetingNewPeopleTitle';
    if (title == 'bankingFinanceTitle') return 'bankingFinanceTitle';
    if (title == 'insuranceServicesTitle') return 'insuranceServicesTitle';
    if (title == 'healthFitnessTitle') return 'healthFitnessTitle';
    if (title == 'emergencyServicesTitle') return 'emergencyServicesTitle';

    switch (title) {
      case 'Shopping & Groceries':
        return 'shoppingGroceriesTitle';
      case 'Restaurant & Dining':
        return 'restaurantDiningTitle';
      case 'Driving & Traffic':
        return 'drivingTrafficTitle';
      case 'At the Airport':
        return 'atAirportTitle';
      case 'Weddings & Events':
        return 'weddingsEventsTitle';
      case 'Meeting New People':
        return 'meetingNewPeopleTitle';
      case 'Banking & Finance':
        return 'bankingFinanceTitle';
      case 'Insurance & Services':
        return 'insuranceServicesTitle';
      case 'Health & Fitness':
        return 'healthFitnessTitle';
      case 'Emergency Services':
        return 'emergencyServicesTitle';
      default:
        return '';
    }
  }

  static String _mapSubtitleToKey(String subtitle) {
    if (subtitle == 'shoppingGroceriesSubtitle') return 'shoppingGroceriesSubtitle';
    if (subtitle == 'restaurantDiningSubtitle') return 'restaurantDiningSubtitle';
    if (subtitle == 'drivingTrafficSubtitle') return 'drivingTrafficSubtitle';
    if (subtitle == 'atAirportSubtitle') return 'atAirportSubtitle';
    if (subtitle == 'weddingsEventsSubtitle') return 'weddingsEventsSubtitle';
    if (subtitle == 'meetingNewPeopleSubtitle') return 'meetingNewPeopleSubtitle';
    if (subtitle == 'bankingFinanceSubtitle') return 'bankingFinanceSubtitle';
    if (subtitle == 'insuranceServicesSubtitle') return 'insuranceServicesSubtitle';
    if (subtitle == 'healthFitnessSubtitle') return 'healthFitnessSubtitle';
    if (subtitle == 'emergencyServicesSubtitle') return 'emergencyServicesSubtitle';

    switch (subtitle) {
      case 'Asking for prices, common items.':
        return 'shoppingGroceriesSubtitle';
      case 'Ordering food, talking to staff.':
        return 'restaurantDiningSubtitle';
      case 'Driving vehicle while obeying traffic signs.':
        return 'drivingTrafficSubtitle';
      case 'Checking in, boarding, customs.':
        return 'atAirportSubtitle';
      case 'Attending weddings, parties and events.':
        return 'weddingsEventsSubtitle';
      case 'Introductions, greetings, small talk.':
        return 'meetingNewPeopleSubtitle';
      case 'Money market, checking, credit & debit':
        return 'bankingFinanceSubtitle';
      case 'Insurance policies and premiums':
        return 'insuranceServicesSubtitle';
      case 'Medical appointments, exercise routines':
        return 'healthFitnessSubtitle';
      case 'Ambulance, fire, police':
        return 'emergencyServicesSubtitle';
      default:
        return '';
    }
  }

  static bool shouldSkipAI(String? key, String text) {
    if (key != null && key.isNotEmpty) return true;
    if (_mapTitleToKey(text).isNotEmpty) return true;
    if (_mapSubtitleToKey(text).isNotEmpty) return true;
    return false;
  }
}
