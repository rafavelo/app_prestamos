import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class PantallaAnalisis extends StatelessWidget {
  const PantallaAnalisis({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Análisis",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.insights_rounded,
              size: 72, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text("Próximamente",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Gráficos de préstamos por mes y año",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }
}
