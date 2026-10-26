import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../models/libro_model.dart';
import '../../services/local_user_preferences_store.dart';
import '../book_detail_screen.dart';
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
  bool _vistaCuadricula = false;
  Set<String> _favoritos = <String>{};
  Set<String> _librosConMarcadores = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.biblioteca.busqueda;
    widget.biblioteca.addListener(_alCambiarBusqueda);
    _scrollController.addListener(_alScrollear);
    _cargarDatosLocales();
  }

  Future<void> _cargarDatosLocales() async {
    try {
      final favs = await _prefs.obtenerFavoritos();
      final conMarcadores = await _prefs.obtenerLibrosConMarcadores();
      if (mounted) {
        setState(() {
          _favoritos = favs;
          _librosConMarcadores = conMarcadores;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_alScrollear);
    _scrollController.dispose();
    widget.biblioteca.removeListener(_alCambiarBusqueda);
    _searchController.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      widget.biblioteca.cargarMas();
    }
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
      final t = l.tipoLibro.trim();
      if (t.isNotEmpty && t != 'General') {
        categorias.add(t);
      }
    }
    final lista = categorias.toList()..sort();
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
                style: const TextStyle(color: Color(0xFFF1F0FB), fontSize: 14.5),
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
                  hintStyle: const TextStyle(color: Color(0xFF646B87), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFF141724),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                  suffixIcon: b.busqueda.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF9499B3)),
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
                    borderSide: const BorderSide(color: Color(0xFF25293C), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
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
                    child: Text(
                      hayFiltroActivo
                          ? 'Filtro aplicado'
                          : '${b.libros.length} libros en catálogo',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC7CBD9),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (hayFiltroActivo)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF818CF8),
                      ),
                      onPressed: _restablecerFiltros,
                      icon: const Icon(Icons.close_rounded, size: 14),
                      label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                    ),
                  // Botón de ordenamiento
                  _botonOrdenar(),
                  const SizedBox(width: 4),
                  // Toggle Lista / Cuadrícula
                  IconButton(
                    icon: Icon(
                      _vistaCuadricula
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: const Color(0xFF818CF8),
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
    final categorias = _obtenerCategorias(b.libros);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Chip Todos
          _chipFiltro(
            etiqueta: 'Todos (${b.libros.length})',
            icono: Icons.auto_stories_rounded,
            esActivo: _filtroRapido == 'todos' && _categoriaSeleccionada == 'Todas',
            colorActivo: const Color(0xFF6366F1),
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
            colorActivo: const Color(0xFFF59E0B),
            colorIcono: const Color(0xFFF59E0B),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'favoritos') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'favoritos';
                  _categoriaSeleccionada = 'Todas';
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
            colorActivo: const Color(0xFF06B6D4),
            colorIcono: const Color(0xFF06B6D4),
            alTocar: () {
              setState(() {
                if (_filtroRapido == 'en_lectura') {
                  _filtroRapido = 'todos';
                } else {
                  _filtroRapido = 'en_lectura';
                  _categoriaSeleccionada = 'Todas';
                }
              });
            },
          ),

          // Chips de categorías dinámicas
          for (final cat in categorias) ...[
            const SizedBox(width: 8),
            _chipFiltro(
              etiqueta: cat,
              icono: Icons.category_outlined,
              esActivo: _categoriaSeleccionada == cat,
              colorActivo: const Color(0xFF818CF8),
              alTocar: () {
                setState(() {
                  if (_categoriaSeleccionada == cat) {
                    _categoriaSeleccionada = 'Todas';
                  } else {
                    _categoriaSeleccionada = cat;
                    _filtroRapido = 'todos';
                  }
                });
              },
            ),
          ],
        ],
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
                ? colorActivo.withValues(alpha: 0.22)
                : const Color(0xFF141724),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: esActivo ? colorActivo : const Color(0xFF26293A),
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
                    : (colorIcono ?? const Color(0xFF9499B3)),
              ),
              const SizedBox(width: 6),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: esActivo ? FontWeight.w600 : FontWeight.w500,
                  color: esActivo ? Colors.white : const Color(0xFFC7CBD9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonOrdenar() {
    return PopupMenuButton<CriterioOrden>(
      initialValue: _criterioOrden,
      tooltip: 'Ordenar libros',
      color: const Color(0xFF1E2235),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2A2E44)),
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF141724),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF26293A)),
        ),
        child: const Icon(
          Icons.swap_vert_rounded,
          color: Color(0xFF818CF8),
          size: 19,
        ),
      ),
      onSelected: (criterio) => setState(() => _criterioOrden = criterio),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: CriterioOrden.tituloAZ,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: Color(0xFF818CF8)),
              SizedBox(width: 10),
              Text('Título (A → Z)', style: TextStyle(color: Color(0xFFF1F0FB), fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: CriterioOrden.tituloZA,
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: Color(0xFF818CF8)),
              SizedBox(width: 10),
              Text('Título (Z → A)', style: TextStyle(color: Color(0xFFF1F0FB), fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: CriterioOrden.anioReciente,
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF818CF8)),
              SizedBox(width: 10),
              Text('Año (Más reciente)', style: TextStyle(color: Color(0xFFF1F0FB), fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: CriterioOrden.anioAntiguo,
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: Color(0xFF818CF8)),
              SizedBox(width: 10),
              Text('Año (Más antiguo)', style: TextStyle(color: Color(0xFFF1F0FB), fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: CriterioOrden.paginasMayor,
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF818CF8)),
              SizedBox(width: 10),
              Text('Páginas (Mayor a menor)', style: TextStyle(color: Color(0xFFF1F0FB), fontSize: 13)),
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
      librosFiltrados = librosFiltrados.where((l) {
        return l.tipoLibro.trim().toLowerCase() ==
            _categoriaSeleccionada.trim().toLowerCase();
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
                  color: const Color(0xFF161824),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF26293A), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
                      ? const Color(0xFFF59E0B)
                      : _filtroRapido == 'en_lectura'
                          ? const Color(0xFF06B6D4)
                          : const Color(0xFF818CF8),
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
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF1F0FB),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _filtroRapido == 'favoritos'
                    ? 'Toca la estrella ⭐ en el detalle de cualquier libro para guardarlo en favoritos.'
                    : _filtroRapido == 'en_lectura'
                        ? 'Inicia el modo lectura o añade un marcador para continuar leyendo desde acá.'
                        : hayFiltroActivo
                            ? 'Prueba seleccionando otra categoría o borra el texto de búsqueda.'
                            : 'Usa el botón Escanear o Subir PDF para digitalizar el primero.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9499B3)),
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
                    foregroundColor: const Color(0xFF818CF8),
                    side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
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
    final tieneItemCargaMas = b.hayMas || b.cargandoMas;

    if (_vistaCuadricula) {
      return RefreshIndicator(
        onRefresh: () async {
          await b.refrescar();
          await _cargarDatosLocales();
        },
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: librosFiltrados.length,
          itemBuilder: (context, i) {
            final libro = librosFiltrados[i];
            return _GridBookCard(
              libro: libro,
              pendiente: b.esPendiente(libro.id),
              esFavorito: _favoritos.contains(libro.id),
              onRetorno: _cargarDatosLocales,
            );
          },
        ),
      );
    }

    final totalItems =
        librosFiltrados.length +
        (tieneHeaderDegradado ? 1 : 0) +
        (tieneItemCargaMas ? 1 : 0);

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

          if (tieneItemCargaMas && indiceLibro == librosFiltrados.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: b.cargandoMas
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cargando más libros...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: b.cargarMas,
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: const Text('Cargar más libros'),
                      ),
              ),
            );
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
}

class _GridBookCard extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;
  final bool esFavorito;
  final VoidCallback? onRetorno;

  const _GridBookCard({
    required this.libro,
    required this.pendiente,
    required this.esFavorito,
    this.onRetorno,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pendiente
              ? Colors.amber.shade700.withValues(alpha: 0.5)
              : const Color(0xFF26293A),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookDetailScreen(
                  idLibro: libro.id,
                  titulo: libro.titulo,
                  libroLocal: pendiente ? libro : null,
                ),
              ),
            );
            onRetorno?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        if (esFavorito)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  libro.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFFF1F0FB),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  libro.autor.isEmpty ? 'Autor no especificado' : libro.autor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF9499B3),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${libro.anioInicio}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC6BFFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pendiente)
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 14,
                        color: Colors.amber,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
