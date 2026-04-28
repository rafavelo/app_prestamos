import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../core/app_colors.dart';

class PantallaGestionUsuarios extends StatefulWidget {
  const PantallaGestionUsuarios({super.key});
  @override
  State<PantallaGestionUsuarios> createState() => _PantallaGestionUsuariosState();
}

class _PantallaGestionUsuariosState extends State<PantallaGestionUsuarios> {
  void _cambiarEstadoBloqueo(String uid, bool estadoActual) {
    FirebaseFirestore.instance
        .collection('config_usuarios')
        .doc(uid)
        .update({'estaBloqueado': !estadoActual});
  }

  void _extenderLicencia(String uid, int anios) {
    DateTime nuevaFecha = anios == 100
        ? DateTime(2099, 12, 31)
        : DateTime.now().add(Duration(days: 365 * anios));
    FirebaseFirestore.instance.collection('config_usuarios').doc(uid).update({
      'fechaVencimiento': Timestamp.fromDate(nuevaFecha),
      'estaBloqueado': false,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(anios == 100
          ? "Licencia de por vida activada"
          : "Licencia extendida por $anios año(s)"),
      backgroundColor: AppColors.success,
    ));
  }

  void _eliminarUsuario(String uid, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Usuario"),
        content: Text("¿Estás seguro de borrar a:\n$email?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseFirestore.instance.collection('config_usuarios').doc(uid).delete();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Usuario eliminado correctamente"),
                backgroundColor: AppColors.danger,
              ));
            },
            child: const Text("BORRAR"),
          ),
        ],
      ),
    );
  }

  void _editarCorreo(String uid, String correoActual) {
    final correoCtrl = TextEditingController(text: correoActual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Corregir Correo"),
        content: TextField(
            controller: correoCtrl,
            decoration: const InputDecoration(labelText: "Correo Nuevo")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (correoCtrl.text.isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('config_usuarios')
                    .doc(uid)
                    .update({'email': correoCtrl.text.trim()});
                Navigator.pop(ctx);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('config_usuarios')
            .orderBy('fechaRegistro', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final usuarios = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            itemCount: usuarios.length,
            itemBuilder: (ctx, i) {
              final data = usuarios[i].data() as Map<String, dynamic>;
              final uid = usuarios[i].id;
              final email = data['email'] ?? 'Sin correo';
              final esAdmin = data['rol'] == 'admin';
              final bloqueado = data['estaBloqueado'] ?? false;
              final vencimiento =
                  (data['fechaVencimiento'] as Timestamp?)?.toDate() ?? DateTime.now();
              bool estaVencido = DateTime.now().isAfter(vencimiento);
              if (esAdmin) return const SizedBox.shrink();

              Color borderColor = bloqueado
                  ? AppColors.danger
                  : (estaVencido ? AppColors.warning : AppColors.success);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: borderColor.withOpacity(0.15),
                        child: Icon(
                          bloqueado
                              ? Icons.block
                              : (estaVencido ? Icons.timer_off : Icons.person),
                          color: borderColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: bloqueado ? TextDecoration.lineThrough : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          onPressed: () => _editarCorreo(uid, email)),
                      IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                          onPressed: () => _eliminarUsuario(uid, email)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          bloqueado
                              ? "BLOQUEADO"
                              : (estaVencido ? "VENCIDO" : "ACTIVO"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: borderColor,
                          ),
                        ),
                      ),
                      Text(
                        "Vence: ${DateFormat('dd/MM/yyyy').format(vencimiento)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                bloqueado ? AppColors.success : const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _cambiarEstadoBloqueo(uid, bloqueado),
                          icon: Icon(bloqueado ? Icons.lock_open : Icons.lock, size: 16),
                          label: Text(bloqueado ? "Desbloquear" : "Bloquear"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PopupMenuButton<int>(
                          offset: const Offset(0, 40),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.av_timer, color: Colors.white, size: 18),
                                SizedBox(width: 5),
                                Text("Renovar",
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          onSelected: (anios) => _extenderLicencia(uid, anios),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 1, child: Text("📅 + 1 Año")),
                            const PopupMenuItem(value: 2, child: Text("📅 + 2 Años")),
                            const PopupMenuItem(value: 5, child: Text("📅 + 5 Años")),
                            const PopupMenuItem(value: 100, child: Text("♾️ De por vida")),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
