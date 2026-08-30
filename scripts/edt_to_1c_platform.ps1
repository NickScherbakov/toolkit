# edt_to_1c.ps1 v3 - Convert 1C EDT extension to platform Hierarchical XML
# PS 5.1 compatible. Correct format verified from 1C platform dump.
param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dst
)
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$EDT_NS_FORM   = "http://g5.1c.ru/v8/dt/form"
$PLAT_NS_FORM  = "http://v8.1c.ru/8.3/xcf/logform"  # platform form NS (verified)
$PLAT_NS_MDC   = "http://v8.1c.ru/8.3/MDClasses"
$PLAT_NS_V8    = "http://v8.1c.ru/8.1/data/core"

# Full namespace declarations matching platform output (verified from dump)
$ROOT_NS_ATTRS = @{
    "xmlns:app"   = "http://v8.1c.ru/8.2/managed-application/core"
    "xmlns:cfg"   = "http://v8.1c.ru/8.1/data/enterprise/current-config"
    "xmlns:cmi"   = "http://v8.1c.ru/8.2/managed-application/cmi"
    "xmlns:ent"   = "http://v8.1c.ru/8.1/data/enterprise"
    "xmlns:lf"    = "http://v8.1c.ru/8.2/managed-application/logform"
    "xmlns:style" = "http://v8.1c.ru/8.1/data/ui/style"
    "xmlns:sys"   = "http://v8.1c.ru/8.1/data/ui/fonts/system"
    "xmlns:v8"    = $PLAT_NS_V8
    "xmlns:v8ui"  = "http://v8.1c.ru/8.1/data/ui"
    "xmlns:web"   = "http://v8.1c.ru/8.1/data/ui/colors/web"
    "xmlns:win"   = "http://v8.1c.ru/8.1/data/ui/colors/windows"
    "xmlns:xen"   = "http://v8.1c.ru/8.3/xcf/enums"
    "xmlns:xpr"   = "http://v8.1c.ru/8.3/xcf/predef"
    "xmlns:xr"    = "http://v8.1c.ru/8.3/xcf/readable"
    "xmlns:xs"    = "http://www.w3.org/2001/XMLSchema"
    "xmlns:xsi"   = "http://www.w3.org/2001/XMLSchema-instance"
}

function New-PlatDoc {
    $d = New-Object System.Xml.XmlDocument
    $d.AppendChild($d.CreateXmlDeclaration("1.0","UTF-8",$null)) | Out-Null
    return $d
}

function Add-RootNs {
    param([System.Xml.XmlDocument]$doc, [System.Xml.XmlElement]$root)
    foreach ($k in $ROOT_NS_ATTRS.Keys) {
        $root.SetAttribute($k, $ROOT_NS_ATTRS[$k])
    }
    $root.SetAttribute("version", "2.20")
}

function Add-El {
    param($doc,$parent,[string]$ns,[string]$name,[string]$text=$null)
    $el = $doc.CreateElement($name, $ns)
    if ($null -ne $text) { $el.InnerText = $text }
    $parent.AppendChild($el) | Out-Null
    return $el
}

function Add-V8Item {
    param($doc,$parent,[string]$lang,[string]$content)
    $item = $doc.CreateElement("v8:item", $PLAT_NS_V8)
    $l = $doc.CreateElement("v8:lang",    $PLAT_NS_V8); $l.InnerText = $lang
    $c = $doc.CreateElement("v8:content", $PLAT_NS_V8); $c.InnerText = $content
    $item.AppendChild($l) | Out-Null
    $item.AppendChild($c) | Out-Null
    $parent.AppendChild($item) | Out-Null
}

function Add-Synonym {
    param($doc,$parent,$synonymNodes)
    $synEl = $doc.CreateElement("Synonym", $PLAT_NS_MDC)
    foreach ($syn in $synonymNodes) {
        $keyEl = $syn.SelectSingleNode("key")
        $valEl = $syn.SelectSingleNode("value")
        $k = if ($keyEl -and $keyEl.InnerText) { $keyEl.InnerText.Trim() } else { "ru" }
        $v = if ($valEl -and $valEl.InnerText) { $valEl.InnerText.Trim() } else { "" }
        Add-V8Item $doc $synEl $k $v
    }
    $parent.AppendChild($synEl) | Out-Null
}

