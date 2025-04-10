import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/sop_model.dart';

class PrintService {
  // Function to generate a print-friendly PDF for an SOP
  Future<void> printSOP(BuildContext context, SOP sop) async {
    final pdf = pw.Document();

    // Get printer information
    final printerList = await Printing.listPrinters();
    debugPrint(
        'Available printers: ${printerList.map((p) => p.name).join(', ')}');

    // Create a PDF document in landscape orientation
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => [
          _buildPDFHeader(sop),
          pw.SizedBox(height: 20),
          _buildSummarySection(sop),
          pw.SizedBox(height: 20),
          _buildStepsGrid(sop),
        ],
        footer: (context) => _buildFooter(context, sop),
      ),
    );

    // Print the document
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${sop.title} - SOP #${sop.id}',
      format: PdfPageFormat.a4.landscape,
    );
  }

  // Build the PDF header with company and SOP information
  pw.Widget _buildPDFHeader(SOP sop) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Elmo's Furniture",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  "Standard Operating Procedure",
                  style: pw.TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "SOP ID: ${sop.id}",
                  style: pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  "Department: ${sop.department}",
                  style: pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  "Revision: ${sop.revisionNumber}",
                  style: pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
                pw.Text(
                  "Date: ${_formatDate(sop.updatedAt)}",
                  style: pw.TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text(
          sop.title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          sop.description,
          style: pw.TextStyle(
            fontSize: 14,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // Build the summary section with tools, safety requirements, and cautions
  pw.Widget _buildSummarySection(SOP sop) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Required Tools:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.tools.map((tool) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            border: pw.Border.all(color: PdfColors.blue200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(tool,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Safety Requirements:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.safetyRequirements.map((safety) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red50,
                            border: pw.Border.all(color: PdfColors.red200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(safety,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      "Cautions:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.cautions.map((caution) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.amber50,
                            border: pw.Border.all(color: PdfColors.amber),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(caution,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a grid of steps with 4 steps per row
  pw.Widget _buildStepsGrid(SOP sop) {
    final steps = sop.steps;
    final List<pw.Widget> rows = [];

    for (int i = 0; i < steps.length; i += 4) {
      final rowSteps = steps.skip(i).take(4).toList();
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rowSteps
              .map((step) => pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child:
                          _buildStepCard(step, i + rowSteps.indexOf(step) + 1),
                    ),
                  ))
              .toList(),
        ),
      );
      rows.add(pw.SizedBox(height: 15));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Step-by-Step Procedure",
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(),
        pw.SizedBox(height: 10),
        ...rows,
      ],
    );
  }

  // Build an individual step card
  pw.Widget _buildStepCard(SOPStep step, int stepNumber) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Step header with step number
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 24,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "$stepNumber",
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    step.title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Step content
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(step.instruction,
                    style: const pw.TextStyle(fontSize: 10)),
                if (step.helpNote != null && step.helpNote!.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "ⓘ ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber800,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            step.helpNote!,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (step.stepTools.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Tools Needed:",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: step.stepTools.map((tool) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          tool,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (step.stepHazards.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Hazards:",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: step.stepHazards.map((hazard) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.fromLTRB(4, 2, 4, 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange50,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          hazard,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (step.assignedTo != null && step.assignedTo!.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text(
                        "Assigned to: ",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.Text(
                        step.assignedTo!,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
                if (step.estimatedTime != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Row(
                    children: [
                      pw.Text(
                        "Est. time: ",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                      pw.Text(
                        "${step.estimatedTime} min",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the footer for each page
  pw.Widget _buildFooter(pw.Context context, SOP sop) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "Created by: ${sop.createdBy}",
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            "Printed on: ${_formatDate(DateTime.now())}",
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
