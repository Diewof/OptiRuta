String _normalizar(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

/// Filtra [items] por [consulta] ignorando mayúsculas y tildes, mirando los
/// textos que devuelva [campos]. Con la consulta vacía devuelve todo.
List<T> filtrarPorTexto<T>(
  List<T> items,
  String consulta,
  List<String?> Function(T) campos,
) {
  final String q = _normalizar(consulta.trim());
  if (q.isEmpty) return items;
  return items
      .where(
        (T i) =>
            campos(i)
                .any((String? c) => c != null && _normalizar(c).contains(q)),
      )
      .toList();
}
