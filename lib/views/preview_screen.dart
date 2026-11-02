import 'package:flutter/material.dart';

import '../controllers/biblioteca_controller.dart';
import '../models/libro_local.dart';
import '../models/libro_model.dart';
import '../models/pagina_model.dart';
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
  bool _enviando = false;
  String? _error;
  int _folioSeleccionado = 0;
  bool _modoBlancoYNegro = false;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editar Folio ${pag.numeroPagina}',
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
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
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
    if (_enviando) return;
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
    final pagActual = total > 0
        ? paginas[_folioSeleccionado.clamp(0, total - 1)]
        : null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Revisión de Folio',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
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
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_folioSeleccionado + 1} / $total',
                      style: TextStyle(
                        fontSize: 11.5,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    Text(
                      'Diccionario: Castellano · $palabras palabras ($caracteres car.)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (total > 1)
                  Row(
                    children: [
                      InkWell(
                        onTap: _folioSeleccionado > 0
                            ? () => setState(() => _folioSeleccionado--)
                            : null,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: _folioSeleccionado > 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      Text(
                        'Folio ${_folioSeleccionado + 1}r',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      InkWell(
                        onTap: _folioSeleccionado < total - 1
                            ? () => setState(() => _folioSeleccionado++)
                            : null,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: _folioSeleccionado < total - 1
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ],
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

          // Cuerpo desplazable: Mitad superior (Passepartout Scan Frame) + Mitad inferior (Transcripción Editable)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (pagActual != null) ...[
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
                            Container(
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
                                  Text(
                                    '98.6% Confianza · ${pagActual.motor ?? 'Gemini OCR'}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFCF9F4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                    child: Text(
                                      pagActual.texto.trim().isEmpty
                                          ? '[Sin texto detectado en este folio]'
                                          : pagActual.texto.trim(),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Newsreader',
                                        fontSize: 12.5,
                                        height: 1.45,
                                        color: theme.colorScheme.onSurface,
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
                            Text(
                              'Captura: 600 DPI · Sensor Óptico',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Texto Transcrito',
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
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
                      TextButton.icon(
                        onPressed: () =>
                            _editarTextoPagina(_folioSeleccionado),
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
                  const SizedBox(height: 16),
                ],

                // 4. Índice completo de todas las páginas para inspección rápida
                if (total > 1) ...[
                  Text(
                    'ÍNDICE DE FOLIOS CAPTURADOS ($total)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(total, (index) {
                    final pag = paginas[index];
                    final seleccionado = index == _folioSeleccionado;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: seleccionado
                          ? theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.45)
                          : theme.cardTheme.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: seleccionado
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        onTap: () =>
                            setState(() => _folioSeleccionado = index),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                          child: Text(
                            '${pag.numeroPagina}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          'Página ${pag.numeroPagina} (${pag.conteoPalabras} palabras)',
                          style: TextStyle(
                            fontFamily: 'Literata',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.edit_note_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                          tooltip: 'Editar folio',
                          onPressed: () => _editarTextoPagina(index),
                        ),
                      ),
                    );
                  }),
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
                  onPressed: _enviando ? null : _guardar,
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
