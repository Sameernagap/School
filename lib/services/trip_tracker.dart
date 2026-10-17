import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Sends the bus position to the school during a trip.
///
/// Positions come from the phone's GPS (also while the screen is off: Android shows a
/// "Trip running" notification) and are sent every [interval] seconds in small batches. When the
/// network drops, positions are kept and sent once it is back. Nothing is sent outside a trip.
class TripTracker extends ChangeNotifier {
  TripTracker._();

  static final TripTracker instance = TripTracker._();
  static const _tripKey = 'bus_active_trip';

  ApiClient? _api;
  int? tripId;
  int interval = 5;
  StreamSubscription<Position>? _positions;
  Timer? _timer;
  final List<Map<String, dynamic>> _buffer = [];
  bool _sending = false;

  Position? lastPosition;
  DateTime? lastSent;
  String? nextStop;
  String? problem;
  List<int> passedStopIds = const [];

  // skip positions while the bus stands still (signal, stop), but send a heartbeat now and then
  Position? _lastQueued;
  DateTime? _lastQueuedAt;

  bool get running => tripId != null;
  int get waiting => _buffer.length;

  /// Checks location step by step without opening any settings page. Returns null when tracking
  /// can run, else what is wrong and which settings page fixes it ('gps' or 'app').
  static Future<({String message, String fix})?> checkLocation() async {
    final bool gpsOn;
    try {
      gpsOn = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return (message: 'Could not read the phone\'s Location setting ($e).', fix: 'gps');
    }
    if (!gpsOn) {
      return (message: 'Location (GPS) is turned off on this phone. Turn it on and tap Start again.', fix: 'gps');
    }
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 60));
      }
    } on TimeoutException {
      return (message: 'No answer to the location question. Tap Start again and choose "While using the app".', fix: 'app');
    } catch (e) {
      // e.g. permissions missing from the app build, or a request already open
      return (message: 'The app could not ask for location access: $e', fix: 'app');
    }
    if (permission == LocationPermission.denied) {
      return (message: 'Location access was not allowed. Tap Start again and choose "While using the app".', fix: 'none');
    }
    if (permission == LocationPermission.deniedForever) {
      return (
        message: 'Location access is blocked for this app. Open App settings › Permissions › Location and choose "Allow only while using the app".',
        fix: 'app'
      );
    }
    return null;
  }

  static Future<void> openFix(String fix) async {
    try {
      if (fix == 'gps') {
        await Geolocator.openLocationSettings();
      } else if (fix == 'app') {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }

  /// Asks for location access. Returns a message to show when tracking cannot run, else null.
  static Future<String?> ensurePermission() async {
    final problem = await checkLocation();
    return problem?.message;
  }

  static Future<int?> savedTripId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tripKey);
  }

  Future<void> start(ApiClient api, int trip, {int seconds = 5}) async {
    if (tripId == trip && _positions != null) return;
    await _stopStream();
    _api = api;
    tripId = trip;
    interval = seconds.clamp(3, 60);
    problem = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tripKey, trip);

    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: interval),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Bus trip running',
          notificationText: 'Parents can see the bus on the map. End the trip in the app when done.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    }
    try {
      _positions = Geolocator.getPositionStream(locationSettings: settings).listen(
        _onPosition,
        onError: (Object e) {
          problem = 'GPS problem: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      problem = 'GPS could not start: $e';
    }
    _restartTimer();
    notifyListeners();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) => flush());
  }

  void _onPosition(Position p) {
    lastPosition = p;
    final now = DateTime.now();
    final previous = _lastQueued;
    if (previous != null && _lastQueuedAt != null) {
      final moved = Geolocator.distanceBetween(previous.latitude, previous.longitude, p.latitude, p.longitude);
      final standing = moved < 8 && p.speed < 1;
      if (standing && now.difference(_lastQueuedAt!).inSeconds < 30) {
        notifyListeners();
        return;
      }
    }
    _lastQueued = p;
    _lastQueuedAt = now;
    _buffer.add({
      'lat': p.latitude,
      'lng': p.longitude,
      'speed': p.speed < 0 ? 0 : p.speed,
      'heading': p.heading < 0 ? 0 : p.heading,
      'accuracy': p.accuracy,
      'time': p.timestamp.toUtc().toIso8601String(),
    });
    if (_buffer.length > 3000) _buffer.removeRange(0, _buffer.length - 3000);
    notifyListeners();
  }

  /// Sends the waiting positions now.
  Future<void> flush() async {
    final api = _api;
    final trip = tripId;
    if (_sending || api == null || trip == null || _buffer.isEmpty) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_buffer.take(200));
    try {
      final data = Map<String, dynamic>.from(await api.post('/bus/trips/$trip/locations', {'points': batch}) as Map);
      _buffer.removeRange(0, batch.length);
      lastSent = DateTime.now();
      problem = null;
      nextStop = data['next_stop']?.toString();
      passedStopIds = (data['passed_stop_ids'] as List? ?? const []).map((e) => e as int).toList();
      final serverInterval = (data['interval'] as num?)?.toInt();
      if (serverInterval != null && serverInterval != interval) {
        interval = serverInterval.clamp(3, 60);
        _restartTimer();
      }
      if (data['state'] == 'done') {
        await stop(); // ended from the office (or automatically)
      }
    } on ApiException catch (e) {
      problem = e.status == 0 ? 'No internet: positions are kept and sent later.' : e.message;
      if (e.status == 403 || e.status == 404) await stop();
    } catch (e) {
      problem = 'No internet: positions are kept and sent later.';
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _stopStream() async {
    _timer?.cancel();
    _timer = null;
    await _positions?.cancel();
    _positions = null;
  }

  /// Stops sending (after "End trip"). Unsent positions are dropped.
  Future<void> stop() async {
    await _stopStream();
    tripId = null;
    _buffer.clear();
    _lastQueued = null;
    nextStop = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tripKey);
    notifyListeners();
  }
}
