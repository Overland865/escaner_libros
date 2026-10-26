import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:escaner_libros/services/pdf_extractor_service.dart';

void main() {
  test('PdfExtractorService extrae texto de un PDF por páginas', () async {
    // Crear un documento PDF de prueba en memoria
    final document = PdfDocument();

    // Página 1
    final page1 = document.pages.add();
    page1.graphics.drawString(
      'Capitulo 1: En un lugar de la Mancha.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    // Página 2
    final page2 = document.pages.add();
    page2.graphics.drawString(
      'Capitulo 2: La primera salida del caballero andante.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final List<int> bytesList = await document.save();
    document.dispose();
    final bytes = Uint8List.fromList(bytesList);

    // Extraer páginas con el servicio
    final resultado = await PdfExtractorService.extraerPaginas(bytes);

    expect(resultado.totalPaginas, 2);
    expect(resultado.paginas.length, 2);
    expect(resultado.paginas[0].numeroPagina, 1);
    expect(resultado.paginas[0].texto, contains('Capitulo 1'));
    expect(resultado.paginas[0].conteoPalabras, greaterThan(0));
    expect(resultado.paginas[1].numeroPagina, 2);
    expect(resultado.paginas[1].texto, contains('Capitulo 2'));
    expect(resultado.totalPalabras, greaterThan(0));
  });
}
