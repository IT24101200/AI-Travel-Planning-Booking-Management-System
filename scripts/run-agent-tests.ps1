param(
    [ValidateSet('All', 'A', 'B', 'C', 'D')]
    [string]$Member = 'All'
)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskAgentRoot = Join-Path $taskRoot 'agentic-ai'
$taskPython = Join-Path $taskAgentRoot 'venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $taskPython)) { $taskPython = 'python' }
$taskSuites = @{
    A = @('test_member_a_coordinator.py', 'test_feasibility_preflight.py', 'test_agent_performance.py', 'test_agent_logging.py')
    B = @('test_member_b_itinerary.py', 'test_itinerary_agent_golden.py', 'test_prompt_injection.py', 'test_multi_destination.py', 'test_route_planning.py')
    C = @('test_member_c_booking.py', 'test_booking_totals.py', 'test_hotel_pagination.py', 'test_transport_pagination.py', 'test_transport_multi_leg.py', 'test_transport_timetables.py', 'test_transport_failure_classification.py')
    D = @('test_member_d_validation.py', 'test_validation_agent.py', 'test_pipeline_integration_contracts.py', 'test_customer_revision.py')
}

Push-Location $taskAgentRoot
try {
    New-Item -ItemType Directory -Path 'test-results' -Force | Out-Null
    $taskFiles = if ($Member -eq 'All') { @() } else { $taskSuites[$Member] }
    $taskRun = [Guid]::NewGuid().ToString('N')
    & $taskPython -m pytest -q @taskFiles "--basetemp=test-results/tmp-$taskRun" "--junitxml=test-results/member-$Member.xml"
    $taskExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $taskExit
