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
            content: Text('El archivo seleccionado está vacío o no se pudo leer.'),
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

        // Si el título está vacío, prellenarlo con el nombre del PDF limpio
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
    final anio = int.tryParse(_anioController.text.trim()) ?? DateTime.now().year;
    final idGenerado = 'LIB-PDF-${DateTime.now().toUtc().microsecondsSinceEpoch}';

    return LibroModel(
      id: idGenerado,
      isbnOCodigo: idGenerado,
      titulo: titulo,
      autor: autor,
      editorial: editorial,
      tipoLibro: tipoFinal,
      anioInicio: anio,
      anioFin: anio,
      palabrasClave: [
        tipoFinal.toLowerCase(),
        autor.toLowerCase(),
        'pdf',
      ],
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
          backgroundColor: resultado.sincronizado ? Colors.green : Colors.amber.shade800,
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
        builder: (_) => PreviewScreen(
          libro: libro,
          biblioteca: widget.biblioteca,
        ),
      ),
    );

    if (guardado == true && mounted) {
      widget.onGuardado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorPrimario = const Color(0xFF283593);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDropZoneCard(theme, colorPrimario),
          const SizedBox(height: 16),
          if (_procesandoPdf) ...[
            _buildProcessingIndicator(),
            const SizedBox(height: 16),
          ],
          if (_resultadoExtraccion != null) ...[
            _buildSummaryCard(theme),
            const SizedBox(height: 16),
            _buildPreviewAccordion(theme),
            const SizedBox(height: 20),
            _buildMetadataForm(theme),
            const SizedBox(height: 24),
            _buildActionButtons(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZoneCard(ThemeData theme, Color colorPrimario) {
    final tieneArchivo = _archivoSeleccionado != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tieneArchivo
              ? const [Color(0xFF181C2E), Color(0xFF101320)]
              : const [Color(0xFF151824), Color(0xFF0E1018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tieneArchivo ? const Color(0xFF6366F1) : const Color(0xFF282C40),
          width: tieneArchivo ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tieneArchivo
                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _procesandoPdf || _guardando ? null : _seleccionarYProcesarPdf,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFF818CF8),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tieneArchivo
                      ? 'Archivo PDF cargado'
                      : 'Subir libro en formato PDF',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F0FB),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tieneArchivo
                      ? 'Toca aquí si deseas cambiar el archivo seleccionado'
                      : 'Selecciona un archivo PDF para extraer su texto y subirlo a la base de datos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF9499B3),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed:
                      _procesandoPdf || _guardando ? null : _seleccionarYProcesarPdf,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.file_upload_outlined, size: 20),
                  label: Text(
                    tieneArchivo ? 'Cambiar archivo PDF' : 'Seleccionar archivo PDF',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF282C40)),
      ),
      padding: const EdgeInsets.all(18),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF818CF8),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extrayendo texto del PDF...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F0FB),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Analizando y procesando cada página del documento',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9499B3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final res = _resultadoExtraccion!;
    final archivo = _archivoSeleccionado!;
    final pesoKb = ((_pesoArchivoBytes ?? 0) / 1024).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF282C40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  archivo.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: Color(0xFFF1F0FB),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$pesoKb KB',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9499B3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                avatar: const Icon(Icons.pages_outlined, size: 16),
                label: Text('${res.totalPaginas} páginas'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.format_size, size: 16),
                label: Text('${res.totalPalabras} palabras'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Texto extraído'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAccordion(ThemeData theme) {
    final res = _resultadoExtraccion!;
    final total = res.paginas.length;
    if (total == 0) return const SizedBox.shrink();

    final paginaActual = res.paginas[_paginaPrevisualizada];

    return Card(
      elevation: 0,
      color: const Color(0xFF141724),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF282C40)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text(
          'Vista previa del texto extraído',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Revisa el contenido de las páginas antes de registrarlo',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
        ),
        leading: const Icon(Icons.article_outlined, color: Color(0xFFC6BFFF)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Página ${_paginaPrevisualizada + 1} de $total',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          visualDensity: VisualDensity.compact,
                          onPressed: _paginaPrevisualizada > 0
                              ? () => setState(() => _paginaPrevisualizada--)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
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
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101116),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF333442)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      paginaActual.texto,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: Color(0xFFD0CBE0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos del documento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _tipoLibro,
            dropdownColor: const Color(0xFF22232E),
            borderRadius: BorderRadius.circular(16),
            menuMaxHeight: 380,
            elevation: 12,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFC6BFFF),
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
                    Icon(icono, size: 20, color: const Color(0xFFC6BFFF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE6E1F5),
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
                            ? const Color(0xFF39345C)
                            : const Color(0xFF2C2D3A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icono,
                        size: 18,
                        color: esSeleccionado
                            ? const Color(0xFFC6BFFF)
                            : const Color(0xFFB9B4C7),
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
                          color: esSeleccionado
                              ? const Color(0xFFE6E1F5)
                              : const Color(0xFFD0CBE0),
                        ),
                      ),
                    ),
                    if (esSeleccionado)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFFC6BFFF),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _tipoLibro = val),
            validator: (val) => val == null ? 'Selecciona un género' : null,
          ),
          if (_tipoLibro == 'Otro') ...[
            const SizedBox(height: 14),
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
                if (_tipoLibro == 'Otro' && (v == null || v.trim().isEmpty)) {
                  return 'Por favor escribe el género del libro';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 14),
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
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _guardando ? null : _guardarDirecto,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _guardando ? 'Guardando en la base de datos...' : 'Guardar y Subir a la Base de Datos',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _guardando ? null : _abrirRevisionCompleta,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.edit_note, size: 20),
          label: const Text('Revisar páginas en detalle antes de subir'),
        ),
      ],
    );
  }
}
