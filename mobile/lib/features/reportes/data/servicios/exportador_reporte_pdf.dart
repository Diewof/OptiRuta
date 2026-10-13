import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/fecha_utils.dart';
import '../../../../core/utils/moneda_utils.dart';
import '../../domain/entities/reporte.dart';
import '../../domain/repositories/reporte_repository.dart';

/// Arma el PDF del reporte y abre el diálogo del sistema para guardarlo o
/// compartirlo (paquetes `pdf` + `printing`).
class ExportadorReportePdf implements ExportadorReporte {
  const ExportadorReportePdf();

  @override
  Future<void> exportarPdf({
    required FiltroReporte filtro,
    required String descripcionFiltros,
    required List<FilaReporte> filas,
  }) async {
    final Uint8List bytes = await construir(
      filtro: filtro,
      descripcionFiltros: descripcionFiltros,
      filas: filas,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'reporte-viajes-${_iso(filtro.desde)}_${_iso(filtro.hasta)}.pdf',
    );
  }

  static String _iso(DateTime f) => f.toIso8601String().split('T').first;

  /// Separado de [exportarPdf] para poder probar el documento sin diálogo.
  Future<Uint8List> construir({
    required FiltroReporte filtro,
    required String descripcionFiltros,
    required List<FilaReporte> filas,
  }) async {
    final NumberFormatCop moneda = NumberFormatCop();
    final TotalesReporte t = TotalesReporte.de(filas);
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context _) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              'OptiRuta · Reporte de viajes cerrados',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${formatearFecha(filtro.desde)} a ${formatearFecha(filtro.hasta)}'
              ' · $descripcionFiltros',
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
              for (int i = 5; i <= 9; i++) i: pw.Alignment.centerRight,
            },
            headers: const <String>[
              'Remisión',
              'Cierre',
              'Ruta',
              'Cliente',
              'Conductor',
              'Km',
              'Flete',
              'Costos',
              'Rentab.',
              'A tiempo',
            ],
            data: <List<String>>[
              for (final FilaReporte f in filas)
                <String>[
                  f.remision,
                  formatearFecha(f.fechaCierre),
                  f.ruta,
                  f.cliente,
                  '${f.conductor} (${f.placa})',
                  f.km.round().toString(),
                  moneda.formatear(f.valorFlete),
                  moneda.formatear(f.costos),
                  moneda.formatear(f.rentabilidad),
                  f.aTiempo == null ? '—' : (f.aTiempo! ? 'Sí' : 'No'),
                ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Totales: ${t.viajes} viajes · ${t.km.round()} km · '
            'Flete ${moneda.formatear(t.valorFlete)} · '
            'Costos ${moneda.formatear(t.costos)} · '
            'Rentabilidad ${moneda.formatear(t.rentabilidad)}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
