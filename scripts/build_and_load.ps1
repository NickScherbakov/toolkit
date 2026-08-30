# build_and_load.ps1 - Build 1C Extension from EDT sources and load into base
# Usage: .\build_and_load.ps1 -InfoBasePath "C:\bases\nopik" -UserName "Администратор (ОрловАВ)"
param(
    [string]$InfoBasePath  = "C:\bases\nopik",
    [string]$UserName      = "Администратор (ОрловАВ)",
    [string]$Password      = "",
    [string]$ExtensionName = "1CDeveloperToolkit",
    [string]$V8Path        = "",
    [switch]$UpdateDB
)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path $MyInvocation.MyCommand.Path

$srcExt   = Join-Path $scriptDir "..\src\Extension"
$tmpConv  = Join-Path $env:TEMP "toolkit_build_$([guid]::NewGuid().ToString('N').Substring(0,8))"
$tmpDump  = Join-Path $env:TEMP "toolkit_extdump_$([guid]::NewGuid().ToString('N').Substring(0,8))"
$tmpMerge = Join-Path $env:TEMP "toolkit_merge_$([guid]::NewGuid().ToString('N').Substring(0,8))"
$logFile  = Join-Path $env:TEMP "toolkit_build_log.txt"

try {
    Write-Host "=== Toolkit 1C Extension Builder ===" -ForegroundColor Cyan
    Write-Host "Source: $srcExt"
    Write-Host "Target: $InfoBasePath / extension: $ExtensionName"

    # 1. Find 1C platform
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

    # 2. Convert EDT to platform XML
    Write-Host "`n[1/3] Converting EDT sources to platform XML..." -ForegroundColor Yellow
    $converter = Join-Path $scriptDir "edt_to_1c_platform.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Src $srcExt -Dst $tmpConv
    if ($LASTEXITCODE -ne 0) { throw "Conversion failed" }

    # 3. Dump current extension state from base (to preserve ObjectBelonging, InternalInfo, Language etc.)
    Write-Host "`n[2/3] Merging with existing extension in base..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $tmpDump | Out-Null
    $dumpLog = Join-Path $env:TEMP "toolkit_dump_log.txt"
    $dumpArgs = "DESIGNER /F`"$InfoBasePath`" /N`"$UserName`""
    if ($Password) { $dumpArgs += " /P`"$Password`"" }
    $dumpArgs += " /DumpConfigToFiles`"$tmpDump`" -Format Hierarchical -Extension `"$ExtensionName`" /Out`"$dumpLog`" /DisableStartupDialogs"
    $proc = Start-Process -FilePath $V8Path -ArgumentList $dumpArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw "Extension dump failed (code $($proc.ExitCode))" }

    # Мержим: берём базовый дамп, заменяем секции объектами из EDT-конвертации
    Copy-Item $tmpDump $tmpMerge -Recurse
    foreach ($section in @("CommonModules","DataProcessors","Roles")) {
        $srcSec = Join-Path $tmpConv  $section
        $dstSec = Join-Path $tmpMerge $section
        if (Test-Path $srcSec) {
            if (Test-Path $dstSec) { Remove-Item $dstSec -Recurse -Force }
            Copy-Item $srcSec $dstSec -Recurse
        }
    }

    # Обновляем ChildObjects в Configuration.xml
    $cfgPath = Join-Path $tmpMerge "Configuration.xml"
    $cfgXml  = [xml](Get-Content $cfgPath -Encoding UTF8 -Raw)
    $MDC_NS  = "http://v8.1c.ru/8.3/MDClasses"
    $nsm     = New-Object System.Xml.XmlNamespaceManager($cfgXml.NameTable)
    $nsm.AddNamespace("m", $MDC_NS)
    $childObjs = $cfgXml.SelectSingleNode("//m:ChildObjects", $nsm)
    $sectionMap = @{ "CommonModules"="CommonModule"; "DataProcessors"="DataProcessor"; "Roles"="Role" }
    foreach ($tag in @("DataProcessor","CommonModule","Role")) {
        $cfgXml.SelectNodes("//m:ChildObjects/m:$tag", $nsm) | ForEach-Object { $childObjs.RemoveChild($_) | Out-Null }
    }
    foreach ($sec in @("CommonModules","DataProcessors","Roles")) {
        $elem = $sectionMap[$sec]
        Get-ChildItem (Join-Path $tmpMerge $sec) -Filter "*.xml" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
            $n = $cfgXml.CreateElement($elem, $MDC_NS)
            $n.InnerText = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $childObjs.AppendChild($n) | Out-Null
        }
    }
    $sw = New-Object System.Xml.XmlWriterSettings
    $sw.Encoding = [System.Text.Encoding]::UTF8; $sw.Indent = $true; $sw.IndentChars = "`t"
    $wr = [System.Xml.XmlWriter]::Create($cfgPath, $sw); $cfgXml.Save($wr); $wr.Close()

    # 4. Load merged XML into base
    Write-Host "`n[3/3] Loading into base..." -ForegroundColor Yellow
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    $loadArgs = "DESIGNER /F`"$InfoBasePath`" /N`"$UserName`""
    if ($Password) { $loadArgs += " /P`"$Password`"" }
    $loadArgs += " /LoadConfigFromFiles`"$tmpMerge`" -Format Hierarchical -Extension `"$ExtensionName`""
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
    foreach ($d in @($tmpConv, $tmpDump, $tmpMerge)) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
