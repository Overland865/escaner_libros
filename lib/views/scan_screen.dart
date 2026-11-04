import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/biblioteca_controller.dart';
import '../models/libro_model.dart';
import '../models/pagina_model.dart';
import '../services/ocr_service.dart';
import 'preview_screen.dart';

/// Escáner Óptico de Libros en vivo + OCR página por página.
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
  bool _tomandoFoto = false;
  int _enCola = 0;
  int _siguienteNumeroPagina = 1;
  final List<Future<void>> _tareasActivas = [];
  bool _saliendo = false;
  bool _mostrarGuia = true;
  int _filtroActivo = 0; // 0: Color Real, 1: B/N Texto Puro
  String _mensaje = 'Digitalizando y transcribiendo página...';

  FlashMode _flashMode = FlashMode.off;
  double _zoomActual = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  Offset? _focusOffset;
  bool _mostrarFocoIndicador = false;

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

      // Usar high (720p) para disparo instantáneo y peso ligero (~200 KB) ideal para Gemini OCR
      CameraController controller = CameraController(
        camaras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await controller.initialize();
      } catch (_) {
        controller = CameraController(
          camaras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();
      }

      // Habilitar autoenfoque continuo si está disponible
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      // Leer niveles de zoom soportados
      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {}

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

  Future<void> _enfocarEnPunto(
    TapDownDetails details,
    CameraController camara,
  ) async {
    if (!camara.value.isInitialized) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final offset = details.localPosition;

    final double x = (offset.dx / size.width).clamp(0.0, 1.0);
    final double y = (offset.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _focusOffset = offset;
      _mostrarFocoIndicador = true;
    });

    try {
      await camara.setFocusPoint(Offset(x, y));
      await camara.setExposurePoint(Offset(x, y));
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _mostrarFocoIndicador = false);
    });
  }

  Future<void> _alternarZoom() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) return;
    final double objetivo = _zoomActual <= 1.2
        ? (2.0 <= _maxZoom ? 2.0 : _maxZoom)
        : _minZoom;
    try {
      await camara.setZoomLevel(objetivo);
      setState(() => _zoomActual = objetivo);
    } catch (_) {}
  }

  Future<void> _alternarFlash() async {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) return;
    final nuevo = _flashMode == FlashMode.torch
        ? FlashMode.off
        : FlashMode.torch;
    try {
      await camara.setFlashMode(nuevo);
      setState(() => _flashMode = nuevo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linterna no disponible en este dispositivo'),
          ),
        );
      }
    }
  }

  void _encolarImagen(
    String ruta,
    int numero, {
    bool eliminarImagenAlFinal = false,
  }) {
    setState(() => _enCola++);

    late final Future<void> tarea;
    tarea = () async {
      try {
        final resultado = await _ocr.procesarImagenDetallado(ruta);
        final texto = (resultado['texto'] as String? ?? '').trim();
        final motor = resultado['motor'] as String? ?? 'Gemini AI';

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
          _paginas.sort((a, b) => a.numeroPagina.compareTo(b.numeroPagina));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              texto.isEmpty
                  ? 'Página $numero sin texto legible · $motor'
                  : '✓ Página $numero lista · $palabras palabras',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade900,
              content: Text('Error en página $numero: $e'),
              duration: const Duration(seconds: 4),
            ),
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
        _tareasActivas.remove(tarea);
        if (mounted) {
          setState(() {
            if (_enCola > 0) _enCola--;
          });
        }
      }
    }();

    _tareasActivas.add(tarea);
  }

  Future<void> _capturar() async {
    final camara = _camara;
    if (camara == null ||
        !camara.value.isInitialized ||
        _tomandoFoto ||
        _procesando) {
      return;
    }
    setState(() => _tomandoFoto = true);
    try {
      final XFile foto = await camara.takePicture();
      final int numero = _siguienteNumeroPagina++;
      if (mounted) setState(() => _tomandoFoto = false);
      _encolarImagen(
        foto.path,
        numero,
        eliminarImagenAlFinal: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _tomandoFoto = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo tomar la foto: $e')));
      }
    }
  }

  Future<void> _importarDeGaleria() async {
    if (_procesando) return;
    try {
      final seleccion = await _galeria.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (seleccion.isEmpty) return;
      for (final XFile archivo in seleccion) {
        if (!mounted) return;
        final int numero = _siguienteNumeroPagina++;
        _encolarImagen(archivo.path, numero);
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
    if (_paginas.isEmpty && _tareasActivas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes escanear al menos una página')),
      );
      return;
    }

    if (_tareasActivas.isNotEmpty) {
      setState(() {
        _procesando = true;
        _mensaje =
            'Finalizando transcripción de $_enCola página(s) en curso...';
      });
      await Future.wait(List<Future<void>>.from(_tareasActivas));
      if (!mounted) return;
      setState(() => _procesando = false);
    }

    if (_paginas.isEmpty) return;
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
      setState(() {
        _saliendo = false;
        _siguienteNumeroPagina = _paginas.length + 1;
      });
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
    final lista = camara != null && camara.value.isInitialized;

    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A110D),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Visor de cámara o estado alternativo sobre fondo cuero oscuro
            if (lista)
              _buildCameraViewport(camara)
            else
              _buildFallbackViewport(camara != null),

            // 2. HUD Óptico de Encuadre de Pliegos (Stitch Screen 5)
            if (_mostrarGuia) _buildOpticalAlignmentHud(),

            // 3. Barra Superior Flotante (Stitch Top Navigation)
            Positioned(top: 0, left: 0, right: 0, child: _buildTopNavigation()),

            // 4. Consola Inferior de Disparo Artesanal y Filtros (Stitch Bottom Deck)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControlDeck(),
            ),

            // 5. Overlay de procesamiento OCR
            if (_procesando || _saliendo) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraViewport(CameraController camara) {
    Widget preview = FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: camara.value.previewSize?.height ?? 1080,
        height: camara.value.previewSize?.width ?? 1920,
        child: CameraPreview(camara),
      ),
    );

    // Aplicar matiz visual si está activo el filtro B/N Texto Puro
    if (_filtroActivo == 1) {
      // B/N Texto Puro
      preview = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33,
          0.59,
          0.11,
          0,
          0,
          0.33,
          0.59,
          0.11,
          0,
          0,
          0.33,
          0.59,
          0.11,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: preview,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _enfocarEnPunto(details, camara),
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          if (_mostrarFocoIndicador && _focusOffset != null)
            Positioned(
              left: _focusOffset!.dx - 28,
              top: _focusOffset!.dy - 28,
              child: IgnorePointer(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4A373),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4A373),
                        shape: BoxShape.circle,
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

  Widget _buildFallbackViewport(bool hayControlador) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF362219), Color(0xFF1A110D)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1810),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_back_outlined,
                  size: 32,
                  color: Color(0xFFD4A373),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hayControlador
                    ? 'Calibrando lente óptica...'
                    : 'Visor en modo de importación de pliegos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Literata',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFCF9F4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Puedes importar imágenes de páginas fotografiadas desde tu galería con el botón inferior izquierdo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: const Color(0xFFEDE7DF).withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _importarDeGaleria,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD4A373),
                  side: const BorderSide(color: Color(0xFFD4A373)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Seleccionar pliegos de la galería'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A110D).withValues(alpha: 0.9),
            const Color(0xFF1A110D).withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Botón circular Cerrar
          _topCircleButton(
            icon: Icons.close_rounded,
            tooltip: 'Cerrar escáner',
            onTap: _procesando ? null : () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),

          // Cápsula central: TOMO EN CURSO + Título
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1810).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOMO EN CURSO',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                        color: Color(0xFFD4A373),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Literata',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFCF9F4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Controles de Sensor Derecha (Linterna, Zoom, Guía & Info)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topCircleButton(
                icon: _flashMode == FlashMode.torch
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                active: _flashMode == FlashMode.torch,
                tooltip: _flashMode == FlashMode.torch
                    ? 'Apagar linterna'
                    : 'Encender linterna',
                onTap: _alternarFlash,
              ),
              const SizedBox(width: 6),
              _topCircleButton(
                icon: _zoomActual > 1.2
                    ? Icons.zoom_out_rounded
                    : Icons.zoom_in_rounded,
                active: _zoomActual > 1.2,
                tooltip: _zoomActual > 1.2
                    ? 'Zoom 2x activo (tocar para 1x)'
                    : 'Zoom 1x (tocar para 2x en texto pequeño)',
                onTap: _alternarZoom,
              ),
              const SizedBox(width: 6),
              _topCircleButton(
                icon: Icons.crop_free_rounded,
                active: _mostrarGuia,
                tooltip: _mostrarGuia ? 'Ocultar retícula' : 'Mostrar retícula',
                onTap: () => setState(() => _mostrarGuia = !_mostrarGuia),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topCircleButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF8C4E26).withValues(alpha: 0.85)
                : const Color(0xFF2C1810).withValues(alpha: 0.78),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? const Color(0xFFD4A373).withValues(alpha: 0.65)
                  : const Color(0xFFFCF9F4).withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? const Color(0xFFD4A373) : const Color(0xFFFCF9F4),
          ),
        ),
      ),
    );
  }

  Widget _buildOpticalAlignmentHud() {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 56,
            bottom: 150,
            left: 14,
            right: 14,
          ),
          child: Column(
            children: [
              // Píldora superior de telemetría óptica
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A110D).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_enCola > 0)
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFFD4A373),
                        ),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _enCola > 0
                          ? 'Transcribiendo $_enCola pág. en segundo plano...'
                          : 'Página detectada • Calibración 100%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFCF9F4),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Marco central con cruces de latón en las 4 esquinas estirado para página simple
              Expanded(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StitchReticlePainter(),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 14,
                          left: 16,
                          child: Text(
                            'PÁGINA $_siguienteNumeroPagina',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Color(0xFFD4A373),
                            ),
                          ),
                        ),

                        // Indicadores inferiores de nitidez dentro del marco
                        Positioned(
                          bottom: 12,
                          left: 16,
                          child: _hudMicroBadge(
                            Icons.straighten_rounded,
                            'Texto nítido',
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 16,
                          child: _hudMicroBadge(
                            Icons.verified_outlined,
                            'Borde recto',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudMicroBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFD4A373)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFFFCF9F4)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlDeck() {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF1A110D),
            const Color(0xFF1A110D).withValues(alpha: 0.94),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hilera de filtros cromáticos de archivo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _filterChip(
                  index: 0,
                  label: 'Color Real',
                  dotColor: const Color(0xFFE09F67),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  index: 1,
                  label: 'B/N Texto Puro',
                  dotColor: Colors.white,
                ),
                const SizedBox(width: 8),
                // Acceso rápido a Galería en la barra de herramientas
                InkWell(
                  onTap: _procesando ? null : _importarDeGaleria,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1810).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD4A373).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 13,
                          color: Color(0xFFD4A373),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Galería',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFCF9F4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Consola principal de captura (3 columnas: Pila de Folios | Obturador Artesanal | Terminar)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Izquierda: Pila de Folios Escaneados con contador
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _procesando
                        ? null
                        : (_paginas.isNotEmpty
                              ? _irARevision
                              : _importarDeGaleria),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 54,
                          height: 62,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Pliegos apilados detrás
                              Positioned(
                                top: 4,
                                left: 4,
                                right: 4,
                                bottom: 0,
                                child: Transform.rotate(
                                  angle: -0.1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8E2D7)
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              // Pliego frontal estilo pergamino
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCF9F4),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD4A373),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      height: 2,
                                      color: const Color(0xFF8C4E26)
                                          .withValues(alpha: 0.4),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _paginas.isEmpty
                                          ? 'Vacío'
                                          : 'Fol. ${_paginas.length}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Literata',
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2C1810),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Insignia con cantidad de páginas
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8C4E26),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFCF9F4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '${_paginas.length}',
                                    style: const TextStyle(
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
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Capturados',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFD4A373),
                              ),
                            ),
                            Text(
                              _paginas.isEmpty ? 'Importar' : 'Revisar',
                              style: const TextStyle(
                                fontFamily: 'Literata',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFCF9F4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Centro: Botón de Obturador Artesanal (Gilded Brass & Leather Ring)
              GestureDetector(
                onTap: _procesando ? null : _capturar,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFD4A373),
                        Color(0xFF8C4E26),
                        Color(0xFF2C1810),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A110D),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4A373).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFCF9F4), Color(0xFFE8E2D7)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.photo_camera_rounded,
                          size: 30,
                          color: Color(0xFF2C1810),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Derecha: Botón Terminar / Finalizar Lote
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _procesando ? null : _irARevision,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C1810)
                                .withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD4A373)
                                  .withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFFD4A373),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Terminar',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: Color(0xFFD4A373),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required int index,
    required String label,
    required Color dotColor,
  }) {
    final selected = _filtroActivo == index;
    return GestureDetector(
      onTap: () => setState(() => _filtroActivo = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFD4A373).withValues(alpha: 0.22)
              : const Color(0xFF2C1810).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFD4A373)
                : const Color(0xFFFCF9F4).withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? const Color(0xFFD4A373)
                    : const Color(0xFFEDE7DF).withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: const Color(0xCC1A110D),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2C1810),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4A373).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFD4A373)),
              const SizedBox(height: 16),
              Text(
                _saliendo ? 'Preparando mesa de revisión OCR...' : _mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Literata',
                  color: Color(0xFFFCF9F4),
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StitchReticlePainter extends CustomPainter {
  const _StitchReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    // Borde sutil exterior
    final borderPaint = Paint()
      ..color = const Color(0xFFD4A373).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(rrect, borderPaint);

    // Cruces de latón en las 4 esquinas
    final cornerPaint = Paint()
      ..color = const Color(0xFFD4A373)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    // Top-Left
    canvas.drawLine(
      Offset(rect.left, rect.top + len),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + len, rect.top),
      cornerPaint,
    );
    // Top-Right
    canvas.drawLine(
      Offset(rect.right - len, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + len),
      cornerPaint,
    );
    // Bottom-Left
    canvas.drawLine(
      Offset(rect.left, rect.bottom - len),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + len, rect.bottom),
      cornerPaint,
    );
    // Bottom-Right
    canvas.drawLine(
      Offset(rect.right - len, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - len),
      cornerPaint,
    );

    // Línea horizontal de barrido óptico
    final scanY = size.height * 0.52;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFFD4A373).withValues(alpha: 0.65),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2))
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(12, scanY),
      Offset(size.width - 12, scanY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StitchReticlePainter oldDelegate) => false;
}
