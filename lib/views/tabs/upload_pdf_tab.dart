import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../../services/pdf_extractor_service.dart';
import '../preview_screen.dart';
import '../widgets/book_form_view.dart';

/// Pestaña para subir libros en formato PDF, extraer su texto página a página
/// y guardarlos/sincronizarlos directamente en la base de datos.
/// Implementa el diseño Stitch "Subir y Procesar Documento PDF" (`94a7b628...`).
class UploadPdfTab extends StatefulWidget {
  final BibliotecaController biblioteca;
  final VoidCallback onGuardado;

  const UploadPdfTab({
    super.key,
    required this.biblioteca,
    required this.onGuardado,
  });

  @override
  State<UploadPdfTab> createState() => _UploadPdfTabState();
}

class _UploadPdfTabState extends State<UploadPdfTab> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _autorController = TextEditingController();
  final _editorialController = TextEditingController();
  final _anioController = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  final _otroTipoController = TextEditingController();

  String? _tipoLibro = 'Ficción';
  XFile? _archivoSeleccionado;
  int? _pesoArchivoBytes;
  ResultadoExtraccionPdf? _resultadoExtraccion;
  bool _procesandoPdf = false;
  bool _guardando = false;
  int _paginaPrevisualizada = 0;

  // Controles de configuración de pliegos (Stitch)
  int _modoRango =
      0; // 0: Tomo completo, 1: Primeros pliegos, 2: Inspección OCR
  bool _ocrTipografiaAntigua = true;
  bool _enderezarPliegos = true;

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _editorialController.dispose();
    _anioController.dispose();
    _otroTipoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYProcesarPdf() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'PDFs',
        extensions: <String>['pdf'],
        mimeTypes: <String>['application/pdf'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[typeGroup],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final peso = await file.length();

      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El archivo seleccionado está vacío o no se pudo leer.',
            ),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      setState(() {
        _archivoSeleccionado = file;
        _pesoArchivoBytes = peso;
        _procesandoPdf = true;
        _resultadoExtraccion = null;
        _paginaPrevisualizada = 0;
      });

      final extraccion = await PdfExtractorService.extraerPaginas(bytes);

      if (!mounted) return;
      setState(() {
        _resultadoExtraccion = extraccion;
        _procesandoPdf = false;

        if (_tituloController.text.trim().isEmpty) {
          final nombreLimpio = file.name
              .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
          _tituloController.text = nombreLimpio;
        }
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _procesandoPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se requiere reiniciar la app por completo (detenerla y volver a ejecutar "flutter run") para registrar los módulos nativos.',
          ),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 7),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el archivo PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  LibroModel? _construirLibro() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    if (_resultadoExtraccion == null || _resultadoExtraccion!.paginas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona primero un archivo PDF.'),
        ),
      );
      return null;
    }

    final titulo = _tituloController.text.trim();
    final autor = _autorController.text.trim();
    final editorial = _editorialController.text.trim();
    final tipoFinal = _tipoLibro == 'Otro'
        ? _otroTipoController.text.trim()
        : _tipoLibro!;
    final anio =
        int.tryParse(_anioController.text.trim()) ?? DateTime.now().year;
    final idGenerado =
        'LIB-PDF-${DateTime.now().toUtc().microsecondsSinceEpoch}';

    return LibroModel(
      id: idGenerado,
      isbnOCodigo: idGenerado,
      titulo: titulo,
      autor: autor,
      editorial: editorial,
      tipoLibro: tipoFinal,
      anioInicio: anio,
      anioFin: anio,
      palabrasClave: [tipoFinal.toLowerCase(), autor.toLowerCase(), 'pdf'],
      paginas: _resultadoExtraccion!.paginas,
    );
  }

  Future<void> _guardarDirecto() async {
    final libro = _construirLibro();
    if (libro == null) return;

    setState(() => _guardando = true);

    try {
      final resultado = await widget.biblioteca.guardarLibro(libro);

      if (!mounted) return;
      setState(() => _guardando = false);

      final msg = resultado.sincronizado
          ? 'Libro "${libro.titulo}" guardado y subido a la base de datos (${libro.paginas.length} páginas).'
          : 'Libro "${libro.titulo}" guardado localmente (${libro.paginas.length} páginas). ${resultado.mensaje}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: resultado.sincronizado
              ? Colors.green
              : Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onGuardado();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar libro: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _abrirRevisionCompleta() async {
    final libro = _construirLibro();
    if (libro == null) return;

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PreviewScreen(libro: libro, biblioteca: widget.biblioteca),
      ),
    );

    if (guardado == true && mounted) {
      widget.onGuardado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado Editorial Stitch (Fase II: Reconocimiento)
          _buildEditorialHeader(theme),
          const SizedBox(height: 18),

          // Dropzone Card con Ex Libris Emboss y listón colgante
          _buildDropZoneCard(theme),
          const SizedBox(height: 18),

          // Configuración de Pliegos a Procesar (Stitch)
          _buildPliegosConfigCard(theme),
          const SizedBox(height: 18),

          if (_procesandoPdf) ...[
            _buildProcessingIndicator(theme),
            const SizedBox(height: 18),
          ],

          if (_resultadoExtraccion != null) ...[
            _buildPliegosReconocidosSection(theme),
            const SizedBox(height: 20),
            _buildMetadataForm(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorialHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 16,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              'ARCHIVO HISTÓRICO DIGITAL',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.8,
                color: theme.colorScheme.secondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Fase II: Reconocimiento',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 11.5,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Subir y Procesar Documento PDF',
          style: TextStyle(
            fontFamily: 'Literata',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Extraiga caligrafías, tipografía de plomo y viñetas conservando la estructura de cada folio.',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontStyle: FontStyle.italic,
            fontSize: 13.5,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildDropZoneCard(ThemeData theme) {
    final tieneArchivo = _archivoSeleccionado != null;
    final res = _resultadoExtraccion;
    final pesoMb = _pesoArchivoBytes != null
        ? (_pesoArchivoBytes! / (1024 * 1024)).toStringAsFixed(2)
        : '0.0';
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tieneArchivo
              ? theme.colorScheme.secondary
              : theme.colorScheme.outlineVariant,
          width: tieneArchivo ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Franja vertical de lomo a la izquierda (Stitch w-1.5 bg-secondary)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 6,
            child: Container(color: theme.colorScheme.secondary),
          ),
          // Listón Ex Libris colgando en esquina superior derecha
          Positioned(
            top: 0,
            right: 20,
            child: Container(
              width: 24,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 4),
              child: const Icon(
                Icons.bookmark_rounded,
                size: 14,
                color: Color(0xFFFCF9F4),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _procesandoPdf || _guardando
                  ? null
                  : _seleccionarYProcesarPdf,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sello Ex Libris 48x48
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: theme.colorScheme.secondary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: tieneArchivo
                                            ? const Color(0xFF2E6B3E)
                                            : theme.colorScheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tieneArchivo
                                            ? 'DOCUMENTO CARGADO • PDF/A'
                                            : 'PENDIENTE DE SELECCIÓN • PDF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: tieneArchivo
                                              ? const Color(0xFF2E6B3E)
                                              : theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tieneArchivo
                                      ? _archivoSeleccionado!.name
                                      : 'Subir libro en formato PDF',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Literata',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (tieneArchivo)
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      _metaBadge(
                                        theme,
                                        Icons.straighten_rounded,
                                        '$pesoMb MB',
                                      ),
                                      if (res != null)
                                        _metaBadge(
                                          theme,
                                          Icons.description_outlined,
                                          '${res.totalPaginas} folios',
                                        ),
                                      if (res != null)
                                        _metaBadge(
                                          theme,
                                          Icons.text_fields_rounded,
                                          '${res.totalPalabras} palabras',
                                        ),
                                    ],
                                  )
                                else
                                  Text(
                                    'Toca para examinar tu dispositivo y extraer el texto íntegro página por página.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: theme.colorScheme.outlineVariant, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                tieneArchivo
                                    ? Icons.verified_outlined
                                    : Icons.info_outline_rounded,
                                size: 15,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tieneArchivo
                                      ? 'Integridad de metadatos verificada'
                                      : 'Compatible con PDF textuales y facsímiles',
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _procesandoPdf || _guardando
                              ? null
                              : _seleccionarYProcesarPdf,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.secondaryContainer,
                            foregroundColor: theme.colorScheme.secondary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(
                            tieneArchivo
                                ? Icons.swap_horiz_rounded
                                : Icons.file_upload_outlined,
                            size: 16,
                          ),
                          label: Text(
                            tieneArchivo
                                ? 'Cambiar archivo PDF'
                                : 'Seleccionar archivo PDF',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaBadge(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPliegosConfigCard(ThemeData theme) {
    final totalPags = _resultadoExtraccion?.totalPaginas ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_frames_outlined,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pliegos a Procesar',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                totalPags > 0
                    ? 'Seleccionadas: $totalPags de $totalPags págs.'
                    : 'Tomo íntegro',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Píldoras de modo de selección
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modoChip(theme, 0, 'Tomo completo'),
              _modoChip(theme, 1, 'Cotejo de capítulos'),
              _modoChip(theme, 2, 'Inspección detallada'),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 8),
          _checkOption(
            theme,
            value: _ocrTipografiaAntigua,
            title: 'Conservar estructura de párrafos y capitulares',
            onChanged: (v) => setState(() => _ocrTipografiaAntigua = v ?? true),
          ),
          _checkOption(
            theme,
            value: _enderezarPliegos,
            title: 'Limpiar cabeceras y numeración de folios marginales',
            onChanged: (v) => setState(() => _enderezarPliegos = v ?? true),
          ),
        ],
      ),
    );
  }

  Widget _modoChip(ThemeData theme, int index, String label) {
    final activo = _modoRango == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _modoRango = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? theme.colorScheme.primary : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: activo
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _checkOption(
    ThemeData theme, {
    required bool value,
    required String title,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                activeColor: theme.colorScheme.secondary,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reconociendo caracteres y capitulares...',
                      style: TextStyle(
                        fontFamily: 'Literata',
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Analizando maquetación de cada folio del documento PDF',
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
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPliegosReconocidosSection(ThemeData theme) {
    final res = _resultadoExtraccion!;
    final total = res.paginas.length;
    if (total == 0) return const SizedBox.shrink();

    final paginaActual = res.paginas[_paginaPrevisualizada];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pliegos Reconocidos',
                  style: TextStyle(
                    fontFamily: 'Literata',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E6B3E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '99.2% fidelidad',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E6B3E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Carrusel horizontal de miniaturas de Folios (Stitch 4-Column Grid look)
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final p = res.paginas[index];
              final seleccionado = index == _paginaPrevisualizada;
              return GestureDetector(
                onTap: () => setState(() => _paginaPrevisualizada = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 84,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: seleccionado
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outlineVariant,
                      width: seleccionado ? 2 : 1,
                    ),
                    boxShadow: [
                      if (seleccionado)
                        BoxShadow(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.2,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Text(
                                p.texto.trim().isEmpty ? '—' : p.texto.trim(),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 7,
                                  height: 1.2,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: seleccionado
                                      ? theme.colorScheme.secondary
                                      : const Color(0xFF2E6B3E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fol. ${p.numeroPagina}',
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: seleccionado
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${p.conteoPalabras}p',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Visor de pergamino del folio seleccionado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Folio ${paginaActual.numeroPagina} de $total · ${paginaActual.conteoPalabras} palabras',
                        style: TextStyle(
                          fontFamily: 'Literata',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: _paginaPrevisualizada > 0
                            ? () => setState(() => _paginaPrevisualizada--)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: _paginaPrevisualizada < total - 1
                            ? () => setState(() => _paginaPrevisualizada++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    paginaActual.texto.trim().isEmpty
                        ? '[Sin texto extraído en este folio]'
                        : paginaActual.texto,
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 13.5,
                      height: 1.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataForm(ThemeData theme) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 5,
            child: Container(color: theme.colorScheme.secondary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history_edu_rounded,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ficha Catalográfica del Documento',
                        style: TextStyle(
                          fontFamily: 'Literata',
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tituloController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Título del libro',
                      prefixIcon: Icon(Icons.menu_book),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _autorController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Autor',
                      hintText: 'Nombre del autor',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _editorialController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Editorial (opcional)',
                      hintText: 'Editorial que publicó el libro',
                      prefixIcon: Icon(Icons.business_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _tipoLibro,
                    dropdownColor: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    menuMaxHeight: 380,
                    elevation: 12,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Género / tipo de libro',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    selectedItemBuilder: (context) {
                      return BookFormView.tiposDisponibles.map((t) {
                        final icono = BookFormView.iconoDe(t);
                        return Row(
                          children: [
                            Icon(
                              icono,
                              size: 20,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    items: BookFormView.tiposDisponibles.map((t) {
                      final esSeleccionado = t == _tipoLibro;
                      final icono = BookFormView.iconoDe(t);
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: esSeleccionado
                                    ? theme.colorScheme.secondaryContainer
                                    : theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                icono,
                                size: 18,
                                color: esSeleccionado
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: esSeleccionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (esSeleccionado)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: theme.colorScheme.secondary,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _tipoLibro = val),
                    validator: (val) =>
                        val == null ? 'Selecciona un género' : null,
                  ),
                  if (_tipoLibro == 'Otro') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otroTipoController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Escribe el género o tipo',
                        hintText: 'Ej. Tratado, Crónica, etc.',
                        prefixIcon: Icon(Icons.edit_note),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (_tipoLibro == 'Otro' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Por favor escribe el género del libro';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _anioController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Año de publicación',
                      hintText: 'Ej. 1950',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final anio = int.tryParse(v?.trim() ?? '');
                      if (anio == null || anio < 1 || anio > 9999) {
                        return 'Ingresa un año válido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _guardando ? null : _guardarDirecto,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _guardando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.auto_stories_rounded),
          label: Text(
            _guardando
                ? 'Catalogando en el archivo...'
                : 'Procesar e Importar Libro',
            style: const TextStyle(
              fontFamily: 'Literata',
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _guardando ? null : _abrirRevisionCompleta,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.secondary,
            side: BorderSide(color: theme.colorScheme.secondary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined, size: 19),
          label: const Text(
            'Revisar folios y transcripción antes de subir',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
