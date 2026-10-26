import 'package:flutter/material.dart';

import '../models/libro_model.dart';
import '../services/api_service.dart';
import '../services/local_user_preferences_store.dart';
import 'reading_mode_screen.dart';

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
  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();
  bool _cargando = false;
  LibroModel? _libro;
  String? _error;
  String? _errorSync;
  ProgresoLectura? _progreso;
  bool _esFavorito = false;

  @override
  void initState() {
    super.initState();
    _libro = widget.libroLocal;
    _errorSync = widget.errorSync;
    _cargarPreferencias();
    if (widget.libroLocal == null) {
      _cargarDetalle();
    }
  }

  Future<void> _cargarPreferencias() async {
    try {
      final prog = await _prefs.obtenerProgreso(widget.idLibro);
      final fav = await _prefs.esFavorito(widget.idLibro);
      if (mounted) {
        setState(() {
          _progreso = prog;
          _esFavorito = fav;
        });
      }
    } catch (_) {}
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

  Future<void> _abrirModoLectura(LibroModel libro, {int desde = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingModeScreen(
          libro: libro,
          idLibro: widget.idLibro,
          paginaInicial: desde,
        ),
      ),
    );
    if (mounted) {
      await _cargarPreferencias();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
              _esFavorito ? Icons.star_rounded : Icons.star_border_rounded,
              color: _esFavorito ? const Color(0xFFF59E0B) : const Color(0xFF9499B3),
            ),
            tooltip: _esFavorito ? 'Quitar de favoritos' : 'Marcar como favorito',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nuevoFav = await _prefs.alternarFavorito(widget.idLibro);
              if (!mounted) return;
              setState(() => _esFavorito = nuevoFav);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    nuevoFav ? 'Libro agregado a favoritos ⭐' : 'Libro eliminado de favoritos',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.libroLocal != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1912),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.5),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: Colors.amber.shade300, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guardado en este dispositivo; aún no está en el servidor.',
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_errorSync != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Error de subida: $_errorSync',
                    style: const TextStyle(color: Color(0xFFC7BBA8), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF26293A), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      libro.titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF1F0FB),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 18, color: Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      libro.autor.isNotEmpty
                          ? 'Autor: ${libro.autor}'
                          : 'Autor no especificado',
                      style: const TextStyle(color: Color(0xFFD4D8EE), fontSize: 13.5),
                    ),
                  ),
                ],
              ),
              if (libro.editorial.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.business_rounded, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editorial: ${libro.editorial}',
                        style: const TextStyle(color: Color(0xFFD4D8EE), fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFA855F7)),
                  const SizedBox(width: 8),
                  Text(
                    libro.anioInicio == libro.anioFin
                        ? 'Año de publicación: ${libro.anioInicio}'
                        : 'Periodo: ${libro.anioInicio} - ${libro.anioFin}',
                    style: const TextStyle(color: Color(0xFFD4D8EE), fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_rounded, size: 18, color: Color(0xFF34D399)),
                  const SizedBox(width: 8),
                  Text(
                    'Tipo: ${libro.tipoLibro}',
                    style: const TextStyle(color: Color(0xFFD4D8EE), fontSize: 13.5),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Color(0xFF26293A), height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: _metricItem(
                      'Páginas',
                      '${paginas.length}',
                      Icons.auto_stories_rounded,
                      const Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricItem(
                      'Año',
                      '${libro.anioInicio}',
                      Icons.event_rounded,
                      const Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
              if (_progreso != null && _progreso!.totalPaginas > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFF26293A), height: 1),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progreso de lectura',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC6BFFF),
                          ),
                        ),
                        Text(
                          'Página ${_progreso!.ultimaPagina + 1} de ${_progreso!.totalPaginas} (${_progreso!.porcentajeEntero}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9499B3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progreso!.porcentaje,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF222638),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Páginas Digitalizadas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF1F0FB),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (paginas.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: () => _abrirModoLectura(
                    libro,
                    desde: (_progreso != null && _progreso!.ultimaPagina > 0)
                        ? _progreso!.ultimaPagina
                        : 0,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: Icon(
                    (_progreso != null && _progreso!.ultimaPagina > 0)
                        ? Icons.play_arrow_rounded
                        : Icons.chrome_reader_mode_outlined,
                    size: 18,
                  ),
                  label: Text(
                    (_progreso != null && _progreso!.ultimaPagina > 0)
                        ? 'Continuar (Pág. ${_progreso!.ultimaPagina + 1})'
                        : 'Modo lectura',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (paginas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No hay páginas registradas para este documento.',
                style: TextStyle(color: Color(0xFF8B8FA8)),
              ),
            ),
          )
        else
          ...paginas.map(
            (pag) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFF141724),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF26293A)),
              ),
              child: ExpansionTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${pag.numeroPagina}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  'Página ${pag.numeroPagina}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F0FB),
                  ),
                ),
                subtitle: Text(
                  '${pag.conteoPalabras} palabras transcritas',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B8FA8)),
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0E15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF222536)),
                    ),
                    child: SelectableText(
                      pag.texto.trim().isEmpty
                          ? '[Sin texto transcrito]'
                          : pag.texto,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 13.5,
                        height: 1.55,
                        color: Color(0xFFE2E0EE),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: TextButton.icon(
                        onPressed: () => _abrirModoLectura(
                          libro,
                          desde: paginas.indexOf(pag),
                        ),
                        icon: const Icon(Icons.fullscreen_rounded, size: 18, color: Color(0xFF818CF8)),
                        label: const Text(
                          'Leer desde aquí',
                          style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                        ),
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

  Widget _metricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2F4A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFF1F0FB),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B8FA8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
