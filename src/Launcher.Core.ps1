function Resolve-CommandPath {
    param([Parameter(Mandatory = $true)][string] $Name)

    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return $null }
    if ($command.Path) { return $command.Path }
    return $command.Source
}

function Test-LocalPort {
    param(
        [Parameter(Mandatory = $true)][int] $Port,
        [int] $TimeoutMilliseconds = 250
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) { return $false }
        $client.EndConnect($async)
        return $true
    }
    catch { return $false }
    finally { $client.Dispose() }
}

function Get-EdgeWindowProcesses {
    param([Parameter(Mandatory = $true)][string] $ProfilePath)

    $escapedProfile = [WildcardPattern]::Escape($ProfilePath)
    $matches = Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$escapedProfile*" }

    foreach ($match in $matches) {
        $process = Get-Process -Id $match.ProcessId -ErrorAction SilentlyContinue
        if ($process -and $process.MainWindowHandle -ne 0) { $process }
    }
}

function Stop-OwnedProcessTree {
    param([Parameter(Mandatory = $true)][int] $ProcessId)

    if ($ProcessId -le 0 -or $ProcessId -eq $PID) { return $false }
    $taskkill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
    if (-not (Test-Path -LiteralPath $taskkill)) { return $false }
    & $taskkill /PID $ProcessId /T /F 2>$null | Out-Null
    return $true
}
