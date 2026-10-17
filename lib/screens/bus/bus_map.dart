import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';

/// One stop on the map.
class MapStop {
  const MapStop({required this.name, required this.point, this.passed = false, this.mine = false, this.time});

  final String name;
  final LatLng point;
  final bool passed;
  final bool mine;
  final String? time;
}

LatLng? latLngOf(dynamic lat, dynamic lng) {
  if (lat is num && lng is num && (lat != 0 || lng != 0)) return LatLng(lat.toDouble(), lng.toDouble());
  return null;
}

/// OpenStreetMap with the route, stops, school and the bus. When [bus] changes, the bus marker
/// glides to the new position over [glide] so it looks like the bus is driving.
class BusMap extends StatefulWidget {
  const BusMap({
    super.key,
    required this.stops,
    this.bus,
    this.school,
    this.path = const [],
    this.glide = const Duration(seconds: 4),
    this.busLabel,
    this.busColor = AppColors.sky,
    this.me,
    this.padding = const EdgeInsets.fromLTRB(40, 120, 40, 260),
  });

  final List<MapStop> stops;
  final LatLng? bus;
  final LatLng? school;
  final List<LatLng> path;
  final Duration glide;
  final String? busLabel;
  final Color busColor;

  /// The phone's own position (attendant screen).
  final LatLng? me;

  /// Room kept free around the route when the map first fits it (cards on top of the map).
  final EdgeInsets padding;

  @override
  State<BusMap> createState() => BusMapState();
}

class BusMapState extends State<BusMap> with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: widget.glide);
  LatLng? _from;
  LatLng? _to;
  bool _ready = false;
  bool _fitted = false;
  bool follow = false;

  LatLng? get shownBus {
    if (_to == null) return null;
    if (_from == null) return _to;
    final t = Curves.easeInOut.transform(_anim.value);
    return LatLng(_from!.latitude + (_to!.latitude - _from!.latitude) * t,
        _from!.longitude + (_to!.longitude - _from!.longitude) * t);
  }

  @override
  void initState() {
    super.initState();
    _to = widget.bus;
    _anim.addListener(() {
      if (!mounted) return;
      setState(() {});
      final pos = shownBus;
      if (follow && pos != null && _ready) _map.move(pos, _map.camera.zoom);
    });
  }

  @override
  void didUpdateWidget(covariant BusMap old) {
    super.didUpdateWidget(old);
    if (widget.glide != old.glide) _anim.duration = widget.glide;
    final next = widget.bus;
    if (next != null && (next.latitude != _to?.latitude || next.longitude != _to?.longitude)) {
      _from = shownBus ?? next;
      _to = next;
      _anim.forward(from: 0);
    } else if (next == null) {
      _from = _to = null;
    }
    if (!_fitted) _fit();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  List<LatLng> get _allPoints => [
        ...widget.stops.map((s) => s.point),
        if (widget.school != null) widget.school!,
        if (widget.bus != null) widget.bus!,
        if (widget.me != null) widget.me!,
      ];

  void _fit() {
    if (!_ready) return;
    final points = _allPoints;
    if (points.isEmpty) return;
    _fitted = true;
    if (points.length == 1) {
      _map.move(points.first, 15);
    } else {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: widget.padding, maxZoom: 16));
    }
  }

  /// Centre on the bus (or the phone) and keep following it.
  void centreOnBus() {
    final pos = shownBus ?? widget.me;
    if (pos == null) return;
    setState(() => follow = true);
    _map.move(pos, _map.camera.zoom < 14 ? 15.5 : _map.camera.zoom);
  }

  void showWholeRoute() {
    setState(() => follow = false);
    _fitted = false;
    _fit();
  }

  @override
  Widget build(BuildContext context) {
    final bus = shownBus;
    final stopsLine = [
      ...widget.stops.map((s) => s.point),
    ];
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _allPoints.isNotEmpty ? _allPoints.first : const LatLng(20.59, 78.96),
        initialZoom: _allPoints.isNotEmpty ? 13 : 4.5,
        onMapReady: () {
          _ready = true;
          _fit();
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture && follow) setState(() => follow = false);
        },
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sameer.school_app',
          maxZoom: 19,
        ),
        PolylineLayer(polylines: [
          if (stopsLine.length > 1)
            Polyline(points: stopsLine, strokeWidth: 5, color: const Color(0x557C8CC9), pattern: StrokePattern.dotted()),
          if (widget.path.length > 1)
            Polyline(points: widget.path, strokeWidth: 5, color: widget.busColor.withAlpha(200)),
        ]),
        MarkerLayer(markers: [
          for (final stop in widget.stops)
            Marker(
              point: stop.point,
              width: stop.mine ? 140 : 26,
              height: stop.mine ? 64 : 26,
              alignment: stop.mine ? Alignment.topCenter : Alignment.center,
              child: stop.mine ? _MyStop(name: stop.name) : _StopDot(passed: stop.passed, name: stop.name),
            ),
          if (widget.school != null)
            Marker(
              point: widget.school!,
              width: 40,
              height: 40,
              child: const _SchoolPin(),
            ),
          if (widget.me != null)
            Marker(
              point: widget.me!,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.sky,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
                ),
              ),
            ),
          if (bus != null)
            Marker(
              point: bus,
              width: 120,
              height: 52,
              child: _BusPin(label: widget.busLabel, color: widget.busColor),
            ),
        ]),
        RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright'))),
          ],
        ),
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.passed, required this.name});

  final bool passed;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: passed ? const Color(0xFF94A3B8) : AppColors.pink, width: 4),
          ),
        ),
      ),
    );
  }
}

class _MyStop extends StatelessWidget {
  const _MyStop({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.pink, width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.pink, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(height: 3),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.pink,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}

class _SchoolPin extends StatelessWidget {
  const _SchoolPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.night,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6)],
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
    );
  }
}

class _BusPin extends StatelessWidget {
  const _BusPin({this.label, required this.color});

  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(Icons.directions_bus_rounded, color: color, size: 18),
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
