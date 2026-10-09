import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key, required this.studentId});

  final int studentId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return PageScaffold(
      title: 'School bus',
      body: AsyncView<dynamic>(
        loader: () => api.get('/students/$studentId/transport'),
        builder: (context, data, reload) {
          if (data == null) {
            return const EmptyView(
                icon: Icons.directions_bus_outlined,
                message: 'This student does not use the school bus.',
                color: AppColors.lime);
          }
          final route = Map<String, dynamic>.from(data['route'] as Map);
          final stop = Map<String, dynamic>.from(data['stop'] as Map);
          final vehicle = data['vehicle'] is Map ? Map<String, dynamic>.from(data['vehicle'] as Map) : null;
          final stops = (data['stops'] as List? ?? const []).cast<Map>();
          final trip = data['trip'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                color: AppColors.lime,
                icon: Icons.directions_bus_rounded,
                title: '${route['code']} · ${route['name']}',
                subtitle: '${stop['name']} · ${data['trip_label']}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (trip != 'drop')
                    Expanded(child: _time('Pick-up', (stop['pickup_time'] ?? '-').toString(), Icons.wb_sunny_outlined)),
                  if (trip == 'both') const SizedBox(width: 10),
                  if (trip != 'pickup')
                    Expanded(child: _time('Drop', (stop['drop_time'] ?? '-').toString(), Icons.nights_stay_outlined)),
                ],
              ),
              if (vehicle != null) ...[
                const SectionTitle('Bus & crew'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Vehicle', '${vehicle['name']} (${vehicle['registration_no']})'),
                      if (vehicle['driver_name'] != null)
                        _person(context, 'Driver', vehicle['driver_name'].toString(), vehicle['driver_phone']?.toString()),
                      if (vehicle['attendant_name'] != null)
                        _person(context, 'Attendant', vehicle['attendant_name'].toString(),
                            vehicle['attendant_phone']?.toString()),
                    ],
                  ),
                ),
              ],
              const SectionTitle('Route stops'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < stops.length; i++)
                      Row(
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: stops[i]['name'] == stop['name'] ? AppColors.lime : Colors.white,
                                  border: Border.all(color: AppColors.lime, width: 3),
                                ),
                              ),
                              if (i < stops.length - 1) Container(width: 3, height: 34, color: AppColors.soft(AppColors.lime)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: Text(
                                (stops[i]['name'] ?? '').toString(),
                                style: TextStyle(
                                  fontWeight: stops[i]['name'] == stop['name'] ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Text('${stops[i]['pickup_time'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Yearly bus fee: ${fmtMoney(data['annual_fee'])}', style: const TextStyle(color: AppColors.muted)),
            ],
          );
        },
      ),
    );
  }

  Widget _time(String label, String value, IconData icon) => AppCard(
        child: Row(
          children: [
            IconTile(icon: icon, color: AppColors.lime, size: 40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.muted)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      );

  Widget _person(BuildContext context, String role, String name, String? phone) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 130, child: Text(role, style: const TextStyle(color: AppColors.muted))),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (phone != null)
              IconButton.filledTonal(
                onPressed: () => launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}')),
                icon: const Icon(Icons.call, size: 18),
              ),
          ],
        ),
      );
}
