import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
// SOLUCIÓN: Se importa el paquete 'path' con el prefijo 'p' para evitar conflictos.
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'g': g,
      'g1': g1,
      'v': v,
    };
  }

  factory MesaDeSenos.fromMap(Map<String, dynamic> map) {
    return MesaDeSenos(
      id: map['id'],
      nombre: map['nombre'],
      g: map['g'],
      g1: map['g1'],
      v: map['v'],
    );
  }
}

// --- Gestor de la Base de Datos SQLite ---
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
    // SOLUCIÓN: Se usa el prefijo 'p' para llamar a la función join().
    String path = p.join(dbPath, 'mesas.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mesas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            g REAL NOT NULL,
            g1 REAL NOT NULL,
            v REAL NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertMesa(MesaDeSenos mesa) async {
    final db = await database;
    return await db.insert('mesas', mesa.toMap());
  }

  Future<List<MesaDeSenos>> getMesas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('mesas');
    return List.generate(maps.length, (i) {
      return MesaDeSenos.fromMap(maps[i]);
    });
  }

  Future<int> deleteMesa(int id) async {
    final db = await database;
    return await db.delete('mesas', where: 'id = ?', whereArgs: [id]);
  }
}

// --- Inicio de la App ---
void main() {
  runApp(const MyApp());
}

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

// --- Pantalla Principal ---
class SineBarCalculatorScreen extends StatefulWidget {
  const SineBarCalculatorScreen({super.key});

  @override
  State<SineBarCalculatorScreen> createState() => _SineBarCalculatorScreenState();
}

class _SineBarCalculatorScreenState extends State<SineBarCalculatorScreen> {
  final _hController = TextEditingController();
  final _lController = TextEditingController();
  final _gbController = TextEditingController();
  final _gagePinController = TextEditingController();
  final _angleController = TextEditingController();

  final _gController = TextEditingController();
  final _g1Controller = TextEditingController();
  final _vController = TextEditingController();

  List<MesaDeSenos> _mesas = [];
  MesaDeSenos? _selectedMesa;

  double _resultA = 0.0, _resultF = 0.0, _resultB = 0.0, _planerGageStack = 0.0;
  double _resultZ = 0.0, _resultY = 0.0, _distanciaTotalOR = 0.0;
  
  @override
  void initState() {
    super.initState();
    _refreshMesas();
  }
  
  void _refreshMesas() async {
    final data = await DatabaseHelper().getMesas();
    setState(() {
      _mesas = data;
      if (_mesas.isNotEmpty && _selectedMesa == null) {
        _selectedMesa = _mesas.first;
        _loadMesaData(_selectedMesa!);
      } else if (_mesas.isEmpty) {
        _selectedMesa = null;
        _clearMesaData();
      }
    });
  }

  void _loadMesaData(MesaDeSenos mesa) {
    _gController.text = mesa.g.toString();
    _g1Controller.text = mesa.g1.toString();
    _vController.text = mesa.v.toString();
  }

