import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';
import '../services/corridor_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../../services/geofence_service.dart';

class AppProvider extends ChangeNotifier {
  // ── Driver ────────────────────────────────────────
  DriverModel? _driver;
  DriverModel? get driver => _driver;

  void setDriver(DriverModel driver) {
    _driver = driver;
    notifyListeners();
  }

  void clearDriver() {
    _driver = null;
    notifyListeners();
  }

  // ── Corridor ──────────────────────────────────────
  bool _isCorridorActive = false;
  bool get isCorridorActive => _isCorridorActive;

  String _activeHospital = '';
  String get activeHospital => _activeHospital;

  String _activePriority = '';
  String get activePriority => _activePriority;

  // ── WebSocket messages ────────────────────────────
  final List<String> _wsMessages = [];
  List<String> get wsMessages => List.unmodifiable(_wsMessages);

  // ── Notifications ─────────────────────────────────
  int _notificationCount = 0;
  int get notificationCount => _notificationCount;

  final List<String> _notifications = [];
  List<String> get notifications => List.unmodifiable(_notifications);

  // ── Services ──────────────────────────────────────
  final CorridorService _corridorService = CorridorService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final GeofenceService _geofenceService = GeofenceService();

  GeofenceService get geofenceService => _geofenceService;

  // ── Activate Corridor ─────────────────────────────

  Future<bool> activateCorridor({
    required String hospitalName,
    required double hospitalLat,
    required double hospitalLng,
    required String priority,
    required String patientCondition,
  }) async {
    if (_driver == null) return false;
    try {
      await _corridorService.activateCorridor(
        driverName: _driver!.fullName,
        vehicleId: _driver!.vehiclePlate,
        contact: _driver!.phone,
        hospitalName: hospitalName,
        hospitalLat: hospitalLat,
        hospitalLng: hospitalLng,
        priority: priority,
        patientCondition: patientCondition,
      );

      _isCorridorActive = true;
      _activeHospital = hospitalName;
      _activePriority = priority;
      notifyListeners();

      // Show corridor active notification
      await _notificationService.showCorridorActive(hospitalName);

      // Start WebSocket listener
      final stream = _corridorService.connectWebSocket();
      stream?.listen((data) {
        _wsMessages.add(data.toString());
        notifyListeners();
      });

      // Start GPS proximity posting
      if (_driver!.fcmToken.isNotEmpty) {
        _locationService.startProximityPosting(
          driverFcmToken: _driver!.fcmToken,
        );

        // Start geofencing
        await _geofenceService.startTracking(
          driverFcmToken: _driver!.fcmToken,
          updateIntervalSeconds: 5,
        );

        // Listen to geofence events
        _geofenceService.events.listen((event) {
          if (event.eventType == 'ENTERED') {
            // Show proximity alert notification
            _notificationService.showProximityAlert(event.signalName);
            // Add to notifications list
            addNotification(
              '📍 Entered ${event.signalName} — ${event.distance.toStringAsFixed(0)}m',
            );
          } else if (event.eventType == 'EXITED') {
            addNotification(
              '📍 Exited ${event.signalName}',
            );
          }
        });
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Deactivate Corridor ───────────────────────────

  Future<void> deactivateCorridor() async {
    await _corridorService.deactivateCorridor();
    _corridorService.disconnectWebSocket();
    _locationService.stopProximityPosting();
    _geofenceService.stopTracking();

    await _notificationService.showCorridorCleared();

    _isCorridorActive = false;
    _activeHospital = '';
    _activePriority = '';
    _wsMessages.clear();
    notifyListeners();
  }

  // ── Notifications ─────────────────────────────────

  void addNotification(String message) {
    _notifications.insert(0, message);
    _notificationCount++;
    notifyListeners();
  }

  void clearNotificationBadge() {
    _notificationCount = 0;
    notifyListeners();
  }
}
