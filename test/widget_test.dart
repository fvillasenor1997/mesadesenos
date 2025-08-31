// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesadesenos/main.dart';

void main() {
  testWidgets('Calculator Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verifica que el título de la aplicación se muestra en la AppBar.
    expect(find.text('Calculadora de Mesa de Senos'), findsOneWidget);

    // Verifica que el botón para calcular existe.
    expect(find.text('Calcular'), findsOneWidget);
    
    // Verifica que no hay un widget con el texto '1', que es parte del test
    // por defecto que fallaba.
    expect(find.text('1'), findsNothing);
  });
}
