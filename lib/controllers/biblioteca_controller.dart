import 'package:flutter/foundation.dart';

import '../models/libro_local.dart';
import '../models/libro_model.dart';
import '../services/api_service.dart';
import '../services/local_library_store.dart';
import '../services/sync_service.dart';

enum EstadoCarga { cargando, listo, error }

/// Estado compartido entre las tres pestañas: la lista de libros vive acá para
/// que "Inicio", "Libros" y "Escanear" siempre muestren la misma información.
///
/// Combina libros remotos con borradores locales pendientes de sync y
/// gestiona la paginación incremental de la biblioteca.
class BibliotecaController extends ChangeNotifier {
  BibliotecaController({LocalLibraryStore? store})
    : _store = store ?? LocalLibraryStore() {
    _sync = SyncService(store: _store);
  }

  final LocalLibraryStore _store;
  late final SyncService _sync;

  static const int _tamanoPagina = 50;

  List<LibroModel> _libros = const [];
  List<LibroModel> _remotos = [];
  final Map<String, EstadoSync> _estadosLocales = {};
  final Map<String, LibroLocal> _librosLocales = {};
  EstadoCarga _estado = EstadoCarga.cargando;
  String? _error;
  bool _errorEsConexion = false;
  bool _servidorAlcanzable = true;
  String? _saludMongo;
  String _busqueda = '';
  String _campoBusqueda = 'todos';
  int _pendientesCount = 0;
  bool _sincronizando = false;
  bool _modoDegradado = false;

  // Paginación
  int _skip = 0;
  int _totalRemoto = 0;
  bool _hayMas = false;
  bool _cargandoMas = false;

  List<LibroModel> get libros => _libros;
  EstadoCarga get estado => _estado;
  String? get error => _error;

  /// `true` si el backend no respondió.
  bool get errorEsConexion => _errorEsConexion;

  String get busqueda => _busqueda;
  String get campoBusqueda => _campoBusqueda;
  bool get servidorAlcanzable => _servidorAlcanzable;
  bool get estaVacio => _estado == EstadoCarga.listo && _libros.isEmpty;

  /// Estado de Atlas según el endpoint /api/salud (null = no se pudo consultar).
  String? get saludMongo => _saludMongo;

  int get pendientesCount => _pendientesCount;
  bool get sincronizando => _sincronizando;

  /// Hay libros locales visibles aunque el remoto falló.
  bool get modoDegradado => _modoDegradado;

  // Getters de paginación
  int get totalRemoto => _totalRemoto;
  bool get hayMas => _hayMas;
  bool get cargandoMas => _cargandoMas;

  /// Estado de sync local para un id, o null si solo existe en remoto.
  EstadoSync? estadoLocalDe(String id) => _estadosLocales[id];
  String? errorSyncDe(String id) => _librosLocales[id]?.ultimoError;

  bool esPendiente(String id) {
    final e = _estadosLocales[id];
    return e == EstadoSync.pendiente ||
        e == EstadoSync.error ||
        e == EstadoSync.sincronizando;
  }

  /// Carga inicial (o reinicio de búsqueda) de la biblioteca paginada.
  Future<void> cargar({String? busqueda, String? campoBusqueda}) async {
    if (busqueda != null) _busqueda = busqueda;
    if (campoBusqueda != null) _campoBusqueda = campoBusqueda;

    _estado = EstadoCarga.cargando;
    _error = null;
    _modoDegradado = false;
    _skip = 0;
    _hayMas = false;
    notifyListeners();

    var remotoOk = false;

    try {
      final res = await ApiService.obtenerLibrosPaginados(
        busqueda: _busqueda.isEmpty ? null : _busqueda,
        campoBusqueda: _campoBusqueda,
        limit: _tamanoPagina,
        skip: 0,
      );
      _remotos = List.of(res.libros);
      _totalRemoto = res.total;
      _skip = res.libros.length;
      _hayMas = res.hasMore;
      remotoOk = true;
      _servidorAlcanzable = true;
      _errorEsConexion = false;
      await _consultarSalud();
    } catch (e) {
      _remotos = [];
      _totalRemoto = 0;
      _hayMas = false;
      _error = e.toString();
      _errorEsConexion = e is ApiException && e.esErrorDeConexion;
      _servidorAlcanzable = !_errorEsConexion;
      _saludMongo = null;
    }

    final locales = await _store.listarPendientes();
    _pendientesCount = locales.length;
    _estadosLocales
      ..clear()
      ..addEntries(locales.map((l) => MapEntry(l.id, l.estado)));
    _librosLocales
      ..clear()
      ..addEntries(locales.map((l) => MapEntry(l.id, l)));

    _libros = _mezclar(
      _remotos,
      locales,
      filtro: _busqueda,
      campo: _campoBusqueda,
    );

    if (remotoOk) {
      _estado = EstadoCarga.listo;
      _error = null;
    } else if (_libros.isNotEmpty) {
      _estado = EstadoCarga.listo;
      _modoDegradado = true;
    } else {
      _estado = EstadoCarga.error;
    }

    notifyListeners();

    // Reintento automático de cola si hay red.
    if (remotoOk && _pendientesCount > 0) {
      await sincronizarAhora(silencioso: true);
    }
  }

