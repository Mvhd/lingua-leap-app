import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

class TopicLocalizer {
  static String localizeTitle(BuildContext context, String? key, String fallback) {
    if (key == null) return fallback;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;

    switch (key) {
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
    if (key == null) return fallback;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;

    switch (key) {
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
}
