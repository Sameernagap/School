import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../student/transport_screen.dart';
import 'bus_map.dart';

/// Parents and students: the child's bus moving on the map, minutes to the stop, on board or not.
/// Refreshes every few seconds only while this screen is open.
class BusLiveScreen extends StatefulWidget {
  const BusLiveScreen({super.key, required this.studentId});

  final int studentId;

  @override
  State<BusLiveScreen> createState() => _BusLiveScreenState();
}

class _BusLiveScreenState extends State<BusLiveScreen> with WidgetsBindingObserver {
  final _mapKey = GlobalKey<BusMapState>();
  Map<String, dynamic>? _data;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  int _interval = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel(); // nothing is downloaded while the app is in the background
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    _timer?.cancel();
    try {
      final data = await context.read<AppState>().api.get('/students/${widget.studentId}/bus/live');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(data as Map);
        _error = null;
        _interval = ((_data!['interval'] as num?) ?? 5).toInt().clamp(3, 60);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _loading = false;
    }
    if (!mounted) return;
    // while the bus runs: every few seconds; otherwise check now and then whether it started
    final running = _data?['running'] == true;
    _timer = Timer(Duration(seconds: running ? _interval : 30), _load);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: data == null
          ? (_error != null ? _errorView() : const Center(child: CircularProgressIndicator()))
          : data['available'] != true
              ? _noBus()
              : _live(data),
    );
  }

  Widget _errorView() => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Back')),
            ]),
          ),
        ),
      );

  Widget _noBus() => SafeArea(
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: _BackButton(onTap: () => Navigator.maybePop(context))),
            const Spacer(),
            const Icon(Icons.directions_bus_outlined, size: 56, color: AppColors.lime),
            const SizedBox(height: 12),
            const Text('This student does not use the school bus.', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
          ],
        ),
      );

  Widget _live(Map<String, dynamic> data) {
    final running = data['running'] == true;
    final myStop = Map<String, dynamic>.from(data['my_stop'] as Map);
    final stops = <MapStop>[];
    for (final s in (data['stops'] as List? ?? const [])) {
      final p = latLngOf(s['latitude'], s['longitude']);
      if (p == null) continue;
      stops.add(MapStop(
          name: s['name'].toString(), point: p, passed: s['passed'] == true, mine: s['id'] == myStop['id'],
          time: s['time']?.toString()));
    }
    final school = data['school'] is Map ? latLngOf(data['school']['latitude'], data['school']['longitude']) : null;
    final bus = data['bus'] is Map ? latLngOf(data['bus']['latitude'], data['bus']['longitude']) : null;
    final path = [
      for (final p in (data['path'] as List? ?? const []))
        if (p is List && p.length == 2) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())
    ];
    final vehicle = data['vehicle'] is Map ? Map<String, dynamic>.from(data['vehicle'] as Map) : const <String, dynamic>{};
    final route = Map<String, dynamic>.from(data['route'] as Map);
    return Stack(
      children: [
        Positioned.fill(
          child: BusMap(
            key: _mapKey,
            stops: stops,
            school: school,
            bus: running ? bus : null,
            path: running ? path : const [],
            busLabel: vehicle['name']?.toString(),
            glide: Duration(milliseconds: (_interval * 900).clamp(1500, 9000)),
          ),
        ),
        // top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _BackButton(onTap: () => Navigator.maybePop(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${vehicle['name'] ?? 'School bus'} · ${route['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        Text('Stop: ${myStop['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // map buttons
        if (running && bus != null)
          Positioned(
            right: 12,
            bottom: 250,
            child: Column(
              children: [
                _MapButton(icon: Icons.my_location_rounded, tooltip: 'Follow the bus', onTap: () => _mapKey.currentState?.centreOnBus()),
                const SizedBox(height: 8),
                _MapButton(icon: Icons.route_rounded, tooltip: 'Whole route', onTap: () => _mapKey.currentState?.showWholeRoute()),
              ],
            ),
          ),
        // bottom card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: _cardDecoration(radius: 24),
              child: running ? _runningCard(data, myStop, vehicle) : _waitingCard(data, myStop, vehicle),
            ),
          ),
        ),
      ],
    );
  }

  Widget _runningCard(Map<String, dynamic> data, Map<String, dynamic> myStop, Map<String, dynamic> vehicle) {
    final trip = Map<String, dynamic>.from(data['trip'] as Map);
    final pickup = trip['direction'] == 'pickup';
    final eta = data['eta_minutes'] as int?;
    final passed = data['stop_passed'] == true;
    final boarding = data['boarding'] is Map ? Map<String, dynamic>.from(data['boarding'] as Map) : null;
    final onBoard = boarding?['status'] == 'in';
    final seconds = data['bus'] is Map ? data['bus']['seconds_ago'] as int? : null;
    final noSignal = seconds != null && seconds > 90;

    String big;
    String line;
    if (pickup && (passed || onBoard)) {
      final school = data['eta_school_minutes'] as int?;
      big = school != null ? '$school min' : 'On the way';
      line = 'to school';
    } else if (passed) {
      big = 'Passed';
      line = pickup ? 'the bus has passed ${myStop['name']}' : 'the bus has reached ${myStop['name']}';
    } else if (eta != null) {
      big = eta <= 1 ? 'Arriving' : '$eta min';
      line = 'to ${myStop['name']}';
    } else {
      big = 'On the way';
      line = data['next_stop'] != null ? 'next stop: ${data['next_stop']}' : (trip['direction_label'] ?? '').toString();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(big, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: noSignal ? AppColors.muted : AppColors.sky, height: 1)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(
              icon: noSignal ? Icons.signal_wifi_off_rounded : Icons.circle,
              text: noSignal ? 'No signal for ${(seconds! / 60).round()} min' : 'Trip running · ${trip['direction_label']}',
              color: noSignal ? AppColors.amber : AppColors.emerald,
            ),
            if (data['boarding_tracked'] == false)
              const SizedBox.shrink()
            else if (boarding != null)
              _Chip(
                icon: onBoard ? Icons.check_circle_rounded : Icons.logout_rounded,
                text: onBoard ? 'On the bus since ${_clock(boarding['time'])}' : 'Got off at ${_clock(boarding['time'])}',
                color: onBoard ? AppColors.emerald : AppColors.indigo,
              )
            else
              const _Chip(icon: Icons.hourglass_empty_rounded, text: 'Not on the bus yet', color: AppColors.muted),
          ],
        ),
        if (!noSignal && seconds != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Updated $seconds s ago', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        _crewRow(vehicle),
      ],
    );
  }

  Widget _waitingCard(Map<String, dynamic> data, Map<String, dynamic> myStop, Map<String, dynamic> vehicle) {
    final pick = myStop['pickup_time'];
    final drop = myStop['drop_time'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('The bus is not on a trip now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          [
            if (pick != null) 'Morning pick-up $pick',
            if (drop != null) 'afternoon drop $drop',
          ].join(' · ').replaceFirst('afternoon', pick == null ? 'Afternoon' : 'afternoon'),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        const Text('The bus appears here as soon as the attendant starts the trip.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        _crewRow(vehicle),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => TransportScreen(studentId: widget.studentId))),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const Text('Bus details and fee'),
          ),
        ),
      ],
    );
  }

  Widget _crewRow(Map<String, dynamic> vehicle) {
    final calls = <Widget>[];
    void add(String role, String? name, dynamic phone) {
      if (phone == null || phone.toString().isEmpty) return;
      calls.add(Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
          onPressed: () => launchUrl(Uri.parse('tel:${phone.toString().replaceAll(' ', '')}')),
          icon: const Icon(Icons.call_rounded, size: 18),
          label: Text('Call $role', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ));
    }

    add('attendant', null, vehicle['attendant_phone']);
    add('driver', null, vehicle['driver_phone']);
    if (calls.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      for (var i = 0; i < calls.length; i++) ...[if (i > 0) const SizedBox(width: 8), calls[i]],
    ]);
  }

  static String _clock(dynamic iso) {
    final t = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}

BoxDecoration _cardDecoration({double radius = 18}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x2A1B1F3B), blurRadius: 18, offset: Offset(0, 6))],
    );

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const SizedBox(width: 46, height: 46, child: Icon(Icons.arrow_back_ios_new_rounded, size: 18)),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: AppColors.ink)),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 9 : 15, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ],
      ),
    );
  }
}
