param(
    [switch]$BackendOnly,
    [switch]$FlutterOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $FlutterOnly) {
    Write-Host 'Running Member D backend booking/payment tests...' -ForegroundColor Cyan
    dotnet test "$projectRoot\backend.Tests\backend.Tests.csproj" `
        --filter 'FullyQualifiedName~BookingServiceTests|FullyQualifiedName~PaymentServiceTests'
}

if (-not $BackendOnly) {
    Write-Host 'Running Member D Flutter booked-inventory tests...' -ForegroundColor Cyan
    Push-Location "$projectRoot\mobile_flutter"
    try {
        flutter pub get
        flutter test test/booked_inventory_pages_test.dart test/trip_history_screen_test.dart
    }
    finally {
        Pop-Location
    }
}

Write-Host 'Member D booking/payment checks passed.' -ForegroundColor Green
