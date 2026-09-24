import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiUrl =
    'https://smartq-production-319f.up.railway.app';

void main() {
  runApp(const SmartQApp());
}

// ============================================================
// APP
// ============================================================

class SmartQApp extends StatelessWidget {
  const SmartQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartQ',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF2563EB),
              width: 2,
            ),
          ),
        ),
      ),
      home: const SessaoInicial(),
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

Map<String, dynamic> decodificarResposta(http.Response resposta) {
  if (resposta.body.isEmpty) {
    return {};
  }

  try {
    final dados = jsonDecode(resposta.body);

    if (dados is Map<String, dynamic>) {
      return dados;
    }

    return {};
  } catch (_) {
    return {};
  }
}

String mensagemErro(
  http.Response resposta, {
  String padrao = 'Ocorreu um erro.',
}) {
  final dados = decodificarResposta(resposta);

  return dados['erro']?.toString() ??
      dados['mensagem']?.toString() ??
      padrao;
}

void mostrarSnackBar(
  BuildContext context,
  String mensagem, {
  bool erro = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            erro ? const Color(0xFFDC2626) : const Color(0xFF172033),
      ),
    );
}


// ============================================================
// SESSAO PERSISTENTE
// ============================================================

class SessaoInicial extends StatefulWidget {
  const SessaoInicial({super.key});

  @override
  State<SessaoInicial> createState() => _SessaoInicialState();
}

class _SessaoInicialState extends State<SessaoInicial> {
  @override
  void initState() {
    super.initState();
    _restaurarSessao();
  }

  Future<void> _restaurarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final usuarioJson = prefs.getString('usuario');

    if (!mounted) return;

    if (token == null || token.isEmpty || usuarioJson == null) {
      _irParaLogin();
      return;
    }

    try {
      final usuario = Map<String, dynamic>.from(jsonDecode(usuarioJson));

      final resposta = await http.get(
        Uri.parse('$apiUrl/minha-senha'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (resposta.statusCode == 401 || resposta.statusCode == 403) {
        await prefs.remove('token');
        await prefs.remove('usuario');
        _irParaLogin();
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FilasPage(usuario: usuario, token: token),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _irParaLogin();
    }
  }

  void _irParaLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  bool ocultarSenha = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final senha = senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      mostrarSnackBar(
        context,
        'Informe o e-mail e a senha.',
        erro: true,
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'senha': senha,
        }),
      );

      final dados = decodificarResposta(resposta);

      if (resposta.statusCode != 200) {
        if (!mounted) return;

        mostrarSnackBar(
          context,
          mensagemErro(
            resposta,
            padrao: 'Não foi possível entrar.',
          ),
          erro: true,
        );

        return;
      }

      final usuario = dados['usuario'];

      if (usuario == null || usuario is! Map) {
        throw Exception('Usuário não retornado pela API');
      }

