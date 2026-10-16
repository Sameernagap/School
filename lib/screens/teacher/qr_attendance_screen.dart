import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'attendance_take_screen.dart';

/// Daily attendance by scanning the QR code printed on each student's ID card.
///
/// Starting a scan puts today's sheet in "scan mode": every student (except approved leave)
/// starts as absent and each scanned card marks that student present. The teacher then
/// reviews the list and submits, which sends the absence alerts to parents.
class QrAttendanceScreen extends StatefulWidget {
  const QrAttendanceScreen({super.key});

  @override
  State<QrAttendanceScreen> createState() => _QrAttendanceScreenState();
}

class _QrAttendanceScreenState extends State<QrAttendanceScreen> {
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  List<Map> _sections = [];
  int? _sectionId;
  Map<String, dynamic>? _sheet;
  final Map<int, String> _status = {};
  bool _loading = true;
  String? _error;

  // scanning state
  bool _busy = false;
  final Map<String, DateTime> _recent = {};
  _ScanResult? _last;

  ApiClient get _api => context.read<AppState>().api;
  final String _today = isoDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final data = await _api.get('/teacher/sections');
      _sections = (data as List).cast<Map>().where((s) => s['is_class_teacher'] == true).toList();
      _sectionId = _sections.isNotEmpty ? _sections.first['id'] as int? : null;
      if (_sectionId != null) {
        await _start();
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _last = null;
    });
    try {
      final data = await _api.post('/teacher/attendance/scan/start', {'section_id': _sectionId, 'date': _today});
      _sheet = Map<String, dynamic>.from(data as Map);
      _status.clear();
      for (final line in (_sheet!['lines'] as List).cast<Map>()) {
        _status[line['student_id'] as int] = (line['status'] ?? 'absent').toString();
      }
    } on ApiException catch (e) {
      if (e.code == 'validation_error') {
        // today's attendance of this section is already submitted
        _sheet = {'state': 'done', 'lines': const []};
        _status.clear();
      } else {
        _error = e.message;
        _sheet = null;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _sheet == null) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (code == null || code.isEmpty) return;
    // the camera sees the same card many times a second: ignore repeats for 4 seconds
    final now = DateTime.now();
    final seen = _recent[code];
    if (seen != null && now.difference(seen).inSeconds < 4) return;
    _recent[code] = now;

    _busy = true;
    try {
      final data = await _api.post('/teacher/attendance/${_sheet!['id']}/scan', {'code': code});
      final result = Map<String, dynamic>.from(data as Map);
      final student = Map<String, dynamic>.from(result['student'] as Map);
      final already = result['result'] == 'already';
      _status[student['id'] as int] = (result['status'] ?? 'present').toString();
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      setState(() => _last = _ScanResult(
            ok: true,
            already: already,
            title: (student['name'] ?? '').toString(),
            subtitle: already ? 'Already marked present' : 'Marked present',
            photoUrl: student['photo_url']?.toString(),
            roll: student['roll_no']?.toString(),
          ));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _last = _ScanResult(ok: false, title: 'Not marked', subtitle: e.message));
    } catch (e) {
      setState(() => _last = _ScanResult(ok: false, title: 'Not marked', subtitle: e.toString()));
    } finally {
      _busy = false;
    }
  }

  Future<void> _review() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendanceTakeScreen(sectionId: _sectionId)),
    );
    // after submitting (or coming back) reload the sheet
    if (mounted) await _start();
  }

  void _markByHand(int studentId, String name) async {
    if (!await confirmDialog(context, 'Mark present', 'Mark $name present without scanning the card?',
        ok: 'Mark present')) {
      return;
    }
    if (!mounted) return;
    await runAction(context, () async {
      await _api.post('/teacher/attendance/${_sheet!['id']}', {
        'lines': [
          {'student_id': studentId, 'status': 'present'}
        ],
      });
      setState(() => _status[studentId] = 'present');
    }, success: '$name marked present');
  }

  @override
  Widget build(BuildContext context) {
    final lines = (_sheet?['lines'] as List? ?? const []).cast<Map>();
    final present = _status.values.where((s) => s == 'present' || s == 'late').length;
    final onLeave = _status.values.where((s) => s == 'leave').length;
    final remaining = lines.where((l) => _status[l['student_id']] == 'absent').toList();
    final done = _sheet?['state'] == 'done';

    return PageScaffold(
      title: 'Scan ID Cards',
      actions: [
        IconButton(
          tooltip: 'Torch',
          icon: const Icon(Icons.flashlight_on_rounded),
          onPressed: () => _camera.toggleTorch(),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _sectionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: [
                      for (final s in _sections)
                        DropdownMenuItem(value: s['id'] as int, child: Text((s['name'] ?? '').toString())),
                    ],
                    onChanged: (v) {
                      _sectionId = v;
                      _start();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(label: fmtDate(_today, year: false), color: AppColors.indigo),
              ],
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_sections.isEmpty)
            const Expanded(
              child: EmptyView(
                icon: Icons.qr_code_scanner_rounded,
                message: 'Daily attendance is taken by the class teacher.\nYou are not the class teacher of any section.',
              ),
            )
          else if (_error != null)
            Expanded(child: ErrorView(message: _error!, onRetry: _start))
          else if (done)
            const Expanded(
              child: EmptyView(icon: Icons.check_circle_rounded, message: "Today's attendance is already submitted."),
            )
          else ...[
            // camera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1.25,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: _camera, onDetect: _onDetect),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Text(
                          'Hold the QR code of the ID card inside the square',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // last scan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LastScanCard(result: _last),
            ),
            // counters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusChip(label: '$present / ${lines.length} present', status: 'present'),
                  StatusChip(label: '${remaining.length} not scanned', status: 'absent'),
                  if (onLeave > 0) StatusChip(label: '$onLeave on leave', status: 'leave'),
                ],
              ),
            ),
            // students not scanned yet
            Expanded(
              child: remaining.isEmpty
                  ? const Center(
                      child: Text('Everyone is marked 🎉',
                          style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      children: [
                        const Text('Not scanned yet (tap to mark present by hand)',
                            style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final l in remaining)
                              ActionChip(
                                label: Text('${l['roll_no'] ?? ''} ${l['name'] ?? ''}'.trim()),
                                onPressed: () => _markByHand(l['student_id'] as int, (l['name'] ?? '').toString()),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.emerald),
                  onPressed: _review,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Review & submit'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanResult {
  _ScanResult({required this.ok, required this.title, required this.subtitle, this.already = false, this.photoUrl, this.roll});

  final bool ok;
  final bool already;
  final String title;
  final String subtitle;
  final String? photoUrl;
  final String? roll;
}

class _LastScanCard extends StatelessWidget {
  const _LastScanCard({required this.result});

  final _ScanResult? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) {
      return const AppCard(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppColors.muted),
            SizedBox(width: 12),
            Expanded(child: Text('Scan the first ID card', style: TextStyle(color: AppColors.muted))),
          ],
        ),
      );
    }
    final color = !r.ok ? AppColors.rose : (r.already ? AppColors.sky : AppColors.emerald);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          if (r.ok)
            Avatar(name: r.title, photoUrl: r.photoUrl, radius: 24, color: color)
          else
            CircleAvatar(radius: 24, backgroundColor: color, child: const Icon(Icons.close_rounded, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.roll != null ? '${r.title} · Roll ${r.roll}' : r.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(r.subtitle, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(r.ok ? Icons.check_circle_rounded : Icons.error_rounded, color: color, size: 30),
        ],
      ),
    );
  }
}
