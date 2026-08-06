# Builds the Flutter web app and serves it locally, for checking a change
# before pushing.
#
# Deployment is handled by .github/workflows/deploy-web.yml, which builds with
# `--base-href /Whats-Due-/flutter-web/` so it can sit alongside index.html on
# Pages. That base href would break a plain localhost server, so this builds at
# the root instead. The two differ only in that one flag.

param(
    [int]$Port = 8765
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$app = Join-Path $repo 'app'

Write-Host 'Building Flutter web...' -ForegroundColor Cyan
Push-Location $app
try {
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)" }
}
finally {
    Pop-Location
}

$built = Join-Path $app 'build\web'
if (-not (Test-Path $built)) { throw "Expected build output at $built" }

Write-Host ''
Write-Host "Serving on http://localhost:$Port  (Ctrl+C to stop)" -ForegroundColor Green
Push-Location $built
try {
    python -m http.server $Port
}
finally {
    Pop-Location
}
