import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../services/trip_tracker.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'bus_map.dart';

/// Bus attendant / driver: the buses' routes with Start trip, or the running trip.
class BusRoutesScreen extends StatefulWidget {
  const BusRoutesScreen({super.key, this.embedded = false});

  /// True when shown as the home page of a bus-staff-only login (no back button).
  final bool embedded;

  @override
  State<BusRoutesScreen> createState() => _BusRoutesScreenState();
}

class _BusRoutesScreenState extends State<BusRoutesScreen> {
  int _version = 0;
  bool _resumed = false;

  ApiClient get _api => context.read<AppState>().api;

  Future<Map<String, dynamic>> _load() async {
    final data = Map<String, dynamic>.from(await _api.get('/bus/routes') as Map);
    if (!_resumed) {
      _resumed = true;
      await _resumeIfNeeded(data);
    }
    return data;
  }

  /// The app was closed during a trip: keep sending positions for the running trip.
  Future<void> _resumeIfNeeded(Map<String, dynamic> data) async {
    final saved = await TripTracker.savedTripId();
    final tracker = TripTracker.instance;
    for (final r in (data['routes'] as List).cast<Map>()) {
      final trip = r['running_trip'];
      if (trip is Map && (trip['id'] == saved || tracker.tripId == trip['id'])) {
        if (await TripTracker.ensurePermission() == null) {
          await tracker.start(_api, trip['id'] as int, seconds: (data['interval'] as num? ?? 5).toInt());
        }
        return;
      }
    }
    if (saved != null) await tracker.stop(); // trip ended meanwhile
  }

