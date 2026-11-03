import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/libro_model.dart';
import 'local_user_preferences_store.dart';

/// Reduce la foto (orientación correcta, máx. 1600 px, JPEG 85 %) antes del OCR.
/// Función de nivel superior para poder ejecutarse con `compute` en un isolate.
Uint8List _optimizarImagenOcr(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  img.Image procesada = img.bakeOrientation(decoded);
  const int maxDim = 1600;
  if (procesada.width > maxDim || procesada.height > maxDim) {
    procesada = procesada.width >= procesada.height
        ? img.copyResize(procesada, width: maxDim, interpolation: img.Interpolation.linear)
        : img.copyResize(procesada, height: maxDim, interpolation: img.Interpolation.linear);
  }
  return Uint8List.fromList(img.encodeJpg(procesada, quality: 85));
}

/// Resultado paginado de libros desde la API.
class ResultadoLibrosPaginados {
  final List<LibroModel> libros;
  final int total;
  final int skip;
  final int limit;
  final bool hasMore;

  const ResultadoLibrosPaginados({
    required this.libros,
    required this.total,
    required this.skip,
    required this.limit,
    required this.hasMore,
  });
}

/// Error de la API.
///
/// [esErrorDeConexion] distingue dos situaciones que la UI debe tratar de
/// forma distinta:
///   * `true`  → el servidor no respondió (apagado, IP/Puerto equivocado,
///               sin red). El mensaje "servidor no disponible" es correcto.
///   * `false` → el servidor respondió con un error (validación, 404, 500).
///               El servidor SÍ está arriba; culpar a la conexión sería mentira.
class ApiException implements Exception {
  final String message;
  final bool esErrorDeConexion;

  /// Código HTTP de la respuesta, o `null` si el fallo fue de transporte.
  /// Permite distinguir "no existe" (404) de "falló el servidor" (5xx).
  final int? statusCode;

  const ApiException(
    this.message, {
    this.esErrorDeConexion = false,
    this.statusCode,
  });

  bool get esNoEncontrado => statusCode == 404;
  bool get esNoAutorizado => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente REST del backend Node.js/Express.
///
/// La app móvil NUNCA habla directo con MongoDB: todas las operaciones pasan
/// por el backend, que es el único dueño de las credenciales de Atlas y Gemini.
class ApiService {
  ApiService._();

  static const Duration _timeoutLectura = Duration(seconds: 45);
  static const Duration _timeoutEscritura = Duration(seconds: 60);
  static const Duration _timeoutTranscripcion = Duration(seconds: 150);
  static const String _legacyApiKeyFileName = 'api_access_key.txt';

  static String _baseUrl = '';
  static String _username = '';
  static String _password = '';
  static VoidCallback? onAuthenticationRequired;

  /// Dirección base del backend, sin barra final y sin el sufijo `/api/libros`.
  static String get baseUrl => _baseUrl;

  static set baseUrl(String value) => _baseUrl = normalizarUrl(value);

  static bool get tieneCredenciales =>
      _username.isNotEmpty && _password.isNotEmpty;

  /// URL del backend desplegado (`.env` → `API_BASE_URL`).
  /// Si aún es un placeholder o está vacía, [tieneUrlProduccion] es false.
  static String get urlProduccion {
    final raw = dotenv.env['API_BASE_URL'];
    if (raw == null || raw.trim().isEmpty) return '';
    return normalizarUrl(raw);
  }

  /// True cuando `API_BASE_URL` apunta a un host remoto (https o no-local).
  static bool get tieneUrlProduccion {
    final u = urlProduccion;
    if (u.isEmpty) return false;
    if (u.contains('localhost') || u.contains('127.0.0.1')) return false;
    if (u.contains('10.0.2.2')) return false;
    return true;
  }

  static String _limpiarComillas(String s) {
    var v = s.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      if (v.length >= 2) v = v.substring(1, v.length - 1).trim();
    }
    return v;
  }

