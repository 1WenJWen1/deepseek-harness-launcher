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

$launcherPath = Join-Path $root 'src\Start-DeepSeekHarness.ps1'
$launcherExists = Test-Path -LiteralPath $launcherPath
Assert-True -Condition $launcherExists -Name 'Launcher script exists'
if ($launcherExists) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($launcherPath, [ref]$tokens, [ref]$parseErrors)
    Assert-True -Condition ($parseErrors.Count -eq 0) -Name 'Launcher has valid PowerShell syntax'
    $launcherText = Get-Content -Raw -LiteralPath $launcherPath
    Assert-True -Condition ($launcherText -match '\btry\b' -and $launcherText -match '\bfinally\b') -Name 'Launcher guarantees cleanup with try/finally'
    Assert-True -Condition ($launcherText -match 'Start-Process') -Name 'Launcher starts child processes'
    Assert-True -Condition ($launcherText -match '--app=http://127\.0\.0\.1:3080') -Name 'Launcher opens the DSH local URL in app mode'
    Assert-True -Condition ($launcherText -match 'Stop-OwnedProcessTree') -Name 'Launcher cleans up its owned DSH process tree'
}

if ($script:Failed -gt 0) {
    Write-Host "$script:Failed test(s) failed; $script:Passed passed." -ForegroundColor Red
    exit 1
}
Write-Host "All $script:Passed tests passed." -ForegroundColor Green