  Future<void> _start(Map route, String direction, int interval) async {
    final problem = await TripTracker.ensurePermission();
    if (!mounted) return;
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }
    Map<String, dynamic>? trip;
    final ok = await runAction(context, () async {
      trip = Map<String, dynamic>.from(await _api.post('/bus/trips', {'route_id': route['id'], 'direction': direction}) as Map);
    });
    if (!ok || trip == null || !mounted) return;
    await TripTracker.instance.start(_api, trip!['id'] as int, seconds: (trip!['interval'] as num? ?? interval).toInt());
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _tripPage(route['mode'], trip!['id'] as int)));
    if (mounted) setState(() => _version++);
  }

  Future<void> _open(Map trip, int interval, {String? mode}) async {
    final tracker = TripTracker.instance;
    if (tracker.tripId != trip['id']) {
      final problem = await TripTracker.ensurePermission();
      if (problem != null) {
        if (mounted) showMessage(context, problem, error: true);
        return;
      }
      await tracker.start(_api, trip['id'] as int, seconds: interval);
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _tripPage(mode, trip['id'] as int)));
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final suggested = hour < 11 ? 'pickup' : 'drop';
    return PageScaffold(
      title: 'Bus trips',
      body: AsyncView<Map<String, dynamic>>(
        reloadKey: _version,
        loader: _load,
        builder: (context, data, reload) {
          final routes = (data['routes'] as List).cast<Map>();
          final interval = (data['interval'] as num? ?? 5).toInt();
          if (routes.isEmpty) {
            return const EmptyView(
                icon: Icons.directions_bus_outlined, message: 'Your bus has no route yet.', color: AppColors.lime);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HeroHeader(
                color: AppColors.lime,
                icon: Icons.directions_bus_rounded,
                title: 'Share the bus location',
                subtitle: 'Start the trip when the bus leaves. Parents see it on the map until you end it.',
              ),
              for (final r in routes) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const IconTile(icon: Icons.alt_route_rounded, color: AppColors.lime, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r['code']} · ${r['name']}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                Text('${r['vehicle']['name']} · ${r['stop_count']} stops · ${r['riders']} students',
                                    style: const TextStyle(color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (r['running_trip'] is Map)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.emerald, padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: () => _open(r['running_trip'] as Map, interval, mode: r['mode']?.toString()),
                            icon: const Icon(Icons.play_circle_fill_rounded),
                            label: Text('Trip running · ${r['running_trip']['direction_label']} — open'),
                          ),
                        )
                      else if (r['busy'] == true)
                        const Text('This bus is on another route now.', style: TextStyle(color: AppColors.muted))
                      else
                        Row(
                          children: [
                            for (final d in const ['pickup', 'drop']) ...[
                              if (d == 'drop') const SizedBox(width: 10),
                              Expanded(
                                child: d == suggested
                                    ? FilledButton.icon(
                                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                        onPressed: () => _start(r, d, interval),
                                        icon: Icon(d == 'pickup' ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded),
                                        label: Text(d == 'pickup' ? 'Start morning' : 'Start afternoon'),
                                      )
                                    : OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                        onPressed: () => _start(r, d, interval),
                                        icon: Icon(d == 'pickup' ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded),
                                        label: Text(d == 'pickup' ? 'Start morning' : 'Start afternoon'),
                                      ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Location is sent every $interval seconds, only during a trip.',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          );
        },
      ),
    );
  }
}

/// Driver alone: simple screen; attendant: full trip screen.
Widget _tripPage(dynamic mode, int tripId) =>
    mode == 'driver' ? DriverTripScreen(tripId: tripId) : BusTripScreen(tripId: tripId);

/// The running trip: map, sending status, students to mark on / off, ID card scan, End trip.
class BusTripScreen extends StatefulWidget {
  const BusTripScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<BusTripScreen> createState() => _BusTripScreenState();
}

class _BusTripScreenState extends State<BusTripScreen> {
  final _mapKey = GlobalKey<BusMapState>();
  Map<String, dynamic>? _trip;
  String? _error;
  Timer? _refresh;
  final Set<int> _busy = {};

  ApiClient get _api => context.read<AppState>().api;
  TripTracker get _tracker => TripTracker.instance;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_onTracker);
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTracker);
    _refresh?.cancel();
    super.dispose();
  }

  void _onTracker() {
    if (!mounted) return;
    if (!_tracker.running && _trip != null && _trip!['state'] == 'running') {
      _load(quiet: true); // ended from the office
    }
    setState(() {});
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final data = Map<String, dynamic>.from(await _api.get('/bus/trips/${widget.tripId}') as Map);
      if (mounted) setState(() => _trip = data);
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
    }
  }

  Future<void> _mark(Map rider, String kind) async {
    final id = rider['student']['id'] as int;
    setState(() => _busy.add(id));
    try {
      await _api.post('/bus/trips/${widget.tripId}/boarding', {'student_id': id, 'kind': kind});
      await _load(quiet: true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _scan() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _ScanSheet(tripId: widget.tripId, api: _api),
    );
    _load(quiet: true);
  }

  Future<void> _saveStopHere(Map stop) async {
    final here = _tracker.lastPosition;
    if (here == null) {
      showMessage(context, 'Waiting for the GPS position…', error: true);
      return;
    }
    final ok = await confirmDialog(context, 'Save stop location',
        'Save your current position as the map location of "${stop['name']}"? Do this while standing at the stop.',
        ok: 'Save');
    if (!ok || !mounted) return;
    await runAction(context, () async {
      await _api.post('/bus/trips/${widget.tripId}/stops/${stop['id']}/location',
          {'lat': here.latitude, 'lng': here.longitude});
      await _load(quiet: true);
    }, success: 'Location of ${stop['name']} saved.');
  }

  Future<void> _end() async {
    final onBoard = (_trip?['on_board'] ?? 0) as int;
    final ok = await confirmDialog(
        context,
        'End trip?',
        onBoard > 0
            ? '$onBoard student(s) are still marked on the bus. End the trip anyway? Parents stop seeing the bus.'
            : 'The bus location stops being shared with parents.',
        ok: 'End trip');
    if (!ok || !mounted) return;
    await _tracker.flush();
    if (!mounted) return;
    final done = await runAction(context, () async {
      await _api.post('/bus/trips/${widget.tripId}/end');
    }, success: 'Trip ended.');
    if (done) {
      await _tracker.stop();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.teacherGround,
        appBar: AppBar(
          backgroundColor: AppColors.teacherGround,
          surfaceTintColor: Colors.transparent,
          title: Text(trip == null ? 'Bus trip' : '${trip['vehicle']['name']} · ${trip['direction_label']}',
              style: headingStyle(size: 20)),
        ),
        body: trip == null
            ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
            : _body(trip),
        bottomNavigationBar: trip == null || trip['state'] != 'running'
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teacher, padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan ID card'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.rose, padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: _end,
                        icon: const Icon(Icons.stop_circle_rounded),
                        label: const Text('End trip'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> trip) {
    final tracker = _tracker;
    final running = trip['state'] == 'running';
    final passed = tracker.passedStopIds.toSet();
    final stops = <MapStop>[];
    final allStops = (trip['stops'] as List).cast<Map>();
    for (final s in allStops) {
      final p = latLngOf(s['latitude'], s['longitude']);
      if (p != null) {
        stops.add(MapStop(name: s['name'].toString(), point: p, passed: s['passed'] == true || passed.contains(s['id'])));
      }
    }
    final school = trip['school'] is Map ? latLngOf(trip['school']['latitude'], trip['school']['longitude']) : null;
    final me = tracker.lastPosition == null ? null : LatLng(tracker.lastPosition!.latitude, tracker.lastPosition!.longitude);
    final riders = (trip['riders'] as List).cast<Map>();
    final sentAgo = tracker.lastSent == null ? null : DateTime.now().difference(tracker.lastSent!).inSeconds;
    final ok = running && tracker.running && tracker.problem == null && sentAgo != null && sentAgo < 60;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // sending status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: !running ? Colors.white : (ok ? const Color(0xFFE5F7EA) : const Color(0xFFFFF4E0)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(!running ? Icons.flag_rounded : (ok ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded),
                    color: !running ? AppColors.muted : (ok ? AppColors.emerald : AppColors.amber)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !running
                            ? 'Trip finished'
                            : ok
                                ? 'Sharing bus location'
                                : (tracker.problem ?? (tracker.lastPosition == null ? 'Waiting for GPS…' : 'Sending…')),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (running)
                        Text(
                          [
                            if (sentAgo != null) 'sent $sentAgo s ago',
                            if (tracker.waiting > 1) '${tracker.waiting} waiting to send',
                            'next: ${tracker.nextStop ?? trip['next_stop'] ?? '—'}',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
                Text('${trip['on_board']}/${riders.length}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 4),
                const Text('on\nbus', style: TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 260,
              child: Stack(
                children: [
                  BusMap(
                    key: _mapKey,
                    stops: stops,
                    school: school,
                    me: me,
                    padding: const EdgeInsets.all(30),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: FloatingActionButton.small(
                      heroTag: 'centre',
                      backgroundColor: Colors.white,
                      onPressed: () => _mapKey.currentState?.centreOnBus(),
                      child: const Icon(Icons.my_location_rounded, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Students'),
          if (riders.isEmpty)
            const AppCard(child: Text('No students travel this way on this route.'))
          else
            for (final r in riders)
              AppCard(
                child: Row(
                  children: [
                    Avatar(name: r['student']['name'].toString(), radius: 20, color: AppColors.teacher),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['student']['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${r['stop']['name']} · ${r['student']['class'] ?? ''} ${r['student']['section'] ?? ''}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    if (_busy.contains(r['student']['id']))
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                    else if (running) ...[
                      _ToggleButton(
                        label: 'On',
                        icon: Icons.login_rounded,
                        active: r['status'] == 'in',
                        color: AppColors.emerald,
                        onTap: () => _mark(r, 'in'),
                      ),
                      const SizedBox(width: 6),
                      _ToggleButton(
                        label: 'Off',
                        icon: Icons.logout_rounded,
                        active: r['status'] == 'out',
                        color: AppColors.indigo,
                        onTap: () => _mark(r, 'out'),
                      ),
                    ] else
                      Text(r['status'] == 'in' ? 'On bus' : (r['status'] == 'out' ? 'Got off' : '—')),
                  ],
                ),
              ),
          const SectionTitle('Stops'),
          AppCard(
            child: Column(
              children: [
                for (final s in allStops)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      (s['passed'] == true || passed.contains(s['id'])) ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      color: (s['passed'] == true || passed.contains(s['id'])) ? AppColors.emerald : AppColors.muted,
                    ),
                    title: Text(s['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: s['latitude'] == null
                        ? const Text('No map location yet', style: TextStyle(color: AppColors.amber))
                        : (s['time'] != null ? Text('Planned ${s['time']}') : null),
                    trailing: running
                        ? TextButton.icon(
                            onPressed: () => _saveStopHere(s),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                            label: Text(s['latitude'] == null ? 'Set here' : 'Update'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton(
      {required this.label, required this.icon, required this.active, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color : color.withAlpha(22),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: active ? Colors.white : color, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera sheet: each scanned ID card marks the child on (or off, if already on) the bus.
class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.tripId, required this.api});

  final int tripId;
  final ApiClient api;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  final MobileScannerController _camera =
      MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.qrCode]);
  final Map<String, DateTime> _recent = {};
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || _busy) return;
    final seen = _recent[code];
    if (seen != null && DateTime.now().difference(seen).inSeconds < 4) return; // same card still in view
    _recent[code] = DateTime.now();
    setState(() => _busy = true);
    try {
      final data = Map<String, dynamic>.from(
          await widget.api.post('/bus/trips/${widget.tripId}/boarding', {'code': code, 'kind': 'toggle'}) as Map);
      HapticFeedback.mediumImpact();
      setState(() {
        _message = data['message'].toString();
        _error = false;
      });
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _message = e.message;
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Stack(
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Row(
              children: [
                const Expanded(
                  child: Text('Scan the ID card as the child gets on or off',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          if (_message != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _error ? AppColors.rose : AppColors.emerald, borderRadius: BorderRadius.circular(16)),
                child: Text(_message!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}


/// Driver of a bus without an attendant: one big status, locked while the bus moves, hold to end.
///
/// The driver taps Start before leaving and holds "End trip" after parking. Nothing else to do:
/// the location is sent by itself, also with the screen off.
class DriverTripScreen extends StatefulWidget {
  const DriverTripScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..addStatusListener(_onHoldDone);
  Map<String, dynamic>? _trip;
  Timer? _tick;
  bool _ending = false;

  TripTracker get _tracker => TripTracker.instance;
  ApiClient get _api => context.read<AppState>().api;

  /// Moving faster than walking speed: buttons are locked.
  bool get _moving => (_tracker.lastPosition?.speed ?? 0) > 2.0;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_refresh);
    _tick = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    _load();
  }

  @override
  void dispose() {
    _tracker.removeListener(_refresh);
    _tick?.cancel();
    _hold.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (_moving && _hold.isAnimating) _hold.reverse();
    if (!_tracker.running && !_ending && _trip != null) {
      Navigator.maybePop(context); // trip ended from the office
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final data = Map<String, dynamic>.from(await _api.get('/bus/trips/${widget.tripId}') as Map);
      if (mounted) setState(() => _trip = data);
    } on ApiException catch (_) {}
  }

  Future<void> _onHoldDone(AnimationStatus status) async {
    if (status != AnimationStatus.completed || _ending) return;
    HapticFeedback.heavyImpact();
    setState(() => _ending = true);
    await _tracker.flush();
    try {
      await _api.post('/bus/trips/${widget.tripId}/end');
      await _tracker.stop();
      if (mounted) {
        showMessage(context, 'Trip ended. Thank you!');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showMessage(context, e.message, error: true);
        setState(() => _ending = false);
        _hold.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final tracker = _tracker;
    final sentAgo = tracker.lastSent == null ? null : DateTime.now().difference(tracker.lastSent!).inSeconds;
    final ok = tracker.running && tracker.problem == null && sentAgo != null && sentAgo < 60;
    final waitingGps = tracker.lastPosition == null;
    final color = ok ? const Color(0xFF22C55E) : (waitingGps ? const Color(0xFF94A3B8) : const Color(0xFFF59E0B));
    final started = DateTime.tryParse(trip?['started_at']?.toString() ?? '')?.toLocal();
    final minutes = started == null ? null : DateTime.now().difference(started).inMinutes;
    final speed = ((tracker.lastPosition?.speed ?? 0) * 3.6).clamp(0, 200).round();

    return PopScope(
      canPop: !_moving,
      child: Scaffold(
        backgroundColor: AppColors.night,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    if (!_moving)
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                      ),
                    Expanded(
                      child: Text(
                        trip == null ? 'Bus trip' : '${trip['vehicle']['name']} · ${trip['direction_label']}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // big status light
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(40),
                    border: Border.all(color: color, width: 6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(ok ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded, color: color, size: 54),
                      const SizedBox(height: 8),
                      Text('$speed km/h',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  ok
                      ? 'Sharing bus location'
                      : (waitingGps ? 'Waiting for GPS…' : (tracker.problem ?? 'Sending…')),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (tracker.nextStop != null || trip?['next_stop'] != null)
                      'Next stop: ${tracker.nextStop ?? trip?['next_stop']}',
                    if (minutes != null) 'Running $minutes min',
                  ].join('   ·   '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_moving)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(22)),
                    child: const Column(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white70, size: 30),
                        SizedBox(height: 6),
                        Text('Drive safely',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('The phone is locked while the bus moves. You can put it away — the location is sent by itself.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                else
                  _HoldToEnd(controller: _hold, busy: _ending),
                const SizedBox(height: 10),
                Text(_moving ? '' : 'Hold the button for 2 seconds after parking',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoldToEnd extends StatelessWidget {
  const _HoldToEnd({required this.controller, required this.busy});

  final AnimationController controller;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    void release() {
      if (!controller.isCompleted) controller.reverse();
    }

    // press and keep the finger on the button: the red fill grows; lifting early cancels
    return Listener(
      onPointerDown: (_) {
        if (!busy) controller.forward();
      },
      onPointerUp: (_) => release(),
      onPointerCancel: (_) => release(),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Container(
          height: 76,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            color: const Color(0xFF7F1D1D),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: controller.value,
                child: Container(color: AppColors.rose),
              ),
              Center(
                child: busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_circle_rounded, color: Colors.white, size: 30),
                          SizedBox(width: 10),
                          Text('Hold to END TRIP',
                              style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
