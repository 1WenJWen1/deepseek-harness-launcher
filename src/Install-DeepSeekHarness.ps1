$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot 'Launcher.Core.ps1')
$launcherPath = Join-Path $scriptRoot 'Start-DeepSeekHarness.ps1'
$iconPath = Join-Path $projectRoot 'assets\deepseek-harness.ico'
$runtimeRoot = Join-Path $projectRoot 'runtime\dsh'
$dshVersion = '0.1.0-rc.6'
$packageSpec = '@deepseek-ai/dsh@0.1.0-rc.6'
$dshPackagePath = Join-Path $runtimeRoot 'node_modules\@deepseek-ai\dsh\package.json'
$dshEntryPath = Join-Path $runtimeRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'

if (-not (Test-Path -LiteralPath $launcherPath)) { throw "Launcher not found: $launcherPath" }
if (-not (Test-Path -LiteralPath $iconPath)) { throw "Icon not found: $iconPath" }

$installedVersion = $null
if (Test-Path -LiteralPath $dshPackagePath) {
    $installedPackage = ConvertFrom-Json (Get-Content -Raw -LiteralPath $dshPackagePath)
    $installedVersion = $installedPackage.version
}
if ($installedVersion -ne $dshVersion -or -not (Test-Path -LiteralPath $dshEntryPath)) {
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null

    $npxCacheRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
    $cachePattern = Join-Path $npxCacheRoot '*\node_modules\@deepseek-ai\dsh\package.json'
    $cachePackage = Get-ChildItem -Path $cachePattern -File -ErrorAction SilentlyContinue |
        Where-Object { (ConvertFrom-Json (Get-Content -Raw -LiteralPath $_.FullName)).version -eq $dshVersion } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($cachePackage) {
        $cachedDshDirectory = Split-Path -Parent $cachePackage.FullName
        $cachedScopeDirectory = Split-Path -Parent $cachedDshDirectory
        $cachedNodeModules = Split-Path -Parent $cachedScopeDirectory
        $runtimeNodeModules = Join-Path $runtimeRoot 'node_modules'
        New-Item -ItemType Directory -Force -Path $runtimeNodeModules | Out-Null
        $robocopyPath = Join-Path $env:SystemRoot 'System32\robocopy.exe'
        $copyArguments = "`"$cachedNodeModules`" `"$runtimeNodeModules`" /E /NFL /NDL /NJH /NJS /NP"
        $copyProcess = Start-Process -FilePath $robocopyPath -ArgumentList $copyArguments -WindowStyle Hidden -Wait -PassThru
        if ($copyProcess.ExitCode -ge 8) { throw "Failed to copy cached DSH runtime (robocopy exit $($copyProcess.ExitCode))." }
    }

    if (-not (Test-Path -LiteralPath $dshEntryPath)) {
        $npmPath = Resolve-NodeToolPath -Name 'npm.cmd'
        if (-not $npmPath) { throw 'npm.cmd not found. Install Node.js before running this installer.' }
        Set-NodeToolPath -ToolPath $npmPath
        & $npmPath install --prefix $runtimeRoot $packageSpec --omit=dev --no-audit --no-fund
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dshEntryPath)) {
            throw "Failed to install $packageSpec into $runtimeRoot"
        }
    }
}

$desktopPath = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktopPath 'DeepSeek Harness.lnk'
$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $powerShellPath
$shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcherPath`""
$shortcut.WorkingDirectory = $projectRoot
$shortcut.IconLocation = "$iconPath,0"
$shortcut.Description = 'Launch DeepSeek Harness in a local app window'
$shortcut.Save()

Write-Output $shortcutPath
