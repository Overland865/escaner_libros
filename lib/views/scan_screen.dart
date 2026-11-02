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
/// Implementa el diseño Stitch "Escáner Óptico de Libros" (`f1b23f57...`).
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
  bool _mostrarGuia = true;
  bool _dobleFolio = true;
  int _filtroActivo = 1; // 0: Color Real, 1: Pergamino Cálido, 2: B/N Texto Puro
  String _mensaje = 'Digitalizando y transcribiendo folio...';

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

      if (falloGemini != null) _avisarFalloGemini(falloGemini);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            texto.isEmpty
                ? 'Folio $numero sin texto legible · $motor'
                : 'Folio $numero · $palabras palabras · $motor',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el folio: $e')),
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
        'Digitalizando y transcribiendo folio...',
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

  void _mostrarInfoTranscripcion() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8C4E26)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sensor Óptico y Transcripción',
                style: TextStyle(fontFamily: 'Literata', fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cada captura se envía de forma segura al backend para transcribirla '
          'con Gemini AI respetando signos clásicos y párrafos. Si no hay red '
          'disponible, se procesa localmente mediante ML Kit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
            if (_mostrarGuia)
              _buildOpticalAlignmentHud(),

            // 3. Barra Superior Flotante (Stitch Top Navigation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopNavigation(),
            ),

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

    // Aplicar matiz visual según el filtro seleccionado en la barra inferior
    if (_filtroActivo == 1) {
      // Pergamino Cálido
      preview = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFFD4A373).withValues(alpha: 0.14),
          BlendMode.softLight,
        ),
        child: preview,
      );
    } else if (_filtroActivo == 2) {
      // B/N Texto Puro
      preview = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: preview,
      );
    }

    return preview;
  }

  Widget _buildFallbackViewport(bool hayControlador) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            Color(0xFF362219),
            Color(0xFF1A110D),
          ],
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

          // Controles de Sensor Derecha (Guía & Info Curvatura/OCR)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topCircleButton(
                icon: Icons.crop_free_rounded,
                active: _mostrarGuia,
                tooltip: _mostrarGuia ? 'Ocultar retícula' : 'Mostrar retícula',
                onTap: () => setState(() => _mostrarGuia = !_mostrarGuia),
              ),
              const SizedBox(width: 8),
              _topCircleButton(
                icon: Icons.auto_fix_high_rounded,
                active: true,
                tooltip: 'Información de corrección y OCR',
                onTap: _mostrarInfoTranscripcion,
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
    final numIzq = (_paginas.length * 2) + 1;
    final numDer = numIzq + 1;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 68,
            bottom: 188,
            left: 20,
            right: 20,
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Páginas detectadas • Calibración 100%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFCF9F4),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Marco central con cruces de latón en las 4 esquinas y eje de lomo
              Expanded(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _StitchReticlePainter(dobleFolio: _dobleFolio),
                    child: Stack(
                      children: [
                        if (_dobleFolio) ...[
                          // Etiqueta Folio Verso (Izquierda)
                          Positioned(
                            top: 12,
                            left: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FOLIO VERSO',
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 10,
                                    color: const Color(0xFFD4A373)
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                                Text(
                                  'Pág. $numIzq',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFCF9F4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Etiqueta Folio Recto (Derecha)
                          Positioned(
                            top: 12,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'FOLIO RECTO',
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 10,
                                    color: const Color(0xFFD4A373)
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                                Text(
                                  'Pág. $numDer',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFCF9F4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Píldora central de Eje del Lomo
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C1810)
                                      .withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD4A373)
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Text(
                                  'EJE DEL LOMO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Color(0xFFD4A373),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Positioned(
                            top: 12,
                            left: 14,
                            child: Text(
                              'FOLIO INDIVIDUAL • PÁG. ${_paginas.length + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: Color(0xFFD4A373),
                              ),
                            ),
                          ),
                        ],

                        // Indicadores inferiores de nitidez dentro del marco
                        Positioned(
                          bottom: 10,
                          left: 14,
                          child: _hudMicroBadge(
                            Icons.straighten_rounded,
                            'Texto nítido',
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 14,
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
              const SizedBox(height: 12),

              // Selector segmentado: Página Simple | Doble Folio (2x)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1810).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFCF9F4).withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modePillButton(
                      icon: Icons.description_outlined,
                      label: 'Página Simple',
                      selected: !_dobleFolio,
                      onTap: () => setState(() => _dobleFolio = false),
                    ),
                    const SizedBox(width: 4),
                    _modePillButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Doble Folio (2x)',
                      selected: _dobleFolio,
                      onTap: () => setState(() => _dobleFolio = true),
                    ),
                  ],
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
            style: const TextStyle(
              fontSize: 9.5,
              color: Color(0xFFFCF9F4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modePillButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8C4E26) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected
                  ? const Color(0xFFFCF9F4)
                  : const Color(0xFFEDE7DF).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? const Color(0xFFFCF9F4)
                    : const Color(0xFFEDE7DF).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
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
                  label: 'Pergamino Cálido',
                  dotColor: const Color(0xFFF5EBD6),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  index: 2,
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
                          colors: [
                            Color(0xFFFCF9F4),
                            Color(0xFFE8E2D7),
                          ],
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
                            color: const Color(0xFF2C1810).withValues(alpha: 0.9),
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
  final bool dobleFolio;

  _StitchReticlePainter({required this.dobleFolio});

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

    // Eje central de pliego (si Doble Folio está activo)
    if (dobleFolio) {
      final centerX = size.width / 2;
      final dashPaint = Paint()
        ..color = const Color(0xFFD4A373).withValues(alpha: 0.55)
        ..strokeWidth = 1.2;

      double y = 32;
      while (y < size.height - 20) {
        canvas.drawLine(
          Offset(centerX, y),
          Offset(centerX, y + 6),
          dashPaint,
        );
        y += 12;
      }
    }

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
  bool shouldRepaint(covariant _StitchReticlePainter oldDelegate) =>
      oldDelegate.dobleFolio != dobleFolio;
}
