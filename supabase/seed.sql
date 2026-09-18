-- Datos base para desarrollo local. NO se aplica en produccion (solo lo corre
-- `supabase db reset` / `supabase start` segun config.toml -> [db.seed]).
--
-- Crea dos usuarios de Auth. El trigger on_auth_user_created (ver la migracion
-- 20260902195223_auth_perfil.sql) puebla public.usuario y app_metadata.rol.
--
-- Credenciales:
--   admin@optiruta.test      / Admin123!       -> ADMINISTRADOR
--   conductor@optiruta.test  / Conductor123!   -> CONDUCTOR

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated',
    'authenticated',
    'admin@optiruta.test',
    extensions.crypt('Admin123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Admin Prueba","documento":"CC-1000","rol":"ADMINISTRADOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'conductor@optiruta.test',
    extensions.crypt('Conductor123!', extensions.gen_salt('bf')),
    now(),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Conductor Prueba","documento":"CC-2000","rol":"CONDUCTOR"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

-- Identidad de proveedor "email" requerida por GoTrue para signInWithPassword.
insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    '{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    '{"sub":"22222222-2222-2222-2222-222222222222","email":"conductor@optiruta.test","email_verified":true,"phone_verified":false}',
    'email',
    now(),
    now(),
    now()
  );
