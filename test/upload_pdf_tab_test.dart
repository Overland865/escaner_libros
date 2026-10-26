import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escaner_libros/controllers/biblioteca_controller.dart';
import 'package:escaner_libros/views/tabs/upload_pdf_tab.dart';

void main() {
  testWidgets('UploadPdfTab muestra zona de carga y boton para seleccionar PDF',
      (tester) async {
    final biblioteca = BibliotecaController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UploadPdfTab(
            biblioteca: biblioteca,
            onGuardado: () {},
          ),
        ),
      ),
    );

    expect(find.text('Subir libro en formato PDF'), findsOneWidget);
    expect(find.text('Seleccionar archivo PDF'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
  });
}
