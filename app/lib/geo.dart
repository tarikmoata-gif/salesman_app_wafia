import 'dart:math';
import 'package:geolocator/geolocator.dart';

const maxMeters = 50.0; // server re-checks; this is for instant UX feedback

double distanceM(double a, double b, double c, double d) {
  double r(double x) => x * pi / 180;
  final h = pow(sin(r(c - a) / 2), 2) + cos(r(a)) * cos(r(c)) * pow(sin(r(d - b) / 2), 2);
  return 2 * 6371000 * asin(sqrt(h));
}

Future<Position> currentPosition() async {
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw Exception('Location permission required');
  }
  return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
}
