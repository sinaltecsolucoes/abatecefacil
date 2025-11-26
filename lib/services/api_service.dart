import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http; // Mantemos para o login
import 'dart:convert';

class ApiService {
  static const String baseUrl = "http://10.0.0.250/api-abastece";

  /// Login (Mantemos via HTTP normal pois é sua API interna)
  static Future<Map<String, dynamic>> login(String login, String senha) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"login": login, "senha": senha}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"erro": true, "mensagem": "Erro no login: $e"};
    }
  }

  /// Consulta NFC-e usando Headless WebView (Navegador Invisível)
  /// Isso "engana" a SEFAZ pois é um navegador real renderizando a página.
  static Future<Map<String, dynamic>> consultarNFCe(String url) async {
    final completer = Completer<Map<String, dynamic>>();
    HeadlessInAppWebView? headlessWebView;

    try {
      debugPrint("DEBUG: Iniciando WebView Invisível para: $url");

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          isInspectable: true, // Útil para debug
          javaScriptEnabled: true, // Essencial: A SEFAZ exige JS
          userAgent: // Fingimos ser um Chrome Android padrão
              "Mozilla/5.0 (Linux; Android 10; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.88 Mobile Safari/537.36",
        ),
        onLoadStop: (controller, url) async {
          debugPrint("DEBUG: Página carregada. Extraindo HTML...");

          // Aguarda um pouco para garantir que scripts da SEFAZ rodaram (opcional, mas seguro)
          await Future.delayed(const Duration(milliseconds: 500));

          final html = await controller.getHtml();

          if (html != null && html.isNotEmpty) {
            // Verifica se tem dados reais ou se é página de erro
            if (html.contains("txtTopo") || html.contains("txtTit")) {
              final dados = _parseHtml(html, url.toString());
              if (!completer.isCompleted) {
                completer.complete({"status": "OK", "dados": dados});
              }
            } else {
              // Se carregou mas não tem as classes, pode ser captcha ou erro
              debugPrint("DEBUG: HTML carregado mas sem classes esperadas.");
              if (!completer.isCompleted) {
                // Tenta parsear mesmo assim, ou retorna erro
                final dados = _parseHtml(html, url.toString());
                completer.complete({"status": "OK", "dados": dados});
              }
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete({"status": "ERRO", "mensagem": "HTML Vazio"});
            }
          }
          // Fecha o navegador para economizar memória
          await headlessWebView?.dispose();
        },
        onLoadError: (controller, url, code, message) {
          debugPrint("DEBUG: Erro no WebView: $message");
          if (!completer.isCompleted) {
            completer.complete(
                {"status": "ERRO", "mensagem": "Falha webview: $message"});
            headlessWebView?.dispose();
          }
        },
      );

      // Inicia o navegador e carrega a página
      await headlessWebView.run();

      // Timeout de segurança: Se em 20s não carregar, cancela
      return completer.future.timeout(const Duration(seconds: 20),
          onTimeout: () {
        headlessWebView?.dispose();
        return {
          "status": "ERRO",
          "mensagem": "Tempo limite excedido (Timeout)"
        };
      });
    } catch (e) {
      return {"status": "ERRO", "mensagem": "Exceção: $e"};
    }
  }

  /// Parser Ajustado para SEFAZ CE
  static Map<String, dynamic> _parseHtml(String html, String url) {
    final document = parser.parse(html);

    // --- Parser Ceará ---
    // Mesmo que a URL mude, se o HTML tiver a estrutura da SEFAZ CE, usaremos este bloco
    if (url.contains("sefaz.ce.gov.br") || html.contains("txtTopo")) {
      final nomePosto = document.querySelector('.txtTopo')?.text.trim() ??
          'Posto não identificado';

      // Busca CNPJ
      String cnpjPosto = '';
      final divs = document.querySelectorAll('.text');
      for (var div in divs) {
        if (div.text.contains('CNPJ')) {
          cnpjPosto = div.text.replaceAll('CNPJ:', '').trim();
          break;
        }
      }

      // Dados do Item (pega o primeiro da lista)
      final descricao =
          document.querySelector('.txtTit')?.text.trim() ?? 'Combustível';

      // Tratamento de números (troca vírgula por ponto)
      String limpaNum(String? s) =>
          s?.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.') ?? '0';

      final qtd = limpaNum(document.querySelector('.Rqtd')?.text);
      final vlUnit = limpaNum(document.querySelector('.RvlUnit')?.text);
      final vlTotalNota = limpaNum(document.querySelector('.txtMax')?.text);

      // Data Emissão
      String dataEmissao = DateTime.now().toString().substring(0, 10);
      final infos = document.querySelector('#infos')?.text ?? '';
      final matchData = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(infos);
      if (matchData != null) dataEmissao = matchData.group(1)!;

      return {
        'emitente': {
          'nome': nomePosto,
          'cnpj': cnpjPosto,
        },
        'itens': [
          {
            'descricao': descricao,
            'quantidade': double.tryParse(qtd) ?? 0.0,
            'valor_unitario': double.tryParse(vlUnit) ?? 0.0,
          }
        ],
        'valor_total': double.tryParse(vlTotalNota) ?? 0.0,
        'data_emissao': dataEmissao,
      };
    }

    // Retorno padrão caso não reconheça o layout
    return {
      'emitente': {'nome': 'Layout Desconhecido', 'cnpj': ''},
      'itens': [],
      'valor_total': 0.0,
      'data_emissao': DateTime.now().toString(),
    };
  }

  static Future<Map<String, dynamic>> salvarAbastecimento(
      Map<String, dynamic> dados) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/salvar_abastecimento.php"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(dados),
      );
      return json.decode(response.body);
    } catch (e) {
      return {"sucesso": false, "mensagem": "Erro ao salvar: $e"};
    }
  }
}
