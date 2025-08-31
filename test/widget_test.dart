// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// No importamos 'main.dart' para aislar la prueba.

void main() {
  // Este es un test de diagnóstico para asegurar que el entorno de
  // pruebas de Flutter funciona correctamente.
  testWidgets('Barebones sanity check', (WidgetTester tester) async {
    // Construimos un widget increíblemente simple.
    // Esto no usa base de datos ni ninguna lógica compleja.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hello'),
        ),
      ),
    );

    // Verificamos que el texto 'Hello' aparece en la pantalla.
    // Si esto funciona, el corredor de pruebas de Flutter está operativo.
    expect(find.text('Hello'), findsOneWidget);
  });
}