function Write-XmlFile {
    param($doc,[string]$path)
    $dir = Split-Path $path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $s = New-Object System.Xml.XmlWriterSettings
    $s.Encoding    = [System.Text.Encoding]::UTF8
    $s.Indent      = $true
    $s.IndentChars = "`t"
    $w = [System.Xml.XmlWriter]::Create($path, $s)
    $doc.Save($w)
    $w.Close()
}

function Read-XmlFile([string]$path) {
    $d = New-Object System.Xml.XmlDocument
    $d.Load($path)
    return $d
}

function Get-NodeText {
    param($root,[string]$localName,[string]$default="")
    if (-not $root) { return $default }
    $el = $root.SelectSingleNode("*[local-name()='$localName']")
    if (-not $el) { $el = $root.SelectSingleNode($localName) }
    if ($el -and $el.InnerText) { return $el.InnerText.Trim() }
    return $default
}

function Get-Uuid([System.Xml.XmlElement]$root) {
    $v = $root.GetAttribute("uuid")
    if ($v) { return $v }
    return [guid]::NewGuid().ToString()
}

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}

function New-MetaDoc {
    param([string]$objType,[string]$uuid)
    $doc  = New-PlatDoc
    $meta = $doc.CreateElement("MetaDataObject", $PLAT_NS_MDC)
    Add-RootNs $doc $meta
    $doc.AppendChild($meta) | Out-Null
    $obj = $doc.CreateElement($objType, $PLAT_NS_MDC)
    $obj.SetAttribute("uuid", $uuid)
    $meta.AppendChild($obj) | Out-Null
    return @{ doc=$doc; obj=$obj }
}

# ---- CommonModule ----
function Convert-CommonModule([string]$mdoPath,[string]$outDir) {
    $modName = [System.IO.Path]::GetFileNameWithoutExtension($mdoPath)
    $xml  = Read-XmlFile $mdoPath
    $root = $xml.DocumentElement
    $uuid = Get-Uuid $root
    $name    = Get-NodeText $root "name"
    $comment = Get-NodeText $root "comment"
    $syns    = $root.SelectNodes("synonym")

    $boolProps = @("global","clientManagedApplication","server","externalConnection",
                   "clientOrdinaryApplication","serverCall","privileged")
    $platNames = @{
        "global"="Global"; "clientManagedApplication"="ClientManagedApplication";
        "server"="Server"; "externalConnection"="ExternalConnection";
        "clientOrdinaryApplication"="ClientOrdinaryApplication";
        "serverCall"="ServerCall"; "privileged"="Privileged"
    }

    $r   = New-MetaDoc "CommonModule" $uuid
    $doc = $r.doc; $obj = $r.obj

    $props = $doc.CreateElement("Properties", $PLAT_NS_MDC)
    $obj.AppendChild($props) | Out-Null

    Add-El $doc $props $PLAT_NS_MDC "Name"    $name    | Out-Null
    Add-Synonym $doc $props $syns
    Add-El $doc $props $PLAT_NS_MDC "Comment" $comment | Out-Null

    foreach ($eKey in $boolProps) {
        $el  = $root.SelectSingleNode("*[local-name()='$eKey']")
        $val = if ($el -and $el.InnerText) { $el.InnerText.Trim() } else { "false" }
        Add-El $doc $props $PLAT_NS_MDC $platNames[$eKey] $val | Out-Null
    }
    Add-El $doc $props $PLAT_NS_MDC "ReturnValuesReuse" "DontUse" | Out-Null

    Write-XmlFile $doc (Join-Path $outDir "$modName.xml")

    $bslSrc = Join-Path (Split-Path $mdoPath) "Ext\Module.bsl"
    if (Test-Path $bslSrc) {
        $bslDst = Join-Path $outDir "$modName\Ext\Module.bsl"
        Ensure-Dir (Split-Path $bslDst)
        Copy-Item $bslSrc $bslDst -Force
    }
    Write-Host "  CM: $name"
    return $name
}

