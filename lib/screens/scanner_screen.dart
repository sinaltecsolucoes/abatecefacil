import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../widgets/data_table_widget.dart';
import 'login_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final player = AudioPlayer();
  bool processing = false;
  Map<String, String> dados = {};
  String? nome;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    nome = prefs.getString('usuario_nome');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Olá, ${nome ?? 'Usuário'}"), actions: [
        IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted)
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
            })
      ]),
      body: SafeArea(
        child: Column(children: [
          Expanded(
              flex: 5,
              child: MobileScanner(controller: controller, onDetect: _detect)),
          Expanded(
              flex: 4,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: dados.isEmpty
                      ? const Center(
                          child: Text("Aponte para o QR Code",
                              style: TextStyle(fontSize: 18)))
                      : DataTableWidget(dados: dados))),
          if (dados.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("SALVAR NO BANCO"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: processing ? null : _salvar))),
          if (processing) const LinearProgressIndicator(),
        ]),
      ),
    );
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (processing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() => processing = true);
    //await player.play(AssetSource('beep-leituraQR.mp3'));

    debugPrint("DEBUG: QR Code lido = $code");

    // Agora basta passar o link inteiro
    await _consultar(code);

    setState(() => processing = false);
  }

  /*String? _extrairParametro(String? url) {
    if (url == null) return null;
    try {
      return Uri.parse(url).queryParameters['p'];
    } catch (_) {
      return null;
    }
  }*/

  Future<void> _consultar(String url) async {
    setState(() => processing = true);

    try {
      debugPrint("DEBUG: Chamando ApiService.consultarNFCe com url=$url");
      final result = await ApiService.consultarNFCe(url);

      debugPrint("DEBUG: Resultado da API = $result");

      if (result['status'] == 'OK') {
        final d = result['dados'];
        debugPrint("DEBUG: Dados parseados = $d");

        final emitente = d['emitente'];
        final item =
            d['itens'].isNotEmpty ? d['itens'][0] : <String, dynamic>{};

        if (mounted) {
          setState(() {
            dados = {
              'posto': emitente['nome'],
              'cnpj': emitente['cnpj'],
              'combustivel': item['descricao'] ?? 'Combustível',
              'litros': (item['quantidade'] as double).toStringAsFixed(3),
              'precoLitro':
                  'R\$ ${(item['valor_unitario'] as double).toStringAsFixed(3)}',
              'total': 'R\$ ${(d['valor_total'] as double).toStringAsFixed(2)}',
              'data': d['data_emissao'],
            };
          });
        }
      } else {
        _msg(result['mensagem'] ?? "Erro na consulta da SEFAZ");
      }
    } catch (e) {
      _msg("Erro de conexão com SEFAZ: $e");
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => processing = true);
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      "usuario_id": prefs.getInt('usuario_id'),
      "data_abastecimento": DateTime.now().toIso8601String(),
      "cnpj_posto": dados['cnpj'],
      "descricao_combustivel": dados['combustivel'],
      "valor_unitario": dados['precoLitro']?.replaceAll('R\$ ', ''),
      "total_litros": dados['litros'],
      "valor_total": dados['total']?.replaceAll('R\$ ', ''),
    };

    try {
      final res = await ApiService.salvarAbastecimento(payload);
      _msg(res['sucesso'] == true ? "Salvo com sucesso!" : "Erro ao salvar");
      if (res['sucesso'] == true) setState(() => dados.clear());
    } catch (e) {
      _msg("Erro de rede");
    } finally {
      setState(() => processing = false);
    }
  }

  void _msg(String txt) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));

  @override
  void dispose() {
    controller.dispose();
    player.dispose();
    super.dispose();
  }
}
