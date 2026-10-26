import 'package:escaner_libros/models/libro_model.dart';
import 'package:escaner_libros/models/pagina_model.dart';
import 'package:escaner_libros/views/reading_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LibroModel _libro(int paginas) => LibroModel(
  id: 'X',
  isbnOCodigo: 'X',
  titulo: 'Libro de prueba',
  autor: 'Autor',
  tipoLibro: 'Ficción',
  anioInicio: 2000,
  anioFin: 2000,
  palabrasClave: const [],
  paginas: List.generate(
    paginas,
    (i) => PaginaModel(
      numeroPagina: i + 1,
      nombreArchivo: 'p${i + 1}.txt',
      conteoPalabras: 2,
      texto: 'Texto de la página ${i + 1}',
    ),
  ),
);

void main() {
  testWidgets('modo lectura pasa de página con botones y deslizando', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReadingModeScreen(libro: _libro(3))),
    );

    expect(find.text('Texto de la página 1'), findsOneWidget);
    expect(find.text('Página 1 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Texto de la página 2'), findsOneWidget);
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Página 3 de 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Página anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 3'), findsOneWidget);
  });

  testWidgets('modo lectura respeta la página inicial', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingModeScreen(libro: _libro(5), paginaInicial: 3),
      ),
    );
    expect(find.text('Página 4 de 5'), findsOneWidget);
  });

  testWidgets('modo lectura con libro sin páginas no falla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReadingModeScreen(libro: _libro(0))),
    );
    expect(find.text('No hay páginas para leer.'), findsOneWidget);
  });
}