      final token = dados['token']?.toString() ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('usuario', jsonEncode(usuario));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FilasPage(
            usuario: Map<String, dynamic>.from(usuario),
            token: token,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      mostrarSnackBar(
        context,
        'Não foi possível conectar ao SmartQ.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SmartQ',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sua fila, sem complicação.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 38),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Acesse sua conta para retirar uma senha.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: senhaController,
                          obscureText: ocultarSenha,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => login(),
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  ocultarSenha = !ocultarSenha;
                                });
                              },
                              icon: Icon(
                                ocultarSenha
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed:
                                carregando ? null : login,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: carregando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: carregando
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CadastroPage(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Ainda não possui conta? Criar conta',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CADASTRO
// ============================================================

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;
  bool ocultarSenha = true;
  bool ocultarConfirmacao = true;

  Future<void> cadastrar() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text;
    final confirmarSenha = confirmarSenhaController.text;

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      mostrarSnackBar(
        context,
        'Preencha todos os campos.',
        erro: true,
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      mostrarSnackBar(
        context,
        'Informe um e-mail válido.',
        erro: true,
      );
      return;
    }

    if (senha.length < 6) {
      mostrarSnackBar(
        context,
        'A senha deve possuir pelo menos 6 caracteres.',
        erro: true,
      );
      return;
    }

    if (senha != confirmarSenha) {
      mostrarSnackBar(
        context,
        'As senhas não coincidem.',
        erro: true,
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('$apiUrl/auth/cadastro'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'senha': senha,
        }),
      );

      if (resposta.statusCode != 201) {
        if (!mounted) return;

        mostrarSnackBar(
          context,
          mensagemErro(
            resposta,
            padrao: 'Não foi possível criar a conta.',
          ),
          erro: true,
        );

        return;
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A),
              size: 44,
            ),
            title: const Text('Conta criada'),
            content: const Text(
              'Seu cadastro foi realizado com sucesso. '
              'Agora você já pode entrar no SmartQ.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      mostrarSnackBar(
        context,
        'Não foi possível conectar ao SmartQ.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Criar conta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            30,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bem-vindo ao SmartQ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Crie sua conta para utilizar as filas disponíveis.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: nomeController,
                    textCapitalization:
                        TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon:
                          Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon:
                          Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: senhaController,
                    obscureText: ocultarSenha,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      helperText:
                          'Mínimo de 6 caracteres',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            ocultarSenha =
                                !ocultarSenha;
                          });
                        },
                        icon: Icon(
                          ocultarSenha
                              ? Icons.visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmarSenhaController,
                    obscureText: ocultarConfirmacao,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => cadastrar(),
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            ocultarConfirmacao =
                                !ocultarConfirmacao;
                          });
                        },
                        icon: Icon(
                          ocultarConfirmacao
                              ? Icons.visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          carregando ? null : cadastrar,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                      child: carregando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Criar conta',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FILAS
// ============================================================

class FilasPage extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final String token;

  const FilasPage({
    super.key,
    required this.usuario,
    required this.token,
  });

  @override
  State<FilasPage> createState() => _FilasPageState();
}

class _FilasPageState extends State<FilasPage> {
  List<dynamic> filas = [];

  bool carregando = true;
  bool atualizando = false;

