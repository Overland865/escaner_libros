import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escaner_libros/controllers/biblioteca_controller.dart';
import 'package:escaner_libros/views/tabs/home_tab.dart';

class FakeBibliotecaController extends BibliotecaController {
  bool _fakeSinConexion = false;
  bool restablecerLlamado = false;

  @override
  EstadoCarga get estado => EstadoCarga.listo;

  @override
  bool get sinConexion => _fakeSinConexion;

  void setSinConexion(bool value) {
    _fakeSinConexion = value;
    notifyListeners();
  }

  @override
  Future<bool> restablecerConexion() async {
    restablecerLlamado = true;
    _fakeSinConexion = false;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets(
      'HomeTab oculta la sección de conexión si hay conexión y la muestra si se pierde',
      (tester) async {
    final fakeController = FakeBibliotecaController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTab(
            biblioteca: fakeController,
            onEscanear: () {},
            onVerLibros: () {},
          ),
        ),
      ),
    );

    // Con conexión: no debe haber ningún anuncio o sección de conexión
    expect(find.text('Sin conexión con el backend'), findsNothing);
    expect(find.text('Restablecer conexión'), findsNothing);

    // Se pierde la conexión: debe mostrarse el anuncio y la opción para restablecerla
    fakeController.setSinConexion(true);
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión con el backend'), findsOneWidget);
    expect(find.text('Restablecer conexión'), findsOneWidget);
    expect(find.text('Diagnóstico'), findsOneWidget);

    // Al presionar 'Restablecer conexión'
    await tester.tap(find.text('Restablecer conexión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeController.restablecerLlamado, isTrue);
    // Una vez restablecida, el anuncio vuelve a ocultarse
    expect(find.text('Sin conexión con el backend'), findsNothing);
  });
}
