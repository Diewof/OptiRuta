# Wrapper para no tener que escribir --dart-define-from-file=.env cada vez.
# Uso: .\run.ps1  (acepta los mismos argumentos que "flutter run", ej. .\run.ps1 -d chrome)

$envFile = Join-Path $PSScriptRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Error "No existe mobile/.env. Copia .env.example a .env y completa los valores."
    exit 1
}

flutter run "--dart-define-from-file=$envFile" @args
