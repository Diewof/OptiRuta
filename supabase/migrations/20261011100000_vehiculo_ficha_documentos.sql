-- Fase 1: ficha tecnica del vehiculo y documentos (SOAT / tecnomecanica).
--
-- Decisiones (dueño, 2026-10-11): solo SOAT y TECNOMECANICA entran al alcance;
-- tarjeta de operacion y polizas quedan fuera. Renovar un documento = insertar
-- una fila nueva: el historial es parte de la hoja de vida y el documento
-- vigente es el de mayor vencimiento por vehiculo y tipo.

-- ---------------------------------------------------------------------------
-- Fecha de hoy en Colombia (los vencimientos son fechas civiles, no instantes)
-- ---------------------------------------------------------------------------
create or replace function public.hoy_bogota()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'America/Bogota')::date;
$$;

-- ---------------------------------------------------------------------------
-- vehiculo: datos tecnicos que sirven al mantenimiento y a la trazabilidad
-- ---------------------------------------------------------------------------
alter table public.vehiculo
  add column marca text
    check (marca is null or char_length(btrim(marca)) between 1 and 40),
  add column linea text
    check (linea is null or char_length(btrim(linea)) between 1 and 40),
  add column modelo_anio integer
    check (modelo_anio is null or modelo_anio between 1980 and 2100),
  add column vin text
    check (vin is null or char_length(btrim(vin)) between 5 and 30),
  add column numero_motor text
    check (numero_motor is null or char_length(btrim(numero_motor)) between 1 and 30),
  add column numero_ejes smallint
    check (numero_ejes is null or numero_ejes between 2 and 9),
  add column cantidad_llantas smallint
    check (cantidad_llantas is null or cantidad_llantas between 4 and 40),
  add column pbv_kg numeric
    check (pbv_kg is null or pbv_kg > 0),
  add column odometro_inicial_km numeric not null default 0
    check (odometro_inicial_km >= 0);

create unique index vehiculo_vin_key on public.vehiculo (upper(vin)) where vin is not null;

comment on column public.vehiculo.pbv_kg is 'Peso bruto vehicular en kg (tarjeta de propiedad).';
comment on column public.vehiculo.odometro_inicial_km is
  'Lectura del tablero al dar de alta el vehiculo en el sistema. El odometro actual es esta lectura mas los km recorridos de los viajes finalizados (GPS).';

-- El INSERT ya esta concedido a nivel de tabla; el UPDATE es por columna.
grant update (marca, linea, modelo_anio, vin, numero_motor, numero_ejes,
              cantidad_llantas, pbv_kg, odometro_inicial_km)
  on public.vehiculo to authenticated;

-- ---------------------------------------------------------------------------
-- documento_vehiculo: datos del documento y sin borrado (historial)
-- ---------------------------------------------------------------------------
alter table public.documento_vehiculo
  add column numero text
    check (numero is null or char_length(btrim(numero)) between 1 and 40),
  add column entidad_emisora text
    check (entidad_emisora is null or char_length(btrim(entidad_emisora)) between 1 and 80),
  add column fecha_expedicion date,
  add constraint documento_vehiculo_fechas_ck
    check (fecha_expedicion is null or fecha_expedicion <= fecha_vencimiento),
  add constraint documento_vehiculo_unico_vencimiento
    unique (vehiculo_id, tipo, fecha_vencimiento);

comment on column public.documento_vehiculo.entidad_emisora is
  'Aseguradora (SOAT) o CDA (tecnomecanica).';

-- Una renovacion es una fila nueva; un error de digitacion se corrige con UPDATE.
revoke delete on public.documento_vehiculo from authenticated;

-- Documento vigente por vehiculo y tipo (el de mayor vencimiento) con su estado.
-- security_invoker: respeta las politicas RLS de documento_vehiculo.
create view public.documento_vehiculo_vigente
with (security_invoker = true) as
select distinct on (d.vehiculo_id, d.tipo)
  d.id,
  d.vehiculo_id,
  d.tipo,
  d.numero,
  d.entidad_emisora,
  d.fecha_expedicion,
  d.fecha_vencimiento,
  d.fecha_vencimiento - public.hoy_bogota() as dias_restantes,
  case
    when d.fecha_vencimiento < public.hoy_bogota() then 'VENCIDO'
    when d.fecha_vencimiento <= public.hoy_bogota() + 30 then 'POR_VENCER'
    else 'VIGENTE'
  end as estado
from public.documento_vehiculo d
order by d.vehiculo_id, d.tipo, d.fecha_vencimiento desc;

revoke all on public.documento_vehiculo_vigente from anon, authenticated;
grant select on public.documento_vehiculo_vigente to authenticated;

-- ---------------------------------------------------------------------------
-- vehiculo_validar_documentos: lanza OR132 si falta o esta vencido el SOAT o
-- la tecnomecanica. Un documento que vence hoy sigue vigente hoy. Uso interno
-- (viaje_iniciar); no se expone al cliente.
-- ---------------------------------------------------------------------------
create or replace function public.vehiculo_validar_documentos(p_vehiculo_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tipo      text;
  v_nombre    text;
  v_vence     date;
  v_problemas text[] := '{}';
begin
  foreach v_tipo in array array['SOAT', 'TECNOMECANICA'] loop
    v_nombre := case v_tipo when 'SOAT' then 'SOAT' else 'la revisión técnico-mecánica' end;

    select max(d.fecha_vencimiento) into v_vence
      from public.documento_vehiculo d
     where d.vehiculo_id = p_vehiculo_id and d.tipo = v_tipo;

    if v_vence is null then
      v_problemas := v_problemas || format('no hay %s registrado', v_nombre);
    elsif v_vence < public.hoy_bogota() then
      v_problemas := v_problemas || format('%s venció el %s', v_nombre, to_char(v_vence, 'DD/MM/YYYY'));
    end if;
  end loop;

  if array_length(v_problemas, 1) > 0 then
    raise exception 'No se puede comenzar el viaje: %.', array_to_string(v_problemas, ' y ')
      using errcode = 'OR132';
  end if;
end;
$$;

revoke all on function public.vehiculo_validar_documentos(uuid) from public, anon, authenticated;