  /// Acepta varias formas y las normaliza:
  ///   `192.168.1.85:3000` → `http://192.168.1.85:3000`
  ///   `https://api.midominio.com/api/libros/` → `https://api.midominio.com`
  static String normalizarUrl(String value) {
    var v = _limpiarComillas(value);
    if (v.isEmpty) return v;
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      // Hosts públicos suelen ir por HTTPS; IPs locales por HTTP.
      final pareceLocal = RegExp(
        r'^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)',
      ).hasMatch(v);
      v = pareceLocal ? 'http://$v' : 'https://$v';
    }
    const sufijo = '/api/libros';
    final idx = v.indexOf(sufijo);
    if (idx != -1) v = v.substring(0, idx);
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// Carga la URL del backend; las credenciales no se persisten.
  static Future<void> init() async {
    _baseUrl = urlProduccion;
    _username = '';
    _password = '';
    await _eliminarClaveLegada();
  }

  static Future<void> _eliminarClaveLegada() async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final legacyFile = File(p.join(docs.path, _legacyApiKeyFileName));
      if (await legacyFile.exists()) await legacyFile.delete();
    } catch (e) {
      debugPrint('ApiService: no se pudo eliminar la clave antigua guardada: $e');
    }
  }

  static Future<void> validarCredenciales(String username, String password) async {
    _username = username.trim();
    _password = password;
    try {
      final res = await _enviar(
        () => http.get(_uri('/api/auth/check'), headers: _headers()),
        _timeoutLectura,
      );
      _decodirRespuestaCruda(
        res,
        'GET /api/auth/check',
        invalidarCredenciales401: false,
      );
    } catch (_) {
      _username = '';
      _password = '';
      rethrow;
    }
  }

  static Future<void> cerrarSesion() async {
    _username = '';
    _password = '';
  }

  static void _invalidarCredenciales() {
    if (!tieneCredenciales) return;
    _username = '';
    _password = '';
    onAuthenticationRequired?.call();
  }

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  static Map<String, String> _headers({
    Map<String, String>? adicionales,
    bool incluirAutenticacion = true,
  }) {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (incluirAutenticacion && tieneCredenciales) {
      h['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$_username:$_password'))}';
    }
    if (adicionales != null) h.addAll(adicionales);
    return h;
  }

  /// Envuelve la petición y traduce los fallos de red a [ApiException].
  static Future<http.Response> _enviar(
    Future<http.Response> Function() accion,
    Duration timeout,
  ) async {
    try {
      return await accion().timeout(timeout);
    } on TimeoutException {
      final esRender = _baseUrl.contains('onrender.com');
      final notaServidor = esRender
          ? '\n\nEl servidor de Render puede tardar unos segundos en activarse '
                'después de un periodo sin uso. Intenta de nuevo en un momento.'
          : '';

      throw ApiException(
        'El servidor no respondió a tiempo.\n'
        'URL intentada: $_baseUrl$notaServidor\n\n'
        'Verifica que el backend esté ejecutándose y que tengas conexión a Internet.',
        esErrorDeConexion: true,
      );
    } on SocketException catch (e) {
      final detalle = e.osError?.message ?? e.message;
      throw ApiException(
        'No se pudo conectar con el servidor backend.\n'
        'URL: $_baseUrl\n'
        'Detalle: $detalle',
        esErrorDeConexion: true,
      );
    } on HandshakeException {
      throw const ApiException(
        'Error de conexión segura (SSL/TLS) con el servidor.',
        esErrorDeConexion: true,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Error de cliente HTTP al conectar con el servidor.\n$_baseUrl\n${e.message}',
        esErrorDeConexion: true,
      );
    }
  }

  static Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final res = await _enviar(
      () => http.get(_uri(path, query), headers: _headers()),
      _timeoutLectura,
    );
    return _decodir(res, 'GET $path');
  }

  static Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    bool incluirAutenticacion = true,
    bool invalidarCredenciales401 = true,
  }) async {
    final res = await _enviar(
      () => http.post(
        _uri(path),
        headers: _headers(incluirAutenticacion: incluirAutenticacion),
        body: jsonEncode(body),
      ),
      timeout ?? _timeoutEscritura,
    );
    return _decodir(
      res,
      'POST $path',
      invalidarCredenciales401: invalidarCredenciales401,
    );
  }

  static Future<dynamic> _delete(String path) async {
    final res = await _enviar(
      () => http.delete(_uri(path), headers: _headers()),
      _timeoutLectura,
    );
    return _decodir(res, 'DELETE $path');
  }

  static dynamic _decodirRespuestaCruda(
    http.Response res,
    String contexto, {
    bool invalidarCredenciales401 = true,
  }) {
    dynamic json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      if (res.statusCode == 413) {
        throw const ApiException(
          'El libro es demasiado grande para el servidor '
          '(límite de 50 MB). Escanea menos páginas por documento.',
        );
      }
      if (res.statusCode >= 500) {
        throw ApiException(
          'El servidor respondió con un error interno (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
      throw ApiException(
        'Respuesta inesperada del servidor (${res.statusCode}).',
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (json is Map && json['success'] == false) {
        throw ApiException(
          (json['message'] ?? json['error'] ?? 'Operación rechazada.')
              .toString(),
          statusCode: res.statusCode,
        );
      }
      return json;
    }

    final mensaje = json is Map
        ? (json['message'] ?? json['error'] ?? 'Error ${res.statusCode}')
        : 'Error ${res.statusCode}';
    debugPrint('$contexto falló: $mensaje');
    if (res.statusCode == 401 && invalidarCredenciales401) {
      _invalidarCredenciales();
    }
    throw ApiException(mensaje.toString(), statusCode: res.statusCode);
  }

  static dynamic _decodir(
    http.Response res,
    String contexto, {
    bool invalidarCredenciales401 = true,
  }) {
    final json = _decodirRespuestaCruda(
      res,
      contexto,
      invalidarCredenciales401: invalidarCredenciales401,
    );
    return json is Map && json.containsKey('data') ? json['data'] : json;
  }

  /// Estado del backend y, por separado, el de Atlas.
  /// Devuelve `null` si el servidor HTTP no responde.
  static Future<Map<String, dynamic>?> consultarSalud({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final res = await _enviar(
        () => http.get(_uri('/api/salud'), headers: _headers()),
        timeout,
      );
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Como [consultarSalud], pero tolera el "arranque en frío" de Render: el
  /// plan gratuito duerme el servicio y puede tardar 30-50 s en despertar.
  /// Si no hay red real, el fallo es inmediato y no se espera de más.
  static Future<Map<String, dynamic>?> consultarSaludConReintento({
    int intentos = 2,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    for (var i = 1; i <= intentos; i++) {
      final salud = await consultarSalud(timeout: timeout);
      if (salud != null) return salud;
      if (i < intentos) await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  /// Verifica el backend y el endpoint protegido de libros.
  /// Devuelve `null` si funciona o un mensaje de error para mostrar en la UI.
  static Future<String?> probarConexion() async {
    if (_baseUrl.isEmpty) {
      return 'No está configurada la URL de producción del backend.';
    }

    final salud = await consultarSalud();
    if (salud == null) {
      return 'No se pudo contactar con el servidor en $_baseUrl.';
    }
    if (salud['servidor'] != 'ok') {
      return 'El servidor respondió, pero no está listo.';
    }

    try {
      final res = await _enviar(
        () =>
            http.get(_uri('/api/libros', {'limit': '1'}), headers: _headers()),
        const Duration(seconds: 10),
      );
      _decodirRespuestaCruda(res, 'GET /api/libros');
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Obtiene lista paginada de libros con metadatos de paginación.
  static Future<ResultadoLibrosPaginados> obtenerLibrosPaginados({
    String? busqueda,
    String campoBusqueda = 'todos',
    int limit = 50,
    int skip = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'skip': '$skip',
      if (busqueda != null && busqueda.trim().isNotEmpty)
        'busqueda': busqueda.trim(),
      if (busqueda != null &&
          busqueda.trim().isNotEmpty &&
          campoBusqueda != 'todos')
        'campo': campoBusqueda,
    };

    final res = await _enviar(
      () => http.get(_uri('/api/libros', query), headers: _headers()),
      _timeoutLectura,
    );
    final json = _decodirRespuestaCruda(res, 'GET /api/libros');
    final rawData = json is Map && json.containsKey('data')
        ? json['data']
        : json;
    final List list = rawData is List ? rawData : const [];

    final total = (json is Map && json['total'] != null)
        ? (json['total'] as num).toInt()
        : list.length;
    final hasMore = (json is Map && json['hasMore'] is bool)
        ? (json['hasMore'] as bool)
        : (skip + list.length < total);

    final libros = list
        .whereType<Map>()
        .map((e) => LibroModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ResultadoLibrosPaginados(
      libros: libros,
      total: total,
      skip: skip,
      limit: limit,
      hasMore: hasMore,
    );
  }

  /// Lista de libros (sin páginas, para el listado).
  static Future<List<LibroModel>> obtenerLibros({
    String? busqueda,
    String campoBusqueda = 'todos',
    int limit = 50,
    int skip = 0,
  }) async {
    final paginado = await obtenerLibrosPaginados(
      busqueda: busqueda,
      campoBusqueda: campoBusqueda,
      limit: limit,
      skip: skip,
    );
    return paginado.libros;
  }

  /// Envía temporalmente una imagen al backend para transcribirla; nunca la guarda.
  static Future<String> transcribirImagen(String pathImagen) async {
    final file = File(pathImagen);
    if (!await file.exists()) {
      throw ApiException('La imagen no existe en la ruta: $pathImagen');
    }

    Uint8List bytes = await file.readAsBytes();
    const String mimeType = 'image/jpeg';

    try {
      // Se ejecuta en un isolate para no congelar la interfaz.
      bytes = await compute(_optimizarImagenOcr, bytes);
    } catch (e) {
      debugPrint('No se pudo optimizar la imagen antes del OCR: $e');
    }
    final base64Image = base64Encode(bytes);







    // Si la app tiene su propia clave, se llama a Gemini directamente:
    // evita la latencia (y los arranques en frío) del backend en Render.
    final claveGemini = (dotenv.maybeGet('GEMINI_API_KEY') ?? '').trim();
    if (claveGemini.isNotEmpty) {
      return _transcribirDirectoConGemini(base64Image, mimeType, claveGemini);
    }

    final res = await _post('/api/transcribir', {
      'imagen': base64Image,
      'mimeType': mimeType,
    }, timeout: _timeoutTranscripcion);

    if (res is Map && res['texto'] != null) {
      return res['texto'].toString().trim();
    }
    throw const ApiException(
      'El backend respondió pero no incluyó texto transcrito.',
    );
  }

  /// Modelos de Gemini disponibles para la clave, del más rápido/estable al resto.
  static const List<String> _modelosGemini = [
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-flash-latest',
  ];

  /// Tiempo máximo por modelo; si uno se cuelga se pasa rápido al siguiente.
  static const Duration _timeoutPorModelo = Duration(seconds: 35);

  static const String _promptTranscripcion =
      'Actúa como un paleógrafo y archivista experto en transcripción de libros '
      'y documentos históricos. Transcribe con la mayor fidelidad posible todo el '
      'texto visible en esta imagen.\n'
      'Reglas:\n'
      '1. Respeta nombres propios, fechas, abreviaturas y ortografía histórica.\n'
      '2. Conserva tildes, diéresis, puntuación, ñ y Ñ.\n'
      '3. Escribe el texto de forma continua; conserva solo los cambios reales de párrafo.\n'
      '4. Si una palabra se corta con guion al final del renglón, únela sin guion.\n'
      '5. Marca las partes ilegibles como [ilegible].\n'
      '6. Devuelve ÚNICAMENTE el texto transcrito, sin introducciones ni bloques de código.';

  static Future<String> _transcribirDirectoConGemini(
    String base64Image,
    String mimeType,
    String apiKey,
  ) async {
    final cuerpo = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _promptTranscripcion},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.1, 'topP': 0.95},
    });

    String ultimoError = 'sin respuesta';
    for (final modelo in _modelosGemini) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$modelo:generateContent?key=$apiKey',
      );
      try {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: cuerpo,
            )
            .timeout(_timeoutPorModelo);

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final partes = data['candidates']?[0]?['content']?['parts'];
          if (partes is List) {
            final texto = partes
                .map((p) => (p is Map ? p['text'] : null) ?? '')
                .join()
                .trim();
            if (texto.isNotEmpty) return texto;
          }
          ultimoError = '$modelo respondió sin texto';
          continue;
        }

        String msg = res.body;
        try {
          msg = jsonDecode(res.body)['error']?['message']?.toString() ?? msg;
        } catch (_) {}
        ultimoError = '$modelo (${res.statusCode}): $msg';
        debugPrint('Gemini: $ultimoError');

        // Clave inválida o petición mal formada: no tiene caso probar otros modelos.
        if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
          throw ApiException('Gemini rechazó la petición: $msg');
        }
      } on TimeoutException {
        ultimoError = '$modelo tardó más de ${_timeoutPorModelo.inSeconds} s';
        debugPrint('Gemini: $ultimoError');
      } on SocketException catch (e) {
        throw ApiException(
          'Sin conexión a internet para transcribir con Gemini: ${e.message}',
        );
      }
    }

    throw ApiException(
      'Gemini no pudo transcribir la página (servicio saturado). '
      'Intenta de nuevo en unos segundos.\nDetalle: $ultimoError',
    );
  }

  /// Detalle completo de un libro (incluye `paginas`).
  /// Si hay conexión se consulta el backend y se actualiza la caché local.
  /// Si no hay conexión o falla la red, se recupera de la caché local para lectura offline.
  static Future<LibroModel?> obtenerDetalleLibro(String id) async {
    try {
      final data = await _get('/api/libros/${Uri.encodeComponent(id)}');
      if (data is! Map) return null;
      final libro = LibroModel.fromJson(Map<String, dynamic>.from(data));
      unawaited(LocalUserPreferencesStore().guardarEnCache(libro));
      return libro;
    } on ApiException catch (e) {
      if (e.esNoEncontrado) return null;
      if (e.esErrorDeConexion) {
        final cache = await LocalUserPreferencesStore().obtenerDeCache(id);
        if (cache != null) return cache;
      }
      rethrow;
    } catch (_) {
      final cache = await LocalUserPreferencesStore().obtenerDeCache(id);
      if (cache != null) return cache;
      rethrow;
    }
  }

  /// Crea o actualiza un libro escaneado (`upsert` en el backend).
  static Future<String> subirLibroEscaneado(LibroModel libro) async {
    await _verificarAlcanzable();

    return _conReintento(() async {
      final res = await _post('/api/libros', libro.toJson());
      return res is Map && res['message'] != null
          ? res['message'].toString()
          : 'Libro guardado';
    });
  }

  /// Falla rápido si el backend no contesta, con un mensaje que dice qué
  /// dirección se intentó y cómo corregirla.
  static Future<void> _verificarAlcanzable() async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        'No está configurada la URL de producción del backend.',
        esErrorDeConexion: true,
      );
    }
    if (await consultarSaludConReintento() != null) return;
    throw ApiException(
      'No hay conexión con el backend de Render en:\n$_baseUrl\n\n'
      'Comprueba tu conexión a Internet e intenta de nuevo en unos momentos.',
      esErrorDeConexion: true,
    );
  }

  /// Reintenta una vez ante fallos de red. Un `upsert` es idempotente, así que
  /// no hay riesgo de crear dos documentos.
  static Future<T> _conReintento<T>(
    Future<T> Function() accion, {
    int intentos = 2,
  }) async {
    for (var i = 1; ; i++) {
      try {
        return await accion();
      } on ApiException catch (e) {
        if (!e.esErrorDeConexion || i >= intentos) rethrow;
        debugPrint(
          'Fallo de red (intento $i/$intentos), reintentando en 2s...',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  static Future<void> eliminarLibro(String id) async {
    await _delete('/api/libros/${Uri.encodeComponent(id)}');
  }
}