  /// Solicita la siguiente página de libros para carga incremental (scroll infinito).
  Future<void> cargarMas() async {
    if (_cargandoMas ||
        !_hayMas ||
        _estado != EstadoCarga.listo ||
        _modoDegradado) {
      return;
    }

    _cargandoMas = true;
    notifyListeners();

    try {
      final res = await ApiService.obtenerLibrosPaginados(
        busqueda: _busqueda.isEmpty ? null : _busqueda,
        campoBusqueda: _campoBusqueda,
        limit: _tamanoPagina,
        skip: _skip,
      );

      _remotos.addAll(res.libros);
      _totalRemoto = res.total;
      _skip += res.libros.length;
      _hayMas = res.hasMore;

      final locales = await _store.listarPendientes();
      _libros = _mezclar(
        _remotos,
        locales,
        filtro: _busqueda,
        campo: _campoBusqueda,
      );
    } catch (e) {
      debugPrint('Error al cargar página adicional: $e');
    } finally {
      _cargandoMas = false;
      notifyListeners();
    }
  }

  List<LibroModel> _mezclar(
    List<LibroModel> remotos,
    List<LibroLocal> locales, {
    required String filtro,
    required String campo,
  }) {
    final map = <String, LibroModel>{};
    for (final r in remotos) {
      map[r.id] = r;
    }
    // Pendientes locales ganan si mismo id / código.
    for (final l in locales) {
      if (_coincideBusqueda(l.libro, filtro, campo)) {
        map[l.id] = l.libro;
      }
    }
    return map.values.toList()..sort(
      (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
    );
  }

  bool _coincideBusqueda(LibroModel libro, String filtro, String campo) {
    final q = filtro.trim().toLowerCase();
    if (q.isEmpty) return true;
    switch (campo) {
      case 'titulo':
        return libro.titulo.toLowerCase().contains(q);
      case 'editorial':
        return libro.editorial.toLowerCase().contains(q);
      case 'autor':
        return libro.autor.toLowerCase().contains(q);
      case 'tipo_libro':
        return libro.tipoLibro.toLowerCase().contains(q);
      case 'anio':
        return '${libro.anioInicio}'.contains(q) ||
            '${libro.anioFin}'.contains(q);
      case 'isbn_o_codigo':
        return libro.isbnOCodigo.toLowerCase().contains(q);
      default:
        return libro.titulo.toLowerCase().contains(q) ||
            libro.editorial.toLowerCase().contains(q) ||
            libro.autor.toLowerCase().contains(q) ||
            libro.isbnOCodigo.toLowerCase().contains(q) ||
            libro.tipoLibro.toLowerCase().contains(q) ||
            '${libro.anioInicio}'.contains(q) ||
            '${libro.anioFin}'.contains(q);
    }
  }

  /// Consulta el estado de Atlas sin bloquear la carga de la lista.
  Future<void> _consultarSalud() async {
    final salud = await ApiService.consultarSalud();
    if (salud == null) {
      _saludMongo = null;
      return;
    }
    _saludMongo = salud['mongo']?.toString();
  }

  /// Búsqueda con rebote para no golpear el backend en cada tecla.
  void buscar(String texto, {String? campo}) {
    _busqueda = texto;
    if (campo != null) _campoBusqueda = campo;
    notifyListeners();
  }

  Future<void> refrescar() => cargar();

  /// Se llama tras subir un libro para que la lista refleje el cambio ya mismo.
  Future<void> registrarLibroGuardado() => cargar();

  /// Guarda siempre en disco como pendiente e intenta sync una vez.
  Future<ResultadoGuardado> guardarLibro(LibroModel libro) async {
    final resultado = await _sync.guardarYSincronizar(libro);
    await cargar();
    return resultado;
  }

  /// Fuerza la sincronización de la cola de pendientes.
  Future<ResultadoSync> sincronizarAhora({bool silencioso = false}) async {
    if (_sincronizando) {
      return const ResultadoSync(
        intentados: 0,
        exitosos: 0,
        fallidos: 0,
        sinConexion: false,
      );
    }
    _sincronizando = true;
    if (!silencioso) notifyListeners();

    try {
      final resultado = await _sync.sincronizarPendientes();
      final locales = await _store.listarPendientes();
      _pendientesCount = locales.length;
      _estadosLocales
        ..clear()
        ..addEntries(locales.map((l) => MapEntry(l.id, l.estado)));
      _librosLocales
        ..clear()
        ..addEntries(locales.map((l) => MapEntry(l.id, l)));

      if (resultado.exitosos > 0) {
        await _recargarTrasSync();
      } else {
        notifyListeners();
      }
      return resultado;
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  Future<void> _recargarTrasSync() async {
    try {
      final res = await ApiService.obtenerLibrosPaginados(
        busqueda: _busqueda.isEmpty ? null : _busqueda,
        campoBusqueda: _campoBusqueda,
        limit: _tamanoPagina,
        skip: 0,
      );
      _remotos = List.of(res.libros);
      _totalRemoto = res.total;
      _skip = res.libros.length;
      _hayMas = res.hasMore;

      final locales = await _store.listarPendientes();
      _pendientesCount = locales.length;
      _estadosLocales
        ..clear()
        ..addEntries(locales.map((l) => MapEntry(l.id, l.estado)));
      _librosLocales
        ..clear()
        ..addEntries(locales.map((l) => MapEntry(l.id, l)));
      _libros = _mezclar(
        _remotos,
        locales,
        filtro: _busqueda,
        campo: _campoBusqueda,
      );
      _estado = EstadoCarga.listo;
      _modoDegradado = false;
      _servidorAlcanzable = true;
      _error = null;
      await _consultarSalud();
    } catch (_) {
      // Mantener lo que ya había en memoria.
    }
    notifyListeners();
  }
}
