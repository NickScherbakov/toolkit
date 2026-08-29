# build_and_load.ps1 - Build 1C Extension from EDT sources and load into base
# Usage: .\build_and_load.ps1 -InfoBasePath "C:\bases\nopik" -UserName "Администратор (ОрловАВ)"
param(
    [string]$InfoBasePath = "C:\bases\nopik",
    [string]$UserName     = "Администратор (ОрловАВ)",
    [string]$Password     = "",
    [string]$ExtensionName = "1CDeveloperToolkit",
    [string]$V8Path       = "",
    [switch]$UpdateDB
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path

$srcExt  = Join-Path $scriptDir "..\src\Extension"
$tmpDir  = Join-Path $env:TEMP "toolkit_build_$([guid]::NewGuid().ToString('N').Substring(0,8))"
$logFile = Join-Path $env:TEMP "toolkit_build_log.txt"

try {
    Write-Host "=== Toolkit 1C Extension Builder ===" -ForegroundColor Cyan
    Write-Host "Source: $srcExt"
    Write-Host "Target: $InfoBasePath / extension: $ExtensionName"

    # 1. Convert EDT to platform XML
    Write-Host "`n[1/2] Converting EDT sources to platform XML format..." -ForegroundColor Yellow
    $converter = Join-Path $scriptDir "edt_to_1c_platform.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Src $srcExt -Dst $tmpDir
    if ($LASTEXITCODE -ne 0) { throw "Conversion failed" }

    # 2. Find 1C platform
    if (-not $V8Path) {
        $found = Get-ChildItem @("C:\Program Files\1cv8\*\bin\1cv8.exe",
            "C:\Program Files (x86)\1cv8\*\bin\1cv8.exe") -ErrorAction SilentlyContinue |
            Sort-Object { try { [version]$_.Directory.Parent.Name } catch { [version]"0.0" } } -Descending |
            Select-Object -First 1
        if ($found) {
            $V8Path = $found.FullName
            Write-Host "Auto-detected platform: $V8Path" -ForegroundColor Yellow
        } else {
            throw "1C platform not found. Specify -V8Path"
        }
    }

    # 3. Load into base
    Write-Host "`n[2/2] Loading into base..." -ForegroundColor Yellow
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    $loadArgs = "DESIGNER /F`"$InfoBasePath`" /N`"$UserName`""
    if ($Password) { $loadArgs += " /P`"$Password`"" }
    $loadArgs += " /LoadConfigFromFiles`"$tmpDir`" -Format Hierarchical -Extension `"$ExtensionName`""
    if ($UpdateDB) { $loadArgs += " /UpdateDBCfg" }
    $loadArgs += " /Out`"$logFile`" /DisableStartupDialogs"

    $proc = Start-Process -FilePath $V8Path -ArgumentList $loadArgs -Wait -PassThru -NoNewWindow
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Encoding UTF8
        if ($log) { $log | ForEach-Object { Write-Host "  $_" } }
    }
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 101) {
        Write-Host "`nExtension loaded successfully (code $($proc.ExitCode))" -ForegroundColor Green
    } else {
        throw "Load failed with exit code $($proc.ExitCode)"
    }
} finally {
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
}