# ---- Form metadata file ----
function Write-FormMetaXml([string]$path,[string]$formName,[string]$uuid) {
    $r   = New-MetaDoc "Form" $uuid
    $doc = $r.doc; $obj = $r.obj

    $props = $doc.CreateElement("Properties", $PLAT_NS_MDC)
    $obj.AppendChild($props) | Out-Null

    Add-El $doc $props $PLAT_NS_MDC "Name" $formName | Out-Null
    $syn = $doc.CreateElement("Synonym", $PLAT_NS_MDC)
    Add-V8Item $doc $syn "ru" $formName
    $props.AppendChild($syn) | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "Comment"               ""        | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "FormType"              "Managed" | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "IncludeHelpInContents" "false"   | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "ExtendedPresentation"  ""        | Out-Null

    Write-XmlFile $doc $path
}

# ---- DataProcessor ----
function Convert-DataProcessor([string]$mdoPath,[string]$outDir) {
    $dpName  = [System.IO.Path]::GetFileNameWithoutExtension($mdoPath)
    $dpDir   = Split-Path $mdoPath
    $xml     = Read-XmlFile $mdoPath
    $root    = $xml.DocumentElement
    $uuid    = Get-Uuid $root
    $name    = Get-NodeText $root "name"
    $comment = Get-NodeText $root "comment"
    $syns    = $root.SelectNodes("synonym")

    $formNames = @()
    $formsDir  = Join-Path $dpDir "Forms"
    if (Test-Path $formsDir) {
        $formNames = @(Get-ChildItem $formsDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    }

    $r   = New-MetaDoc "DataProcessor" $uuid
    $doc = $r.doc; $obj = $r.obj

    # InternalInfo - required for DataProcessor (generated types with unique UUIDs)
    $PLAT_NS_XR = "http://v8.1c.ru/8.3/xcf/readable"
    $ii = $doc.CreateElement("InternalInfo", $PLAT_NS_MDC)
    $obj.AppendChild($ii) | Out-Null
    # Object type
    $gt1 = $doc.CreateElement("xr:GeneratedType", $PLAT_NS_XR)
    $gt1.SetAttribute("name", "DataProcessorObject.$name")
    $gt1.SetAttribute("category", "Object")
    $ti1 = $doc.CreateElement("xr:TypeId",  $PLAT_NS_XR); $ti1.InnerText = [guid]::NewGuid().ToString()
    $vi1 = $doc.CreateElement("xr:ValueId", $PLAT_NS_XR); $vi1.InnerText = [guid]::NewGuid().ToString()
    $gt1.AppendChild($ti1) | Out-Null; $gt1.AppendChild($vi1) | Out-Null
    $ii.AppendChild($gt1) | Out-Null
    # Manager type
    $gt2 = $doc.CreateElement("xr:GeneratedType", $PLAT_NS_XR)
    $gt2.SetAttribute("name", "DataProcessorManager.$name")
    $gt2.SetAttribute("category", "Manager")
    $ti2 = $doc.CreateElement("xr:TypeId",  $PLAT_NS_XR); $ti2.InnerText = [guid]::NewGuid().ToString()
    $vi2 = $doc.CreateElement("xr:ValueId", $PLAT_NS_XR); $vi2.InnerText = [guid]::NewGuid().ToString()
    $gt2.AppendChild($ti2) | Out-Null; $gt2.AppendChild($vi2) | Out-Null
    $ii.AppendChild($gt2) | Out-Null

    $props = $doc.CreateElement("Properties", $PLAT_NS_MDC)
    $obj.AppendChild($props) | Out-Null

    Add-El $doc $props $PLAT_NS_MDC "Name"                $name    | Out-Null
    Add-Synonym $doc $props $syns
    Add-El $doc $props $PLAT_NS_MDC "Comment"             $comment | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "UseStandardCommands" "false"  | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "ExtendedPresentation" ""      | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "Explanation"          ""      | Out-Null

    $childObjs = $doc.CreateElement("ChildObjects", $PLAT_NS_MDC)
    $obj.AppendChild($childObjs) | Out-Null

    foreach ($fn in $formNames) {
        Add-El $doc $childObjs $PLAT_NS_MDC "Form" $fn | Out-Null
    }

    Write-XmlFile $doc (Join-Path $outDir "$dpName.xml")

    # ObjectModule / ManagerModule BSL
    foreach ($bslName in @("ObjectModule.bsl","ManagerModule.bsl")) {
        $bslSrc = Join-Path $dpDir "Ext\$bslName"
        if (Test-Path $bslSrc) {
            $bslDst = Join-Path $outDir "$dpName\Ext\$bslName"
            Ensure-Dir (Split-Path $bslDst)
            Copy-Item $bslSrc $bslDst -Force
        }
    }

    # Forms
    foreach ($fn in $formNames) {
        $formSrc  = Join-Path $formsDir $fn
        $formUuid = [guid]::NewGuid().ToString()

        # Form metadata XML: DataProcessors/DpName/Forms/FormName.xml
        $formMetaPath = Join-Path $outDir "$dpName\Forms\$fn.xml"
        Ensure-Dir (Split-Path $formMetaPath)
        Write-FormMetaXml $formMetaPath $fn $formUuid

        # Form definition: Form.form -> Ext/Form.xml
        $formFile = Join-Path $formSrc "Form.form"
        if (Test-Path $formFile) {
            $formXmlDst = Join-Path $outDir "$dpName\Forms\$fn\Ext\Form.xml"
            Convert-FormFile $formFile $formXmlDst
        }

        # Module.bsl
        $bslSrc1 = Join-Path $formSrc "Ext\Form\Module.bsl"
        $bslSrc2 = Join-Path $formSrc "Form\Module.bsl"
        if     (Test-Path $bslSrc1) { $bslSrc = $bslSrc1 }
        elseif (Test-Path $bslSrc2) { $bslSrc = $bslSrc2 }
        else                        { $bslSrc = $null }
        if ($bslSrc) {
            $bslDst = Join-Path $outDir "$dpName\Forms\$fn\Ext\Form\Module.bsl"
            Ensure-Dir (Split-Path $bslDst)
            Copy-Item $bslSrc $bslDst -Force
        }
    }

    Write-Host "  DP: $name (forms: $($formNames.Count))"
    return $name
}

# ---- Role ----
function Convert-Role([string]$mdoPath,[string]$outDir) {
    $roleName = [System.IO.Path]::GetFileNameWithoutExtension($mdoPath)
    $xml  = Read-XmlFile $mdoPath
    $root = $xml.DocumentElement
    $uuid = Get-Uuid $root
    $name    = Get-NodeText $root "name"
    $comment = Get-NodeText $root "comment"
    $syns    = $root.SelectNodes("synonym")

    $r   = New-MetaDoc "Role" $uuid
    $doc = $r.doc; $obj = $r.obj

    $props = $doc.CreateElement("Properties", $PLAT_NS_MDC)
    $obj.AppendChild($props) | Out-Null

    Add-El $doc $props $PLAT_NS_MDC "Name"    $name    | Out-Null
    Add-Synonym $doc $props $syns
    Add-El $doc $props $PLAT_NS_MDC "Comment" $comment | Out-Null

    Write-XmlFile $doc (Join-Path $outDir "$roleName.xml")
    Write-Host "  Role: $name"
    return $name
}

# ---- Form file (EDT -> platform) ----
function Convert-FormFile([string]$srcPath,[string]$dstPath) {
    # Change EDT form NS to platform form NS
    $text = [System.IO.File]::ReadAllText($srcPath, [System.Text.Encoding]::UTF8)
    $text = $text -replace [regex]::Escape($EDT_NS_FORM), $PLAT_NS_FORM
    Ensure-Dir (Split-Path $dstPath)
    [System.IO.File]::WriteAllText($dstPath, $text, [System.Text.Encoding]::UTF8)
}

# ---- Configuration.xml ----
function Build-ConfigurationXml([string]$extMdoPath,[hashtable]$objects,[string]$dstPath) {
    $xml  = Read-XmlFile $extMdoPath
    $root = $xml.DocumentElement
    $uuid    = Get-Uuid $root
    $name    = Get-NodeText $root "name"
    $comment = Get-NodeText $root "comment"
    $version = Get-NodeText $root "version"
    $compat  = Get-NodeText $root "compatibilityMode" "Version8_3_14"
    $purpose = Get-NodeText $root "extensionPurpose"  "Customization"
    $syns    = $root.SelectNodes("synonym")

    $r   = New-MetaDoc "Configuration" $uuid
    $doc = $r.doc; $obj = $r.obj

    # Properties section
    $props = $doc.CreateElement("Properties", $PLAT_NS_MDC)
    $obj.AppendChild($props) | Out-Null

    Add-El $doc $props $PLAT_NS_MDC "Name"       $name    | Out-Null
    Add-Synonym $doc $props $syns
    Add-El $doc $props $PLAT_NS_MDC "Comment"    $comment | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "NamePrefix" ""       | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "Version"    $version | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "Vendor"     ""       | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "ExtensionPurpose" $purpose                           | Out-Null
    Add-El $doc $props $PLAT_NS_MDC "ConfigurationExtensionCompatibilityMode" $compat     | Out-Null

    # ChildObjects section
    $childObjs = $doc.CreateElement("ChildObjects", $PLAT_NS_MDC)
    $obj.AppendChild($childObjs) | Out-Null

    foreach ($section in @("CommonModules","DataProcessors","Roles")) {
        # Map section name to ChildObjects element name
        $elemName = switch ($section) {
            "CommonModules"  { "CommonModule" }
            "DataProcessors" { "DataProcessor" }
            "Roles"          { "Role" }
        }
        if ($objects[$section] -and $objects[$section].Count -gt 0) {
            foreach ($objName in $objects[$section]) {
                Add-El $doc $childObjs $PLAT_NS_MDC $elemName $objName | Out-Null
            }
        }
    }

    Write-XmlFile $doc $dstPath
}

# ============================================================
# MAIN
# ============================================================
$Src = [System.IO.Path]::GetFullPath($Src)
$Dst = [System.IO.Path]::GetFullPath($Dst)
Write-Host "Source: $Src"
Write-Host "Dest  : $Dst"

$extMdoPath = Join-Path $Src "Extension.mdo"
if (-not (Test-Path $extMdoPath)) {
    Write-Host "ERROR: Extension.mdo not found" -ForegroundColor Red; exit 1
}

$srcDir = Join-Path $Src "src"
if (-not (Test-Path $srcDir)) { $srcDir = $Src }

Ensure-Dir $Dst
$objects = @{ CommonModules=@(); DataProcessors=@(); Roles=@() }

# CommonModules
$cmSrc = Join-Path $srcDir "CommonModules"
if (Test-Path $cmSrc) {
    Write-Host "CommonModules:"
    $cmDst = Join-Path $Dst "CommonModules"; Ensure-Dir $cmDst
    foreach ($mdo in Get-ChildItem $cmSrc -Filter "*.mdo" -Recurse | Sort-Object FullName) {
        $n = Convert-CommonModule $mdo.FullName $cmDst
        if ($n) { $objects["CommonModules"] += $n }
    }
}

# DataProcessors
$dpSrc = Join-Path $srcDir "DataProcessors"
if (Test-Path $dpSrc) {
    Write-Host "DataProcessors:"
    $dpDst = Join-Path $Dst "DataProcessors"; Ensure-Dir $dpDst
    foreach ($mdo in Get-ChildItem $dpSrc -Filter "*.mdo" -Recurse | Sort-Object FullName) {
        $n = Convert-DataProcessor $mdo.FullName $dpDst
        if ($n) { $objects["DataProcessors"] += $n }
    }
}

# Roles
$roleSrc = Join-Path $srcDir "Roles"
if (Test-Path $roleSrc) {
    Write-Host "Roles:"
    $roleDst = Join-Path $Dst "Roles"; Ensure-Dir $roleDst
    foreach ($mdo in Get-ChildItem $roleSrc -Filter "*.mdo" -Recurse | Sort-Object FullName) {
        $n = Convert-Role $mdo.FullName $roleDst
        if ($n) { $objects["Roles"] += $n }
    }
}

Write-Host "Building Configuration.xml..."
Build-ConfigurationXml $extMdoPath $objects (Join-Path $Dst "Configuration.xml")

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "CommonModules : $($objects.CommonModules.Count)"
Write-Host "DataProcessors: $($objects.DataProcessors.Count)"
Write-Host "Roles         : $($objects.Roles.Count)"
Write-Host "Output: $Dst"
