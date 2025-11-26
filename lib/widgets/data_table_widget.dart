import 'package:flutter/material.dart';

class DataTableWidget extends StatelessWidget {
  final Map<String, String> dados;
  const DataTableWidget({super.key, required this.dados});

  TableRow _row(String label, String value) {
    return TableRow(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      Padding(
          padding: const EdgeInsets.all(12),
          child: Text(value, textAlign: TextAlign.end)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
              borderRadius: BorderRadius.circular(8)),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
          children: [
            _row("Posto", dados['posto'] ?? '-'),
            _row("CNPJ", dados['cnpj'] ?? '-'),
            _row("Combustível", dados['combustivel'] ?? '-'),
            _row("Litros", dados['litros'] ?? '-'),
            _row("R\$/Litro", dados['precoLitro'] ?? '-'),
            _row("Total Pago", dados['total'] ?? '-'),
            _row("Data", dados['data'] ?? '-'),
          ],
        ),
      ),
    );
  }
}
