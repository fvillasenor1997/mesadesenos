import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:math';

// --- 1. Modelo de Datos ---
// Representa una mesa de senos con sus propiedades.
class SineBar {
  final int? id;
  final String name;
  final double grosorBaseG;
  final double grosorMesaG1;
  final double verticePivoteoV;
  final double distanciaCentrosL;

  SineBar({
    this.id,
    required this.name,
    required this.grosorBaseG,
    required this.grosorMesaG1,
    required this.verticePivoteoV,
    required this.distanciaCentrosL,
  });

  // Convierte un objeto SineBar a un Map para la base de datos.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'grosorBaseG': grosorBaseG,
      'grosorMesaG1': grosorMesaG1,
      'verticePivoteoV': verticePivoteoV,
      'distanciaCentrosL': distanciaCentrosL,
    };
  }
}

// --- 2. Gestor de la Base de Datos ---
// Clase para manejar todas las operaciones de SQLite.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sine_bars.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sine_bars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        grosorBaseG REAL NOT NULL,
        grosorMesaG1 REAL NOT NULL,
        verticePivoteoV REAL NOT NULL,
        distanciaCentrosL REAL NOT NULL
      )
    ''');
  }

  Future<void> insertSineBar(SineBar sineBar) async {
    final db = await instance.database;
    await db.insert('sine_bars', sineBar.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SineBar>> getSineBars() async {
    final db = await instance.database;
    final maps = await db.query('sine_bars', orderBy: 'name ASC');
    return List.generate(maps.length, (i) {
      return SineBar(
        id: maps[i]['id'] as int,
        name: maps[i]['name'] as String,
        grosorBaseG: maps[i]['grosorBaseG'] as double,
        grosorMesaG1: maps[i]['grosorMesaG1'] as double,
        verticePivoteoV: maps[i]['verticePivoteoV'] as double,
        distanciaCentrosL: maps[i]['distanciaCentrosL'] as double,
      );
    });
  }

  Future<void> deleteSineBar(int id) async {
    final db = await instance.database;
    await db.delete('sine_bars', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

// --- 3. Aplicación Principal ---
void main() => runApp(const MyApp());

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
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      debugShowCheckedModeBanner: false,
      home: const SineBarCalculatorScreen(),
    );
  }
}

// --- 4. Pantalla Principal de la Calculadora ---
class SineBarCalculatorScreen extends StatefulWidget {
  const SineBarCalculatorScreen({super.key});

  @override
  State<SineBarCalculatorScreen> createState() => _SineBarCalculatorScreenState();
}

class _SineBarCalculatorScreenState extends State<SineBarCalculatorScreen> {
  final _hController = TextEditingController();
  final _lController = TextEditingController();
  final _gController = TextEditingController();
  final _g1Controller = TextEditingController();
  final _vController = TextEditingController();
  final _gbController = TextEditingController();
  final _gagePinController = TextEditingController();
  final _angleController = TextEditingController();
  
  final Map<String, FocusNode> _focusNodes = {
    'H': FocusNode(), 'L': FocusNode(), 'G': FocusNode(), 'G1': FocusNode(),
    'V': FocusNode(), 'GB': FocusNode(), 'GagePin': FocusNode(), 'Angle': FocusNode(),
  };

  String? _activeField;
  static const Map<String, Offset> _markerPositions = {
    'G': Offset(25, 225), 'G1': Offset(25, 170), 'V': Offset(105, 130),
    'GB': Offset(310, 115), 'GagePin': Offset(225, 160), 'Angle': Offset(375, 215),
    'L': Offset(280, 255), // Añadida posición para 'L'
  };

  double _resultA = 0.0, _resultF = 0.0, _resultB = 0.0, _planerGageStack = 0.0;
  double _resultZ = 0.0, _resultY = 0.0, _distanciaTotalOR = 0.0;
  
  List<SineBar> _sineBars = [];
  SineBar? _selectedSineBar;

  @override
  void initState() {
    super.initState();
    _refreshSineBars();
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        setState(() {
          _activeField = node.hasFocus ? key : null;
        });
      });
    });
  }

  Future<void> _refreshSineBars() async {
    final data = await DatabaseHelper.instance.getSineBars();
    setState(() {
      _sineBars = data;
      // Si el seleccionado fue borrado, deselecciónalo.
      if (_selectedSineBar != null && !_sineBars.any((sb) => sb.id == _selectedSineBar!.id)) {
        _selectedSineBar = null;
      }
    });
  }

  void _performCalculations() {
    final h = double.tryParse(_hController.text) ?? 0.0;
    final l = double.tryParse(_lController.text) ?? 0.0;
    final g = double.tryParse(_gController.text) ?? 0.0;
    final g1 = double.tryParse(_g1Controller.text) ?? 0.0;
    final v = double.tryParse(_vController.text) ?? 0.0;
    final gb = double.tryParse(_gbController.text) ?? 0.0;
    final gagePin = double.tryParse(_gagePinController.text) ?? 0.0;
    final angleDeg = double.tryParse(_angleController.text) ?? 0.0;
    final angleRad = angleDeg * (pi / 180.0);

    setState(() {
      _resultA = (sin(angleRad) * l) + (cos(angleRad) * h);
      _resultF = ((cos((45 * pi / 180.0) - angleRad) * sin(45 * pi / 180.0)) + 0.5);
      _resultB = _resultF * gagePin;
      _planerGageStack = _resultA - _resultB;

      _resultZ = (sin(angleRad) + cos(angleRad) - 1 != 0)
          ? (tan(angleRad) * gb) + (gagePin * sin(angleRad)) / (sin(angleRad) + cos(angleRad) - 1)
          : double.infinity;
      _resultY = (_resultZ * cos(angleRad)) + (g1 * cos(angleRad)) - (v * cos(angleRad));
      _distanciaTotalOR = g + _resultY;
    });
  }

  Widget _buildTextField({ required TextEditingController controller, required String label, required FocusNode focusNode }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration( labelText: label ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
  
  void _onSineBarSelected(SineBar? sineBar) {
    setState(() {
      _selectedSineBar = sineBar;
      if (sineBar != null) {
        _gController.text = sineBar.grosorBaseG.toString();
        _g1Controller.text = sineBar.grosorMesaG1.toString();
        _vController.text = sineBar.verticePivoteoV.toString();
        _lController.text = sineBar.distanciaCentrosL.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de Mesa de Senos')),
      body: SingleChildScrollView(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDiagram(),
                const SizedBox(height: 24),
                _buildSineBarSelector(),
                const SizedBox(height: 24),
                _buildDataInputs(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _performCalculations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Calcular', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 24),
                _buildResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets de construcción de UI ---

  Widget _buildDiagram() => AspectRatio(
    aspectRatio: 1.25,
    child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(size: Size.infinite, painter: DiagramPainter()),
          ),
        ),
        if (_activeField != null && _markerPositions.containsKey(_activeField))
          Positioned(
            left: _markerPositions[_activeField]!.dx,
            top: _markerPositions[_activeField]!.dy,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ),
      ],
    ),
  );
  
  Widget _buildSineBarSelector() => Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleccionar Mesa de Senos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<SineBar>(
            value: _selectedSineBar,
            hint: const Text('Seleccione una mesa guardada...'),
            isExpanded: true,
            items: _sineBars.map((SineBar bar) {
              return DropdownMenuItem<SineBar>(
                value: bar,
                child: Text(bar.name),
              );
            }).toList(),
            onChanged: _onSineBarSelected,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Gestionar Mesas'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageSineBarsScreen()),
                );
                _refreshSineBars(); // Actualiza la lista al regresar.
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDataInputs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Entradas de Datos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.indigo)),
      const SizedBox(height: 16),
      _buildTextField(controller: _angleController, label: 'Ángulo (<)', focusNode: _focusNodes['Angle']!),
      _buildTextField(controller: _gController, label: 'Grosor Base (G)', focusNode: _focusNodes['G']!),
      _buildTextField(controller: _g1Controller, label: 'Grosor Mesa (G1)', focusNode: _focusNodes['G1']!),
      _buildTextField(controller: _vController, label: 'Vértice de Pivoteo (V)', focusNode: _focusNodes['V']!),
      _buildTextField(controller: _gbController, label: 'Gage Block (GB)', focusNode: _focusNodes['GB']!),
      _buildTextField(controller: _gagePinController, label: 'Diámetro de Gage Pin (Ø)', focusNode: _focusNodes['GagePin']!),
      _buildTextField(controller: _hController, label: 'Altura (H)', focusNode: _focusNodes['H']!),
      _buildTextField(controller: _lController, label: 'Distancia Centros (L)', focusNode: _focusNodes['L']!),
    ],
  );

  Widget _buildResults() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Resultados', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.indigo)),
      const Divider(thickness: 1, height: 32),
      _buildResultRow('Resultado Y:', _resultY),
      Card( color: Colors.indigo[50], child: Padding(padding: const EdgeInsets.all(12.0), child: _buildResultRow('DISTANCIA TOTAL (OR):', _distanciaTotalOR))),
      const Divider(thickness: 1, height: 32),
      _buildResultRow('Resultado A:', _resultA),
      _buildResultRow('Resultado B:', _resultB),
      Card( color: Colors.blue[50], child: Padding(padding: const EdgeInsets.all(12.0), child: _buildResultRow('Planer Gage Stack (A-B):', _planerGageStack))),
    ],
  );

  Widget _buildResultRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
          Text(
            value.isNaN || value.isInfinite ? 'Error' : value.toStringAsFixed(4),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNodes.forEach((_, node) => node.dispose());
    // ... dispose other controllers
    super.dispose();
  }
}

// --- 5. Pantalla para Gestionar Mesas de Senos ---
class ManageSineBarsScreen extends StatefulWidget {
  const ManageSineBarsScreen({super.key});

  @override
  _ManageSineBarsScreenState createState() => _ManageSineBarsScreenState();
}

class _ManageSineBarsScreenState extends State<ManageSineBarsScreen> {
  List<SineBar> _sineBars = [];

  @override
  void initState() {
    super.initState();
    _refreshSineBars();
  }

  Future<void> _refreshSineBars() async {
    final data = await DatabaseHelper.instance.getSineBars();
    setState(() {
      _sineBars = data;
    });
  }

  void _showAddSineBarDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final gController = TextEditingController();
    final g1Controller = TextEditingController();
    final vController = TextEditingController();
    final lController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Mesa de Senos'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre Descriptivo'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                TextFormField(controller: gController, decoration: const InputDecoration(labelText: 'Grosor Base (G)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                TextFormField(controller: g1Controller, decoration: const InputDecoration(labelText: 'Grosor Mesa (G1)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                TextFormField(controller: vController, decoration: const InputDecoration(labelText: 'Vértice Pivoteo (V)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                TextFormField(controller: lController, decoration: const InputDecoration(labelText: 'Distancia Centros (L)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Requerido' : null),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newBar = SineBar(
                  name: nameController.text,
                  grosorBaseG: double.parse(gController.text),
                  grosorMesaG1: double.parse(g1Controller.text),
                  verticePivoteoV: double.parse(vController.text),
                  distanciaCentrosL: double.parse(lController.text),
                );
                await DatabaseHelper.instance.insertSineBar(newBar);
                _refreshSineBars();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Mesas de Senos')),
      body: _sineBars.isEmpty
          ? const Center(child: Text('No hay mesas guardadas. Presiona + para añadir una.'))
          : ListView.builder(
              itemCount: _sineBars.length,
              itemBuilder: (context, index) {
                final bar = _sineBars[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(bar.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('L: ${bar.distanciaCentrosL}, G: ${bar.grosorBaseG}, G1: ${bar.grosorMesaG1}, V: ${bar.verticePivoteoV}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await DatabaseHelper.instance.deleteSineBar(bar.id!);
                        _refreshSineBars();
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSineBarDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- 6. Pintor del Diagrama (Sin cambios) ---
class DiagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.black..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final redLinePaint = Paint()..color = Colors.red..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final greenFillPaint = Paint()..color = Colors.green.withOpacity(0.5)..style = PaintingStyle.fill;
    final blueFillPaint = Paint()..color = Colors.cyan.withOpacity(0.5)..style = PaintingStyle.fill;

    void drawText(String text, Offset position, {Color color = Colors.black, double fontSize = 14.0}) {
      final textSpan = TextSpan(style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold), text: text);
      final textPainter = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
      textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    canvas.drawRect(Rect.fromLTWH(50, 200, 120, 60), linePaint);
    final topRect = Rect.fromLTWH(80, 150, 60, 50);
    canvas.drawRect(topRect, linePaint);
    canvas.drawRect(topRect, greenFillPaint);
    canvas.drawCircle(const Offset(110, 200), 10, linePaint);
    canvas.drawLine(const Offset(110, 190), const Offset(110, 210), linePaint);
    canvas.drawLine(const Offset(100, 200), const Offset(120, 200), linePaint);
    drawText('G', const Offset(30, 230), color: Colors.red);
    drawText('G1', const Offset(30, 175), color: Colors.red);
    drawText('V', const Offset(110, 135), color: Colors.red);
    canvas.drawLine(const Offset(40, 230), const Offset(50, 230), redLinePaint);
    canvas.drawLine(const Offset(40, 175), const Offset(80, 175), redLinePaint);
    canvas.drawLine(const Offset(110, 145), const Offset(110, 150), redLinePaint);
    drawText('Ø', const Offset(205, 170), color: Colors.red);
    drawText('GAGE PIN', const Offset(205, 185), fontSize: 10);
    canvas.drawCircle(const Offset(180, 175), 10, linePaint);

    canvas.drawRect(Rect.fromLTWH(250, 230, 120, 60), linePaint);
    canvas.drawCircle(const Offset(280, 230), 10, linePaint);
    canvas.drawLine(const Offset(280, 220), const Offset(280, 240), linePaint);
    canvas.drawLine(const Offset(270, 230), const Offset(290, 230), linePaint);
    
    canvas.save();
    canvas.translate(280, 230);
    canvas.rotate(-0.35);
    final angledRect = Rect.fromLTWH(0, -50, 60, 50);
    canvas.drawRect(angledRect, linePaint);
    canvas.drawRect(angledRect, blueFillPaint);
    canvas.restore();

    canvas.drawCircle(const Offset(340, 150), 10, linePaint);
    final Path gageBlockPath = Path()..moveTo(310, 175)..lineTo(370, 145)..lineTo(378, 153)..lineTo(318, 183)..close();
    canvas.drawPath(gageBlockPath, linePaint);
    canvas.drawPath(gageBlockPath, greenFillPaint);
    
    drawText('GB', const Offset(300, 120), color: Colors.red);
    canvas.drawLine(const Offset(300, 130), const Offset(320, 170), redLinePaint);
    drawText('Ø', const Offset(360, 130), color: Colors.red);
    drawText('GAGE PIN', const Offset(360, 115), fontSize: 10);
    drawText('Y', const Offset(250, 160), color: Colors.red);
    drawText('A', const Offset(250, 190), color: Colors.red);
    drawText('OR', const Offset(230, 230), color: Colors.red);
    drawText('<', const Offset(380, 220), color: Colors.red, fontSize: 20);
    drawText('L', const Offset(320, 255), color: Colors.red);
    canvas.drawLine(const Offset(280, 230), const Offset(370, 230), redLinePaint);
    canvas.drawArc(Rect.fromCircle(center: const Offset(280, 230), radius: 25), 0, -0.35, false, redLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

