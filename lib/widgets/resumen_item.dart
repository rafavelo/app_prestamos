import 'package:flutter/material.dart';

class ResumenItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const ResumenItem(this.label, this.valor, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text(valor,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
