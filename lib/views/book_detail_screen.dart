import 'package:flutter/material.dart';

import '../models/libro_model.dart';
import '../services/api_service.dart';

class BookDetailScreen extends StatefulWidget {
  final String idLibro;
  final String titulo;
  final LibroModel? libroLocal;
  final String? errorSync;

  const BookDetailScreen({
    super.key,
    required this.idLibro,
    required this.titulo,
    this.libroLocal,
    this.errorSync,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _cargando = false;
  LibroModel? _libro;
  String? _error;
  String? _errorSync;

  @override
  void initState() {
    super.initState();
    _libro = widget.libroLocal;
    _errorSync = widget.errorSync;
    if (widget.libroLocal == null) {
      _cargarDetalle();
    }
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final libro = await ApiService.obtenerDetalleLibro(widget.idLibro);
      if (mounted) {
        setState(() {
          _libro = libro;
          _cargando = false;
          if (libro == null) {
            _error = 'No se encontró el documento en el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de conexión: $e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _eliminar() async {
    final libro = _libro;
    if (libro == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Seguro que quieres eliminar "${libro.titulo}"? Esta acción no se '
          'puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await ApiService.eliminarLibro(libro.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Documento eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo, style: const TextStyle(fontSize: 18)),
        actions: [
          if (_libro != null && widget.libroLocal == null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar documento',
              onPressed: _eliminar,
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cargarDetalle,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _construirDetalle(),
    );
  }

  Widget _construirDetalle() {
    final libro = _libro!;
    final paginas = libro.paginas;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.libroLocal != null) ...[
          Card(
            color: colors.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guardado en este dispositivo; aún no está en el servidor.',
                    style: TextStyle(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_errorSync != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'Error de subida: $_errorSync',
                      style: TextStyle(color: colors.onTertiaryContainer),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libro.titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        libro.autor.isNotEmpty
                            ? 'Autor: ${libro.autor}'
                            : 'Autor no especificado',
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (libro.editorial.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Editorial: ${libro.editorial}',
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      libro.anioInicio == libro.anioFin
                          ? 'Año de publicación: ${libro.anioInicio}'
                          : 'Periodo: ${libro.anioInicio} - ${libro.anioFin}',
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.category, size: 18, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Tipo: ${libro.tipoLibro}',
                      style: TextStyle(color: colors.onSurface),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricItem(
                      'Páginas',
                      '${paginas.length}',
                      Icons.auto_stories,
                    ),
                    _metricItem('Año', '${libro.anioInicio}', Icons.event),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Páginas Digitalizadas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (paginas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No hay páginas registradas para este documento.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...paginas.map(
            (pag) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    '${pag.numeroPagina}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text('Página ${pag.numeroPagina}'),
                subtitle: Text('${pag.conteoPalabras} palabras transcritas'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText(
                      pag.texto.trim().isEmpty
                          ? '[Sin texto transcrito]'
                          : pag.texto,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _metricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF3F51B5), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
