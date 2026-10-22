import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/biblioteca_controller.dart';
import '../models/libro_model.dart';
import '../models/pagina_model.dart';
import '../services/ocr_service.dart';
import 'preview_screen.dart';

/// Cámara en vivo + OCR página por página.
///
/// Devuelve `true` al navigation si el libro quedó guardado en el dispositivo
/// (con o sin sync al backend).
class ScanScreen extends StatefulWidget {
  final String idLibro;
  final String titulo;
  final String autor;
  final String editorial;
  final String tipoLibro;
  final int anioPublicacion;
  final BibliotecaController biblioteca;

  const ScanScreen({
    super.key,
    required this.idLibro,
    required this.titulo,
    required this.autor,
    required this.editorial,
    required this.tipoLibro,
    required this.anioPublicacion,
    required this.biblioteca,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _camara;
  final OcrService _ocr = OcrService();
  final List<PaginaModel> _paginas = [];
  final ImagePicker _galeria = ImagePicker();

  bool _procesando = false;
  bool _saliendo = false;
  String _mensaje = 'Digitalizando y transcribiendo página...';

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró ninguna cámara en el dispositivo'),
            ),
          );
        }
        return;
      }
      final controller = CameraController(
        camaras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camara = controller);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la cámara: $e')),
        );
      }
    }
  }

  /// Transcribe una imagen y la agrega al lote de páginas.
  Future<void> _procesarImagen(
    String ruta,
    String mensajeCarga, {
    bool eliminarImagenAlFinal = false,
  }) async {
    setState(() {
      _procesando = true;
      _mensaje = mensajeCarga;
    });

    try {
      final resultado = await _ocr.procesarImagenDetallado(ruta);
      final texto = (resultado['texto'] as String? ?? '').trim();
      final motor = resultado['motor'] as String? ?? 'OCR';
      final falloGemini = resultado['falloGemini'] as String?;

      final numero = _paginas.length + 1;
      final palabras = texto.isEmpty
          ? 0
          : texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length;

      if (!mounted) return;
      setState(() {
        _paginas.add(
          PaginaModel(
            numeroPagina: numero,
            nombreArchivo: 'pagina_${numero.toString().padLeft(3, '0')}.txt',
            conteoPalabras: palabras,
            texto: texto,
            motor: motor,
          ),
        );
      });

      // Si se cayó a ML Kit, el motivo importa: el usuario puede corregirlo.
      if (falloGemini != null) _avisarFalloGemini(falloGemini);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            texto.isEmpty
                ? 'Página $numero sin texto legible · $motor'
                : 'Página $numero · $palabras palabras · $motor',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la página: $e')),
        );
      }
    } finally {
      if (eliminarImagenAlFinal) {
        try {
          final imagenTemporal = File(ruta);
          if (await imagenTemporal.exists()) await imagenTemporal.delete();
        } catch (e) {
          debugPrint('No se pudo eliminar la captura temporal: $e');
        }
      }
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Muestra el motivo real por el que falló Gemini, para que el usuario
  /// pueda corregirlo en vez de ver un "fallback" sin explicación.
  void _avisarFalloGemini(String motivo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: Colors.amber.shade900,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Se usó ML Kit local',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    motivo,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturar() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized || _procesando) return;
    try {
      final XFile foto = await camara.takePicture();
      await _procesarImagen(
        foto.path,
        'Digitalizando y transcribiendo página...',
        eliminarImagenAlFinal: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: $e')));
      }
    }
  }

  /// Permite transcribir páginas ya fotografiadas sin usar la cámara en vivo.
  Future<void> _importarDeGaleria() async {
    if (_procesando) return;
    try {
      final seleccion = await _galeria.pickMultiImage(imageQuality: 92);
      if (seleccion.isEmpty) return;
      for (final XFile archivo in seleccion) {
        if (!mounted) return;
        await _procesarImagen(archivo.path, 'Procesando ${archivo.name}...');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la galería: $e')),
        );
      }
    }
  }

  Future<void> _irARevision() async {
    if (_paginas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes escanear al menos una página')),
      );
      return;
    }
    setState(() => _saliendo = true);

    final libro = LibroModel(
      id: widget.idLibro,
      isbnOCodigo: widget.idLibro,
      titulo: widget.titulo,
      autor: widget.autor,
      editorial: widget.editorial,
      tipoLibro: widget.tipoLibro,
      anioInicio: widget.anioPublicacion,
      anioFin: widget.anioPublicacion,
      palabrasClave: [
        widget.tipoLibro.toLowerCase(),
        widget.autor.toLowerCase(),
      ],
      paginas: _paginas,
    );

    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PreviewScreen(libro: libro, biblioteca: widget.biblioteca),
      ),
    );

    if (!mounted) return;
    if (guardado == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saliendo = false);
    }
  }

  @override
  void dispose() {
    _camara?.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    final lista = _camaraLista(camara);

    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.titulo,
            style: const TextStyle(fontSize: 17),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton.icon(
              onPressed: _procesando ? null : _irARevision,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Finalizar'),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!lista) _sinCamara(camara != null),
            if (lista) _vistaCamara(camara!),
            if (_procesando || _saliendo) _overlay(),
          ],
        ),
      ),
    );
  }

  bool _camaraLista(CameraController? c) => c != null && c.value.isInitialized;

  Widget _sinCamara(bool hayControlador) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography,
              size: 54,
              color: hayControlador ? Colors.grey : Colors.amber.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              hayControlador
                  ? 'La cámara no está lista.'
                  : 'No se pudo iniciar la cámara.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Habilita el permiso de cámara en los ajustes del sistema o '
              'continúa importando páginas desde la galería.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _importarDeGaleria,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Importar desde la galería'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vistaCamara(CameraController camara) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: camara.value.previewSize?.height ?? 1080,
            height: camara.value.previewSize?.width ?? 1920,
            child: CameraPreview(camara),
          ),
        ),
        Positioned(top: 16, left: 16, child: const _IndicadorTranscripcion()),
        Positioned(
          top: 16,
          right: 16,
          child: _ContadorPaginas(cantidad: _paginas.length),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Importar desde la galería',
                  onPressed: _procesando ? null : _importarDeGaleria,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                FloatingActionButton.large(
                  onPressed: _procesando ? null : _capturar,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF1A237E),
                    size: 32,
                  ),
                ),
                IconButton(
                  tooltip: 'Finalizar y revisar',
                  onPressed: _procesando ? null : _irARevision,
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _overlay() {
    return Container(
      color: const Color(0xB3000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _saliendo ? 'Guardando en la base de datos...' : _mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContadorPaginas extends StatelessWidget {
  final int cantidad;
  const _ContadorPaginas({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            '$cantidad ${cantidad == 1 ? 'página' : 'páginas'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicadorTranscripcion extends StatelessWidget {
  const _IndicadorTranscripcion();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transcripción segura',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Cada página se envía al backend para transcribirla con Gemini. '
              'La imagen no se guarda en la biblioteca; solo se conserva el '
              'texto resultante. Si el backend no está disponible, se usa ML Kit '
              'localmente. Las imágenes elegidas de la galería no se modifican.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              'Gemini backend',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
