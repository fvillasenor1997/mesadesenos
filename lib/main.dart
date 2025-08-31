import 'package:flutter/material.dart';
import 'dart:math';

// --- Punto de entrada de la aplicación ---
void main() {
  runApp(const MyApp());
}

// --- Widget Raíz de la Aplicación ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora de Mesa de Senos',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SineBarCalculatorScreen(),
    );
  }
}

// --- Pantalla Principal de la Calculadora (Stateful) ---
class SineBarCalculatorScreen extends StatefulWidget {
  const SineBarCalculatorScreen({super.key});

  @override
  State<SineBarCalculatorScreen> createState() => _SineBarCalculatorScreenState();
}

class _SineBarCalculatorScreenState extends State<SineBarCalculatorScreen> {
  // --- Controladores para los campos de texto ---
  final angleController = TextEditingController();
  final lengthController = TextEditingController(); // L
  final heightController = TextEditingController(); // H
  final distanceController = TextEditingController(); // Mesa de senos
  final gController = TextEditingController();
  final g1Controller = TextEditingController();
  final vController = TextEditingController();
  final gbController = TextEditingController();
  final gagePinController = TextEditingController();

  // --- Claves Globales para obtener la posición de los widgets ---
  final Map<String, GlobalKey> _fieldKeys = {
    'G': GlobalKey(),
    'G1': GlobalKey(),
    'V': GlobalKey(),
    'GB': GlobalKey(),
    'Angle': GlobalKey(),
    'GagePin': GlobalKey(),
  };

  String? _activeFieldKey; // Almacena la clave del campo activo

  // --- Coordenadas de destino en la imagen (ajustar si es necesario) ---
  final Map<String, Offset> _targetPoints = {
    'G': const Offset(190, 240),
    'G1': const Offset(190, 180),
    'V': const Offset(230, 150),
    'GB': const Offset(310, 150),
    'Angle': const Offset(340, 215),
    'GagePin': const Offset(280, 150),
  };

  // --- Nodos de Foco para detectar la selección ---
  final Map<String, FocusNode> _focusNodes = {};

  // --- Variables para los resultados ---
  double resultA = 0.0, resultF = 0.0, resultB = 0.0, planerGageStackAB = 0.0;
  double resultZ = 0.0, resultY = 0.0, distanciaTotalOR = 0.0;
  
  @override
  void initState() {
    super.initState();
    // Inicializar FocusNodes y añadir listeners
    _fieldKeys.forEach((key, value) {
      _focusNodes[key] = FocusNode()
        ..addListener(() {
          setState(() {
            _activeFieldKey = (_focusNodes[key]!.hasFocus) ? key : null;
          });
        });
    });
  }

