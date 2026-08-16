$ErrorActionPreference = 'Stop'
$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([bool] $Condition, [string] $Name)
    if ($Condition) {
        $script:Passed++
        Write-Host "PASS: $Name"
    }
    else {
        $script:Failed++
        Write-Host "FAIL: $Name" -ForegroundColor Red
    }
}

$root = Split-Path -Parent $PSScriptRoot
$corePath = Join-Path $root 'src\Launcher.Core.ps1'
if (-not (Test-Path -LiteralPath $corePath)) {
    throw "Core implementation missing: $corePath"
}
. $corePath

$nodePath = Resolve-CommandPath -Name 'node.exe'
Assert-True -Condition ([bool]$nodePath -and (Test-Path -LiteralPath $nodePath)) -Name 'Resolve-CommandPath finds node.exe'

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$unusedPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()
Assert-True -Condition (-not (Test-LocalPort -Port $unusedPort -TimeoutMilliseconds 100)) -Name 'Test-LocalPort returns false for an unused port'

Assert-True -Condition (-not (Stop-OwnedProcessTree -ProcessId 0)) -Name 'Stop-OwnedProcessTree ignores PID zero'
Assert-True -Condition (-not (Stop-OwnedProcessTree -ProcessId $PID)) -Name 'Stop-OwnedProcessTree ignores the current process'

if ($script:Failed -gt 0) {
    Write-Host "$script:Failed test(s) failed; $script:Passed passed." -ForegroundColor Red
    exit 1
}
Write-Host "All $script:Passed tests passed." -ForegroundColor Green
