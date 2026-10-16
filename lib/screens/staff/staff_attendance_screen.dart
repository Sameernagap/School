import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

const _statusLabels = {'present': 'Present', 'late': 'Late', 'absent': 'Absent', 'leave': 'On leave'};

/// The teacher's own attendance: check in / out by scanning the school's check-in QR poster.
class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get('/staff/attendance');
      _data = Map<String, dynamic>.from(data as Map);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkInOut() async {
    String? code;
    if (_data?['require_qr'] == true) {
      code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _CheckinScanner()));
      if (code == null) return;
    }
    setState(() => _busy = true);
    final checkingIn = _data?['state'] != 'checked_in';
    await runAction(context, () async {
      final data = await _api.post('/staff/attendance', {if (code != null) 'code': code});
      _data = Map<String, dynamic>.from(data as Map);
      HapticFeedback.mediumImpact();
    }, success: checkingIn ? 'Checked in. Have a good day!' : 'Checked out. See you tomorrow!');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PageScaffold(
      title: 'My Attendance',
      body: data == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _TodayCard(data: data, busy: _busy, onPressed: _checkInOut),
                  const SizedBox(height: 16),
                  const SectionTitle('This month'),
                  _MonthRow(month: Map<String, dynamic>.from(data['month'] as Map)),
                  const SizedBox(height: 16),
                  const SectionTitle('Last 14 days'),
                  for (final r in (data['recent'] as List).cast<Map>()) _DayTile(row: r),
                  if ((data['recent'] as List).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No working days yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data, required this.busy, required this.onPressed});

  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final today = Map<String, dynamic>.from(data['today'] as Map);
    final inside = data['state'] == 'checked_in';
    final requireQr = data['require_qr'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(fmtDate(today['date']),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: inside ? const Color(0xFFDDF6E8) : const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(inside ? 'At school' : (today['check_in'] == null ? 'Not checked in' : 'Checked out'),
                    style: TextStyle(
                        color: inside ? const Color(0xFF0F6B3E) : const Color(0xFF8A5A00),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TimeBox(label: 'In', value: fmtTime(today['check_in'])),
              const SizedBox(width: 10),
              _TimeBox(label: 'Out', value: fmtTime(today['check_out'])),
              const SizedBox(width: 10),
              _TimeBox(label: 'Hours', value: fmtHours(today['worked_hours'])),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC93C),
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              onPressed: busy ? null : onPressed,
              icon: Icon(requireQr ? Icons.qr_code_scanner_rounded : (inside ? Icons.logout_rounded : Icons.login_rounded)),
              label: Text(busy
                  ? 'Please wait…'
                  : requireQr
                      ? (inside ? 'Scan to check out' : 'Scan to check in')
                      : (inside ? 'Check out' : 'Check in')),
            ),
          ),
          const SizedBox(height: 8),
          Text('Late after ${data['late_after']}',
              style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month});

  final Map<String, dynamic> month;

  @override
  Widget build(BuildContext context) {
    Widget box(String label, String key, String status) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.soft(statusColor(status)), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text('${month[key] ?? 0}',
                    style: TextStyle(color: statusColor(status), fontSize: 22, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        box('Present', 'present', 'present'),
        const SizedBox(width: 8),
        box('Late', 'late', 'late'),
        const SizedBox(width: 8),
        box('Absent', 'absent', 'absent'),
        const SizedBox(width: 8),
        box('Leave', 'leave', 'leave'),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.row});

  final Map row;

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? 'absent').toString();
    final late = (row['late_minutes'] ?? 0) as num;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtDate(row['date']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (row['check_in'] != null)
                    Text(
                        '${fmtTime(row['check_in'])} – ${fmtTime(row['check_out'])} · ${fmtHours(row['worked_hours'])}'
                        '${late > 0 ? ' · ${late.toInt()} min late' : ''}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
            StatusChip(label: _statusLabels[status] ?? status, status: status),
          ],
        ),
      ),
    );
  }
}

/// Full-screen camera that returns the text of the first QR code it reads.
class _CheckinScanner extends StatefulWidget {
  const _CheckinScanner();

  @override
  State<_CheckinScanner> createState() => _CheckinScannerState();
}

class _CheckinScannerState extends State<_CheckinScanner> {
  final MobileScannerController _camera =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan the check-in QR'),
        actions: [
          IconButton(
              tooltip: 'Torch', icon: const Icon(Icons.flashlight_on_rounded), onPressed: () => _camera.toggleTorch()),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: (capture) {
              final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (_done || code == null) return;
              _done = true;
              Navigator.pop(context, code);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFC93C), width: 4),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text('Point the camera at the STAFF CHECK-IN poster in the school office',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
