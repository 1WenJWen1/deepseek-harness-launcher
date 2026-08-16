$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\Launcher.Core.ps1')

$failures = 0
function Check {
    param([bool] $Condition, [string] $Name)
    if ($Condition) { Write-Host "PASS: $Name" -ForegroundColor Green }
    else { Write-Host "FAIL: $Name" -ForegroundColor Red; $script:failures++ }
}

function Get-ProfileEdgeProcesses {
    param([string] $ProfilePath)
    $escapedProfile = [WildcardPattern]::Escape($ProfilePath)
    Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$escapedProfile*" }
}

$launcherPath = Join-Path $root 'src\Start-DeepSeekHarness.ps1'
$iconPath = Join-Path $root 'assets\deepseek-harness.ico'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DeepSeek Harness.lnk'
$profilePath = Join-Path $root 'work\edge-profile'
$readySignalPath = Join-Path $root 'work\launcher-ready.signal'
$port = 3080

Check (Test-Path -LiteralPath $shortcutPath) 'Desktop shortcut exists'
Check (Test-Path -LiteralPath $launcherPath) 'Launcher exists'
Check (Test-Path -LiteralPath $iconPath) 'Icon exists'
Check ([bool](Resolve-NodeToolPath -Name 'node.exe')) 'Node.js resolves'
$dshEntryPath = Join-Path $root 'runtime\dsh\node_modules\@deepseek-ai\dsh\lib\bin.js'
Check (Test-Path -LiteralPath $dshEntryPath) 'Pinned local DSH entry exists'

$edgeCandidates = @(
    (Resolve-CommandPath -Name 'msedge.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
)
$edgePath = $edgeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
Check ([bool]$edgePath) 'Microsoft Edge exists'

if (Test-Path -LiteralPath $shortcutPath) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    Check ($shortcut.Arguments -like "*$launcherPath*") 'Shortcut points to this launcher'
    Check ($shortcut.Arguments -like '*-WindowStyle Hidden*') 'Shortcut requests a hidden host'
    Check ($shortcut.IconLocation -like "$iconPath*") 'Shortcut uses the generated icon'
}

Check (-not (Test-LocalPort -Port $port)) 'Port 3080 is initially free'
if ($failures -gt 0) { exit 1 }

$sentinelNode = $null
$sentinelEdge = $null
$launcherHost = $null
$sentinelProfile = Join-Path $root 'work\sentinel-edge-profile'
try {
    if ([System.IO.File]::Exists($readySignalPath)) { [System.IO.File]::Delete($readySignalPath) }
    $nodePath = Resolve-NodeToolPath -Name 'node.exe'
    $sentinelNode = Start-Process -FilePath $nodePath -ArgumentList @('-e', 'setInterval(()=>{},1000)') -WindowStyle Hidden -PassThru
    New-Item -ItemType Directory -Force -Path $sentinelProfile | Out-Null
    $sentinelEdge = Start-Process -FilePath $edgePath -ArgumentList @('--headless=new', '--disable-gpu', "--user-data-dir=$sentinelProfile", 'about:blank') -WindowStyle Hidden -PassThru
    $sentinelDeadline = [DateTime]::UtcNow.AddSeconds(10)
    while (@(Get-ProfileEdgeProcesses -ProfilePath $sentinelProfile).Count -eq 0 -and [DateTime]::UtcNow -lt $sentinelDeadline) {
        Start-Sleep -Milliseconds 250
    }

    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $launcherHost = Start-Process -FilePath $powerShellPath -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $launcherPath) -WindowStyle Hidden -PassThru

    $startupDeadline = [DateTime]::UtcNow.AddSeconds(120)
    while ([DateTime]::UtcNow -lt $startupDeadline -and -not (Test-LocalPort -Port $port -TimeoutMilliseconds 300)) {
        Start-Sleep -Milliseconds 500
    }
    Check (Test-LocalPort -Port $port) 'DSH listens on port 3080'
    Check ((Get-Process -Id $launcherHost.Id -ErrorAction SilentlyContinue).MainWindowHandle -eq 0) 'Launcher host has no console window'

    $windowDeadline = [DateTime]::UtcNow.AddSeconds(60)
    $appWindows = @()
    while ([DateTime]::UtcNow -lt $windowDeadline) {
        $appWindows = @(Get-EdgeWindowProcesses -ProfilePath $profilePath)
        if ($appWindows.Count -gt 0 -and [System.IO.File]::Exists($readySignalPath)) { break }
        Start-Sleep -Milliseconds 500
    }
    Check ($appWindows.Count -gt 0) 'Isolated Edge app window is visible'
    Check ([System.IO.File]::Exists($readySignalPath)) 'Launcher acknowledges ownership of the app window'

    foreach ($window in $appWindows) { [void]$window.CloseMainWindow() }
    $shutdownDeadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $shutdownDeadline -and (Test-LocalPort -Port $port -TimeoutMilliseconds 200)) {
        Start-Sleep -Milliseconds 500
    }
    Check (-not (Test-LocalPort -Port $port)) 'Closing the app window releases port 3080'
    Check ([bool](Get-Process -Id $sentinelNode.Id -ErrorAction SilentlyContinue)) 'Unrelated Node process remains running'
    Check (@(Get-ProfileEdgeProcesses -ProfilePath $sentinelProfile).Count -gt 0) 'Unrelated Edge process remains running'
}
finally {
    if ($launcherHost -and (Get-Process -Id $launcherHost.Id -ErrorAction SilentlyContinue)) { [void](Stop-OwnedProcessTree -ProcessId $launcherHost.Id) }
    if ($sentinelNode) { [void](Stop-OwnedProcessTree -ProcessId $sentinelNode.Id) }
    foreach ($edgeProcess in @(Get-ProfileEdgeProcesses -ProfilePath $sentinelProfile)) {
        Stop-Process -Id $edgeProcess.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

if ($failures -gt 0) { exit 1 }
Write-Host 'Installation lifecycle verified.' -ForegroundColor Green
