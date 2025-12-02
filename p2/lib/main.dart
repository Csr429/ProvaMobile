import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

const Color primaryColor = Colors.lightBlue;
const Color secondaryColor = Colors.cyan;
const Color iceBlueBackground = Color(0xFFF0F8FF);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

Future<Database> createDatabase() async {
  final databasePath = await getDatabasesPath();
  final dbPath = path.join(databasePath, '202310010e202310105.db');

  print('DB DIR: $databasePath');
  print('DB PATH: $dbPath');

  return openDatabase(
    dbPath,
    version: 2,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE tarefas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          titulo TEXT,
          descricao TEXT,
          prioridade TEXT,
          status TEXT,
          dataAgendamento TEXT,
          criadoEm TEXT
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE tarefas ADD COLUMN status TEXT');
        await db.execute(
          'ALTER TABLE tarefas ADD COLUMN dataAgendamento TEXT',
        );
        await db.execute('DROP TABLE IF EXISTS tarefas_old');
      }
    },
  );
}

String tarefaToJson(Map<String, dynamic> tarefa) {
  return jsonEncode(tarefa);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro de Tarefas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: iceBlueBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const TarefasPage(),
    );
  }
}

class TarefasPage extends StatefulWidget {
  const TarefasPage({super.key});

  @override
  State<TarefasPage> createState() => _TarefasPageState();
}

class _TarefasPageState extends State<TarefasPage> {
  Database? db;
  List<Map<String, dynamic>> tarefas = [];

  @override
  void initState() {
    super.initState();
    _openDb();
  }

  Future<void> _openDb() async {
    db = await createDatabase();
    if (mounted) readTarefas();
  }

  Future<void> readTarefas() async {
    if (db == null) return;
    final data = await db!.query(
      'tarefas',
      orderBy:
          'status = "Pendente" ASC, status = "Aguardando" ASC, prioridade DESC, criadoEm DESC',
    );
    if (mounted) setState(() => tarefas = data);
  }

