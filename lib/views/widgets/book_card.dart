import 'package:flutter/material.dart';

import '../../models/libro_model.dart';
import '../book_detail_screen.dart';

class BookCard extends StatelessWidget {
  final LibroModel libro;
  final bool pendiente;
  final String? errorSync;
  final bool esFavorito;
  final VoidCallback? onRetorno;

  const BookCard({
    super.key,
    required this.libro,
    this.pendiente = false,
    this.errorSync,
    this.esFavorito = false,
    this.onRetorno,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Gradientes editoriales clásicos según la temática
    final tipo = libro.tipoLibro.toLowerCase();
    final isHistory = tipo.contains('historia') || tipo.contains('filosof') || tipo.contains('ensayo');
    final isFiction = tipo.contains('ficci') || tipo.contains('novela') || tipo.contains('cuento');
    final isFantasy = tipo.contains('fantas') || tipo.contains('magia') || tipo.contains('poes');

    final gradientColors = isHistory
        ? const [Color(0xFF6B2D2D), Color(0xFF9E4747)] // Burdeos clásico
        : isFiction
            ? const [Color(0xFF8C4E26), Color(0xFFC48B5E)] // Cuero tostado
            : isFantasy
                ? const [Color(0xFF2D4A3E), Color(0xFF52796F)] // Verde bosque encuadernado
                : const [Color(0xFF3E2723), Color(0xFF6D4C41)]; // Café encuadernación

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pendiente
              ? Colors.amber.shade700.withValues(alpha: 0.6)
              : colors.outlineVariant,
          width: pendiente ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                  errorSync: errorSync,
                ),
              ),
            );
            onRetorno?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada de libro clásica con sombra suave y lomo
                    Container(
                      width: 50,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 8,
                            offset: const Offset(1, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            width: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.white.withValues(alpha: 0.15),
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: Color(0xFFFCF9F4),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            libro.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Literata',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  libro.autor.isNotEmpty
                                      ? libro.autor
                                      : 'Autor no especificado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Newsreader',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (esFavorito) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFD4A373),
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer.withValues(alpha: isDark ? 0.4 : 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.secondary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        libro.tipoLibro,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? colors.secondary : const Color(0xFF6E3616),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (libro.editorial.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Text(
                          libro.editorial,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (pendiente)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900.withValues(alpha: isDark ? 0.35 : 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.shade700.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 14,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pendiente',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            libro.anioInicio == libro.anioFin
                                ? '${libro.anioInicio}'
                                : '${libro.anioInicio} - ${libro.anioFin}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (libro.paginas.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${libro.paginas.length} págs',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
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
