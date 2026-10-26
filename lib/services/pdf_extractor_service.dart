import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/pagina_model.dart';

/// Resultado del análisis y extracción de texto de un archivo PDF.
class ResultadoExtraccionPdf {
  final int totalPaginas;
  final int totalPalabras;
  final List<PaginaModel> paginas;

  const ResultadoExtraccionPdf({
    required this.totalPaginas,
    required this.totalPalabras,
    required this.paginas,
  });
}

/// Servicio encargado de procesar archivos PDF y extraer su texto página a página.
class PdfExtractorService {
  /// Extrae el texto de un documento PDF dado en [bytes] y devuelve
  /// la lista de [PaginaModel] para cada página procesada.
  static Future<ResultadoExtraccionPdf> extraerPaginas(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final paginas = <PaginaModel>[];
    int totalPalabras = 0;

    for (int i = 0; i < document.pages.count; i++) {
      final textoPagina = extractor
          .extractText(startPageIndex: i, endPageIndex: i)
          .trim();
      final conteo = _contarPalabras(textoPagina);
      totalPalabras += conteo;

      paginas.add(
        PaginaModel(
          numeroPagina: i + 1,
          nombreArchivo: 'pagina_${(i + 1).toString().padLeft(3, '0')}.txt',
          conteoPalabras: conteo,
          texto: textoPagina.isEmpty
              ? '(Página sin texto digital detectable)'
              : textoPagina,
          confianza: 1.0,
          motor: 'Extractor PDF',
        ),
      );
    }

    final totalPaginas = document.pages.count;
    document.dispose();

    return ResultadoExtraccionPdf(
      totalPaginas: totalPaginas,
      totalPalabras: totalPalabras,
      paginas: paginas,
    );
  }

  static int _contarPalabras(String texto) {
    final trimmed = texto.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;
  }
}
