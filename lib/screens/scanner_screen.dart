import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final player = AudioPlayer();

  bool processing = false;
  String? nomeUsuario;

  // Lista que alimenta a tela
  List<Map<String, String>> listaAbastecimentos = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nomeUsuario = prefs.getString('usuario_nome');
    });
  }

  // --- INTERFACE (BUILD) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Olá, ${nomeUsuario ?? 'Motorista'}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              if (listaAbastecimentos.isNotEmpty) {
                setState(() => listaAbastecimentos.clear());
              }
            },
            tooltip: "Limpar Lista",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),

      // 1. SAFEAREA (Corpo Principal)
      body: SafeArea(
        child: Column(
          children: [
            // A. CÂMERA
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: Stack(
                children: [
                  MobileScanner(controller: controller, onDetect: _detect),
                  if (processing)
                    const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Aponte para o QR Code",
                        style: TextStyle(
                            color: Colors.white,
                            backgroundColor: Colors.black54),
                      ),
                    ),
                  )
                ],
              ),
            ),

            // B. CABEÇALHO DA LISTA
            /*    Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cupons Lidos: ${listaAbastecimentos.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (listaAbastecimentos.isNotEmpty)
                    const Text(
                      "Toque para ver detalhes",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),*/

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Contador
                  Text(
                    "Lidos: ${listaAbastecimentos.length}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  // Botão de Digitação Manual (Mais discreto e bem posicionado)
                  OutlinedButton.icon(
                    onPressed: _abrirDialogoManual,
                    icon: const Icon(Icons.keyboard, size: 18),
                    label: const Text("Digitar Chave"),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),

            // C. LISTA DE CARDS
            Expanded(
              child: listaAbastecimentos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Nenhum cupom lido ainda."),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: listaAbastecimentos.length,
                      itemBuilder: (context, index) {
                        final item = listaAbastecimentos[
                            listaAbastecimentos.length - 1 - index];
                        final realIndex =
                            listaAbastecimentos.length - 1 - index;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          elevation: 3,
                          child: ExpansionTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.local_gas_station,
                                  color: Colors.white),
                            ),
                            title: Text(
                              item['posto'] ?? 'Posto',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "${item['data']} • ${item['total']}",
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _infoRow(
                                        "Combustível", item['combustivel']),
                                    _infoRow("Litros", "${item['litros']} L"),
                                    _infoRow("Valor Unitário",
                                        "${item['valorUnit']}"),
                                    _infoRow("CNPJ", item['cnpj']),
                                    _infoRow("Placa", item['placa']),
                                    _infoRow("Cupom", item['cupom']),
                                    _infoRow(
                                        "Quilometragem", item['quilometro']),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        label: const Text("Remover este item",
                                            style:
                                                TextStyle(color: Colors.red)),
                                        onPressed: () {
                                          setState(() {
                                            listaAbastecimentos
                                                .removeAt(realIndex);
                                          });
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // D. BOTÃO DE SALVAR
            if (listaAbastecimentos.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text("ENVIAR TUDO PARA O BANCO"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700]),
                    onPressed: processing ? null : _salvarTodos,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS LÓGICOS ---

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Função chamada pela Câmera
  void _detect(BarcodeCapture capture) {
    if (processing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    _consultar(code); // Reutiliza a mesma lógica
  }

  // Lógica central de consulta (Câmera ou Manual)
  Future<void> _consultar(String codigoOuChave) async {
    // Evita duplicatas
    if (listaAbastecimentos.any((item) => item['url_raw'] == codigoOuChave)) {
      return;
    }

    setState(() => processing = true);
    // await player.play(AssetSource('beep.mp3'));

    try {
      final result = await ApiService.consultarNFCe(codigoOuChave);

      if (result['status'] == 'OK') {
        final d = result['dados'];

        setState(() {
          listaAbastecimentos.add({
            'url_raw': codigoOuChave,
            'data': d['Data'].toString(),
            'posto': d['Posto'].toString(),
            'cnpj': d['CNPJPosto'].toString(),
            'cupom': d['Cupom'].toString(),
            'combustivel': d['Combustivel'].toString(),
            'placa': d['Placa'].toString(),
            'valorUnit': 'R\$ ${(d['ValorUnit'] as num).toStringAsFixed(3)}',
            'litros': (d['Litros'] as num).toStringAsFixed(3),
            'total': 'R\$ ${(d['ValorTotal'] as num).toStringAsFixed(2)}',
            'quilometro': d['Quilometro'].toString(),
          });
        });
        _msg("Leitura realizada com sucesso!");
      } else {
        _msg(result['mensagem']);
      }
    } catch (e) {
      _msg("Erro ao ler: $e");
    } finally {
      setState(() => processing = false);
    }
  }

  // Função para abrir caixa de texto manual
  void _abrirDialogoManual() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Entrada Manual"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Digite os 44 números da Chave de Acesso:"),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ex: 2323...",
                  suffixIcon: Icon(Icons.vpn_key),
                ),
                maxLength: 44,
                maxLines: 1,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                final chave = textController.text.trim().replaceAll(RegExp(r'\D'), '');
                Navigator.pop(context);

                if (chave.length >= 44) {
                  _consultar(chave);
                } else {
                  _msg("A chave deve ter 44 dígitos.");
                }
              },
              child: const Text("Consultar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _salvarTodos() async {
    setState(() => processing = true);
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt('usuario_id') ?? 0;

    final payload = listaAbastecimentos.map((item) {
      return {
        "usuario_id": usuarioId,
        "data_abastecimento": item['data'],
        "cnpj_posto": item['cnpj'],
        "descricao_combustivel": item['combustivel'],
        "valor_unitario": item['valorUnit']!.replaceAll('R\$ ', ''),
        "total_litros": item['litros'],
        "valor_total": item['total']!.replaceAll('R\$ ', ''),
        "placa_veiculo": item['placa'],
        "quilometragem":
            item['quilometro'] == 'Não informado' ? null : item['quilometro'],
        "numero_cupom": item['cupom'],
      };
    }).toList();

    final res = await ApiService.salvarVariosAbastecimentos(payload);

    if (res['sucesso'] == true) {
      _msg("Sucesso! ${listaAbastecimentos.length} abastecimentos salvos.");
      setState(() => listaAbastecimentos.clear());
    } else {
      _msg(res['mensagem'] ?? "Erro ao salvar.");
    }
    setState(() => processing = false);
  }

  void _msg(String txt) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(txt), duration: const Duration(seconds: 2)));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    player.dispose();
    super.dispose();
  }
}
