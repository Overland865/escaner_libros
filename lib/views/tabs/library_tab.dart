import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../../services/local_user_preferences_store.dart';
import '../widgets/backend_connection_sheet.dart';
import '../widgets/book_card.dart';

/// Criterios de ordenamiento para el catálogo de libros.
enum CriterioOrden {
  tituloAZ,
  tituloZA,
  anioReciente,
  anioAntiguo,
  paginasMayor,
}

/// Pestaña 3 — Listado completo del archivo con buscador universal, filtros por categoría/lectura, favoritos y ordenamiento.
class LibraryTab extends StatefulWidget {
  final BibliotecaController biblioteca;

  const LibraryTab({super.key, required this.biblioteca});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();

  Timer? _debounce;
  String _filtroRapido = 'todos'; // 'todos', 'favoritos', 'en_lectura'
  String _categoriaSeleccionada = 'Todas';
  CriterioOrden _criterioOrden = CriterioOrden.tituloAZ;
  bool _vistaCuadricula = true; // Vista cuadrícula por defecto modelada en Stitch
  Set<String> _favoritos = <String>{};
  Set<String> _librosConMarcadores = <String>{};
  Map<String, ProgresoLectura> _progresos = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.biblioteca.busqueda;
    widget.biblioteca.addListener(_alCambiarBusqueda);
    _cargarDatosLocales();
  }

  Future<void> _cargarDatosLocales() async {
    try {
      final favs = await _prefs.obtenerFavoritos();
      final progs = <String, ProgresoLectura>{};
      final enLectura = <String>{};
      for (final l in widget.biblioteca.libros) {
        try {
          final p = await _prefs.obtenerProgreso(l.id);
          if (p != null) {
            progs[l.id] = p;
            final totalReal =
                l.paginas.isNotEmpty ? l.paginas.length : p.totalPaginas;
            if (totalReal > 0 && p.ultimaPagina >= 0 && p.ultimaPagina < totalReal - 1) {
              enLectura.add(l.id);
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _favoritos = favs;
          _librosConMarcadores = enLectura;
          _progresos = progs;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    widget.biblioteca.removeListener(_alCambiarBusqueda);
    _searchController.dispose();
    super.dispose();
  }

  /// Mantiene el campo sincronizado si la búsqueda se borra desde otro lado.
  void _alCambiarBusqueda() {
    if (_searchController.text == widget.biblioteca.busqueda) return;
    _searchController.value = TextEditingValue(
      text: widget.biblioteca.busqueda,
      selection: TextSelection.collapsed(
        offset: widget.biblioteca.busqueda.length,
      ),
    );
  }

  /// Rebote de 400 ms: busca universalmente en todos los campos (título, autor, editorial, año, etc.).
  void _programarBusqueda(String texto) {
    widget.biblioteca.buscar(texto, campo: 'todos');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.biblioteca.cargar(busqueda: texto, campoBusqueda: 'todos');
    });
  }

  void _restablecerFiltros() {
    setState(() {
      _filtroRapido = 'todos';
      _categoriaSeleccionada = 'Todas';
      _criterioOrden = CriterioOrden.tituloAZ;
    });
    if (_searchController.text.isNotEmpty) {
      _debounce?.cancel();
      _searchController.clear();
      widget.biblioteca.cargar(busqueda: '', campoBusqueda: 'todos');
    }
  }

  List<String> _obtenerCategorias(List<LibroModel> libros) {
    final categorias = <String>{};
    for (final l in libros) {
      for (final parte in l.tipoLibro.split(',')) {
        final t = parte.trim();
        if (t.isNotEmpty && t != 'General') {
          categorias.add(t);
        }
      }
      for (final p in l.palabrasClave) {
        final t = p.trim();
        if (t.isNotEmpty && t != 'General' && t.length < 40) {
          categorias.add(t);
        }
      }
    }
    final lista = categorias.toList()
      ..sort((a, b) {
        final aClean = a.replaceFirst(RegExp(r'^category:\s*', caseSensitive: false), '');
        final bClean = b.replaceFirst(RegExp(r'^category:\s*', caseSensitive: false), '');
        return aClean.toLowerCase().compareTo(bClean.toLowerCase());
      });
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.biblioteca,
      builder: (context, _) {
        final b = widget.biblioteca;
        final hayFiltroActivo = b.busqueda.isNotEmpty ||
            _filtroRapido != 'todos' ||
            _categoriaSeleccionada != 'Todas';

        return Column(
          children: [
            // Buscador universal
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14.5),
                onChanged: _programarBusqueda,
                onSubmitted: (q) {
                  _debounce?.cancel();
                  widget.biblioteca.cargar(
                    busqueda: q,
                    campoBusqueda: 'todos',
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por título, autor, editorial, año...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                  prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.secondary),
                  suffixIcon: b.busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            widget.biblioteca.cargar(
                              busqueda: '',
                              campoBusqueda: 'todos',
                            );
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Barra de filtros rápidos por chips (Categorías, Favoritos, En lectura)
            _barraFiltrosRapidos(b),

            const SizedBox(height: 10),

            // Barra de herramientas: resumen de conteo, botón de orden y vista lista/cuadrícula
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            hayFiltroActivo
                                ? 'Filtro aplicado'
                                : (b.totalPaginas > 1
                                    ? 'Pág. ${b.paginaActual}/${b.totalPaginas} (${b.totalRemoto > 0 ? b.totalRemoto : b.libros.length} vol.)'
                                    : '${b.libros.length} libros en catálogo'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (b.totalPaginas > 1 && !hayFiltroActivo) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Página anterior',
                            onPressed: b.tienePaginaAnterior
                                ? () {
                                    b.irAPagina(b.paginaActual - 1);
                                    _scrollController.animateTo(
                                      0,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Página siguiente',
                            onPressed: b.tienePaginaSiguiente
                                ? () {
                                    b.irAPagina(b.paginaActual + 1);
                                    _scrollController.animateTo(
                                      0,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hayFiltroActivo)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Theme.of(context).colorScheme.secondary,
                      ),
                      onPressed: _restablecerFiltros,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                    ),
                  // Botón clásico de filtrado
                  _botonFiltrar(b),
                  const SizedBox(width: 4),
                  // Botón de ordenamiento
                  _botonOrdenar(),
                  const SizedBox(width: 4),
                  // Toggle Lista / Cuadrícula
                  IconButton(
                    icon: Icon(
                      _vistaCuadricula
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 21,
                    ),
                    tooltip: _vistaCuadricula
                        ? 'Vista de lista'
                        : 'Vista de cuadrícula',
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _vistaCuadricula = !_vistaCuadricula),
                  ),
                ],
              ),
            ),
            Expanded(child: _cuerpo(b)),
          ],
        );
      },
    );
  }

  Widget _barraFiltrosRapidos(BibliotecaController b) {
    final theme = Theme.of(context);
    final tieneCategoria = _categoriaSeleccionada != 'Todas';
    final filtroActivo = tieneCategoria || _filtroRapido != 'todos';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Botón clásico de filtros rápidos
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _mostrarModalFiltros(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: filtroActivo
                    ? theme.colorScheme.secondary.withValues(alpha: 0.16)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: filtroActivo
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outlineVariant,
                  width: filtroActivo ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: filtroActivo
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: filtroActivo
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (filtroActivo) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Chip Todos
          _chipFiltro(
            etiqueta: 'Todos (${b.libros.length})',
            icono: Icons.auto_stories_rounded,
            esActivo: _filtroRapido == 'todos' && !tieneCategoria,
            colorActivo: theme.colorScheme.secondary,
            alTocar: () {
              setState(() {
                _filtroRapido = 'todos';
                _categoriaSeleccionada = 'Todas';
              });
            },
          ),
          const SizedBox(width: 8),

          // Chip Favoritos
          _chipFiltro(
            etiqueta: _favoritos.isNotEmpty
                ? 'Favoritos (${_favoritos.length})'
                : 'Favoritos',
            icono: Icons.star_rounded,
            esActivo: _filtroRapido == 'favoritos',
            colorActivo: const Color(0xFFD4A373),
            colorIcono: const Color(0xFFD4A373),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'favoritos') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'favoritos';
                }
              });
            },
          ),
          const SizedBox(width: 8),

          // Chip En lectura
          _chipFiltro(
            etiqueta: _librosConMarcadores.isNotEmpty
                ? 'En lectura (${_librosConMarcadores.length})'
                : 'En lectura',
            icono: Icons.bookmark_rounded,
            esActivo: _filtroRapido == 'en_lectura',
            colorActivo: const Color(0xFF8C4E26),
            colorIcono: const Color(0xFF8C4E26),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'en_lectura') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'en_lectura';
                }
              });
            },
          ),

          // Si hay una categoría seleccionada, mostrar chip activo con botón "X"
          if (tieneCategoria) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_rounded,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _categoriaSeleccionada.replaceFirst(RegExp(r'^category:\s*', caseSensitive: false), ''),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() => _categoriaSeleccionada = 'Todas');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botonFiltrar(BibliotecaController b) {
    final theme = Theme.of(context);
    final filtroActivo = _categoriaSeleccionada != 'Todas' || _filtroRapido != 'todos';

    return Tooltip(
      message: 'Filtrar catálogo',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _mostrarModalFiltros(b),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: filtroActivo
                ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filtroActivo
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                color: filtroActivo
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
                size: 19,
              ),
              if (filtroActivo)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarModalFiltros(BibliotecaController b) {
    final categorias = _obtenerCategorias(b.libros);
    String tempFiltroRapido = _filtroRapido;
    String tempCategoria = _categoriaSeleccionada;
    String filtroTextoCategoria = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final categoriasFiltradas = filtroTextoCategoria.isEmpty
                ? categorias
                : categorias
                    .where((c) => c
                        .toLowerCase()
                        .contains(filtroTextoCategoria.toLowerCase()))
                    .toList();

            final hayFiltros = tempFiltroRapido != 'todos' || tempCategoria != 'Todas';

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tirador superior
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Cabecera del modal
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: theme.colorScheme.secondary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filtrar Catálogo',
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (hayFiltros)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.secondary,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              setModalState(() {
                                tempFiltroRapido = 'todos';
                                tempCategoria = 'Todas';
                              });
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: const Text('Limpiar filtros', style: TextStyle(fontSize: 12.5)),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),

                  // Contenido scrolleable
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        // Sección 1: Colección o Estado
                        Text(
                          'COLECCIÓN O ESTADO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chipOpcionModal(
                              etiqueta: 'Todos (${b.libros.length})',
                              icono: Icons.auto_stories_rounded,
                              seleccionado: tempFiltroRapido == 'todos',
                              color: theme.colorScheme.secondary,
                              alTocar: () => setModalState(() => tempFiltroRapido = 'todos'),
                              theme: theme,
                              isDark: isDark,
                            ),
                            _chipOpcionModal(
                              etiqueta: 'Favoritos (${_favoritos.length})',
                              icono: Icons.star_rounded,
                              seleccionado: tempFiltroRapido == 'favoritos',
                              color: const Color(0xFFD4A373),
                              alTocar: () => setModalState(
                                () => tempFiltroRapido = (tempFiltroRapido == 'favoritos' ? 'todos' : 'favoritos'),
                              ),
                              theme: theme,
                              isDark: isDark,
                            ),
                            _chipOpcionModal(
                              etiqueta: 'En lectura (${_librosConMarcadores.length})',
                              icono: Icons.bookmark_rounded,
                              seleccionado: tempFiltroRapido == 'en_lectura',
                              color: const Color(0xFF8C4E26),
                              alTocar: () => setModalState(
                                () => tempFiltroRapido = (tempFiltroRapido == 'en_lectura' ? 'todos' : 'en_lectura'),
                              ),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección 2: Categorías
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CATEGORÍA O GÉNERO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            if (tempCategoria != 'Todas')
                              Flexible(
                                child: Text(
                                  tempCategoria.replaceFirst(RegExp(r'^category:\s*', caseSensitive: false), ''),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Buscador interno de categorías si hay más de 5
                        if (categorias.length > 5) ...[
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar categoría...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.secondary),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              fillColor: theme.colorScheme.surfaceContainer,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: theme.colorScheme.secondary, width: 1.4),
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() => filtroTextoCategoria = val.trim());
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chipOpcionModal(
                              etiqueta: 'Todas las categorías',
                              icono: Icons.grid_view_rounded,
                              seleccionado: tempCategoria == 'Todas',
                              color: theme.colorScheme.secondary,
                              alTocar: () => setModalState(() => tempCategoria = 'Todas'),
                              theme: theme,
                              isDark: isDark,
                            ),
                            for (final cat in categoriasFiltradas)
                              _chipOpcionModal(
                                etiqueta: cat.replaceFirst(RegExp(r'^category:\s*', caseSensitive: false), ''),
                                icono: Icons.category_outlined,
                                seleccionado: tempCategoria == cat,
                                color: theme.colorScheme.secondary,
                                alTocar: () => setModalState(
                                  () => tempCategoria = (tempCategoria == cat ? 'Todas' : cat),
                                ),
                                theme: theme,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: theme.colorScheme.outlineVariant),

                  // Barra de acciones: Limpiar todo / Aplicar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            onPressed: () {
                              setState(() {
                                _filtroRapido = 'todos';
                                _categoriaSeleccionada = 'Todas';
                              });
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Limpiar todo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _filtroRapido = tempFiltroRapido;
                                _categoriaSeleccionada = tempCategoria;
                              });
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                            label: const Text(
                              'Aplicar filtros',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _chipOpcionModal({
    required String etiqueta,
    required IconData icono,
    required bool seleccionado,
    required Color color,
    required VoidCallback alTocar,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: alTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: isDark ? 0.35 : 0.18)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? color : theme.colorScheme.outlineVariant,
            width: seleccionado ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 15,
              color: seleccionado ? color : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                color: seleccionado
                    ? (isDark ? Colors.white : color)
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro({
    required String etiqueta,
    required IconData icono,
    required bool esActivo,
    required VoidCallback alTocar,
    required Color colorActivo,
    Color? colorIcono,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: esActivo
                ? colorActivo.withValues(alpha: isDark ? 0.3 : 0.16)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: esActivo ? colorActivo : theme.colorScheme.outlineVariant,
              width: esActivo ? 1.4 : 1.0,
            ),
            boxShadow: esActivo
                ? [
                    BoxShadow(
                      color: colorActivo.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                size: 15,
                color: esActivo
                    ? colorActivo
                    : (colorIcono ?? theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: esActivo ? FontWeight.w600 : FontWeight.w500,
                  color: esActivo
                      ? (isDark ? Colors.white : colorActivo)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonOrdenar() {
    final theme = Theme.of(context);

    return PopupMenuButton<CriterioOrden>(
      initialValue: _criterioOrden,
      tooltip: 'Ordenar libros',
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(
          Icons.swap_vert_rounded,
          color: theme.colorScheme.secondary,
          size: 19,
        ),
      ),
      onSelected: (criterio) => setState(() => _criterioOrden = criterio),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CriterioOrden.tituloAZ,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Título (A → Z)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.tituloZA,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Título (Z → A)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.anioReciente,
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Año (Más reciente)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.anioAntiguo,
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Año (Más antiguo)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: CriterioOrden.paginasMayor,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: theme.colorScheme.secondary),
              const SizedBox(width: 10),
              Text('Páginas (Mayor a menor)', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cuerpo(BibliotecaController b) {
    if (b.estado == EstadoCarga.cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 12),
            Text(
              'Cargando biblioteca...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (b.estado == EstadoCarga.error) {
      final sinConexion = b.errorEsConexion;
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(
            sinConexion ? Icons.cloud_off : Icons.error_outline,
            size: 54,
            color: sinConexion
                ? Colors.grey.shade400
                : Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              sinConexion ? 'Servidor no disponible' : 'No se pudo consultar',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              b.error ?? 'Error desconocido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: sinConexion
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ),
          if (b.saludMongo != null && b.saludMongo != 'conectado')
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Text(
                'El servidor responde, pero MongoDB Atlas no. Atlas pausa el '
                'cluster tras 5 min de inactividad y tarda unos segundos en '
                'despertar. Reintenta en un momento.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      showBackendConnectionSheet(context, onRetry: b.refrescar),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Ver conexión'),
                ),
                ElevatedButton.icon(
                  onPressed: b.refrescar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 1. Filtrado dinámico por favoritos o lecturas activas
    var librosFiltrados = List<LibroModel>.from(b.libros);
    if (_filtroRapido == 'favoritos') {
      librosFiltrados = librosFiltrados.where((l) => _favoritos.contains(l.id)).toList();
    } else if (_filtroRapido == 'en_lectura') {
      librosFiltrados = librosFiltrados.where((l) => _librosConMarcadores.contains(l.id)).toList();
    }

    // 2. Filtrado por género / categoría seleccionada
    if (_categoriaSeleccionada != 'Todas') {
      final catBuscada = _categoriaSeleccionada.trim().toLowerCase();
      final catLimpia = catBuscada.replaceFirst(RegExp(r'^category:\s*'), '');
      librosFiltrados = librosFiltrados.where((l) {
        final tipo = l.tipoLibro.trim().toLowerCase();
        if (tipo == catBuscada || tipo == catLimpia) return true;
        if (catLimpia.isNotEmpty && tipo.contains(catLimpia)) return true;
        return l.palabrasClave.any((p) {
          final pk = p.trim().toLowerCase();
          return pk == catBuscada || pk == catLimpia || (catLimpia.isNotEmpty && pk.contains(catLimpia));
        });
      }).toList();
    }

    // 3. Ordenamiento según el criterio seleccionado
    switch (_criterioOrden) {
      case CriterioOrden.tituloAZ:
        librosFiltrados.sort(
          (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
        );
        break;
      case CriterioOrden.tituloZA:
        librosFiltrados.sort(
          (a, b) => b.titulo.toLowerCase().compareTo(a.titulo.toLowerCase()),
        );
        break;
      case CriterioOrden.anioReciente:
        librosFiltrados.sort((a, b) => b.anioInicio.compareTo(a.anioInicio));
        break;
      case CriterioOrden.anioAntiguo:
        librosFiltrados.sort((a, b) => a.anioInicio.compareTo(b.anioInicio));
        break;
      case CriterioOrden.paginasMayor:
        librosFiltrados.sort(
          (a, b) => b.paginas.length.compareTo(a.paginas.length),
        );
        break;
    }

    final hayFiltroActivo = b.busqueda.isNotEmpty ||
        _filtroRapido != 'todos' ||
        _categoriaSeleccionada != 'Todas';

    if (b.libros.isEmpty || librosFiltrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await b.refrescar();
          await _cargarDatosLocales();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _filtroRapido == 'favoritos'
                      ? Icons.star_border_rounded
                      : _filtroRapido == 'en_lectura'
                          ? Icons.bookmark_border_rounded
                          : hayFiltroActivo
                              ? Icons.search_off_rounded
                              : Icons.menu_book_rounded,
                  size: 44,
                  color: _filtroRapido == 'favoritos'
                      ? const Color(0xFFD4A373)
                      : _filtroRapido == 'en_lectura'
                          ? const Color(0xFF8C4E26)
                          : Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _filtroRapido == 'favoritos'
                    ? 'No hay libros favoritos'
                    : _filtroRapido == 'en_lectura'
                        ? 'No tienes lecturas iniciadas'
                        : _categoriaSeleccionada != 'Todas'
                            ? 'No hay libros en "$_categoriaSeleccionada"'
                            : b.busqueda.isNotEmpty
                                ? 'Sin resultados para "${b.busqueda}"'
                                : 'No hay libros registrados aún',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _filtroRapido == 'favoritos'
                    ? 'Toca la estrella ⭐ en el detalle de cualquier libro para guardarlo en favoritos.'
                    : _filtroRapido == 'en_lectura'
                        ? 'Abre cualquier libro en modo lectura para continuar leyéndolo desde aquí.'
                        : hayFiltroActivo
                            ? 'Prueba seleccionando otra categoría o borra el texto de búsqueda.'
                            : 'Usa el botón Escanear o Subir PDF para digitalizar el primero.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            if (hayFiltroActivo) ...[
              const SizedBox(height: 18),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _restablecerFiltros,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Ver todos los libros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    side: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final tieneHeaderDegradado = b.modoDegradado;

    if (_vistaCuadricula) {
      return RefreshIndicator(
        onRefresh: () async {
          await b.refrescar();
          await _cargarDatosLocales();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (tieneHeaderDegradado)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1912),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.5),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 18,
                          color: Colors.amber.shade300,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mostrando libros guardados en el dispositivo (sin conexión al servidor).',
                            style: TextStyle(fontSize: 12, color: Color(0xFFC7BBA8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final libro = librosFiltrados[i];
                    return GridBookCard(
                      libro: libro,
                      pendiente: b.esPendiente(libro.id),
                      esFavorito: _favoritos.contains(libro.id),
                      progreso: _progresos[libro.id],
                      onRetorno: _cargarDatosLocales,
                    );
                  },
                  childCount: librosFiltrados.length,
                ),
              ),
            ),
            if (b.totalPaginas > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  child: _barraPaginacion(b),
                ),
              )
            else
              const SliverToBoxAdapter(
                child: SizedBox(height: 96),
              ),
          ],
        ),
      );
    }

    final totalItems =
        librosFiltrados.length +
        (tieneHeaderDegradado ? 1 : 0) +
        (b.totalPaginas > 1 ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () async {
        await b.refrescar();
        await _cargarDatosLocales();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: totalItems,
        itemBuilder: (context, i) {
          if (tieneHeaderDegradado && i == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1912),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.5),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: Colors.amber.shade300,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mostrando libros guardados en el dispositivo '
                      '(sin conexión al servidor).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFC7BBA8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final indiceLibro = tieneHeaderDegradado ? i - 1 : i;

          if (b.totalPaginas > 1 && indiceLibro == librosFiltrados.length) {
            return _barraPaginacion(b);
          }

          final libro = librosFiltrados[indiceLibro];
          return BookCard(
            libro: libro,
            pendiente: b.esPendiente(libro.id),
            errorSync: b.errorSyncDe(libro.id),
            esFavorito: _favoritos.contains(libro.id),
            onRetorno: _cargarDatosLocales,
          );
        },
      ),
    );
  }

  Widget _barraPaginacion(BibliotecaController b) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Anterior
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(
                color: b.tienePaginaAnterior
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: b.tienePaginaAnterior
                ? () {
                    b.irAPagina(b.paginaActual - 1);
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Anterior', style: TextStyle(fontSize: 12.5)),
          ),

          // Selector central de página
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _mostrarDialogoIrAPagina(b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pág. ${b.paginaActual} de ${b.totalPaginas}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),

          // Botón Siguiente
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(
                color: b.tienePaginaSiguiente
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: b.tienePaginaSiguiente
                ? () {
                    b.irAPagina(b.paginaActual + 1);
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            label: const Text('Siguiente', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoIrAPagina(BibliotecaController b) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saltar a página',
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Total: ${b.totalPaginas} págs (${b.totalRemoto} libros)',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int p = 1; p <= b.totalPaginas; p++)
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(ctx);
                            if (p != b.paginaActual) {
                              b.irAPagina(p);
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: Container(
                            width: 48,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p == b.paginaActual
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: p == b.paginaActual
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.outlineVariant,
                                width: p == b.paginaActual ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              '$p',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: p == b.paginaActual
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: p == b.paginaActual
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