  String? erro;
  Map<String, dynamic>? minhaSenha;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    await Future.wait([
      carregarFilas(),
      carregarMinhaSenha(),
    ]);
  }

  Future<void> carregarMinhaSenha() async {
    try {
      final resposta = await http.get(
        Uri.parse('$apiUrl/minha-senha'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (resposta.statusCode != 200) return;
      final dados = decodificarResposta(resposta);
      if (!mounted) return;

      setState(() {
        minhaSenha = dados['senha'] is Map
            ? Map<String, dynamic>.from(dados['senha'])
            : null;
      });
    } catch (_) {}
  }

  Future<void> carregarFilas({
    bool mostrarCarregamento = true,
  }) async {
    if (mostrarCarregamento) {
      setState(() {
        carregando = true;
        erro = null;
      });
    } else {
      setState(() {
        atualizando = true;
      });
    }

    try {
      final resposta = await http.get(
        Uri.parse('$apiUrl/filas'),
      );

      if (resposta.statusCode != 200) {
        throw Exception('Erro ao buscar filas');
      }

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      setState(() {
        filas = dados is List ? dados : [];
        erro = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = 'Não foi possível carregar as filas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
          atualizando = false;
        });
      }
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('usuario');
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome =
        widget.usuario['nome']?.toString() ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'SmartQ',
          style: TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: atualizando
                ? null
                : () async {
                    await carregarFilas(mostrarCarregamento: false);
                    await carregarMinhaSenha();
                  },
            icon: atualizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Conta',
            onSelected: (valor) {
              if (valor == 'sair') {
                logout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.usuario['email']
                              ?.toString() ??
                          '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded),
                    SizedBox(width: 10),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFE8EEFF),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await carregarFilas(mostrarCarregamento: false);
            await carregarMinhaSenha();
          },
          child: carregando
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : erro != null
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 100),
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          erro!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Verifique sua conexão e tente novamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: FilledButton.icon(
                            onPressed: carregarFilas,
                            icon: const Icon(
                              Icons.refresh_rounded,
                            ),
                            label:
                                const Text('Tentar novamente'),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        26,
                        20,
                        30,
                      ),
                      children: [
                        Text(
                          'Olá, ${primeiroNome(nome)}!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Escolha onde você deseja ser atendido.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (minhaSenha != null) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.confirmation_number_rounded, color: Color(0xFF2563EB)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Você já está em uma fila', style: TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text('${minhaSenha!['filaNome']} • ${minhaSenha!['codigo']}', style: const TextStyle(color: Color(0xFF475569))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (filas.isEmpty)
                          const _EmptyFilas()
                        else
                          ...filas.map(
                            (fila) => Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 14,
                              ),
                              child: _FilaCard(
                                fila: fila,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FilaPage(
                                        filaId:
                                            fila['id'],
                                        filaNome:
                                            fila['nome'],
                                        statusInicial:
                                            fila['status'],
                                        token: widget.token,
                                        senhaInicial: minhaSenha != null &&
                                                minhaSenha!['filaId'] == fila['id']
                                            ? minhaSenha
                                            : null,
                                      ),
                                    ),
                                  );

                                  await carregarFilas(
                                    mostrarCarregamento: false,
                                  );
                                  await carregarMinhaSenha();
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

String primeiroNome(String nome) {
  final partes = nome.trim().split(' ');

  if (partes.isEmpty || partes.first.isEmpty) {
    return 'Usuário';
  }

  return partes.first;
}

class _EmptyFilas extends StatelessWidget {
  const _EmptyFilas();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 14),
          Text(
            'Nenhuma fila disponível',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCard extends StatelessWidget {
  final dynamic fila;
  final VoidCallback onTap;

  const _FilaCard({
    required this.fila,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aberta = fila['status'] == 'aberta';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: aberta
                      ? const Color(0xFFE8EEFF)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.groups_2_outlined,
                  color: aberta
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila['nome']?.toString() ??
                          'Fila',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: aberta
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          aberta
                              ? 'Aberta para atendimento'
                              : 'Fila fechada',
                          style: TextStyle(
                            color: aberta
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FILA / SENHA
// ============================================================

class FilaPage extends StatefulWidget {
  final int filaId;
  final String filaNome;
  final String statusInicial;
  final String token;
  final Map<String, dynamic>? senhaInicial;

  const FilaPage({
    super.key,
    required this.filaId,
    required this.filaNome,
    required this.statusInicial,
    required this.token,
    this.senhaInicial,
  });

  @override
  State<FilaPage> createState() => _FilaPageState();
}

class _FilaPageState extends State<FilaPage> {
  bool carregando = false;
  bool carregandoStatus = true;

  String statusFila = 'aberta';

  int quantidadeAguardando = 0;
  String? senhaAtual;
  String? proximaSenha;

  Map<String, dynamic>? senha;

  Timer? timerSenha;
  Timer? timerFila;

  @override
  void initState() {
    super.initState();

    statusFila = widget.statusInicial;
    senha = widget.senhaInicial == null
        ? null
        : Map<String, dynamic>.from(widget.senhaInicial!);

    if (senha != null) {
      iniciarMonitoramentoSenha();
    }

    carregarStatusFila();

    timerFila = Timer.periodic(
      const Duration(seconds: 3),
      (_) => carregarStatusFila(),
    );
  }

  Future<void> carregarStatusFila() async {
    try {
      final resposta = await http.get(
        Uri.parse(
          '$apiUrl/filas/${widget.filaId}/status',
        ),
      );

      if (resposta.statusCode != 200) {
        return;
      }

      final dados = decodificarResposta(resposta);

      if (!mounted) return;

      setState(() {
        statusFila =
            dados['status']?.toString() ?? statusFila;

        quantidadeAguardando =
            dados['quantidadeAguardando'] ?? 0;

        senhaAtual = dados['senhaAtual']?.toString();

        proximaSenha =
            dados['proximaSenha']?.toString();

        carregandoStatus = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          carregandoStatus = false;
        });
      }
    }
  }

  Future<void> entrarNaFila() async {
    if (statusFila != 'aberta') {
      mostrarSnackBar(
        context,
        'Esta fila está fechada no momento.',
        erro: true,
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse(
          '$apiUrl/filas/${widget.filaId}/senhas',
        ),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      final dados = decodificarResposta(resposta);

      if (resposta.statusCode != 201) {
        if (!mounted) return;

        mostrarSnackBar(
          context,
          mensagemErro(
            resposta,
            padrao: 'Não foi possível retirar a senha.',
          ),
          erro: true,
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        senha = dados;
      });

      iniciarMonitoramentoSenha();
      await carregarStatusFila();
    } catch (e) {
      if (!mounted) return;

      mostrarSnackBar(
        context,
        'Erro ao retirar a senha.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  void iniciarMonitoramentoSenha() {
    timerSenha?.cancel();

    timerSenha = Timer.periodic(
      const Duration(seconds: 2),
      (_) => atualizarSenha(),
    );
  }

  Future<void> atualizarSenha() async {
    if (senha == null) return;

    try {
      final resposta = await http.get(
        Uri.parse(
          '$apiUrl/senhas/${senha!['id']}',
        ),
      );

      if (resposta.statusCode != 200) {
        return;
      }

      final dados = decodificarResposta(resposta);

      if (!mounted) return;

      final statusAnterior =
          senha?['status']?.toString();

      setState(() {
        senha = dados;
      });

      final novoStatus =
          dados['status']?.toString();

      if (novoStatus == 'atendido' ||
          novoStatus == 'cancelado') {
        timerSenha?.cancel();
      }

      if (statusAnterior != novoStatus) {
        carregarStatusFila();
      }
    } catch (e) {
      debugPrint('Erro ao atualizar senha: $e');
    }
  }

  Future<void> cancelarSenha() async {
    if (senha == null ||
        senha!['status'] != 'aguardando') {
      return;
    }

    final confirmar =
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title:
                      const Text('Cancelar senha?'),
                  content: Text(
                    'Deseja cancelar a senha '
                    '${senha!['codigo']}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          false,
                        );
                      },
                      child: const Text('Voltar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFDC2626),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      },
                      child:
                          const Text('Cancelar senha'),
                    ),
                  ],
                );
              },
            ) ??
            false;

    if (!confirmar) return;

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse(
          '$apiUrl/senhas/${senha!['id']}/cancelar',
        ),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (resposta.statusCode != 200) {
        if (!mounted) return;

        mostrarSnackBar(
          context,
          mensagemErro(
            resposta,
            padrao:
                'Não foi possível cancelar a senha.',
          ),
          erro: true,
        );

        return;
      }

      final dados = decodificarResposta(resposta);

      if (!mounted) return;

      setState(() {
        if (dados['senha'] is Map) {
          senha = Map<String, dynamic>.from(
            dados['senha'],
          );
        } else {
          senha = {
            ...senha!,
            'status': 'cancelado',
          };
        }
      });

      timerSenha?.cancel();
      await carregarStatusFila();

      if (!mounted) return;

      mostrarSnackBar(
        context,
        'Senha cancelada.',
      );
    } catch (e) {
      if (!mounted) return;

      mostrarSnackBar(
        context,
        'Erro ao cancelar a senha.',
        erro: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  void retirarOutraSenha() {
    setState(() {
      senha = null;
    });

    carregarStatusFila();
  }

  @override
  void dispose() {
    timerSenha?.cancel();
    timerFila?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.filaNome,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: senha == null
            ? _buildFilaDisponivel()
            : _buildSenhaDigital(),
      ),
    );
  }

  Widget _buildFilaDisponivel() {
    final aberta = statusFila == 'aberta';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  color: Color(0xFF2563EB),
                  size: 29,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.filaNome,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 10),
              _StatusFilaBadge(aberta: aberta),
              const SizedBox(height: 26),
              if (carregandoStatus)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        titulo: 'Aguardando',
                        valor:
                            '$quantidadeAguardando',
                        icone:
                            Icons.people_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoBox(
                        titulo: 'Em atendimento',
                        valor: senhaAtual ?? '-',
                        icone: Icons
                            .confirmation_number_outlined,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ao retirar uma senha, acompanhe esta '
                  'tela. Ela será atualizada automaticamente '
                  'quando chegar a sua vez.',
                  style: TextStyle(
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed:
                aberta && !carregando
                    ? entrarNaFila
                    : null,
            style: FilledButton.styleFrom(
              backgroundColor:
                  const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: carregando
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.confirmation_number_rounded,
                  ),
            label: carregando
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    aberta
                        ? 'Retirar senha'
                        : 'Fila fechada',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSenhaDigital() {
    final status =
        senha!['status']?.toString() ?? 'aguardando';

    final visual = StatusSenhaVisual.from(status);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            24,
            30,
            24,
            30,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'SUA SENHA',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                senha!['codigo']?.toString() ?? '-',
                style: TextStyle(
                  fontSize: 68,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: visual.cor,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: visual.corFundo,
                  borderRadius:
                      BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      visual.icone,
                      size: 18,
                      color: visual.cor,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      visual.titulo,
                      style: TextStyle(
                        color: visual.cor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                visual.descricao,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.filaNome,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (status == 'aguardando')
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Senhas aguardando nesta fila',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Text(
                  '$quantidadeAguardando',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        if (status == 'chamando') ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFBBF7D0),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF15803D),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sua senha foi chamada. '
                    'Dirija-se ao atendimento.',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (status == 'aguardando')
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed:
                  carregando ? null : cancelarSenha,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(0xFFDC2626),
                side: const BorderSide(
                  color: Color(0xFFFCA5A5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(
                Icons.close_rounded,
              ),
              label: const Text(
                'Cancelar senha',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (status == 'atendido' ||
            status == 'cancelado')
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: retirarOutraSenha,
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Voltar para a fila',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// COMPONENTES
// ============================================================

class _StatusFilaBadge extends StatelessWidget {
  final bool aberta;

  const _StatusFilaBadge({
    required this.aberta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: aberta
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aberta
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            aberta ? 'FILA ABERTA' : 'FILA FECHADA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: aberta
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;

  const _InfoBox({
    required this.titulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 21,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(height: 13),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusSenhaVisual {
  final String titulo;
  final String descricao;
  final Color cor;
  final Color corFundo;
  final IconData icone;

  const StatusSenhaVisual({
    required this.titulo,
    required this.descricao,
    required this.cor,
    required this.corFundo,
    required this.icone,
  });

  factory StatusSenhaVisual.from(String status) {
    switch (status) {
      case 'chamando':
        return const StatusSenhaVisual(
          titulo: 'SUA VEZ',
          descricao:
              'Sua senha está sendo chamada para atendimento.',
          cor: Color(0xFF15803D),
          corFundo: Color(0xFFDCFCE7),
          icone: Icons.notifications_active_rounded,
        );

      case 'atendido':
        return const StatusSenhaVisual(
          titulo: 'ATENDIMENTO FINALIZADO',
          descricao:
              'Seu atendimento foi concluído com sucesso.',
          cor: Color(0xFF15803D),
          corFundo: Color(0xFFDCFCE7),
          icone: Icons.check_circle_outline_rounded,
        );

      case 'cancelado':
        return const StatusSenhaVisual(
          titulo: 'SENHA CANCELADA',
          descricao:
              'Esta senha não está mais aguardando atendimento.',
          cor: Color(0xFFB91C1C),
          corFundo: Color(0xFFFEE2E2),
          icone: Icons.cancel_outlined,
        );

      default:
        return const StatusSenhaVisual(
          titulo: 'AGUARDANDO',
          descricao:
              'Acompanhe esta tela. Avisaremos quando chegar a sua vez.',
          cor: Color(0xFF2563EB),
          corFundo: Color(0xFFDBEAFE),
          icone: Icons.schedule_rounded,
        );
    }
  }
}