  void _performCalculations() {
    // Convertir texto a double, con 0.0 como valor por defecto
    final angleDeg = double.tryParse(angleController.text) ?? 0.0;
    final length = double.tryParse(lengthController.text) ?? 0.0;
    final height = double.tryParse(heightController.text) ?? 0.0;
    final g = double.tryParse(gController.text) ?? 0.0;
    final g1 = double.tryParse(g1Controller.text) ?? 0.0;
    final v = double.tryParse(vController.text) ?? 0.0;
    final gb = double.tryParse(gbController.text) ?? 0.0;
    final gagePin = double.tryParse(gagePinController.text) ?? 0.0;

    // --- CONVERSIÓN CRÍTICA: Grados a Radianes ---
    final angleRad = angleDeg * (pi / 180.0);
    final angle45Rad = 45 * (pi / 180.0);

    setState(() {
      // Fórmulas de la parte superior
      resultA = (sin(angleRad) * length) + (cos(angleRad) * height);
      resultF = ((cos(angle45Rad - angleRad) * sin(angle45Rad)) + 0.5);
      resultB = resultF * gagePin;
      planerGageStackAB = resultA - resultB;
      
      // Fórmulas de la parte inferior
      final denominatorZ = sin(angleRad) + cos(angleRad) - 1;
      resultZ = (denominatorZ != 0)
          ? (tan(angleRad) * gb) + (gagePin * sin(angleRad)) / denominatorZ
          : double.infinity;
      
      resultY = (resultZ * cos(angleRad)) + (g1 * cos(angleRad)) - (v * cos(angleRad));
      distanciaTotalOR = g + resultY;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de Mesa de Senos')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imagen como guía
                Image.asset('assets/diagrama_completo.png'),
                const SizedBox(height: 24),
                
                // Campos de texto con claves
                _buildTextField('Ángulo en decimales', angleController, 'Angle'),
                _buildTextField('Length (L)', lengthController),
                _buildTextField('Height (H)', heightController),
                _buildTextField('Distancia entre centros', distanceController),
                _buildTextField('G (GROSOR BASE MESA DE SENOS)', gController, 'G'),
                _buildTextField('G1 (GROSOR MESA DE SENOS)', g1Controller, 'G1'),
                _buildTextField('V (VERTICE DE PIVOTEO)', vController, 'V'),
                _buildTextField('GB (GAGE BLOCK)', gbController, 'GB'),
                _buildTextField('Ø (DIAMETRO DE GAGE PIN)', gagePinController, 'GagePin'),
                
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus(); // Ocultar teclado
                    _performCalculations();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Calcular'),
                ),
                const SizedBox(height: 24),
                _buildResultsCard(), // Widget para mostrar resultados
              ],
            ),
          ),
          // --- Capa para dibujar la flecha ---
          CustomPaint(
            painter: ArrowPainter(
              activeFieldKey: _activeFieldKey,
              fieldKeys: _fieldKeys,
              targetPoints: _targetPoints,
            ),
            child: Container(),
          ),
        ],
      ),
    );
  }
  
  // Widget para construir un campo de texto con su clave y nodo de foco
  Widget _buildTextField(String label, TextEditingController controller, [String? key]) {
    return Padding(
      key: key != null ? _fieldKeys[key] : null,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: key != null ? _focusNodes[key] : null,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
  
  // Widget para mostrar los resultados de forma ordenada
  Widget _buildResultsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resultados', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 20),
            _buildResultRow('Resultado A', resultA),
            _buildResultRow('Resultado F', resultF),
            _buildResultRow('Resultado B', resultB),
            _buildResultRow('Resultado Z', resultZ),
            _buildResultRow('Resultado Y', resultY),
            const Divider(height: 20),
            _buildHighlightResult('Planer Gage Stack (A-B)', planerGageStackAB),
            _buildHighlightResult('DISTANCIA TOTAL (OR)', distanciaTotalOR),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value.isNaN || value.isInfinite ? 'Error' : value.toStringAsFixed(4),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHighlightResult(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
          Text(
            value.isNaN || value.isInfinite ? 'Error' : value.toStringAsFixed(4),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Limpiar controladores y nodos de foco
    angleController.dispose(); lengthController.dispose(); heightController.dispose();
    distanceController.dispose(); gController.dispose(); g1Controller.dispose();
    vController.dispose(); gbController.dispose(); gagePinController.dispose();
    _focusNodes.forEach((key, node) => node.dispose());
    super.dispose();
  }
}


// --- Clase para Dibujar la Flecha en el Canvas ---
class ArrowPainter extends CustomPainter {
  final String? activeFieldKey;
  final Map<String, GlobalKey> fieldKeys;
  final Map<String, Offset> targetPoints;

  ArrowPainter({
    required this.activeFieldKey,
    required this.fieldKeys,
    required this.targetPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activeFieldKey == null) return;

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Obtener la caja de renderizado del campo de texto activo
    final RenderBox? fieldBox =
        fieldKeys[activeFieldKey]!.currentContext?.findRenderObject() as RenderBox?;
    
    if (fieldBox == null) return;
    
    // Calcular el punto de inicio (desde el borde del campo de texto)
    final fieldPosition = fieldBox.localToGlobal(Offset.zero);
    final startPoint = Offset(fieldPosition.dx + fieldBox.size.width / 2, fieldPosition.dy);

    // Obtener el punto de destino
    final endPoint = targetPoints[activeFieldKey]!;

    // Dibujar la línea
    canvas.drawLine(startPoint, endPoint, paint);

    // Dibujar la punta de la flecha
    final path = Path();
    final angle = atan2(endPoint.dy - startPoint.dy, endPoint.dx - startPoint.dx);
    path.moveTo(endPoint.dx - 12 * cos(angle - 0.4), endPoint.dy - 12 * sin(angle - 0.4));
    path.lineTo(endPoint.dx, endPoint.dy);
    path.lineTo(endPoint.dx - 12 * cos(angle + 0.4), endPoint.dy - 12 * sin(angle + 0.4));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ArrowPainter oldDelegate) {
    // Redibujar solo si el campo activo ha cambiado
    return oldDelegate.activeFieldKey != activeFieldKey;
  }
}

