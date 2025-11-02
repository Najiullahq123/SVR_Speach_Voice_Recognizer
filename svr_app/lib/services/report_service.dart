import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'firestore_service.dart';

class ReportService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> generateAndShareReport({
    required BuildContext context,
    required String reportType, // 'pdf' or 'excel'
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating report...')));

      if (kIsWeb) {
        // Handle web downloads
        await _generateAndDownloadWebReport(
          context: context,
          reportType: reportType,
          period: period,
          metrics: metrics,
          deviceUsage: deviceUsage,
          alertFrequency: alertFrequency,
          activeHours: activeHours,
          topUsers: topUsers,
        );
      } else {
        // Handle mobile downloads
        String filePath;
        String fileName;

        if (reportType == 'pdf') {
          filePath = await _generatePDFReport(
            period: period,
            metrics: metrics,
            deviceUsage: deviceUsage,
            alertFrequency: alertFrequency,
            activeHours: activeHours,
            topUsers: topUsers,
          );
          fileName = 'analytics_report.pdf';
        } else {
          filePath = await _generateExcelReport(
            period: period,
            metrics: metrics,
            deviceUsage: deviceUsage,
            alertFrequency: alertFrequency,
            activeHours: activeHours,
            topUsers: topUsers,
          );
          fileName = 'analytics_report.xlsx';
        }

        // Share the file
        await Share.shareXFiles([
          XFile(filePath, name: fileName),
        ], text: 'Analytics Report - $period');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$fileName generated and ready to share!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateAndDownloadWebReport({
    required BuildContext context,
    required String reportType,
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    try {
      List<int> fileBytes;
      String fileName;

      if (reportType == 'pdf') {
        fileBytes = await _generatePDFBytes(
          period: period,
          metrics: metrics,
          deviceUsage: deviceUsage,
          alertFrequency: alertFrequency,
          activeHours: activeHours,
          topUsers: topUsers,
        );
        fileName = 'analytics_report.pdf';
      } else {
        fileBytes = await _generateExcelBytes(
          period: period,
          metrics: metrics,
          deviceUsage: deviceUsage,
          alertFrequency: alertFrequency,
          activeHours: activeHours,
          topUsers: topUsers,
        );
        fileName = 'analytics_report.xlsx';
      }

      // Create blob and download link for web
      final blob = html.Blob([fileBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName downloaded successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _generatePDFReport({
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                'SVR Analytics Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Report Info
            pw.Text('Period: $period'),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),

            // Key Metrics
            pw.Text(
              'Key Metrics',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Alerts', metrics['totalAlerts'].toString()],
                ['Resolved Alerts', metrics['resolvedAlerts'].toString()],
                ['Active Devices', metrics['activeDevices'].toString()],
                [
                  'Avg Response Time (min)',
                  metrics['avgResponseTime'].toStringAsFixed(1),
                ],
              ],
            ),
            pw.SizedBox(height: 20),

            // Device Usage
            pw.Text(
              'Device Usage by User',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['User', 'Device Usage %'],
              data: deviceUsage
                  .map(
                    (user) => [
                      user['user'].toString(),
                      '${user['percentage']}%',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // Alert Frequency
            pw.Text(
              'Alert Frequency',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Alert Type', 'Count'],
              data: alertFrequency
                  .map(
                    (alert) => [
                      alert['type'].toString(),
                      alert['count'].toString(),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // Active Hours
            pw.Text(
              'Active Hours',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Hour', 'Activity Count'],
              data: activeHours.take(12).map((hour) {
                final hourNum = hour['hour'] as int;
                String hourLabel;
                if (hourNum == 0)
                  hourLabel = '12 AM';
                else if (hourNum < 12)
                  hourLabel = '$hourNum AM';
                else if (hourNum == 12)
                  hourLabel = '12 PM';
                else
                  hourLabel = '${hourNum - 12} PM';

                return [hourLabel, hour['count'].toString()];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // Top Users
            pw.Text(
              'Top Users by Activity',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Rank', 'User', 'Activities'],
              data: topUsers
                  .asMap()
                  .entries
                  .map(
                    (entry) => [
                      (entry.key + 1).toString(),
                      entry.value['name'].toString(),
                      entry.value['alertCount'].toString(),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/analytics_report.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  Future<String> _generateExcelReport({
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Analytics Report'];

    // Add header info
    sheet.appendRow([TextCellValue('SVR Analytics Report')]);
    sheet.appendRow([TextCellValue('Period:'), TextCellValue(period)]);
    sheet.appendRow([
      TextCellValue('Generated:'),
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([]); // Empty row

    // Key Metrics
    sheet.appendRow([TextCellValue('Key Metrics')]);
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    sheet.appendRow([
      TextCellValue('Total Alerts'),
      IntCellValue(metrics['totalAlerts'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Resolved Alerts'),
      IntCellValue(metrics['resolvedAlerts'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Active Devices'),
      IntCellValue(metrics['activeDevices'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Avg Response Time (min)'),
      DoubleCellValue(metrics['avgResponseTime'] as double),
    ]);
    sheet.appendRow([]); // Empty row

    // Device Usage
    sheet.appendRow([TextCellValue('Device Usage by User')]);
    sheet.appendRow([TextCellValue('User'), TextCellValue('Device Usage %')]);
    for (final user in deviceUsage) {
      sheet.appendRow([
        TextCellValue(user['user'] as String),
        TextCellValue('${user['percentage']}%'),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Alert Frequency
    sheet.appendRow([TextCellValue('Alert Frequency')]);
    sheet.appendRow([TextCellValue('Alert Type'), TextCellValue('Count')]);
    for (final alert in alertFrequency) {
      sheet.appendRow([
        TextCellValue(alert['type'] as String),
        IntCellValue(alert['count'] as int),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Active Hours
    sheet.appendRow([TextCellValue('Active Hours')]);
    sheet.appendRow([TextCellValue('Hour'), TextCellValue('Activity Count')]);
    for (final hour in activeHours.take(12)) {
      final hourNum = hour['hour'] as int;
      String hourLabel;
      if (hourNum == 0)
        hourLabel = '12 AM';
      else if (hourNum < 12)
        hourLabel = '$hourNum AM';
      else if (hourNum == 12)
        hourLabel = '12 PM';
      else
        hourLabel = '${hourNum - 12} PM';

      sheet.appendRow([
        TextCellValue(hourLabel),
        IntCellValue(hour['count'] as int),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Top Users
    sheet.appendRow([TextCellValue('Top Users by Activity')]);
    sheet.appendRow([
      TextCellValue('Rank'),
      TextCellValue('User'),
      TextCellValue('Activities'),
    ]);
    for (final entry in topUsers.asMap().entries) {
      sheet.appendRow([
        IntCellValue(entry.key + 1),
        TextCellValue(entry.value['name'] as String),
        IntCellValue(entry.value['alertCount'] as int),
      ]);
    }

    // Save Excel to temporary directory
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/analytics_report.xlsx');
    final excelBytes = excel.encode();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
    }

    return file.path;
  }

  Future<List<int>> _generatePDFBytes({
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                'SVR Analytics Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Report Info
            pw.Text('Period: $period'),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),

            // Key Metrics
            pw.Text(
              'Key Metrics',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total Alerts', metrics['totalAlerts'].toString()],
                ['Resolved Alerts', metrics['resolvedAlerts'].toString()],
                ['Active Devices', metrics['activeDevices'].toString()],
                [
                  'Avg Response Time (min)',
                  metrics['avgResponseTime'].toStringAsFixed(1),
                ],
              ],
            ),
            pw.SizedBox(height: 20),

            // Device Usage
            pw.Text(
              'Device Usage by User',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['User', 'Device Usage %'],
              data: deviceUsage
                  .map(
                    (user) => [
                      user['user'].toString(),
                      '${user['percentage']}%',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // Alert Frequency
            pw.Text(
              'Alert Frequency',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Alert Type', 'Count'],
              data: alertFrequency
                  .map(
                    (alert) => [
                      alert['type'].toString(),
                      alert['count'].toString(),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // Active Hours
            pw.Text(
              'Active Hours',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Hour', 'Activity Count'],
              data: activeHours.take(12).map((hour) {
                final hourNum = hour['hour'] as int;
                String hourLabel;
                if (hourNum == 0)
                  hourLabel = '12 AM';
                else if (hourNum < 12)
                  hourLabel = '$hourNum AM';
                else if (hourNum == 12)
                  hourLabel = '12 PM';
                else
                  hourLabel = '${hourNum - 12} PM';

                return [hourLabel, hour['count'].toString()];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // Top Users
            pw.Text(
              'Top Users by Activity',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Rank', 'User', 'Activities'],
              data: topUsers
                  .asMap()
                  .entries
                  .map(
                    (entry) => [
                      (entry.key + 1).toString(),
                      entry.value['name'].toString(),
                      entry.value['alertCount'].toString(),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<List<int>> _generateExcelBytes({
    required String period,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> deviceUsage,
    required List<Map<String, dynamic>> alertFrequency,
    required List<Map<String, dynamic>> activeHours,
    required List<Map<String, dynamic>> topUsers,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Analytics Report'];

    // Add header info
    sheet.appendRow([TextCellValue('SVR Analytics Report')]);
    sheet.appendRow([TextCellValue('Period:'), TextCellValue(period)]);
    sheet.appendRow([
      TextCellValue('Generated:'),
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
    ]);
    sheet.appendRow([]); // Empty row

    // Key Metrics
    sheet.appendRow([TextCellValue('Key Metrics')]);
    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    sheet.appendRow([
      TextCellValue('Total Alerts'),
      IntCellValue(metrics['totalAlerts'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Resolved Alerts'),
      IntCellValue(metrics['resolvedAlerts'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Active Devices'),
      IntCellValue(metrics['activeDevices'] as int),
    ]);
    sheet.appendRow([
      TextCellValue('Avg Response Time (min)'),
      DoubleCellValue(metrics['avgResponseTime'] as double),
    ]);
    sheet.appendRow([]); // Empty row

    // Device Usage
    sheet.appendRow([TextCellValue('Device Usage by User')]);
    sheet.appendRow([TextCellValue('User'), TextCellValue('Device Usage %')]);
    for (final user in deviceUsage) {
      sheet.appendRow([
        TextCellValue(user['user'] as String),
        TextCellValue('${user['percentage']}%'),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Alert Frequency
    sheet.appendRow([TextCellValue('Alert Frequency')]);
    sheet.appendRow([TextCellValue('Alert Type'), TextCellValue('Count')]);
    for (final alert in alertFrequency) {
      sheet.appendRow([
        TextCellValue(alert['type'] as String),
        IntCellValue(alert['count'] as int),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Active Hours
    sheet.appendRow([TextCellValue('Active Hours')]);
    sheet.appendRow([TextCellValue('Hour'), TextCellValue('Activity Count')]);
    for (final hour in activeHours.take(12)) {
      final hourNum = hour['hour'] as int;
      String hourLabel;
      if (hourNum == 0)
        hourLabel = '12 AM';
      else if (hourNum < 12)
        hourLabel = '$hourNum AM';
      else if (hourNum == 12)
        hourLabel = '12 PM';
      else
        hourLabel = '${hourNum - 12} PM';

      sheet.appendRow([
        TextCellValue(hourLabel),
        IntCellValue(hour['count'] as int),
      ]);
    }
    sheet.appendRow([]); // Empty row

    // Top Users
    sheet.appendRow([TextCellValue('Top Users by Activity')]);
    sheet.appendRow([
      TextCellValue('Rank'),
      TextCellValue('User'),
      TextCellValue('Activities'),
    ]);
    for (final entry in topUsers.asMap().entries) {
      sheet.appendRow([
        IntCellValue(entry.key + 1),
        TextCellValue(entry.value['name'] as String),
        IntCellValue(entry.value['alertCount'] as int),
      ]);
    }

    final excelBytes = excel.encode();
    return excelBytes ?? [];
  }
}
