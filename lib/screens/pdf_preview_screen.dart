import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_colors.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final List<Uint8List> _pages = [];
  bool _loading = true;
  int _currentPage = 0;
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _rasterearPaginas();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _rasterearPaginas() async {
    await for (final page in Printing.raster(widget.pdfBytes, dpi: 160)) {
      final png = await page.toPng();
      if (mounted) setState(() => _pages.add(png));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.fileName,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          if (_pages.isNotEmpty)
            Text('Pág. ${_currentPage + 1} de ${_pages.length}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.normal)),
        ]),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            tooltip: 'Compartir',
            onPressed: () => Printing.sharePdf(
                bytes: widget.pdfBytes, filename: widget.fileName),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Imprimir',
            onPressed: () =>
                Printing.layoutPdf(onLayout: (_) async => widget.pdfBytes),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
            tooltip: 'Guardar',
            onPressed: () => _guardarLocalmente(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color(0xFF525659),
      body: _loading && _pages.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _pages.length,
              itemBuilder: (ctx, i) => InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        _pages[i],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _guardarLocalmente(BuildContext context) async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (!storage.isGranted) await Permission.storage.request();
    }

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }

      final path = directory?.path ?? '';
      String finalFileName = widget.fileName;
      final fileToCheck = File('$path/$finalFileName');
      if (await fileToCheck.exists()) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final name = widget.fileName.replaceAll('.pdf', '');
        finalFileName = '${name}_$ts.pdf';
      }

      final file = File('$path/$finalFileName');
      await file.writeAsBytes(widget.pdfBytes, flush: true);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Guardado: $finalFileName'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'ABRIR',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(file.path),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }
}
