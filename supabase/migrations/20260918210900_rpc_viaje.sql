-- RPC de dominio para viaje: cambiar_estado, cerrar, registrar_ajuste.
--
-- SECURITY DEFINER + search_path vacio (mismo patron que handle_new_user en
-- 20260902195223_auth_perfil.sql): corren con permisos del dueno para poder
-- hacer el UPDATE que la tabla `viaje` ya no permite via grant directo, y
-- todo objeto va calificado por esquema.

-- ---------------------------------------------------------------------------
-- viaje_cambiar_estado
--
-- Administrador: puede mover el viaje a cualquier siguiente estado valido
-- (la validacion fina de la secuencia la hace el trigger viaje_validar_transicion).
-- Conductor: solo puede avanzar su propio viaje ASIGNADO->EN_CURSO y
-- EN_CURSO->FINALIZADO (lo que corresponde a que el mismo esta en ruta);
-- asignar y cerrar son decisiones administrativas.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_cambiar_estado(p_viaje_id uuid, p_nuevo_estado text)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rol         text := (auth.jwt() -> 'app_metadata' ->> 'rol');
  v_es_propio   boolean;
  v_estado_actual text;
  v_viaje       public.viaje;
begin
  select v.estado, exists (
           select 1 from public.conductor c
           where c.id = v.conductor_id and c.usuario_id = (select auth.uid())
         )
    into v_estado_actual, v_es_propio
    from public.viaje v
   where v.id = p_viaje_id
   for update;

  if not found then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  if v_rol = 'ADMINISTRADOR' then
    null; -- autorizado para cualquier transicion valida
  elsif v_rol = 'CONDUCTOR' and v_es_propio then
    if not (
      (v_estado_actual = 'ASIGNADO' and p_nuevo_estado = 'EN_CURSO') or
      (v_estado_actual = 'EN_CURSO' and p_nuevo_estado = 'FINALIZADO')
    ) then
      raise exception 'El conductor no puede realizar esta transicion de estado.'
        using errcode = 'OR104';
    end if;
  else
    raise exception 'No autorizado para cambiar el estado de este viaje.'
      using errcode = 'OR105';
  end if;

  update public.viaje
     set estado = p_nuevo_estado
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cambiar_estado(uuid, text) from public;
grant execute on function public.viaje_cambiar_estado(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- viaje_cerrar
--
-- Solo administrador. Exige estado FINALIZADO y valor_flete > 0 (regla
-- diseno-base-de-datos-optiruta.md seccion 2.4); delega la transicion en
-- viaje_cambiar_estado y ademas sella fecha_cierre.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_cerrar(p_viaje_id uuid)
returns public.viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_viaje public.viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede cerrar un viaje.'
      using errcode = 'OR105';
  end if;

  if not exists (select 1 from public.viaje where id = p_viaje_id) then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  -- estado y fecha_cierre se fijan en el mismo UPDATE: una vez que
  -- viaje_validar_transicion ve estado = CERRADO ya no permite ningun otro
  -- UPDATE sobre la fila (por eso viaje_cerrar no delega en un segundo paso
  -- a viaje_cambiar_estado).
  update public.viaje
     set estado = 'CERRADO',
         fecha_cierre = now()
   where id = p_viaje_id
   returning * into v_viaje;

  return v_viaje;
end;
$$;

revoke all on function public.viaje_cerrar(uuid) from public;
grant execute on function public.viaje_cerrar(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- viaje_registrar_ajuste
--
-- Unico camino para tocar un viaje CERRADO: inserta en ajuste_viaje
-- (append-only) con motivo obligatorio. Solo administrador.
-- ---------------------------------------------------------------------------
create or replace function public.viaje_registrar_ajuste(
  p_viaje_id uuid,
  p_motivo text,
  p_campo_modificado text default null,
  p_valor_anterior text default null,
  p_valor_nuevo text default null
)
returns public.ajuste_viaje
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ajuste public.ajuste_viaje;
begin
  if (auth.jwt() -> 'app_metadata' ->> 'rol') <> 'ADMINISTRADOR' then
    raise exception 'Solo un administrador puede registrar ajustes de viaje.'
      using errcode = 'OR105';
  end if;

  if btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'El motivo del ajuste es obligatorio.' using errcode = 'OR106';
  end if;

  if not exists (select 1 from public.viaje where id = p_viaje_id) then
    raise exception 'El viaje no existe.' using errcode = 'OR103';
  end if;

  insert into public.ajuste_viaje (viaje_id, usuario_id, motivo, campo_modificado, valor_anterior, valor_nuevo)
  values (p_viaje_id, (select auth.uid()), p_motivo, p_campo_modificado, p_valor_anterior, p_valor_nuevo)
  returning * into v_ajuste;

  return v_ajuste;
end;
$$;

revoke all on function public.viaje_registrar_ajuste(uuid, text, text, text, text) from public;
grant execute on function public.viaje_registrar_ajuste(uuid, text, text, text, text) to authenticated;
