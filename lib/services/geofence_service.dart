import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'astra_signals.dart';

// ─────────────────────────────────────────────────────────────────
// Geofence Event Model
// ─────────────────────────────────────────────────────────────────

class GeofenceEvent {
  final String signalId;
  final String signalName;
  final String eventType; // "ENTERED" or "EXITED"
  final double distance; // meters
  final double driverLat;
  final double driverLng;
  final DateTime timestamp;

  GeofenceEvent({
    required this.signalId,
    required this.signalName,
    required this.eventType,
    required this.distance,
    required this.driverLat,
    required this.driverLng,
    required this.timestamp,
  });

  @override
  String toString() =>
      '$eventType: $signalName ($distance.toStringAsFixed(1)m) at $timestamp';
}

// ─────────────────────────────────────────────────────────────────
// Geofence Service
// ─────────────────────────────────────────────────────────────────

class GeofenceService {
  // Singleton
  static final GeofenceService _instance = GeofenceService._();
  factory GeofenceService() => _instance;
  GeofenceService._();

  // GPS tracking
  StreamSubscription<Position>? _positionStream;

  // Geofence event broadcasting
  final StreamController<GeofenceEvent> _eventController =
      StreamController<GeofenceEvent>.broadcast();
  Stream<GeofenceEvent> get events => _eventController.stream;

  // Track which signals driver is currently inside
  // Prevents multiple ENTERED events for same signal
  final Set<String> _enteredSignals = {};

  bool get isTracking => _positionStream != null && !_eventController.isClosed;

  // ── Start GPS Tracking ─────────────────────────────────────────

  Future<void> startTracking({
    required String driverFcmToken,
    int updateIntervalSeconds = 5,
  }) async {
    if (isTracking) return; // Already tracking

    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _eventController.addError('Location permission denied for geofencing');
        return;
      }

      // Start listening to position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters or interval
          timeLimit: Duration(seconds: updateIntervalSeconds),
        ),
      ).listen(
        (Position position) {
          _checkSignals(
            position,
            driverFcmToken,
          );
        },
        onError: (e) {
          _eventController.addError(e);
        },
      );
    } catch (e) {
      _eventController.addError(e);
    }
  }

  // ── Stop GPS Tracking ──────────────────────────────────────────

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _enteredSignals.clear();
  }

  // ── Check Distance to All Signals ──────────────────────────────

  Future<void> _checkSignals(Position position, String fcmToken) async {
    for (var signal in astraSignals) {
      final signalId = signal['id'] as String;
      final signalName = signal['name'] as String;
      final signalLat = signal['lat'] as double;
      final signalLng = signal['lng'] as double;
      final radiusMeters = signal['radius_meters'] as int;

      // Calculate distance using Haversine formula
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        signalLat,
        signalLng,
      );

      // Check if driver entered zone
      if (distance <= radiusMeters && !_enteredSignals.contains(signalId)) {
        _enteredSignals.add(signalId);

        final event = GeofenceEvent(
          signalId: signalId,
          signalName: signalName,
          eventType: 'ENTERED',
          distance: distance,
          driverLat: position.latitude,
          driverLng: position.longitude,
          timestamp: DateTime.now(),
        );

        _eventController.add(event);

        // Send notification to backend
        _notifyBackendProximity(
          driverLat: position.latitude,
          driverLng: position.longitude,
          signalLat: signalLat,
          signalLng: signalLng,
          signalId: signalId,
          signalName: signalName,
          fcmToken: fcmToken,
        );

        // Log to Firestore
        _logToFirestore(event, fcmToken);
      }

      // Check if driver exited zone
      if (distance > radiusMeters && _enteredSignals.contains(signalId)) {
        _enteredSignals.remove(signalId);

        final event = GeofenceEvent(
          signalId: signalId,
          signalName: signalName,
          eventType: 'EXITED',
          distance: distance,
          driverLat: position.latitude,
          driverLng: position.longitude,
          timestamp: DateTime.now(),
        );

        _eventController.add(event);
        _logToFirestore(event, fcmToken);
      }
    }
  }

  // ── Haversine Distance Calculation ────────────────────────────

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000; // Earth radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dphi = (lat2 - lat1) * pi / 180;
    final dlambda = (lng2 - lng1) * pi / 180;

    final a = sin(dphi / 2) * sin(dphi / 2) +
        cos(phi1) * cos(phi2) * sin(dlambda / 2) * sin(dlambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // ── Notify Backend ────────────────────────────────────────────

  Future<void> _notifyBackendProximity({
    required double driverLat,
    required double driverLng,
    required double signalLat,
    required double signalLng,
    required String signalId,
    required String signalName,
    required String fcmToken,
  }) async {
    try {
      await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/notify/proximity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'driver_lat': driverLat,
              'driver_lng': driverLng,
              'signal_lat': signalLat,
              'signal_lng': signalLng,
              'signal_id': signalId,
              'signal_name': signalName,
              'driver_fcm_token': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Silently fail — network issues shouldn't crash
    }
  }

  // ── Log to Firestore ──────────────────────────────────────────

  Future<void> _logToFirestore(GeofenceEvent event, String fcmToken) async {
    try {
      // This could integrate with FirebaseFirestore in the future
      // For now, just log to console during development
      // ignore: avoid_print
      print('[GEOFENCE] ${event.toString()}');
    } catch (e) {
      // Silent fail
    }
  }

  // ── Get Distance to Nearest Signal ────────────────────────────

  Future<Map<String, dynamic>?> getDistanceToNearestSignal(
    Position position,
  ) async {
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestSignal;

    for (var signal in astraSignals) {
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        signal['lat'] as double,
        signal['lng'] as double,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestSignal = {
          ...signal,
          'distance': distance,
        };
      }
    }

    return nearestSignal;
  }

  // ── Get All Signals with Distance ────────────────────────────

  Future<List<Map<String, dynamic>>> getAllSignalsWithDistance(
    Position position,
  ) async {
    return astraSignals.map((signal) {
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        signal['lat'] as double,
        signal['lng'] as double,
      );
      return {
        ...signal,
        'distance': distance,
        'inzone': distance <= (signal['radius_meters'] as int),
      };
    }).toList()
      ..sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
  }

  // ── Cleanup ────────────────────────────────────────────────────

  void dispose() {
    _positionStream?.cancel();
    _eventController.close();
  }
}
