# Wrapper para no tener que escribir --dart-define-from-file=.env cada vez.
# Uso: .\build.ps1          -> flutter build apk --release
#      .\build.ps1 appbundle -> flutter build appbundle --release
#      .\build.ps1 apk --debug -> cualquier argumento extra se reenvia tal cual

$envFile = Join-Path $PSScriptRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Error "No existe mobile/.env. Copia .env.example a .env y completa los valores."
    exit 1
}

$target = if ($args.Count -gt 0) { $args[0] } else { "apk" }
$rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

flutter build $target "--dart-define-from-file=$envFile" --release @rest
