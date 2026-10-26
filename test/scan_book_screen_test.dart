import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:escaner_libros/views/tabs/scan_tab.dart';
import 'package:escaner_libros/controllers/biblioteca_controller.dart';

void main() {
  testWidgets('ScanBookScreen se renderiza con titulo y formulario', (tester) async {
    final biblioteca = BibliotecaController();

    await tester.pumpWidget(
      MaterialApp(
        home: ScanBookScreen(
          biblioteca: biblioteca,
          onGuardado: () {},
        ),
      ),
    );

    expect(find.text('Escanear libro con cámara'), findsOneWidget);
    expect(find.byType(ScanTab), findsOneWidget);
    expect(find.text('Comenzar Digitalización con Cámara'), findsOneWidget);
  });
}
