$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'Launcher.Core.ps1')
$messagesPath = Join-Path $projectRoot 'resources\messages.zh-CN.json'
$messages = ConvertFrom-Json ([System.IO.File]::ReadAllText($messagesPath, [System.Text.Encoding]::UTF8))

function Show-LauncherError {
    param([string] $Message)
    $shell = New-Object -ComObject WScript.Shell
    [void]$shell.Popup($Message, 0, 'DeepSeek Harness', 16)
}

function Resolve-EdgePath {
    $fromPath = Resolve-CommandPath -Name 'msedge.exe'
    if ($fromPath) { return $fromPath }

    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return $null
}

$dshProcess = $null
$ownsEdgeProfile = $false
$port = 3080
$profilePath = Join-Path $projectRoot 'work\edge-profile'
$readySignalPath = Join-Path $projectRoot 'work\launcher-ready.signal'

try {
    if ([System.IO.File]::Exists($readySignalPath)) { [System.IO.File]::Delete($readySignalPath) }
    $nodePath = Resolve-NodeToolPath -Name 'node.exe'
    if (-not $nodePath) { throw $messages.NodeMissing }
    Set-NodeToolPath -ToolPath $nodePath
    $dshEntryPath = Join-Path $projectRoot 'runtime\dsh\node_modules\@deepseek-ai\dsh\lib\bin.js'
    if (-not (Test-Path -LiteralPath $dshEntryPath)) { throw $messages.DshNotInstalled }

    $edgePath = Resolve-EdgePath
    if (-not $edgePath) { throw $messages.EdgeMissing }

    if (Test-LocalPort -Port $port) {
        throw ($messages.PortBusy -f $port)
    }

    $ownsEdgeProfile = $true
    [void](Stop-EdgeProfileProcesses -ProfilePath $profilePath)
    New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
    $dshProcess = Start-Process -FilePath $nodePath `
        -ArgumentList @("`"$dshEntryPath`"", 'web') `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -PassThru

    $ready = $false
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($dshProcess.HasExited) { throw $messages.DshExited }
        if (Test-LocalPort -Port $port -TimeoutMilliseconds 300) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw $messages.DshTimeout }

    $edgeArguments = @(
        '--app=http://127.0.0.1:3080',
        "--user-data-dir=$profilePath",
        '--no-first-run',
        '--disable-background-mode',
        '--disable-features=msEdgeStartupBoost'
    )
    $edgeStart = Start-Process -FilePath $edgePath -ArgumentList $edgeArguments -PassThru
    if (-not $edgeStart) { throw $messages.EdgeStartFailed }

    $windowSeen = $false
    $windowDeadline = [DateTime]::UtcNow.AddSeconds(60)
    while ([DateTime]::UtcNow -lt $windowDeadline) {
        if (@(Get-EdgeWindowProcesses -ProfilePath $profilePath).Count -gt 0) {
            $windowSeen = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $windowSeen) { throw $messages.EdgeWindowMissing }
    [System.IO.File]::WriteAllText($readySignalPath, 'ready', [System.Text.Encoding]::ASCII)

    while (@(Get-EdgeWindowProcesses -ProfilePath $profilePath).Count -gt 0) {
        Start-Sleep -Milliseconds 750
    }
}
catch {
    Show-LauncherError -Message $_.Exception.Message
}
finally {
    if ([System.IO.File]::Exists($readySignalPath)) { [System.IO.File]::Delete($readySignalPath) }
    if ($dshProcess) { [void](Stop-OwnedProcessTree -ProcessId $dshProcess.Id) }
    if ($ownsEdgeProfile) { [void](Stop-EdgeProfileProcesses -ProfilePath $profilePath) }
}
