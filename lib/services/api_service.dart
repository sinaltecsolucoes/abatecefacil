import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _infoSimplesToken =
      "3eA72go_IGOCn7Xvikd2iLVECaKi1UL5tX11mzpI";

  // Endpoints da InfoSimples
  static const Map<String, String> _endpoints = {
    'ce_nfce': 'https://api.infosimples.com/api/v2/consultas/sefaz/ce/nfce',
    'ce_cfe':
        'https://api.infosimples.com/api/v2/consultas/sefaz/ce/cfe', // MFE Ceará
    'ba': 'https://api.infosimples.com/api/v2/consultas/sefaz/ba/nfce',
    'ma': 'https://api.infosimples.com/api/v2/consultas/sefaz/ma/nfce',
    'pb': 'https://api.infosimples.com/api/v2/consultas/sefaz/pb/nfce',
    'pe': 'https://api.infosimples.com/api/v2/consultas/sefaz/pe/nfce',
    'pi': 'https://api.infosimples.com/api/v2/consultas/sefaz/pi/nfce',
    'rn': 'https://api.infosimples.com/api/v2/consultas/sefaz/rn/nfce-resumida',
  };

  // Mapa de Códigos IBGE para Sigla do Estado
  // Os dois primeiros dígitos da chave dizem de onde ela é
  static const Map<String, String> _codigoIbgeEstados = {
    '21': 'ma',
    '22': 'pi',
    '23': 'ce',
    '24': 'rn',
    '25': 'pb',
    '26': 'pe',
    '29': 'ba',
  };

  static const String baseUrl = "http://10.0.0.250/api-abastece";
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> login(String login, String senha) async {
    try {
      final uri = Uri.parse("$baseUrl/login.php");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"login": login, "senha": senha}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"erro": true, "mensagem": "Erro no login: $e"};
    }
  }

  static Future<Map<String, dynamic>> consultarNFCe(String urlQrCode) async {
    try {
      final chave = _extrairChave(urlQrCode);
      if (chave.length != 44) {
        return {"status": "ERRO", "mensagem": "Chave inválida (44 dígitos)."};
      }

      if (_cache.containsKey(chave)) {
        debugPrint("⚡ CACHE RÁPIDO: Retornando dados da memória.");
        return _cache[chave]!;
      }

      // --- INTELIGÊNCIA PELA CHAVE DE ACESSO ---

      // 1. Identifica o Estado (2 primeiros dígitos)
      final codigoIbge = chave.substring(0, 2);
      final estado =
          _codigoIbgeEstados[codigoIbge] ?? 'ce'; // Padrão CE se não achar

      // 2. Identifica o Modelo (Dígitos 20 e 21) -> 59=SAT, 65=NFCe
      final modelo = chave.substring(20, 22);

      String endpoint;
      String paramName;

      // Lógica de Roteamento
      if (modelo == '59' && estado == 'ce') {
        // MFE/SAT do Ceará
        endpoint = _endpoints['ce_cfe']!;
        paramName = 'chave';
      } else {
        // NFC-e (Qualquer estado) ou SAT de outros estados (se houver no futuro)
        endpoint = _endpoints[estado] ?? _endpoints['ce_nfce']!;
        paramName = 'nfce';
      }

      debugPrint("🔍 Análise da Chave: UF=$codigoIbge($estado) | Mod=$modelo");
      debugPrint("🚀 Endpoint escolhido: $endpoint");

      // 3. Monta a URL
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "token": _infoSimplesToken,
        "timeout": "120",
        "arquivos": "0",
        "original": "0",
        paramName: chave,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['code'] == 200 &&
            jsonResponse['data'] is List &&
            jsonResponse['data'].isNotEmpty) {
          final resultado = _mapInfoSimplesToApp(jsonResponse['data'][0]);
          _cache[chave] = resultado;
          return resultado;
        } else {
          final msg = jsonResponse['code_message'] ?? "Erro na API";
          return {"status": "ERRO", "mensagem": "InfoSimples: $msg"};
        }
      } else {
        return {
          "status": "ERRO",
          "mensagem": "Erro HTTP ${response.statusCode}"
        };
      }
    } catch (e) {
      return {"status": "ERRO", "mensagem": "Sem resposta (Timeout)."};
    }
  }

  static String _extrairChave(String url) {
    final regex = RegExp(r'\d{44}');
    return regex.firstMatch(url)?.group(0) ?? "";
  }

  /*static Map<String, dynamic> _mapInfoSimplesToApp(Map<String, dynamic> data) {
    try {
      final emitente = data['emitente'] ?? {};
      final nfe = data['nfe'] ?? {};
      final totais = data['totais'] ?? {};
      final produtos = data['produtos'] as List? ?? [];

      // DATA
      String rawDate = nfe['data_emissao'] ??
          data['data_emissao'] ??
          data['data_hora_emissao'] ??
          DateTime.now().toString();
      final dataEmissao = _formatarDataUniversal(rawDate);

      // DEMAIS CAMPOS
      final cupom =
          nfe['numero']?.toString() ?? data['numero_cfe']?.toString() ?? '0';
      final cnpjPuro = emitente['normalizado_cnpj']?.toString() ??
          emitente['cnpj']?.toString().replaceAll(RegExp(r'\D'), '') ??
          '';
      final nomePosto = emitente['nome_fantasia'] ??
          emitente['nome'] ??
          emitente['nome_razao_social'] ??
          'Posto';

      double valorTotalNota = _toDouble(totais['normalizado_valor_nfe'] ??
          totais['valor_nfe'] ??
          data['normalizado_valor_total'] ??
          data['valor_total']);

      // PRODUTOS
      String combustivel = 'Combustível';
      double litros = 0.0;
      double valorUnit = 0.0;
      double valorTotalItem = 0.0;

      if (produtos.isNotEmpty) {
        final prod = produtos[0];
        combustivel = (prod['descricao'] ?? prod['item'] ?? 'Combustível')
            .toString()
            .trim();

        litros = _toDouble(prod['quantidade_comercial']);
        if (litros == 0) litros = _toDouble(prod['qtd']);
        if (litros == 0) litros = _toDouble(prod['quantidade']);

        valorTotalItem = _toDouble(prod['valor_produto']);
        if (valorTotalItem == 0) valorTotalItem = _toDouble(prod['valor']);
        if (valorTotalItem == 0)
          valorTotalItem = _toDouble(prod['valor_total_item']);

        valorUnit = _toDouble(prod['valor_unitario_comercial']);
        if (valorUnit == 0) valorUnit = _toDouble(prod['valor_unitario']);
        if (valorUnit == 0) valorUnit = _toDouble(prod['valor_unidade']);

        if (valorUnit == 0 && litros > 0 && valorTotalItem > 0) {
          valorUnit = valorTotalItem / litros;
        }
      }

      // PLACA
      String placa = 'Não informado';
      if (data['transporte']?['veiculo']?['placa'] != null) {
        placa = data['transporte']['veiculo']['placa'];
      } else {
        String obs =
            (data['observacoes'] ?? data['info_adicionais'] ?? '').toString();
        final placaMatch =
            RegExp(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}', caseSensitive: false)
                .firstMatch(obs);
        if (placaMatch != null) placa = placaMatch.group(0)!.toUpperCase();
      }

      return {
        "status": "OK",
        "dados": {
          "Data": dataEmissao,
          "Posto": nomePosto,
          "CNPJPosto": cnpjPuro,
          "Cupom": cupom,
          "Combustivel": combustivel,
          "Placa": placa,
          "ValorUnit": valorUnit,
          "Litros": litros,
          "ValorTotal": valorTotalNota,
          "Quilometro": "Não informado",
        }
      };
    } catch (e) {
      return {"status": "ERRO", "mensagem": "Erro leitura: $e"};
    }
  }*/

  static Map<String, dynamic> _mapInfoSimplesToApp(Map<String, dynamic> data) {
    try {
      final emitente = data['emitente'] ?? {};
      final nfe = data['nfe'] ?? {};
      final infosNota = data['informacoes_nota'] ?? {};
      final totais = data['totais'] ?? {};
      final produtos = data['produtos'] as List? ?? [];

      // 1. DATA (Mantendo a correção anterior)
      String rawDate = data['data_hora_emissao'] ??
          nfe['data_emissao'] ??
          infosNota['data_emissao'] ??
          data['data_emissao'] ??
          DateTime.now().toString();

      final dataEmissao = _formatarDataUniversal(rawDate);

      // 2. DEMAIS DADOS
      final cupom = nfe['numero']?.toString() ??
          infosNota['numero']?.toString() ??
          data['numero_cfe']?.toString() ??
          '0';

      // --- CORREÇÃO DO CNPJ (LIMPEZA TOTAL) ---
      // Pega o valor de onde estiver disponível (normalizado ou sujo)
      String rawCnpj = emitente['normalizado_cnpj']?.toString() ??
          emitente['cnpj']?.toString() ??
          '';

      // Aplica a limpeza de TUDO que não for número (pontos, traços, barras, espaços)
      final cnpjPuro = rawCnpj.replaceAll(RegExp(r'\D'), '');
      // ----------------------------------------

      final nomePosto = emitente['nome_fantasia'] ??
          emitente['nome'] ??
          emitente['nome_razao_social'] ??
          'Posto';

      double valorTotalNota = _toDouble(totais['normalizado_valor_nfe'] ??
          totais['valor_nfe'] ??
          data['normalizado_valor_total'] ??
          data['valor_total']);

      // 3. PRODUTOS
      String combustivel = 'Combustível';
      double litros = 0.0;
      double valorUnit = 0.0;
      double valorTotalItem = 0.0;

      if (produtos.isNotEmpty) {
        final prod = produtos[0];
        combustivel = (prod['descricao'] ?? prod['item'] ?? 'Combustível')
            .toString()
            .trim();

        litros = _toDouble(prod['quantidade_comercial']);
        if (litros == 0) litros = _toDouble(prod['qtd']);
        if (litros == 0) litros = _toDouble(prod['quantidade']);

        valorTotalItem = _toDouble(prod['valor_produto']);
        if (valorTotalItem == 0) valorTotalItem = _toDouble(prod['valor']);
        if (valorTotalItem == 0)
          valorTotalItem = _toDouble(prod['valor_total_item']);

        valorUnit = _toDouble(prod['valor_unitario_comercial']);
        if (valorUnit == 0) valorUnit = _toDouble(prod['valor_unitario']);
        if (valorUnit == 0) valorUnit = _toDouble(prod['valor_unidade']);

        if (valorUnit == 0 && litros > 0 && valorTotalItem > 0) {
          valorUnit = valorTotalItem / litros;
        }
      }

      // 4. PLACA
      String placa = 'Não informado';
      if (data['transporte']?['veiculo']?['placa'] != null) {
        placa = data['transporte']['veiculo']['placa'];
      } else {
        String obs =
            (data['observacoes'] ?? data['info_adicionais'] ?? '').toString();
        final placaMatch =
            RegExp(r'[A-Z]{3}[0-9][A-Z0-9][0-9]{2}', caseSensitive: false)
                .firstMatch(obs);
        if (placaMatch != null) placa = placaMatch.group(0)!.toUpperCase();
      }

      return {
        "status": "OK",
        "dados": {
          "Data": dataEmissao,
          "Posto": nomePosto,
          "CNPJPosto": cnpjPuro, // Agora vai sempre limpo!
          "Cupom": cupom,
          "Combustivel": combustivel,
          "Placa": placa,
          "ValorUnit": valorUnit,
          "Litros": litros,
          "ValorTotal": valorTotalNota,
          "Quilometro": "Não informado",
        }
      };
    } catch (e) {
      debugPrint("Erro parser: $e");
      return {"status": "ERRO", "mensagem": "Erro ao ler dados do cupom"};
    }
  }

  static String _formatarDataUniversal(String input) {
    try {
      input = input.trim();
      // 1. Data por extenso (SAT)
      if (input.contains(' de ')) {
        final meses = {
          'janeiro': '01',
          'fevereiro': '02',
          'março': '03',
          'abril': '04',
          'maio': '05',
          'junho': '06',
          'julho': '07',
          'agosto': '08',
          'setembro': '09',
          'outubro': '10',
          'novembro': '11',
          'dezembro': '12'
        };
        String limpa =
            input.replaceAll(',', '').replaceAll('às', '').toLowerCase();
        final parts = limpa.split(' ');
        if (parts.length >= 5) {
          String dia = parts[0].padLeft(2, '0');
          String mesNome = parts[2];
          String ano = parts[4];
          String hora = parts.length > 5 ? parts[5] : "00:00:00";
          String mesNumero = meses[mesNome] ?? '01';
          return "$ano-$mesNumero-$dia $hora";
        }
      }
      // 2. Data com Barras (DD/MM/AAAA)
      if (input.contains('/')) {
        final partesEspaco = input.split(' ');
        final soData = partesEspaco[0];
        final soHora = partesEspaco.length > 1 ? partesEspaco[1] : "";
        final partsData = soData.split('/');
        if (partsData.length == 3) {
          String dia = partsData[0];
          String mes = partsData[1];
          String ano = partsData[2];
          String horaFinal = soHora.isNotEmpty
              ? soHora
              : DateTime.now().toString().substring(11, 19);
          return "$ano-$mes-$dia $horaFinal";
        }
      }
      // 3. Data ISO
      if (input.contains('-')) {
        if (input.length <= 10) {
          final hora = DateTime.now().toString().substring(11, 19);
          return "$input $hora";
        }
        return input;
      }
      return DateTime.now().toString().substring(0, 19);
    } catch (e) {
      return DateTime.now().toString().substring(0, 19);
    }
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  static Future<Map<String, dynamic>> salvarVariosAbastecimentos(
      List<Map<String, dynamic>> lista) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/salvar_varios.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"abastecimentos": lista}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"sucesso": false, "mensagem": "Erro ao salvar: $e"};
    }
  }
}
