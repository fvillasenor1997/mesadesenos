import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:math';

// --- Modelo de Datos para la Mesa de Senos ---
class MesaDeSenos {
  int? id;
  String nombre;
  double g;
  double g1;
  double v;

  MesaDeSenos({
    this.id,
    required this.nombre,
    required this.g,
    required this.g1,
    required this.v,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'g': g,
        'g1': g1,
        'v': v,
      };

  factory MesaDeSenos.fromMap(Map<String, dynamic> map) => MesaDeSenos(
        id: map['id'],
        nombre: map['nombre'],
        g: map['g'],
        g1: map['g1'],
        v: map['v'],
      );
}

// --- Gestor de la Base de Datos SQLite (Singleton) ---
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'mesas_v2.db');
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
          CREATE TABLE mesas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL UNIQUE,
            g REAL NOT NULL,
            g1 REAL NOT NULL,
            v REAL NOT NULL
          )
        ''');
    });
  }

  Future<int> insertMesa(MesaDeSenos mesa) async {
    final db = await database;
    return await db.insert('mesas', mesa.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MesaDeSenos>> getMesas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('mesas');
    return List.generate(maps.length, (i) => MesaDeSenos.fromMap(maps[i]));
  }

  Future<int> deleteMesa(int id) async {
    final db = await database;
    return await db.delete('mesas', where: 'id = ?', whereArgs: [id]);
  }
}

// --- Punto de entrada de la aplicación ---
void main() {
  // Asegura que los bindings de Flutter estén inicializados antes de usar plugins.
  WidgetsFlutterBinding.ensureInitialized();
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
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SineBarCalculatorScreen(),
    );
  }
}

// --- Pantalla Principal de la Calculadora ---
class SineBarCalculatorScreen extends StatefulWidget {
  const SineBarCalculatorScreen({super.key});

  @override
  State<SineBarCalculatorScreen> createState() => _SineBarCalculatorScreenState();
}

class _SineBarCalculatorScreenState extends State<SineBarCalculatorScreen> {
  late Future<List<MesaDeSenos>> _loadMesasFuture;
  final dbHelper = DatabaseHelper();
  
  // Controladores y estado de la UI
  final controllers = {
    'Angle': TextEditingController(), 'L': TextEditingController(), 'H': TextEditingController(),
    'Distancia': TextEditingController(), 'G': TextEditingController(), 'G1': TextEditingController(),
    'V': TextEditingController(), 'GB': TextEditingController(), 'GagePin': TextEditingController(),
  };

  final Map<String, GlobalKey> _fieldKeys = {
    'G': GlobalKey(), 'G1': GlobalKey(), 'V': GlobalKey(), 'GB': GlobalKey(),
    'Angle': GlobalKey(), 'GagePin': GlobalKey(),
  };

  final Map<String, FocusNode> _focusNodes = {};
  String? _activeFieldKey;
  
  // --- CAMBIO: Se definen rectángulos para resaltar en lugar de puntos de destino ---
  final Map<String, Rect> _highlightRects = {
    'G': Rect.fromCenter(center: const Offset(190, 240), width: 30, height: 30),
    'G1': Rect.fromCenter(center: const Offset(190, 180), width: 35, height: 30),
    'V': Rect.fromCenter(center: const Offset(230, 150), width: 30, height: 30),
    'GB': Rect.fromCenter(center: const Offset(310, 150), width: 40, height: 30),
    'Angle': Rect.fromCenter(center: const Offset(340, 215), width: 30, height: 30),
    'GagePin': Rect.fromCenter(center: const Offset(280, 150), width: 30, height: 30),
  };

  MesaDeSenos? _selectedMesa;
  Map<String, double> results = {};

  @override
  void initState() {
    super.initState();
    _loadMesasFuture = dbHelper.getMesas();
    _fieldKeys.forEach((key, _) {
      _focusNodes[key] = FocusNode()
        ..addListener(() {
          setState(() {
            _activeFieldKey = (_focusNodes[key]!.hasFocus) ? key : null;
          });
        });
    });
  }
  
  void _performCalculations() {
    double getValue(String key) => double.tryParse(controllers[key]!.text) ?? 0.0;
    
    final angleDeg = getValue('Angle');
    final length = getValue('L');
    final height = getValue('H');
    final g = getValue('G');
    final g1 = getValue('G1');
    final v = getValue('V');
    final gb = getValue('GB');
    final gagePin = getValue('GagePin');

    final angleRad = angleDeg * (pi / 180.0);
    final angle45Rad = 45 * (pi / 180.0);
    
    final resultA = (sin(angleRad) * length) + (cos(angleRad) * height);
    final resultF = ((cos(angle45Rad - angleRad) * sin(angle45Rad)) + 0.5);
    final resultB = resultF * gagePin;
    final planerGageStackAB = resultA - resultB;
    
    final denominatorZ = sin(angleRad) + cos(angleRad) - 1;
    final resultZ = (denominatorZ != 0)
        ? (tan(angleRad) * gb) + (gagePin * sin(angleRad)) / denominatorZ
        : double.infinity;
    
    final resultY = (resultZ * cos(angleRad)) + (g1 * cos(angleRad)) - (v * cos(angleRad));
    final distanciaTotalOR = g + resultY;
    
    setState(() {
      results = {
        'A': resultA, 'F': resultF, 'B': resultB, 'Z': resultZ, 'Y': resultY,
        'PlanerGageStack': planerGageStackAB, 'DistanciaTotal': distanciaTotalOR,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Mesa de Senos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gestionar Mesas',
            onPressed: () async {
              await _showManageMesasDialog();
              setState(() {
                _loadMesasFuture = dbHelper.getMesas();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<MesaDeSenos>>(
        future: _loadMesasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar la base de datos: ${snapshot.error}"));
          }
          
          final mesas = snapshot.data ?? [];
          if (mesas.isNotEmpty && _selectedMesa == null) {
            _selectedMesa = mesas.first;
            _updateControllersFromMesa(_selectedMesa!);
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/diagrama_completo.png'),
                    const SizedBox(height: 16),
                    _buildMesaSelector(mesas),
                    const Divider(height: 24),
                    _buildTextField('Ángulo en decimales', 'Angle'),
                    _buildTextField('Length (L)', 'L'),
                    _buildTextField('Height (H)', 'H'),
                    _buildTextField('G (GROSOR BASE)', 'G', isEnabled: false),
                    _buildTextField('G1 (GROSOR MESA)', 'G1', isEnabled: false),
                    _buildTextField('V (VERTICE)', 'V', isEnabled: false),
                    _buildTextField('GB (GAGE BLOCK)', 'GB'),
                    _buildTextField('Ø (DIAMETRO GAGE PIN)', 'GagePin'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _performCalculations();
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Calcular', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(height: 24),
                    _buildResultsCard(),
                  ],
                ),
              ),
              // --- CAMBIO: Se usa el nuevo HighlightPainter en lugar de ArrowPainter ---
              CustomPaint(
                painter: HighlightPainter(_activeFieldKey, _highlightRects),
                child: Container(),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Widgets Auxiliares ---
  Widget _buildMesaSelector(List<MesaDeSenos> mesas) {
    return DropdownButtonFormField<MesaDeSenos>(
      value: _selectedMesa,
      decoration: const InputDecoration(labelText: 'Mesa de Senos Seleccionada'),
      items: mesas.map((mesa) => DropdownMenuItem(value: mesa, child: Text(mesa.nombre))).toList(),
      onChanged: (mesa) {
        if (mesa == null) return;
        setState(() {
          _selectedMesa = mesa;
          _updateControllersFromMesa(mesa);
        });
      },
    );
  }
  
  void _updateControllersFromMesa(MesaDeSenos mesa) {
      controllers['G']!.text = mesa.g.toString();
      controllers['G1']!.text = mesa.g1.toString();
      controllers['V']!.text = mesa.v.toString();
  }

  Widget _buildTextField(String label, String key, {bool isEnabled = true}) {
    return Padding(
      key: _fieldKeys[key],
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controllers[key],
        focusNode: _focusNodes[key],
        decoration: InputDecoration(labelText: label, fillColor: isEnabled ? Colors.grey[200] : Colors.grey[350]),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: isEnabled,
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resultados', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 20),
            _buildResultRow('Resultado A', results['A']),
            _buildResultRow('Resultado Y', results['Y']),
            const Divider(height: 20),
            _buildHighlightResult('Planer Gage Stack', results['PlanerGageStack']),
            _buildHighlightResult('DISTANCIA TOTAL', results['DistanciaTotal']),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(String label, double? value) {
     final valStr = (value == null || value.isNaN || value.isInfinite) ? 'Error' : value.toStringAsFixed(4);
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [ Text(label), Text(valStr, style: const TextStyle(fontWeight: FontWeight.w500)) ],
       ),
     );
  }

  Widget _buildHighlightResult(String label, double? value) {
    final valStr = (value == null || value.isNaN || value.isInfinite) ? 'Error' : value.toStringAsFixed(4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
          Text(valStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
        ],
      ),
    );
  }
  
  Future<void> _showManageMesasDialog() async {
    return showDialog(context: context, builder: (context) => const ManageMesasDialog());
  }

  @override
  void dispose() {
    controllers.forEach((_, controller) => controller.dispose());
    _focusNodes.forEach((_, node) => node.dispose());
    super.dispose();
  }
}

// --- Diálogo para Añadir/Eliminar Mesas ---
class ManageMesasDialog extends StatefulWidget {
  const ManageMesasDialog({super.key});
  @override
  State<ManageMesasDialog> createState() => _ManageMesasDialogState();
}

class _ManageMesasDialogState extends State<ManageMesasDialog> {
  late Future<List<MesaDeSenos>> _mesasFuture;
  final dbHelper = DatabaseHelper();
  final nameCtrl = TextEditingController(), gCtrl = TextEditingController(), g1Ctrl = TextEditingController(), vCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mesasFuture = dbHelper.getMesas();
  }

  void _addMesa() async {
    final newMesa = MesaDeSenos(
      nombre: nameCtrl.text,
      g: double.tryParse(gCtrl.text) ?? 0.0,
      g1: double.tryParse(g1Ctrl.text) ?? 0.0,
      v: double.tryParse(vCtrl.text) ?? 0.0,
    );
    if (newMesa.nombre.isNotEmpty) {
      await dbHelper.insertMesa(newMesa);
      nameCtrl.clear(); gCtrl.clear(); g1Ctrl.clear(); vCtrl.clear();
      setState(() { _mesasFuture = dbHelper.getMesas(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gestionar Mesas de Senos'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: gCtrl, decoration: const InputDecoration(labelText: 'G'), keyboardType: TextInputType.number),
            TextField(controller: g1Ctrl, decoration: const InputDecoration(labelText: 'G1'), keyboardType: TextInputType.number),
            TextField(controller: vCtrl, decoration: const InputDecoration(labelText: 'V'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _addMesa, child: const Text('Añadir / Actualizar Mesa')),
            const Divider(),
            Expanded(child: _buildMesaList()),
          ],
        ),
      ),
      actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')) ],
    );
  }

  Widget _buildMesaList() {
    return FutureBuilder<List<MesaDeSenos>>(
      future: _mesasFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          shrinkWrap: true,
          children: snapshot.data!.map((mesa) => ListTile(
            title: Text(mesa.nombre),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await dbHelper.deleteMesa(mesa.id!);
                setState(() { _mesasFuture = dbHelper.getMesas(); });
              },
            ),
          )).toList(),
        );
      },
    );
  }
}

// --- CAMBIO: Se reemplaza ArrowPainter por HighlightPainter ---
class HighlightPainter extends CustomPainter {
  final String? activeFieldKey;
  final Map<String, Rect> highlightRects;

  HighlightPainter(this.activeFieldKey, this.highlightRects);

  @override
  void paint(Canvas canvas, Size size) {
    if (activeFieldKey == null) return;

    final paint = Paint()
      ..color = Colors.red.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final rectToDraw = highlightRects[activeFieldKey];
    if (rectToDraw != null) {
      // Dibuja un rectángulo redondeado para un look más suave
      canvas.drawRRect(
        RRect.fromRectAndRadius(rectToDraw, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return oldDelegate.activeFieldKey != activeFieldKey;
  }
}

