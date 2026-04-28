import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_colors.dart';
import '../core/formatters.dart';
import '../core/theme_manager.dart';
import '../models/prestamo.dart';
import '../widgets/boton_menu.dart';
import 'formulario_prestamo.dart';
import 'gestion_usuarios.dart';
import 'lista_usuarios.dart';
import 'pantalla_historial.dart';
import 'pantalla_pin.dart';
import 'pantalla_analisis.dart';
import 'pantalla_ranking_clientes.dart';
import 'pantalla_simulador.dart';

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});
  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  final User? user = FirebaseAuth.instance.currentUser;
  final String correoSuperAdmin = "rafavelo1991@gmail.com";

  Stream<int> get _conteoVencidosStream {
    return FirebaseFirestore.instance
        .collection('prestamos')
        .where('usuarioId', isEqualTo: user?.uid)
        .where('estaCancelado', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final p = Prestamo.fromMap(doc.data(), doc.id);
        if (p.diasTranscurridos > p.plazoDias) count++;
      }
      return count;
    });
  }

  void _mostrarDetalleAlertas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Clientes con Retraso"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('prestamos')
                .where('usuarioId', isEqualTo: user?.uid)
                .where('estaCancelado', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final prestamos = snapshot.data!.docs
                  .map((d) => Prestamo.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .toList();
              final vencidos =
                  prestamos.where((p) => p.diasTranscurridos > p.plazoDias).toList();
              if (vencidos.isEmpty) return const Text("No hay clientes vencidos.");
              return ListView.builder(
                shrinkWrap: true,
                itemCount: vencidos.length,
                itemBuilder: (ctx, i) {
                  final p = vencidos[i];
                  final diasVencido = p.diasTranscurridos - p.plazoDias;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.danger.withOpacity(0.1),
                          child: const Icon(Icons.warning_rounded,
                              color: AppColors.danger, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                "Vencido hace $diasVencido ${diasVencido == 1 ? 'día' : 'días'}",
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "S/. ${moneyFormat.format(p.montoLiquidarFull)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar"))
        ],
      ),
    );
  }

  void _confirmarCierreSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Estás seguro de que deseas salir?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
            child: const Text("Salir"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool esSuperAdmin = user?.email == correoSuperAdmin;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Panel Principal",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(user?.email ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeManager,
              builder: (context, modo, _) => Icon(
                modo == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
            ),
            tooltip: "Cambiar Tema",
            onPressed: () => themeManager.alternarTema(),
          ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: _mostrarDetalleAlertas,
            ),
            StreamBuilder<int>(
              stream: _conteoVencidosStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == 0) return const SizedBox.shrink();
                return Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('${snapshot.data}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                );
              },
            ),
          ]),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: "Cerrar Sesión",
            onPressed: () => _confirmarCierreSesion(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(children: [
          if (esSuperAdmin)
            _buildAdminBanner(context),

          StreamBuilder<int>(
            stream: _conteoVencidosStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == 0) return const SizedBox.shrink();
              return _buildAlertBanner(snapshot.data!, esOscuro);
            },
          ),

          _buildCloudBadge(esOscuro),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 11,
            childAspectRatio: 0.95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              BotonMenu(
                icon: Icons.person_add_rounded,
                label: 'Agregar\nPréstamo',
                color: AppColors.success,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FormularioPrestamo())),
              ),
              BotonMenu(
                icon: Icons.edit_note_rounded,
                label: 'Modificar\nPréstamo',
                color: AppColors.warning,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ListaUsuarios(modoEdicion: true))),
              ),
              BotonMenu(
                icon: Icons.payments_rounded,
                label: 'Ver y\nCobrar',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ListaUsuarios(modoEdicion: false))),
              ),
              BotonMenu(
                icon: Icons.delete_sweep_rounded,
                label: 'Eliminar\nPréstamo',
                color: AppColors.danger,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ListaUsuarios(modoEliminar: true))),
              ),
              BotonMenu(
                icon: Icons.bar_chart_rounded,
                label: 'Historial\ny Balance',
                color: AppColors.purple,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaHistorial())),
              ),
              BotonMenu(
                icon: Icons.lock_person_rounded,
                label: 'Seguridad\nPIN',
                color: AppColors.teal,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PantallaPin(esConfiguracion: true))),
              ),
              BotonMenu(
                icon: Icons.workspace_premium_rounded,
                label: 'Top\nClientes',
                color: Colors.amber,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaRankingClientes())),
              ),
              BotonMenu(
                icon: Icons.insights_rounded,
                label: 'Análisis',
                color: Colors.cyan.shade700,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaAnalisis())),
              ),
              BotonMenu(
                icon: Icons.calculate_rounded,
                label: 'Simular\nPréstamo',
                color: AppColors.purple,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaSimulador())),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildAdminBanner(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PantallaGestionUsuarios())),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1C1C), Color(0xFF2A2A2A)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(children: [
          Icon(Icons.admin_panel_settings_rounded, size: 32, color: Colors.amber),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Administrador",
                  style: TextStyle(color: Colors.amber, fontSize: 12)),
              Text("Panel de Gestión de Usuarios",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
        ]),
      ),
    );
  }

  Widget _buildAlertBanner(int count, bool esOscuro) {
    return InkWell(
      onTap: _mostrarDetalleAlertas,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(esOscuro ? 0.15 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded, color: AppColors.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                "⚠️ $count ${count == 1 ? 'cliente vencido' : 'clientes vencidos'}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 14),
              ),
              Text("La fecha de pago se venció. Toca para ver.",
                  style: TextStyle(
                      fontSize: 12,
                      color: esOscuro ? Colors.white60 : Colors.black54)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.danger),
        ]),
      ),
    );
  }

  Widget _buildCloudBadge(bool esOscuro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: esOscuro
            ? const Color(0xFF1A1A1A)
            : AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esOscuro
              ? Colors.white.withOpacity(0.06)
              : AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(children: [
        Icon(Icons.cloud_done_rounded,
            size: 28,
            color: esOscuro ? Colors.white70 : AppColors.primary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Modo Cloud Activado",
              style: TextStyle(
                  color: esOscuro ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text("Datos sincronizados en tiempo real",
              style: TextStyle(
                  color: esOscuro ? Colors.white38 : AppColors.accent,
                  fontSize: 12)),
        ]),
      ]),
    );
  }
}
