import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/scraper_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'admin_layout.dart';

class AdminScraperScreen extends StatefulWidget {
  const AdminScraperScreen({super.key});

  @override
  State<AdminScraperScreen> createState() => _AdminScraperScreenState();
}

class _AdminScraperScreenState extends State<AdminScraperScreen> {
  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Scraper & Logs',
      activeRoute: RoutePaths.adminScraper,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Sidebar
            SizedBox(
              width: 320,
              child: _buildSettingsCard(context),
            ),
            const SizedBox(width: 24),
            // Logs Table
            Expanded(
              child: _buildLogsCard(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return StreamBuilder<ScraperSettingsModel>(
      stream: context.read<FirestoreService>().streamScraperSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading settings: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final settings = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppAdminColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppAdminColors.border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, color: AppAdminColors.primaryNeon),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Scheduler Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text('Enable Auto-Scrape', style: TextStyle(color: Colors.white70))),
                  Switch(
                    value: settings.enabled,
                    activeThumbColor: AppAdminColors.primaryNeon,
                    onChanged: (val) {
                      context.read<FirestoreService>().updateScraperSettings(
                            enabled: val,
                            runHour: settings.runHour,
                          );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Daily Run Time (24h format)', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: settings.runHour,
                dropdownColor: AppAdminColors.cardLight,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: List.generate(24, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text('${i.toString().padLeft(2, '0')}:00'),
                  );
                }),
                onChanged: (val) {
                  if (val != null) {
                    context.read<FirestoreService>().updateScraperSettings(
                          enabled: settings.enabled,
                          runHour: val,
                        );
                  }
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              _buildStatusRow('Bot Status', settings.status.toUpperCase()),
              const SizedBox(height: 12),
              _buildStatusRow(
                'Last Run',
                settings.lastRun != null
                    ? DateFormat('dd MMM yyyy, HH:mm').format(settings.lastRun!)
                    : 'Never',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label, 
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: value == 'ERROR' || value == 'FAILED'
                ? Colors.red
                : value == 'RUNNING'
                    ? AppAdminColors.primaryNeon
                    : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLogsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppAdminColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppAdminColors.border, width: 1.0),
      ),
      child: StreamBuilder<List<ScraperLogModel>>(
        stream: context.read<FirestoreService>().streamScraperLogs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Error loading logs: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!;

          if (logs.isEmpty) {
            return const Center(child: Text('No logs available.', style: TextStyle(color: Colors.white70)));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Recent Scrape Logs',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(height: 1, color: AppAdminColors.border),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Theme(
                      data: ThemeData.dark().copyWith(
                        dividerColor: AppAdminColors.border,
                        dataTableTheme: const DataTableThemeData(
                          headingTextStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                          dataTextStyle: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowHeight: 56,
                        dataRowMinHeight: 80,
                        dataRowMaxHeight: double.infinity,
                        columns: const [
                          DataColumn(label: Text('DATE/TIME')),
                          DataColumn(label: Text('TRIGGER')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('SOURCES')),
                          DataColumn(label: Text('FOUND')),
                          DataColumn(label: Text('NEW')),
                          DataColumn(label: Text('DUR (s)')),
                        ],
                        rows: logs.map((log) {
                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('dd MMM HH:mm').format(log.timestamp))),
                              DataCell(Text(log.triggeredBy.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: log.status == 'success'
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.status.toUpperCase(),
                                  style: TextStyle(
                                    color: log.status == 'success' ? Colors.green : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )),
                              DataCell(
                                SizedBox(
                                  width: 230,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: log.details.entries.map((e) {
                                        final source = e.key.toUpperCase();
                                        final uploaded = e.value['uploaded'] ?? 0;
                                        final found = e.value['found'] ?? 0;
                                        final isSuccess = e.value['status'] == 'success';
                                        
                                        final hasEvents = found > 0;
                                        final bgColor = isSuccess && hasEvents
                                            ? AppAdminColors.primaryNeon.withValues(alpha: 0.1)
                                            : AppAdminColors.cardLight;
                                        final textColor = isSuccess && hasEvents
                                            ? AppAdminColors.primaryNeon
                                            : Colors.white54;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSuccess && hasEvents 
                                                  ? AppAdminColors.primaryNeon.withValues(alpha: 0.3) 
                                                  : AppAdminColors.border,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                source,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$uploaded / $found',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: textColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(log.eventsFound.toString())),
                              DataCell(Text(log.eventsUploaded.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(log.durationSeconds.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
