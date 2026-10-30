import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/informe.dart';
import '../../domain/repositories/reporte_repository.dart';

/// Arma el PDF de un informe y abre el diálogo del sistema para guardarlo o
/// compartirlo (paquetes `pdf` + `printing`).
class ExportadorReportePdf implements ExportadorReporte {
  const ExportadorReportePdf();

  @override
  Future<void> exportarPdf({
    required Informe informe,
    required String descripcionFiltros,
    required String nombreArchivo,
  }) async {
    final Uint8List bytes = await construir(
      informe: informe,
      descripcionFiltros: descripcionFiltros,
    );
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
  }

  /// Separado de [exportarPdf] para poder probar el documento sin diálogo.
  Future<Uint8List> construir({
    required Informe informe,
    required String descripcionFiltros,
  }) async {
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context _) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              _seguro('OptiRuta · ${informe.titulo}'),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _seguro(descripcionFiltros),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (pw.Context _) => <pw.Widget>[
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: <int, pw.Alignment>{
              for (final int i in informe.numericas)
                i: pw.Alignment.centerRight,
            },
            headerAlignments: <int, pw.Alignment>{
              for (final int i in informe.numericas)
                i: pw.Alignment.centerRight,
            },
            headers: informe.columnas.map(_seguro).toList(),
            data: <List<String>>[
              for (final List<String> fila in informe.filas)
                fila.map(_seguro).toList(),
            ],
          ),
          if (informe.resumen != null) ...<pw.Widget>[
            pw.SizedBox(height: 10),
            pw.Text(
              _seguro(informe.resumen!),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ],
          for (final String nota in informe.notas)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                _seguro(nota),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }

  /// La fuente estándar del PDF (Helvetica) no dibuja estos símbolos.
  static String _seguro(String texto) =>
      texto.replaceAll('—', '-').replaceAll('−', '-').replaceAll('→', '->');
}
