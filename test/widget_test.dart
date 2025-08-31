// This is a basic Flutter widget test.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesadesenos/main.dart';

void main() {
  // Esencial para inicializar el entorno de prueba antes de ejecutar los tests,
  // especialmente cuando se usan plugins con código nativo como sqflite.
  TestWidgetsFlutterBinding.ensureInitialized();

  // --- Simulación de la Base de Datos (Mocking) ---
  // Configuramos un manejador falso para el plugin sqflite.
  // Esto permite que el test se ejecute sin una base de datos real.
  setUpAll(() {
    // El nombre del canal debe coincidir con el que usa el plugin sqflite.
    const MethodChannel('com.tekartik.sqflite')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      // Cuando la app intente obtener la ruta de la base de datos,
      // devolvemos una ruta temporal para el test.
      if (methodCall.method == 'getDatabasesPath') {
        return '.';
      }
      // Cuando la app intente consultar la base de datos (ej. getMesas),
      // devolvemos una lista vacía para simular que no hay datos.
      if (methodCall.method == 'query') {
        return [];
      }
      // Para otras operaciones (abrir, insertar, etc.), devolvemos un valor
      // que simula éxito (como el ID 1 o 1 fila afectada).
      if (['openDatabase', 'insert', 'delete'].contains(methodCall.method)) {
        return 1;
      }
      return null;
    });
  });

  // Limpiamos la simulación después de que terminen todos los tests.
  tearDownAll(() {
    const MethodChannel('com.tekartik.sqflite').setMockMethodCallHandler(null);
  });

  testWidgets('Calculator Smoke Test', (WidgetTester tester) async {
    // Construimos la app y disparamos un frame.
    await tester.pumpWidget(const MyApp());

    // Verificamos que el título se muestra correctamente.
    expect(find.text('Calculadora de Mesa de Senos'), findsOneWidget);

    // Como nuestra simulación devuelve una lista vacía de mesas, la app
    // debería mostrar el texto indicando que no hay mesas. Verificamos esto.
    expect(find.text('No hay mesas guardadas. Añade una desde el menú de ajustes.'), findsOneWidget);

    // Verificamos que el botón para calcular existe.
    expect(find.text('Calcular'), findsOneWidget);
  });
}

