param(
    [switch]$SkipReact
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-Configured([string]$Name) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name))) {
        throw "Required environment variable '$Name' is not configured. Load a local .env/user-secret first."
    }
}

Assert-Configured 'DATABASE_URL'
Assert-Configured 'JWT__KEY'
Assert-Configured 'AGENT_SERVICE_API_KEY'
Assert-Configured 'ALLOWED_ORIGINS'

Write-Host 'Starting ASP.NET on http://localhost:5138 and FastAPI on http://localhost:8005.'
Write-Host 'Flutter should be launched separately with the appropriate --dart-define=API_BASE_URL value.'

Start-Process powershell -WorkingDirectory (Join-Path $repoRoot 'backend') -ArgumentList '-NoExit', '-Command', 'dotnet run --launch-profile http'
Start-Process powershell -WorkingDirectory (Join-Path $repoRoot 'agentic-ai') -ArgumentList '-NoExit', '-Command', '.\venv\Scripts\Activate.ps1; uvicorn main:app --reload --port 8005'

if (-not $SkipReact) {
    Start-Process powershell -WorkingDirectory (Join-Path $repoRoot 'frontend-react') -ArgumentList '-NoExit', '-Command', 'npm run dev'
}
