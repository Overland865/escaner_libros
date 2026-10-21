import 'package:flutter/material.dart';

/// Datos del documento a digitalizar.
class DatosLibroForm {
  final String codigo;
  final String titulo;
  final String iglesia;
  final String tipoLibro;
  final int anioPublicacion;

  const DatosLibroForm({
    required this.codigo,
    required this.titulo,
    required this.iglesia,
    required this.tipoLibro,
    required this.anioPublicacion,
  });
}

/// Formulario reutilizable embebido en la pestaña "Escanear".
class BookFormView extends StatefulWidget {
  final ValueChanged<DatosLibroForm> onEnviar;

  const BookFormView({super.key, required this.onEnviar});

  @override
  State<BookFormView> createState() => _BookFormViewState();
}

class _BookFormViewState extends State<BookFormView> {
  final _formKey = GlobalKey<FormState>();

  static const tiposDisponibles = [
    'Bautismos y Defunciones',
    'Bautismos',
    'Defunciones',
    'Matrimonios',
    'Confirmaciones',
    'Actas Parroquiales',
    'Visitas Pastorales',
    'Documento Histórico General',
  ];

  final _codigoController = TextEditingController();
  final _tituloController = TextEditingController();
  final _iglesiaController = TextEditingController();
  final _anioPublicacionController = TextEditingController();

  String? _tipoLibro;

  @override
  void dispose() {
    _codigoController.dispose();
    _tituloController.dispose();
    _iglesiaController.dispose();
    _anioPublicacionController.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onEnviar(
      DatosLibroForm(
        codigo: _codigoController.text.trim(),
        titulo: _tituloController.text.trim(),
        iglesia: _iglesiaController.text.trim(),
        tipoLibro: _tipoLibro!,
        anioPublicacion: int.parse(_anioPublicacionController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codigoController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Código / Identificador Único',
              hintText: 'Ej. LIB-1850-SAN-001',
              prefixIcon: Icon(Icons.qr_code),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _tituloController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título del Libro',
              hintText: 'Ej. Libro de Bautismos y Defunciones',
              prefixIcon: Icon(Icons.menu_book),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _iglesiaController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Parroquia / Iglesia Custodia',
              hintText: 'Ej. Parroquia San Miguel Arcángel',
              prefixIcon: Icon(Icons.church),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _tipoLibro,
            decoration: const InputDecoration(
              labelText: 'Tipo de Documento',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            items: tiposDisponibles
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) {
              setState(() => _tipoLibro = val);
            },
            validator: (value) => value == null ? 'Selecciona un tipo' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _anioPublicacionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Año de publicación',
              hintText: 'Ej. 1850',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final year = int.tryParse(value?.trim() ?? '');
              if (year == null || year < 1 || year > 9999) {
                return 'Ingresa un año válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text(
              'Comenzar Digitalización con Cámara',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
