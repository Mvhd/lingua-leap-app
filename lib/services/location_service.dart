import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final Geocoding _geocoding = Geocoding();

  /// Fetches the user's current location (Country Name) using GPS.
  Future<String?> getCurrentCountry() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied, we cannot request permissions.');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)
      );

      // Reverse geocoding to get country
      List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final String? code = place.isoCountryCode;
        if (code != null && code.isNotEmpty) {
          return code.toUpperCase(); // e.g. "NG", "ES", "US"
        }
        return place.country; // Fallback to full name e.g. "Nigeria"
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
