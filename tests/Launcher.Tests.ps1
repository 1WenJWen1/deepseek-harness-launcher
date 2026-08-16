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

$npxPath = Resolve-NodeToolPath -Name 'npx.cmd'
Assert-True -Condition ([bool]$npxPath -and (Test-Path -LiteralPath $npxPath)) -Name 'Resolve-NodeToolPath finds the independently installed npx.cmd'

$managedNodePath = Resolve-NodeToolPath -Name 'node.exe'
$managedNodeVersion = & $managedNodePath --version
$managedNodeMajor = [int](($managedNodeVersion -replace '^v', '') -split '\.')[0]
Assert-True -Condition ($managedNodeMajor -ge 22) -Name 'Resolve-NodeToolPath prefers the managed Node 22 runtime over bundled legacy Node'

$savedPath = $env:Path
try {
    Set-NodeToolPath -ToolPath $npxPath
    $expectedNodeDirectory = Split-Path -Parent $npxPath
    $actualFirstPath = ($env:Path -split ';')[0]
    Assert-True -Condition ($actualFirstPath.TrimEnd('\') -eq $expectedNodeDirectory.TrimEnd('\')) -Name 'Set-NodeToolPath puts the matching Node runtime first'
}
finally {
    $env:Path = $savedPath
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$unusedPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()
Assert-True -Condition (-not (Test-LocalPort -Port $unusedPort -TimeoutMilliseconds 100)) -Name 'Test-LocalPort returns false for an unused port'

Assert-True -Condition (-not (Stop-OwnedProcessTree -ProcessId 0)) -Name 'Stop-OwnedProcessTree ignores PID zero'
Assert-True -Condition (-not (Stop-OwnedProcessTree -ProcessId $PID)) -Name 'Stop-OwnedProcessTree ignores the current process'
Assert-True -Condition (-not (Stop-OwnedProcessTree -ProcessId 2147483000)) -Name 'Stop-OwnedProcessTree ignores an already exited process without error'
$missingEdgeProfile = Join-Path $env:TEMP ([Guid]::NewGuid().ToString('N'))
Assert-True -Condition ((Stop-EdgeProfileProcesses -ProfilePath $missingEdgeProfile) -eq 0) -Name 'Stop-EdgeProfileProcesses safely handles an unused profile'

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
    Assert-True -Condition ($launcherText -match 'launcher-ready\.signal') -Name 'Launcher publishes a window-ready signal'
    Assert-True -Condition ($launcherText -match "Resolve-NodeToolPath -Name 'node\.exe'") -Name 'Launcher resolves the direct Node runtime'
    Assert-True -Condition ($launcherText -match 'node_modules.*@deepseek-ai.*dsh.*lib.*bin\.js') -Name 'Launcher uses the locally installed DSH entry'
    Assert-True -Condition ($launcherText -notmatch "Resolve-NodeToolPath -Name 'npx\.cmd'") -Name 'Launcher does not resolve npx at startup'
    Assert-True -Condition (([regex]::Matches($launcherText, 'Stop-EdgeProfileProcesses')).Count -ge 2) -Name 'Launcher cleans its isolated Edge profile before and after use'
}

$installerPath = Join-Path $root 'src\Install-DeepSeekHarness.ps1'
$installerExists = Test-Path -LiteralPath $installerPath
Assert-True -Condition $installerExists -Name 'Installer script exists'
if ($installerExists) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($installerPath, [ref]$tokens, [ref]$parseErrors)
    Assert-True -Condition ($parseErrors.Count -eq 0) -Name 'Installer has valid PowerShell syntax'
    $installerText = Get-Content -Raw -LiteralPath $installerPath
    Assert-True -Condition ($installerText -match '-WindowStyle Hidden') -Name 'Shortcut hides the PowerShell window'
    Assert-True -Condition ($installerText -match '-ExecutionPolicy Bypass') -Name 'Shortcut permits the signed-local launcher script to run'
    Assert-True -Condition ($installerText -match 'IconLocation') -Name 'Shortcut assigns the generated icon'
    Assert-True -Condition ($installerText -match 'DeepSeek Harness\.lnk') -Name 'Installer creates exactly the named launcher shortcut'
    Assert-True -Condition ($installerText -match "Resolve-NodeToolPath -Name 'npm\.cmd'") -Name 'Installer resolves npm for one-time deployment'
    Assert-True -Condition ($installerText -match '@deepseek-ai/dsh@0\.1\.0-rc\.6') -Name 'Installer pins the tested DSH release candidate'
    Assert-True -Condition ($installerText -match '_npx' -and $installerText -match 'robocopy') -Name 'Installer bootstraps from the verified npx cache before network fallback'
}

$verificationPath = Join-Path $root 'tests\Verify-Installation.ps1'
$verificationExists = Test-Path -LiteralPath $verificationPath
Assert-True -Condition $verificationExists -Name 'Installation lifecycle verification exists'
if ($verificationExists) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($verificationPath, [ref]$tokens, [ref]$parseErrors)
    Assert-True -Condition ($parseErrors.Count -eq 0) -Name 'Installation verification has valid PowerShell syntax'
    $verificationText = Get-Content -Raw -LiteralPath $verificationPath
    Assert-True -Condition ($verificationText -match 'CloseMainWindow') -Name 'Lifecycle test closes the isolated app window'
    Assert-True -Condition ($verificationText -match 'Test-LocalPort') -Name 'Lifecycle test verifies port startup and shutdown'
    Assert-True -Condition ($verificationText -match 'launcher-ready\.signal') -Name 'Lifecycle test waits for launcher window ownership'
}

$readmePath = Join-Path $root 'outputs\README.txt'
Assert-True -Condition (Test-Path -LiteralPath $readmePath) -Name 'Chinese usage README exists'

if ($script:Failed -gt 0) {
    Write-Host "$script:Failed test(s) failed; $script:Passed passed." -ForegroundColor Red
    exit 1
}
Write-Host "All $script:Passed tests passed." -ForegroundColor Green
