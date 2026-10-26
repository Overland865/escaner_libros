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

  testWidgets(
      'seleccionar Otro muestra campo de escritura y usa el genero escrito al enviar',
      (tester) async {
    DatosLibroForm? enviado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BookFormView(onEnviar: (datos) => enviado = datos),
          ),
        ),
      ),
    );

    // Inicialmente no está el campo de Otro
    expect(find.text('Escribe el género o tipo'), findsNothing);

    // Llenar campos requeridos
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Grimorio Antiguo');
    await tester.enterText(find.widgetWithText(TextFormField, 'Autor'), 'Mago Merlín');
    await tester.enterText(find.widgetWithText(TextFormField, 'Año de publicación'), '1520');

    // Seleccionar 'Otro' en el Dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // El dropdown debe incluir los nuevos géneros solicitados
    expect(find.text('Ficción').last, findsOneWidget);
    expect(find.text('Ciencia ficción / Futurista').last, findsOneWidget);
    expect(find.text('Fantasía y magia').last, findsOneWidget);
    expect(find.text('Terror y horror').last, findsOneWidget);

    // Desplazarse hacia abajo en el menú desplegable (ListView.last)
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    final itemOtro = find.text('Otro').last;
    expect(itemOtro, findsOneWidget);
    await tester.tap(itemOtro);
    await tester.pumpAndSettle();

    // Ahora debe aparecer el campo de escritura libre
    expect(find.text('Escribe el género o tipo'), findsOneWidget);

    // Intentar enviar con campo 'Otro' vacío debe fallar
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Por favor escribe el género del libro'), findsOneWidget);
    expect(enviado, isNull);

    // Escribir el género personalizado
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Escribe el género o tipo'),
      'Magia medieval',
    );

    // Enviar el formulario
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(enviado, isNotNull);
    expect(enviado?.titulo, 'Grimorio Antiguo');
    expect(enviado?.tipoLibro, 'Magia medieval');
  });
}
