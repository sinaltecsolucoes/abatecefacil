import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtrl = TextEditingController(text: "admin");
  final _senhaCtrl = TextEditingController(text: "123456");
  bool _loading = false;

  Future<void> _fazerLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final result = await ApiService.login(_loginCtrl.text, _senhaCtrl.text);
      if (result['sucesso'] == true && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('usuario_id', result['usuario_id']);
        await prefs.setString('usuario_nome', result['nome']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
      } else {
        _msg(result['mensagem'] ?? "Erro no login");
      }
    } catch (e) {
      _msg("Sem conexão com o servidor");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String txt) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Abastece Fácil")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextField(controller: _loginCtrl, decoration: const InputDecoration(labelText: "Login")),
          TextField(controller: _senhaCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Senha")),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _loading ? null : _fazerLogin, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("ENTRAR", style: TextStyle(fontSize: 18)))),
        ]),
      ),
    );
  }
}