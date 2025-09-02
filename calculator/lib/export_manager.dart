import 'dart:io';
import 'package:calculator/home.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles exporting and sharing calculation results.
class ExportManager {
  /// Exports calculation [lines] into a PDF and shares it.
  static Future<void> exportToPdf(List<LineData> lines, String fileName) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'Calculation Export'),
                pw.SizedBox(height: 16),

                for (final line in lines.where((l) => l.controller.text.isNotEmpty))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${line.index}. ${line.controller.text}',
                          style: pw.TextStyle(font: pw.Font.courier(), fontSize: 12),
                        ),
                        if (line.result.isNotEmpty)
                          pw.Text(
                            '   = ${line.result}',
                            style: pw.TextStyle(color: PdfColors.green, font: pw.Font.courier(), fontSize: 12),
                          ),
                        if (line.error != null)
                          pw.Text(
                            '   Error: ${line.error}',
                            style: pw.TextStyle(color: PdfColors.red, font: pw.Font.courier(), fontSize: 12),
                          ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 20),
                pw.Text(
                  'Exported on: ${DateTime.now()}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();

      // Ensure filename
      final safeFileName =
          (fileName.isEmpty ? 'calculation_${DateTime.now().millisecondsSinceEpoch}' : fileName)
              .replaceAll(RegExp(r'\s+'), '_');

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$safeFileName.pdf');
      await file.writeAsBytes(bytes);

      // Share via Printing (PDF viewer or share sheet)
      await Printing.sharePdf(bytes: bytes, filename: '$safeFileName.pdf');
    } catch (e) {
      print('Failed to export PDF: $e');
    }
  }

  /// Shares calculation [lines] as plain text (placeholder for image export).
  static Future<void> shareAsImage(List<LineData> lines) async {
    try {
      final content = lines
          .where((line) => line.controller.text.isNotEmpty)
          .map((line) =>
              '${line.index}. ${line.controller.text}\n${line.result.isNotEmpty ? '   = ${line.result}' : ''}')
          .join('\n\n');

      // TODO: Replace with actual image rendering and sharing.
      await Share.share(content, subject: 'Calculation Export');
    } catch (e) {
      print('Failed to share as image: $e');
    }
  }
}
