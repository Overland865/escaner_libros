import 'package:escaner_libros/views/widgets/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login se renderiza con campos de credenciales y conectar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onCredencialesValidadas: () {})),
    );

    expect(find.text('Biblioteca Digital'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
    expect(find.textContaining('API key'), findsNothing);
    expect(find.text('Acceso al backend'), findsNothing);
  });

  testWidgets('login does not offer account creation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onCredencialesValidadas: () {})),
    );
    expect(find.textContaining('Crear cuenta'), findsNothing);
  });
}