  void _openTarefaForm([Map<String, dynamic>? tarefa]) {
    if (db == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext ctx) => TarefaFormPage(
          db: db!,
          tarefa: tarefa,
        ),
      ),
    ).then((_) => readTarefas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Tarefas')),
      body: tarefas.isEmpty
          ? const Center(child: Text('Nenhuma tarefa cadastrada.'))
          : ListView.builder(
              itemCount: tarefas.length,
              itemBuilder: (context, i) {
                final tarefa = tarefas[i];
                final status = tarefa['status'] ?? 'Pendente';
                IconData icon;
                Color color;

                switch (status) {
                  case 'Resolvido':
                    icon = Icons.check_circle_outline;
                    color = Colors.green;
                    break;
                  case 'Aguardando':
                    icon = Icons.people_alt_outlined;
                    color = Colors.amber;
                    break;
                  case 'Agendamento':
                    icon = Icons.schedule;
                    color = Colors.orange;
                    break;
                  default:
                    icon = Icons.pending;
                    color = Colors.red;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(
                    tarefa['titulo'],
                    style: status == 'Resolvido'
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prioridade: ${tarefa['prioridade'] ?? 'Baixa'}'),
                      Text('Status: $status'),
                      if (tarefa['dataAgendamento'] != null)
                        Text(
                          'Agendado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(tarefa['dataAgendamento']))}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _openTarefaForm(tarefa),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTarefaForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TarefaFormPage extends StatefulWidget {
  final Database db;
  final Map<String, dynamic>? tarefa;

  const TarefaFormPage({super.key, required this.db, this.tarefa});

  @override
  State<TarefaFormPage> createState() => _TarefaFormPageState();
}

class _TarefaFormPageState extends State<TarefaFormPage> {
  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _dataAgendamentoController;
  String _prioridadeSelecionada = 'Baixa';
  String _statusSelecionado = 'Pendente';
  String? _dataCriacao;

  final List<String> _prioridades = ['Baixa', 'Média', 'Alta'];
  final List<String> _statuses = [
    'Pendente',
    'Resolvido',
    'Aguardando',
    'Agendamento',
  ];
  bool get isEditing => widget.tarefa != null;
  bool get showDataAgendamento => _statusSelecionado == 'Agendamento';

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController();
    _descricaoController = TextEditingController();
    _dataAgendamentoController = TextEditingController();

    if (isEditing) {
      _tituloController.text = widget.tarefa!['titulo'] ?? '';
      _descricaoController.text = widget.tarefa!['descricao'] ?? '';
      final prioridade = widget.tarefa!['prioridade'] as String?;
      _prioridadeSelecionada =
          _prioridades.contains(prioridade) ? prioridade! : 'Baixa';
      _statusSelecionado = widget.tarefa!['status'] ?? 'Pendente';
      _dataAgendamentoController.text =
          widget.tarefa!['dataAgendamento'] != null
              ? DateFormat('dd/MM/yyyy HH:mm')
                  .format(DateTime.parse(widget.tarefa!['dataAgendamento']))
              : '';
      _dataCriacao = widget.tarefa!['criadoEm'];
    } else {
      _dataCriacao = DateTime.now().toIso8601String();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _dataAgendamentoController.dispose();
    super.dispose();
  }

  Future<void> _saveTarefa() async {
    String? dataAgendamentoIso;
    if (showDataAgendamento && _dataAgendamentoController.text.isNotEmpty) {
      try {
        final dataHora = DateFormat('dd/MM/yyyy HH:mm')
            .parse(_dataAgendamentoController.text);
        dataAgendamentoIso = dataHora.toIso8601String();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formato de data inválido. Use: dd/MM/yyyy HH:mm'),
          ),
        );
        return;
      }
    }

    final data = {
      'titulo': _tituloController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'prioridade': _prioridadeSelecionada,
      'status': _statusSelecionado,
      'dataAgendamento': dataAgendamentoIso,
      'criadoEm': _dataCriacao ?? DateTime.now().toIso8601String(),
    };

    final json = tarefaToJson(data);
    print('TAREFA JSON: $json');

    if (isEditing && widget.tarefa!['id'] != null) {
      await widget.db.update(
        'tarefas',
        data,
        where: 'id = ?',
        whereArgs: [widget.tarefa!['id']],
      );
    } else {
      await widget.db.insert('tarefas', data);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteTarefa() async {
    if (!isEditing || widget.tarefa!['id'] == null) return;
    await widget.db.delete(
      'tarefas',
      where: 'id = ?',
      whereArgs: [widget.tarefa!['id']],
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatDate(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(isoDate));
    } catch (_) {
      return 'Data inválida';
    }
  }

  List<DropdownMenuItem<String>> _buildPrioridadeItems() {
    return _prioridades
        .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildStatusItems() {
    return _statuses
        .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        actions: isEditing && widget.tarefa!['id'] != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteTarefa,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descricaoController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Prioridade'),
              value: _prioridades.contains(_prioridadeSelecionada)
                  ? _prioridadeSelecionada
                  : null,
              items: _buildPrioridadeItems(),
              onChanged: (String? value) => value != null
                  ? setState(() => _prioridadeSelecionada = value)
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Status'),
              value: _statuses.contains(_statusSelecionado)
                  ? _statusSelecionado
                  : null,
              items: _buildStatusItems(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _statusSelecionado = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _dataAgendamentoController,
                    decoration: const InputDecoration(
                      labelText: 'Data/Hora Agendamento',
                      hintText: 'dd/MM/yyyy HH:mm',
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const Text(
                    'Exemplo: 30/11/2025 14:30',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              crossFadeState: showDataAgendamento
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            const SizedBox(height: 16),
            if (_dataCriacao != null)
              Text(
                'Criado em: ${_formatDate(_dataCriacao!)}',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveTarefa,
              icon: const Icon(Icons.save),
              label:
                  Text(isEditing ? 'Atualizar Tarefa' : 'Salvar Tarefa'),
            ),
            if (isEditing && widget.tarefa!['id'] != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _deleteTarefa,
                icon:
                    const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text(
                  'Excluir Tarefa',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
