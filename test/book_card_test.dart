import 'package:escaner_libros/models/libro_model.dart';
import 'package:escaner_libros/models/pagina_model.dart';
import 'package:escaner_libros/views/widgets/book_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un libro pendiente abre su detalle local', (tester) async {
    final libro = LibroModel(
      id: 'LIB-LOCAL-001',
      isbnOCodigo: 'LIB-LOCAL-001',
      titulo: 'Libro pendiente',
      autor: 'Autora',
      tipoLibro: 'Novela',
      anioInicio: 2024,
      anioFin: 2024,
      palabrasClave: const [],
      paginas: [
        PaginaModel(
          numeroPagina: 1,
          nombreArchivo: 'pagina_001.txt',
          conteoPalabras: 2,
          texto: 'Texto guardado',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookCard(
            libro: libro,
            pendiente: true,
            errorSync: 'Backend respondió HTTP 503',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Libro pendiente').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Guardado en este dispositivo; aún no está en el servidor.'),
      findsOneWidget,
    );
    expect(
      find.text('Error de subida: Backend respondió HTTP 503'),
      findsOneWidget,
    );
    expect(find.text('Página 1'), findsOneWidget);
  });
}
