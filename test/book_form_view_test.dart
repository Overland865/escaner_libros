import 'package:escaner_libros/views/widgets/book_form_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('nuevo libro empieza en blanco y solicita año de publicación', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookFormView(onEnviar: (_) {})),
      ),
    );

    final camposTexto = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );
    expect(camposTexto, hasLength(4));
    for (final campo in camposTexto) {
      expect(campo.controller?.text, isEmpty);
    }
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      isNull,
    );
    expect(find.text('Título'), findsOneWidget);
    expect(find.text('Autor'), findsOneWidget);
    expect(find.text('Editorial (opcional)'), findsOneWidget);
    expect(find.text('Año de publicación'), findsOneWidget);
    expect(find.text('Código / Identificador Único'), findsNothing);
    expect(find.text('Parroquia / Iglesia Custodia'), findsNothing);
    expect(find.text('Bautismos y Defunciones'), findsNothing);
  });
}
