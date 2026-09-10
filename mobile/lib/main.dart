import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SmartQApp());
}

class SmartQApp extends StatelessWidget {
  const SmartQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartQ',
      home: const FilasPage(),
    );
  }
}

class FilasPage extends StatefulWidget {
  const FilasPage({super.key});

  @override
  State<FilasPage> createState() => _FilasPageState();
}

class _FilasPageState extends State<FilasPage> {
  final String apiUrl = 'http://localhost:3000';

  List<dynamic> filas = [];
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregarFilas();
  }

  Future<void> carregarFilas() async {
    try {
      final resposta = await http.get(
        Uri.parse('$apiUrl/filas'),
      );

      if (resposta.statusCode != 200) {
        throw Exception('Erro ao buscar filas');
      }

      final dados = jsonDecode(resposta.body);

      setState(() {
        filas = dados;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = 'Erro ao carregar filas';
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartQ'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: carregando
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : erro != null
                ? Center(
                    child: Text(erro!),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Escolha uma fila',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filas.length,
                          itemBuilder: (context, index) {
                            final fila = filas[index];

                            return Card(
                              child: ListTile(
                                title: Text(fila['nome']),
                                subtitle: Text(
                                  'Status: ${fila['status']}',
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FilaPage(
                                        filaId: fila['id'],
                                        filaNome: fila['nome'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
class FilaPage extends StatefulWidget {
  final int filaId;
  final String filaNome;

  const FilaPage({
    super.key,
    required this.filaId,
    required this.filaNome,
  });

  @override
  State<FilaPage> createState() => _FilaPageState();
}

class _FilaPageState extends State<FilaPage> {
  final String apiUrl = 'http://localhost:3000';

  bool carregando = false;
  Map<String, dynamic>? senha;
  Timer? timer;

  Future<void> entrarNaFila() async {
    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse(
          '$apiUrl/filas/${widget.filaId}/senhas',
        ),
      );

      final dados = jsonDecode(resposta.body);

      if (resposta.statusCode != 201) {
        throw Exception(
          dados['erro'] ?? 'Erro ao entrar na fila',
        );
      }

      if (!mounted) return;

      setState(() {
        senha = dados;
      });

      timer?.cancel();

      timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) {
          atualizarSenha();
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao entrar na fila'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> atualizarSenha() async {
    if (senha == null) {
      return;
    }

    try {
      final resposta = await http.get(
        Uri.parse(
          '$apiUrl/senhas/${senha!['id']}',
        ),
      );

      if (resposta.statusCode != 200) {
        return;
      }

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      setState(() {
        senha = dados;
      });
    } catch (e) {
      print('Erro ao atualizar senha: $e');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filaNome),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: senha == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.filaNome,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: carregando
                          ? null
                          : entrarNaFila,
                      child: carregando
                          ? const CircularProgressIndicator()
                          : const Text('Entrar na fila'),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Sua senha',
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      senha!['codigo'],
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Status: ${senha!['status']}',
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}