import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/biblioteca_controller.dart';
import '../models/libro_local.dart';
import '../models/libro_model.dart';
import '../models/pagina_model.dart';
import '../services/ocr_service.dart';
import 'widgets/backend_connection_sheet.dart';

/// Revisión del texto transcrito antes de guardarlo (local + sync si hay red).
/// Implementa el diseño Stitch "Revisión de Folio OCR" (`6cf20932...`).
class PreviewScreen extends StatefulWidget {
  final LibroModel libro;
  final BibliotecaController biblioteca;

  const PreviewScreen({
    super.key,
    required this.libro,
    required this.biblioteca,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final OcrService _ocr = OcrService();
  final ImagePicker _picker = ImagePicker();

  bool _enviando = false;
  bool _reescaneando = false;
  String? _error;
  int _folioSeleccionado = 0;
  bool _modoBlancoYNegro = false;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  void _normalizarTextoActual(String tipo) {
    if (widget.libro.paginas.isEmpty) return;
    final pag = widget.libro.paginas[_folioSeleccionado];
    String nuevo = pag.texto;

    if (tipo == 's_larga') {
      nuevo = nuevo.replaceAll('ſ', 's');
    } else if (tipo == 'ligaduras') {
      nuevo = nuevo.replaceAll('æ', 'ae').replaceAll('œ', 'oe');
    } else if (tipo == 'saltos') {
      nuevo = nuevo
          .replaceAll(RegExp(r'-\s*\n\s*'), '')
          .replaceAll(RegExp(r'[ \t]+'), ' ');
    }

    if (nuevo != pag.texto) {
      setState(() {
        widget.libro.paginas[_folioSeleccionado] = pag.copyWith(
          texto: nuevo,
          conteoPalabras: PaginaModel.contarPalabras(nuevo),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Normalización tipográfica aplicada al folio'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El folio ya se encuentra normalizado'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _volverAEscanearPagina(int index) async {
    if (_reescaneando || _enviando) return;
    if (index < 0 || index >= widget.libro.paginas.length) return;

    final pag = widget.libro.paginas[index];
    final theme = Theme.of(context);

    final ImageSource? fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.document_scanner_outlined,
                        color: theme.colorScheme.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volver a escanear Hoja ${pag.numeroPagina}',
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'El nuevo texto reemplazará el contenido actual de esta hoja',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  title: const Text(
                    'Tomar nueva foto con cámara',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Capturar nuevamente la página directamente',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  title: const Text(
                    'Seleccionar imagen de la galería',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Elegir una foto existente en el dispositivo',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (fuente == null || !mounted) return;

    try {
      final XFile? archivo = await _picker.pickImage(
        source: fuente,
        imageQuality: 80,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (archivo == null || !mounted) return;

      setState(() {
        _reescaneando = true;
        _folioSeleccionado = index;
      });

      try {
        final resultado = await _ocr.procesarImagenDetallado(archivo.path);
        final nuevoTexto = (resultado['texto'] as String? ?? '').trim();
        final motor = resultado['motor'] as String? ?? 'Gemini (Backend)';
        final palabras = PaginaModel.contarPalabras(nuevoTexto);

        if (!mounted) return;
        setState(() {
          widget.libro.paginas[index] = pag.copyWith(
            texto: nuevoTexto,
            conteoPalabras: palabras,
            motor: motor,
          );
          _reescaneando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoTexto.isEmpty
                  ? 'Hoja ${pag.numeroPagina} reescaneada (sin texto detectado)'
                  : '✓ Hoja ${pag.numeroPagina} actualizada ($palabras palabras)',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        if (fuente == ImageSource.camera) {
          try {
            final temp = File(archivo.path);
            if (await temp.exists()) await temp.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _reescaneando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: theme.colorScheme.error,
          content: Text('Error al volver a escanear la hoja: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _eliminarPagina(int index) async {
    if (_reescaneando || _enviando) return;
    if (index < 0 || index >= widget.libro.paginas.length) return;

    final pag = widget.libro.paginas[index];
    final theme = Theme.of(context);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
          size: 36,
        ),
        title: Text(
          '¿Eliminar Hoja ${pag.numeroPagina}?',
          style: const TextStyle(fontFamily: 'Literata', fontSize: 18),
        ),
        content: Text(
          widget.libro.paginas.length == 1
              ? 'Esta es la única hoja capturada. Si la eliminas, regresarás a la cámara para escanear de nuevo.'
              : 'Se eliminará la Hoja ${pag.numeroPagina} (${pag.conteoPalabras} palabras) y las demás hojas se reenumerarán automáticamente.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      widget.libro.paginas.removeAt(index);
      for (int i = 0; i < widget.libro.paginas.length; i++) {
        final numPag = i + 1;
        widget.libro.paginas[i] = widget.libro.paginas[i].copyWith(
          numeroPagina: numPag,
          nombreArchivo: 'pagina_${numPag.toString().padLeft(3, '0')}.txt',
        );
      }
      if (_folioSeleccionado >= widget.libro.paginas.length) {
        _folioSeleccionado =
            (widget.libro.paginas.length - 1).clamp(0, 999999);
      }
    });

    if (widget.libro.paginas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se eliminaron todas las hojas. Regresando al escáner.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hoja ${pag.numeroPagina} eliminada'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editarTextoPagina(int index) async {
    final pag = widget.libro.paginas[index];
    final controller = TextEditingController(text: pag.texto);
    final theme = Theme.of(context);

    final nuevoTexto = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: theme.colorScheme.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Editar Folio ${pag.numeroPagina}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Literata',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Corrige erratas o ligaduras mal detectadas',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'Newsreader',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe o edita el texto del folio...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(controller.text),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (nuevoTexto != null && nuevoTexto != pag.texto && mounted) {
      setState(() {
        widget.libro.paginas[index] = pag.copyWith(
          texto: nuevoTexto,
          conteoPalabras: PaginaModel.contarPalabras(nuevoTexto),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Folio ${pag.numeroPagina} actualizado'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _guardar() async {
    if (_enviando || _reescaneando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final ResultadoGuardado resultado = await widget.biblioteca.guardarLibro(
        widget.libro,
      );
      if (!mounted) return;

      final icono = resultado.sincronizado
          ? Icons.cloud_done_rounded
          : Icons.phone_android_rounded;
      final titulo = resultado.sincronizado
          ? 'Guardado y sincronizado'
          : 'Guardado en el dispositivo';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: Icon(
            icono,
            color: Theme.of(context).colorScheme.secondary,
            size: 40,
          ),
          title: Text(
            titulo,
            style: const TextStyle(fontFamily: 'Literata'),
          ),
          content: Text(
            '${resultado.mensaje}\n\n"${widget.libro.titulo}" con '
            '${pags(widget.libro.paginas.length)}.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paginas = widget.libro.paginas;
    final total = paginas.length;
    final caracteres = paginas.fold<int>(0, (sum, p) => sum + p.texto.length);
    final palabras = paginas.fold<int>(0, (sum, p) => sum + p.conteoPalabras);
    final indiceSeguro = total > 0 ? _folioSeleccionado.clamp(0, total - 1) : 0;
    final pagActual = total > 0 ? paginas[indiceSeguro] : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Flexible(
                  child: Text(
                    'Revisión de Folio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'OCR ACTIVO',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              widget.libro.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (total > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 13,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${indiceSeguro + 1} / $total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Conexión del backend',
            onPressed: () => showBackendConnectionSheet(
              context,
              onRetry: () async => setState(() {}),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-barra de Diccionario & Selector de Folios (Stitch)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Castellano · $palabras palabras ($caracteres car.)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (total > 1) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: indiceSeguro > 0
                            ? () => setState(
                                () => _folioSeleccionado = indiceSeguro - 1,
                              )
                            : null,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: indiceSeguro > 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      Text(
                        'Folio ${indiceSeguro + 1}r',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      InkWell(
                        onTap: indiceSeguro < total - 1
                            ? () => setState(
                                () => _folioSeleccionado = indiceSeguro + 1,
                              )
                            : null,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: indiceSeguro < total - 1
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Selector de páginas escaneadas AL INICIO (fijo y cómodo para cambiar de hoja)
          if (total > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PÁGINAS ESCANEADAS ($total)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      Text(
                        'Toca una hoja para revisarla',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontStyle: FontStyle.italic,
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: total,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final pag = paginas[index];
                        final seleccionado = index == indiceSeguro;
                        final resumen = pag.texto.trim().isEmpty
                            ? 'Sin texto'
                            : pag.texto
                                .trim()
                                .replaceAll(RegExp(r'\s+'), ' ');

                        return InkWell(
                          onTap: () =>
                              setState(() => _folioSeleccionado = index),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 145,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: seleccionado
                                  ? theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.55)
                                  : theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: seleccionado
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.outlineVariant,
                                width: seleccionado ? 1.6 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: seleccionado
                                                ? theme.colorScheme.secondary
                                                : theme.colorScheme
                                                    .surfaceContainerHighest,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${pag.numeroPagina}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: seleccionado
                                                  ? theme
                                                      .colorScheme.onSecondary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hoja ${pag.numeroPagina}',
                                          style: TextStyle(
                                            fontFamily: 'Literata',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${pag.conteoPalabras} pal.',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: seleccionado
                                            ? theme.colorScheme.secondary
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  resumen,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.error),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _enviando ? null : _guardar,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),

          // Cuerpo desplazable: Acciones de la hoja + Marco Passepartout + Transcripción Editable
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (pagActual != null) ...[
                  // Barra rápida de acciones para la hoja seleccionada (Reescanear, Editar, Eliminar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Hoja ${pagActual.numeroPagina}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 0,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _accionHojaBtn(
                                  theme: theme,
                                  icon: _reescaneando
                                      ? Icons.sync_rounded
                                      : Icons.camera_alt_outlined,
                                  label: _reescaneando
                                      ? 'Escaneando...'
                                      : 'Volver a escanear',
                                  onTap: _reescaneando
                                      ? null
                                      : () =>
                                          _volverAEscanearPagina(indiceSeguro),
                                ),
                                const SizedBox(width: 6),
                                _accionHojaBtn(
                                  theme: theme,
                                  icon: Icons.edit_outlined,
                                  label: 'Editar',
                                  onTap: _reescaneando
                                      ? null
                                      : () => _editarTextoPagina(indiceSeguro),
                                ),
                                const SizedBox(width: 6),
                                _accionHojaBtn(
                                  theme: theme,
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Eliminar',
                                  esPeligro: true,
                                  onTap: _reescaneando
                                      ? null
                                      : () => _eliminarPagina(indiceSeguro),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Mitad Superior: Marco Passepartout con Facsímil del Folio y Bounding Box OCR
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF241D1A)
                          : const Color(0xFFE8DECA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Barra superior dentro del Passepartout
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C1810)
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '98.6% Confianza · ${pagActual.motor ?? 'Gemini OCR'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFCF9F4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Conmutador Color / B&N
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1810)
                                    .withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _modoBlancoYNegro = false,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: !_modoBlancoYNegro
                                            ? const Color(0xFF8C4E26)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Color',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFCF9F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _modoBlancoYNegro = true,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _modoBlancoYNegro
                                            ? const Color(0xFF8C4E26)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'B/N',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFCF9F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Simulación del pliego físico con cajas de detección OCR
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _modoBlancoYNegro
                                ? (isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white)
                                : (isDark
                                    ? const Color(0xFF1C1613)
                                    : const Color(0xFFF6EFE2)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8C4E26)
                                  .withValues(alpha: 0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '— FOLIO ${pagActual.numeroPagina} —',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Literata',
                                  fontSize: 10,
                                  letterSpacing: 2.0,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.colorScheme.secondary,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: _reescaneando
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: theme
                                                      .colorScheme.secondary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Transcribiendo nueva captura...',
                                                style: TextStyle(
                                                  fontFamily: 'Newsreader',
                                                  fontStyle: FontStyle.italic,
                                                  fontSize: 13,
                                                  color: theme
                                                      .colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            pagActual.texto.trim().isEmpty
                                                ? '[Sin texto detectado en este folio]'
                                                : pagActual.texto.trim(),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Newsreader',
                                              fontSize: 12.5,
                                              height: 1.45,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    top: -8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'BLOQUE ENFOCADO',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                          color: Color(0xFFFCF9F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Captura: 600 DPI · Sensor Óptico',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${pagActual.conteoPalabras} palabras en folio',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Cabecera de Transcripción + Herramientas de Normalización Histórica
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: theme.colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Texto Transcrito',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Literata',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Editable',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editarTextoPagina(indiceSeguro),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar folio'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.secondary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Barra de chips de normalización histórica (Stitch)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _normChip(
                          theme,
                          prefix: 'ſ → s',
                          label: 'S-larga',
                          onTap: () => _normalizarTextoActual('s_larga'),
                        ),
                        const SizedBox(width: 8),
                        _normChip(
                          theme,
                          prefix: 'æ / œ',
                          label: 'Ligaduras',
                          onTap: () => _normalizarTextoActual('ligaduras'),
                        ),
                        const SizedBox(width: 8),
                        _normChip(
                          theme,
                          prefix: '¶',
                          label: 'Unir guiones de salto',
                          onTap: () => _normalizarTextoActual('saltos'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Pozo de Pergamino del Folio Activo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FOLIO ${pagActual.numeroPagina}',
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            Text(
                              pagActual.nombreArchivo,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          color: theme.colorScheme.outlineVariant,
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          pagActual.texto.trim().isEmpty
                              ? '[Sin texto detectado]'
                              : pagActual.texto,
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 15,
                            height: 1.65,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Barra inferior fija de guardado y sincronización
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: (_enviando || _reescaneando) ? null : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _enviando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.task_alt_rounded),
                  label: Text(
                    _enviando
                        ? 'Guardando y sincronizando...'
                        : 'Confirmar y Guardar Libro',
                    style: const TextStyle(
                      fontFamily: 'Literata',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionHojaBtn({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool esPeligro = false,
  }) {
    final color = esPeligro
        ? theme.colorScheme.error
        : theme.colorScheme.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _normChip(
    ThemeData theme, {
    required String prefix,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prefix,
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String pags(int n) => n == 1 ? '1 página' : '$n páginas';
}
