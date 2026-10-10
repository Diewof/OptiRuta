/// Recorta [valor] y convierte una cadena vacia en `null`. Usado por los
/// casos de uso de alta/edicion de cliente para higienizar los campos de
/// contacto opcionales antes de enviarlos.
String? limpiarTextoOpcional(String? valor) {
  final String? recortado = valor?.trim();
  return (recortado == null || recortado.isEmpty) ? null : recortado;
}
