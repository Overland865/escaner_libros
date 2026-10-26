import 'package:flutter/material.dart';

/// Datos del documento a digitalizar.
class DatosLibroForm {
  final String titulo;
  final String autor;
  final String editorial;
  final String tipoLibro;
  final int anioPublicacion;

  const DatosLibroForm({
    required this.titulo,
    required this.autor,
    required this.editorial,
    required this.tipoLibro,
    required this.anioPublicacion,
  });
}

/// Formulario reutilizable embebido en la pestaña "Escanear".
class BookFormView extends StatefulWidget {
  final ValueChanged<DatosLibroForm> onEnviar;

  static const tiposDisponibles = [
    'Ficción',
    'Ciencia ficción / Futurista',
    'Fantasía y magia',
    'Terror y horror',
    'Misterio y suspenso',
    'Aventura',
    'Romance',
    'Novela',
    'Cuento',
    'Poesía',
    'Ensayo',
    'Biografía',
    'Historia',
    'Filosofía',
    'Ciencia',
    'Tecnología',
    'Educación',
    'Infantil y juvenil',
    'Cómic y novela gráfica',
    'Arte y fotografía',
    'Cocina',
    'Salud y bienestar',
    'Religión y espiritualidad',
    'Desarrollo personal',
    'Referencia y consulta',
    'Otro',
  ];

  static IconData iconoDe(String genero) {
    switch (genero) {
      case 'Ficción':
        return Icons.auto_stories;
      case 'Ciencia ficción / Futurista':
        return Icons.rocket_launch_outlined;
      case 'Fantasía y magia':
        return Icons.auto_awesome;
      case 'Terror y horror':
        return Icons.psychology_alt_outlined;
      case 'Misterio y suspenso':
        return Icons.search;
      case 'Aventura':
        return Icons.explore_outlined;
      case 'Romance':
        return Icons.favorite_border;
      case 'Novela':
        return Icons.menu_book;
      case 'Cuento':
        return Icons.import_contacts;
      case 'Poesía':
        return Icons.format_quote;
      case 'Ensayo':
        return Icons.article_outlined;
      case 'Biografía':
        return Icons.person_outline;
      case 'Historia':
        return Icons.history_edu;
      case 'Filosofía':
        return Icons.lightbulb_outline;
      case 'Ciencia':
        return Icons.science_outlined;
      case 'Tecnología':
        return Icons.computer;
      case 'Educación':
        return Icons.school_outlined;
      case 'Infantil y juvenil':
        return Icons.child_care;
      case 'Cómic y novela gráfica':
        return Icons.photo_album_outlined;
      case 'Arte y fotografía':
        return Icons.palette_outlined;
      case 'Cocina':
        return Icons.restaurant;
      case 'Salud y bienestar':
        return Icons.spa_outlined;
      case 'Religión y espiritualidad':
        return Icons.church_outlined;
      case 'Desarrollo personal':
        return Icons.self_improvement;
      case 'Referencia y consulta':
        return Icons.library_books_outlined;
      case 'Otro':
        return Icons.edit_note;
      default:
        return Icons.category_outlined;
    }
  }

  const BookFormView({super.key, required this.onEnviar});

  @override
  State<BookFormView> createState() => _BookFormViewState();
}

class _BookFormViewState extends State<BookFormView> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _autorController = TextEditingController();
  final _editorialController = TextEditingController();
  final _anioPublicacionController = TextEditingController();
  final _otroTipoController = TextEditingController();

  String? _tipoLibro;

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _editorialController.dispose();
    _anioPublicacionController.dispose();
    _otroTipoController.dispose();
    super.dispose();
  }

  void _enviar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tipoFinal = _tipoLibro == 'Otro'
        ? _otroTipoController.text.trim()
        : _tipoLibro!;

    widget.onEnviar(
      DatosLibroForm(
        titulo: _tituloController.text.trim(),
        autor: _autorController.text.trim(),
        editorial: _editorialController.text.trim(),
        tipoLibro: tipoFinal,
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
            controller: _tituloController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Título del libro',
              prefixIcon: Icon(Icons.menu_book),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _autorController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Autor',
              hintText: 'Nombre del autor',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _editorialController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Editorial (opcional)',
              hintText: 'Nombre de la editorial',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _tipoLibro,
            dropdownColor: const Color(0xFF22232E),
            borderRadius: BorderRadius.circular(16),
            menuMaxHeight: 380,
            elevation: 12,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFFC6BFFF),
            ),
            decoration: const InputDecoration(
              labelText: 'Género / tipo de libro',
              hintText: 'Selecciona una categoría',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            selectedItemBuilder: (context) {
              return BookFormView.tiposDisponibles.map((t) {
                final icono = BookFormView.iconoDe(t);
                return Row(
                  children: [
                    Icon(icono, size: 20, color: const Color(0xFFC6BFFF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE6E1F5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: BookFormView.tiposDisponibles.map((t) {
              final esSeleccionado = t == _tipoLibro;
              final icono = BookFormView.iconoDe(t);
              return DropdownMenuItem<String>(
                value: t,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: esSeleccionado
                              ? const Color(0xFF39345C)
                              : const Color(0xFF2C2D3A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icono,
                          size: 18,
                          color: esSeleccionado
                              ? const Color(0xFFC6BFFF)
                              : const Color(0xFFB9B4C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: esSeleccionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: esSeleccionado
                                ? const Color(0xFFE6E1F5)
                                : const Color(0xFFD0CBE0),
                          ),
                        ),
                      ),
                      if (esSeleccionado)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Color(0xFFC6BFFF),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _tipoLibro = val);
            },
            validator: (value) => value == null ? 'Selecciona un tipo' : null,
          ),
          if (_tipoLibro == 'Otro') ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _otroTipoController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Escribe el género o tipo',
                hintText: 'Ej. Grimorio, Crónica medieval, Tratado...',
                prefixIcon: const Icon(Icons.edit_note),
                border: const OutlineInputBorder(),
                helperText: 'Género libre para este libro',
                helperStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              validator: (value) {
                if (_tipoLibro == 'Otro' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Por favor escribe el género del libro';
                }
                return null;
              },
            ),
          ],
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
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
