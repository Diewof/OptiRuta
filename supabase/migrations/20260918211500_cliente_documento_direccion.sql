-- Agrega documento (NIT/CC) y direccion a cliente: decision tomada al
-- construir el modulo de clientes (Fase 3 del plan de features), que no
-- estaba resuelta en el diseño original (arquitectura-y-estandares.md §8
-- solo pedia "datos de contacto"). No se toca la migracion ya mergeada
-- 20260918210700_dominio_catalogos.sql: esto es un ALTER TABLE aditivo.
-- `correo` se conserva (ya en uso, sin razon documentada para eliminarla).

alter table public.cliente
  add column documento text,
  add column direccion text;

comment on column public.cliente.documento is
  'NIT o cedula del cliente. Opcional: la bitacora historica no lo registra.';

-- El INSERT ya es de tabla completa (sin lista de columnas en el grant
-- original); solo el UPDATE estaba acotado a columnas explicitas y hay que
-- ampliarlo para que admin pueda editar los campos nuevos.
grant update (documento, direccion) on public.cliente to authenticated;