  void _clearMesaData() {
     _gController.clear();
     _g1Controller.clear();
     _vController.clear();
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
      final angle45Rad = 45 * (pi / 180.0);
      _resultF = ((cos(angle45Rad - angleRad) * sin(angle45Rad)) + 0.5);
      _resultB = _resultF * gagePin;
      _planerGageStack = _resultA - _resultB;

      if (sin(angleRad) + cos(angleRad) - 1 != 0) {
        _resultZ = (tan(angleRad) * gb) + (gagePin * sin(angleRad)) / (sin(angleRad) + cos(angleRad) - 1);
      } else {
        _resultZ = double.infinity;
      }
      _resultY = (_resultZ * cos(angleRad)) + (g1 * cos(angleRad)) - (v * cos(angleRad));
      _distanciaTotalOR = g + _resultY;
    });
  }
  
  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, fillColor: enabled ? Colors.grey[200] : Colors.grey[350]),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: enabled,
      ),
    );
  }

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

  void _navigateToManageMesas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageMesasScreen()),
    );
    _refreshMesas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de Mesa de Senos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToManageMesas,
            tooltip: 'Gestionar Mesas',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Seleccionar Mesa de Senos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_mesas.isNotEmpty)
                DropdownButtonFormField<MesaDeSenos>(
                  value: _selectedMesa,
                  items: _mesas.map((mesa) {
                    return DropdownMenuItem<MesaDeSenos>(
                      value: mesa,
                      child: Text(mesa.nombre),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMesa = value;
                      if (value != null) {
                        _loadMesaData(value);
                      }
                    });
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                )
              else
                Text(
                  'No hay mesas guardadas. Añade una desde el menú de ajustes.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const Divider(height: 32),
              
              Text('Entradas de Datos', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.indigo)),
              _buildTextField(controller: _gController, label: 'Grosor Base (G)', enabled: false),
              _buildTextField(controller: _g1Controller, label: 'Grosor Mesa (G1)', enabled: false),
              _buildTextField(controller: _vController, label: 'Vértice de Pivoteo (V)', enabled: false),
              _buildTextField(controller: _angleController, label: 'Ángulo (<)'),
              _buildTextField(controller: _gbController, label: 'Gage Block (GB)'),
              _buildTextField(controller: _gagePinController, label: 'Diámetro de Gage Pin (Ø)'),
              _buildTextField(controller: _hController, label: 'Altura (H)'),
              _buildTextField(controller: _lController, label: 'Distancia Centros (L)'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _performCalculations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('Calcular'),
              ),
              const SizedBox(height: 24),
              Text('Resultados', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.indigo)),
              const Divider(thickness: 1, height: 32),
              _buildResultRow('Resultado Y:', _resultY),
              Card(
                color: Colors.indigo[50],
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildResultRow('DISTANCIA TOTAL (OR):', _distanciaTotalOR)),
              ),
              const Divider(thickness: 1, height: 32),
              _buildResultRow('Resultado A:', _resultA),
              _buildResultRow('Resultado B:', _resultB),
              Card(
                color: Colors.blue[50],
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildResultRow('Planer Gage Stack (A-B):', _planerGageStack)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Pantalla para Gestionar Mesas ---
class ManageMesasScreen extends StatefulWidget {
  const ManageMesasScreen({super.key});

  @override
  State<ManageMesasScreen> createState() => _ManageMesasScreenState();
}

class _ManageMesasScreenState extends State<ManageMesasScreen> {
  late Future<List<MesaDeSenos>> _mesasFuture;

  @override
  void initState() {
    super.initState();
    _refreshMesaList();
  }

  void _refreshMesaList() {
    setState(() {
      _mesasFuture = DatabaseHelper().getMesas();
    });
  }

  void _showAddMesaDialog() {
    final nameController = TextEditingController();
    final gController = TextEditingController();
    final g1Controller = TextEditingController();
    final vController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir Nueva Mesa de Senos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(controller: gController, decoration: const InputDecoration(labelText: 'Grosor Base (G)'), keyboardType: TextInputType.number),
                TextField(controller: g1Controller, decoration: const InputDecoration(labelText: 'Grosor Mesa (G1)'), keyboardType: TextInputType.number),
                TextField(controller: vController, decoration: const InputDecoration(labelText: 'Vértice de Pivoteo (V)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final newMesa = MesaDeSenos(
                  nombre: nameController.text,
                  g: double.tryParse(gController.text) ?? 0.0,
                  g1: double.tryParse(g1Controller.text) ?? 0.0,
                  v: double.tryParse(vController.text) ?? 0.0,
                );
                await DatabaseHelper().insertMesa(newMesa);
                Navigator.of(context).pop();
                _refreshMesaList();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Mesas'),
      ),
      body: FutureBuilder<List<MesaDeSenos>>(
        future: _mesasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay mesas guardadas.'));
          }
          final mesas = snapshot.data!;
          return ListView.builder(
            itemCount: mesas.length,
            itemBuilder: (context, index) {
              final mesa = mesas[index];
              return ListTile(
                title: Text(mesa.nombre),
                subtitle: Text('G: ${mesa.g}, G1: ${mesa.g1}, V: ${mesa.v}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await DatabaseHelper().deleteMesa(mesa.id!);
                    _refreshMesaList();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMesaDialog,
        child: const Icon(Icons.add),
        tooltip: 'Añadir Mesa',
      ),
    );
  }
}

