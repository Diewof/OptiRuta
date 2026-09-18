-- pg_cron mensual que dispara la Edge Function precio-acpm-scraper via
-- pg_net (diseno-base-de-datos-optiruta.md seccion 6: "el ACPM en Colombia
-- se fija por resolucion del gobierno... no hace falta mas frecuencia que
-- mensual").
--
-- Los secretos (URL del proyecto y la clave de servicio que valida la
-- cabecera x-service-secret en la Edge Function) NO se commitean: se
-- guardan una sola vez en Supabase Vault, fuera de esta migracion, con:
--
--   select vault.create_secret('https://<proyecto>.supabase.co', 'project_url');
--   select vault.create_secret('<mismo valor que el secreto de la funcion PRECIO_ACPM_SCRAPER_SECRET>', 'precio_acpm_scraper_secret');
--
-- Si esos secretos no existen todavia (p. ej. en un stack local recien
-- creado), el job simplemente no encuentra la fila y no dispara nada; no
-- rompe `supabase db reset`.
-- pg_cron y pg_net no son reubicables: cada uno fija su propio esquema
-- (cron / net) sin importar el "with schema" que se pida.
create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function public.disparar_precio_acpm_scraper()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text;
  v_secreto text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'project_url';
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'precio_acpm_scraper_secret';

  if v_url is null or v_secreto is null then
    raise warning 'Faltan los secretos project_url / precio_acpm_scraper_secret en Vault; no se dispara el scraper de ACPM.';
    return;
  end if;

  perform net.http_post(
    url := v_url || '/functions/v1/precio-acpm-scraper',
    headers := jsonb_build_object('x-service-secret', v_secreto, 'content-type', 'application/json'),
    body := '{}'::jsonb
  );
end;
$$;

revoke all on function public.disparar_precio_acpm_scraper() from public, anon, authenticated;

select cron.schedule(
  'precio-acpm-scraper-mensual',
  '0 6 1 * *',
  $$select public.disparar_precio_acpm_scraper();$$
);
