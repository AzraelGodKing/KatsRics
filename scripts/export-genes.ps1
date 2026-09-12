# Scrapes RimWorld GeneDef / GeneTemplateDef XML into Genes.json
# Expands Skill + Chemical GeneTemplateDefs the same way the game does at load.
# Usage (from repo root):
#   powershell -NoProfile -File scripts/export-genes.ps1

param(
  [string]$RimWorldRoot = 'E:\SteamLibrary\steamapps\common\RimWorld',
  [string]$WorkshopRoot = 'E:\SteamLibrary\steamapps\workshop\content\294100'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'ActiveMods.json'))) {
  $root = (Get-Location).Path
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-InnerText([System.Xml.XmlNode]$node) {
  if ($null -eq $node) { return $null }
  return ($node.InnerText -replace "`r", '').Trim()
}

function Get-ChildText([System.Xml.XmlNode]$parent, [string]$name) {
  if ($null -eq $parent) { return $null }
  return (Get-InnerText ($parent.SelectSingleNode($name)))
}

function Get-AboutName([string]$modDir) {
  $about = Join-Path $modDir 'About\About.xml'
  if (-not (Test-Path -LiteralPath $about)) { return [IO.Path]::GetFileName($modDir) }
  try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.Load($about)
    $n = $xml.SelectSingleNode('//ModMetaData/name')
    if ($n -and $n.InnerText) { return $n.InnerText.Trim() }
  } catch {}
  return [IO.Path]::GetFileName($modDir)
}

function Resolve-ModContentRoot([string]$modDir) {
  $versionDirs = @()
  foreach ($d in [IO.Directory]::GetDirectories($modDir)) {
    $name = [IO.Path]::GetFileName($d)
    if ($name -match '^\d+\.\d+') { $versionDirs += $d }
  }
  $versionDirs = @(
    $versionDirs | Sort-Object {
      $n = [IO.Path]::GetFileName($_)
      if ($n -match '^(\d+)\.(\d+)') { [int]$Matches[1] * 1000 + [int]$Matches[2] } else { 0 }
    } -Descending
  )
  foreach ($vd in $versionDirs) {
    if (Test-Path -LiteralPath (Join-Path $vd 'Defs')) { return $vd }
  }
  return $modDir
}

function Normalize-Description([string]$desc) {
  if (-not $desc) { return '' }
  $desc = $desc.Replace('\n', "`n")
  $desc = $desc -replace '\{0\}', '{0}'
  return $desc.Trim()
}

function Get-IntField([hashtable]$fields, [string]$name, [int]$default = 0) {
  if (-not $fields.ContainsKey($name)) { return $default }
  $t = Get-InnerText $fields[$name]
  if ($t -match '^-?\d+$') { return [int]$t }
  return $default
}

function Get-FloatField([hashtable]$fields, [string]$name, [double]$default = 1.0) {
  if (-not $fields.ContainsKey($name)) { return $default }
  $t = Get-InnerText $fields[$name]
  $parsed = 0.0
  if ([double]::TryParse($t, [ref]$parsed)) { return $parsed }
  return $default
}

function Get-MergedFields([System.Xml.XmlElement]$node, [hashtable]$named) {
  $chain = New-Object System.Collections.Generic.List[System.Xml.XmlElement]
  $cur = $node
  $guard = 0
  while ($null -ne $cur -and $guard -lt 32) {
    $guard++
    $chain.Insert(0, $cur)
    $pn = $cur.GetAttribute('ParentName')
    if (-not $pn) { break }
    if (-not $named.ContainsKey($pn)) { break }
    $cur = $named[$pn]
  }
  $fields = @{}
  foreach ($n in $chain) {
    foreach ($child in $n.ChildNodes) {
      if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
      $fields[$child.Name] = $child
    }
  }
  return $fields
}

function Is-AbstractNode([System.Xml.XmlElement]$node) {
  $a = $node.GetAttribute('Abstract')
  return ($a -eq 'True' -or $a -eq 'true')
}

function Find-GeneXmlFiles([string]$contentRoot) {
  $defs = Join-Path $contentRoot 'Defs'
  if (-not (Test-Path -LiteralPath $defs)) { return @() }
  $files = [IO.Directory]::GetFiles($defs, '*.xml', [IO.SearchOption]::AllDirectories)
  $hit = New-Object System.Collections.Generic.List[string]
  foreach ($f in $files) {
    if ($f -match '[\\/]AnimalGeneDefs[\\/]') { continue }
    try {
      $sample = [IO.File]::ReadAllText($f)
      if ($sample.Contains('GeneDef') -or $sample.Contains('GeneTemplateDef') -or $sample.Contains('GeneCategoryDef')) {
        [void]$hit.Add($f)
      }
    } catch {}
  }
  return @($hit)
}

function Collect-NamedNodes([string]$file, [hashtable]$namedGenes, [hashtable]$namedTemplates, [hashtable]$categories) {
  try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.XmlResolver = $null
    $xml.Load($file)
  } catch {
    Write-Warning ('Skip unreadable XML: {0} - {1}' -f $file, $_.Exception.Message)
    return
  }

  foreach ($n in $xml.SelectNodes('//GeneCategoryDef')) {
    $dn = Get-ChildText $n 'defName'
    if (-not $dn) { continue }
    $label = Get-ChildText $n 'label'
    if (-not $label) { $label = $dn }
    $categories[$dn] = $label
  }

  foreach ($n in $xml.SelectNodes('//GeneDef')) {
    $nameAttr = $n.GetAttribute('Name')
    if ($nameAttr) { $namedGenes[$nameAttr] = $n }
  }
  foreach ($n in $xml.SelectNodes('//GeneTemplateDef')) {
    $nameAttr = $n.GetAttribute('Name')
    if ($nameAttr) { $namedTemplates[$nameAttr] = $n }
  }
}

function Add-GeneEntry(
  [hashtable]$bucket,
  [string]$defName,
  [string]$label,
  [string]$labelShort,
  [string]$description,
  [string]$category,
  [int]$cpx,
  [int]$met,
  [int]$arc,
  [double]$marketFactor,
  [string]$modName,
  [bool]$fromTemplate
) {
  if (-not $defName) { return }
  if ($bucket.ContainsKey($defName)) { return }

  $entry = [ordered]@{
    DefName          = $defName
    Label            = $label
    LabelShort       = $labelShort
    Description      = $description
    DisplayCategory  = $category
    BiostatCpx       = $cpx
    BiostatMet       = $met
    BiostatArc       = $arc
    MarketValueFactor = [math]::Round($marketFactor, 3)
    FromTemplate     = $fromTemplate
    ModSource        = $modName
  }
  $bucket[$defName] = $entry
}

function Emit-ConcreteGenes([string]$file, [string]$modName, [hashtable]$namedGenes, [hashtable]$bucket) {
  try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.XmlResolver = $null
    $xml.Load($file)
  } catch { return }

  foreach ($n in $xml.SelectNodes('//GeneDef')) {
    if (Is-AbstractNode $n) { continue }
    $defName = Get-ChildText $n 'defName'
    if (-not $defName) { continue }

    $fields = Get-MergedFields $n $namedGenes
    $label = if ($fields.ContainsKey('label')) { Get-InnerText $fields['label'] } else { $defName }
    $labelShort = if ($fields.ContainsKey('labelShortAdj')) { Get-InnerText $fields['labelShortAdj'] } else { '' }
    $descRaw = if ($fields.ContainsKey('description')) { Get-InnerText $fields['description'] } else { '' }
    $desc = Normalize-Description $descRaw
    $cat = if ($fields.ContainsKey('displayCategory')) { Get-InnerText $fields['displayCategory'] } else { 'Unknown' }

    Add-GeneEntry $bucket $defName $label $labelShort $desc $cat `
      (Get-IntField $fields 'biostatCpx') `
      (Get-IntField $fields 'biostatMet') `
      (Get-IntField $fields 'biostatArc') `
      (Get-FloatField $fields 'marketValueFactor' 1.0) `
      $modName $false
  }
}

function Get-ChemicalBiostatOverride([hashtable]$fields, [string]$chemical, [string]$statName, [int]$fallback) {
  if (-not $fields.ContainsKey('chemicalBiostatOverrides')) { return $fallback }
  $node = $fields['chemicalBiostatOverrides']
  foreach ($li in $node.SelectNodes('li')) {
    $chem = Get-ChildText $li 'chemical'
    if ($chem -ne $chemical) { continue }
    $v = Get-ChildText $li $statName
    if ($v -match '^-?\d+$') { return [int]$v }
  }
  return $fallback
}

function Emit-TemplateGenes(
  [string]$file,
  [string]$modName,
  [hashtable]$namedTemplates,
  [object[]]$skills,
  [object[]]$chemicals,
  [hashtable]$bucket
) {
  try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.XmlResolver = $null
    $xml.Load($file)
  } catch { return }

  foreach ($n in $xml.SelectNodes('//GeneTemplateDef')) {
    if (Is-AbstractNode $n) { continue }
    $templateName = Get-ChildText $n 'defName'
    if (-not $templateName) { continue }

    $fields = Get-MergedFields $n $namedTemplates
    $geneType = if ($fields.ContainsKey('geneTemplateType')) { Get-InnerText $fields['geneTemplateType'] } else { '' }
    $labelTpl = if ($fields.ContainsKey('label')) { Get-InnerText $fields['label'] } else { $templateName }
    $labelShortTpl = if ($fields.ContainsKey('labelShortAdj')) { Get-InnerText $fields['labelShortAdj'] } else { '' }
    $descRaw = if ($fields.ContainsKey('description')) { Get-InnerText $fields['description'] } else { '' }
    $descTpl = Normalize-Description $descRaw
    $cat = if ($fields.ContainsKey('displayCategory')) { Get-InnerText $fields['displayCategory'] } else { 'Unknown' }
    $baseCpx = Get-IntField $fields 'biostatCpx'
    $baseMet = Get-IntField $fields 'biostatMet'
    $baseArc = Get-IntField $fields 'biostatArc'
    $mkt = Get-FloatField $fields 'marketValueFactor' 1.0

    if ($geneType -eq 'Skill') {
      foreach ($sk in $skills) {
        $defName = '{0}_{1}' -f $templateName, $sk.DefName
        $label = $labelTpl -replace '\{0\}', $sk.Label
        $labelShort = $labelShortTpl -replace '\{0\}', $sk.Label
        $desc = $descTpl -replace '\{0\}', $sk.Label
        Add-GeneEntry $bucket $defName $label $labelShort $desc $cat $baseCpx $baseMet $baseArc $mkt $modName $true
      }
    }
    elseif ($geneType -eq 'Chemical') {
      foreach ($ch in $chemicals) {
        $defName = '{0}_{1}' -f $templateName, $ch.DefName
        $label = $labelTpl -replace '\{0\}', $ch.Label
        $labelShort = $labelShortTpl -replace '\{0\}', $ch.Label
        $desc = $descTpl -replace '\{0\}', $ch.Label
        $cpx = Get-ChemicalBiostatOverride $fields $ch.DefName 'biostatCpx' $baseCpx
        $met = Get-ChemicalBiostatOverride $fields $ch.DefName 'biostatMet' $baseMet
        $arc = Get-ChemicalBiostatOverride $fields $ch.DefName 'biostatArc' $baseArc
        Add-GeneEntry $bucket $defName $label $labelShort $desc $cat $cpx $met $arc $mkt $modName $true
      }
    }
  }
}

function Collect-Skills([string]$rimRoot) {
  $out = New-Object System.Collections.Generic.List[object]
  $skillsFile = Join-Path $rimRoot 'Data\Core\Defs\SkillDefs\Skills.xml'
  if (-not (Test-Path -LiteralPath $skillsFile)) { return @() }
  $xml = New-Object System.Xml.XmlDocument
  $xml.PreserveWhitespace = $false
  $xml.Load($skillsFile)
  foreach ($n in $xml.SelectNodes('//SkillDef')) {
    $dn = Get-ChildText $n 'defName'
    if (-not $dn) { continue }
    $label = Get-ChildText $n 'skillLabel'
    if (-not $label) { $label = $dn.ToLowerInvariant() }
    [void]$out.Add([pscustomobject]@{ DefName = $dn; Label = $label })
  }
  return ,$out.ToArray()
}

function Collect-Chemicals([string]$rimRoot) {
  $out = New-Object System.Collections.Generic.List[object]
  $seen = @{}
  $dataRoot = Join-Path $rimRoot 'Data'
  if (-not (Test-Path -LiteralPath $dataRoot)) { return @() }
  foreach ($f in [IO.Directory]::GetFiles($dataRoot, '*.xml', [IO.SearchOption]::AllDirectories)) {
    try {
      $sample = [IO.File]::ReadAllText($f)
      if (-not $sample.Contains('<ChemicalDef>')) { continue }
      $xml = New-Object System.Xml.XmlDocument
      $xml.PreserveWhitespace = $false
      $xml.XmlResolver = $null
      $xml.Load($f)
      foreach ($n in $xml.SelectNodes('//ChemicalDef')) {
        $dn = Get-ChildText $n 'defName'
        if (-not $dn -or $seen.ContainsKey($dn)) { continue }
        $label = Get-ChildText $n 'label'
        if (-not $label) { $label = $dn.ToLowerInvariant() }
        $seen[$dn] = $true
        [void]$out.Add([pscustomobject]@{ DefName = $dn; Label = $label })
      }
    } catch {}
  }
  return ,$out.ToArray()
}

if (-not (Test-Path -LiteralPath $RimWorldRoot)) {
  throw ('RimWorld root not found: {0}' -f $RimWorldRoot)
}

$sources = New-Object System.Collections.Generic.List[object]
$dataRoot = Join-Path $RimWorldRoot 'Data'
foreach ($pack in @('Core', 'Royalty', 'Ideology', 'Biotech', 'Anomaly', 'Odyssey')) {
  $packPath = Join-Path $dataRoot $pack
  if (Test-Path -LiteralPath $packPath) {
    [void]$sources.Add([pscustomobject]@{ Name = $pack; Root = $packPath })
  }
}

$localMods = Join-Path $RimWorldRoot 'Mods'
if (Test-Path -LiteralPath $localMods) {
  foreach ($d in [IO.Directory]::GetDirectories($localMods)) {
    [void]$sources.Add([pscustomobject]@{ Name = (Get-AboutName $d); Root = (Resolve-ModContentRoot $d) })
  }
}

$activePath = Join-Path $root 'ActiveMods.json'
$activeIds = @{}
if (Test-Path -LiteralPath $activePath) {
  $active = Get-Content -Raw -LiteralPath $activePath | ConvertFrom-Json
  foreach ($m in $active.mods) {
    if ($m.steamId) { $activeIds[[string]$m.steamId] = [string]$m.name }
  }
}

if (Test-Path -LiteralPath $WorkshopRoot) {
  foreach ($id in $activeIds.Keys) {
    $modDir = Join-Path $WorkshopRoot $id
    if (-not (Test-Path -LiteralPath $modDir)) { continue }
    $name = $activeIds[$id]
    if (-not $name) { $name = Get-AboutName $modDir }
    [void]$sources.Add([pscustomobject]@{ Name = $name; Root = (Resolve-ModContentRoot $modDir) })
  }
}

$skills = Collect-Skills $RimWorldRoot
$chemicals = Collect-Chemicals $RimWorldRoot
Write-Host ('Template expanders: {0} skills, {1} chemicals' -f $skills.Count, $chemicals.Count)

$namedGenes = @{}
$namedTemplates = @{}
$categories = @{}
$fileList = New-Object System.Collections.Generic.List[object]

foreach ($src in $sources) {
  foreach ($f in (Find-GeneXmlFiles $src.Root)) {
    [void]$fileList.Add([pscustomobject]@{ File = $f; Mod = $src.Name })
    Collect-NamedNodes $f $namedGenes $namedTemplates $categories
  }
}

$bucket = @{}
foreach ($item in $fileList) {
  Emit-ConcreteGenes $item.File $item.Mod $namedGenes $bucket
  Emit-TemplateGenes $item.File $item.Mod $namedTemplates $skills $chemicals $bucket
}

# Apply human-readable category labels when available
foreach ($key in @($bucket.Keys)) {
  $cat = [string]$bucket[$key].DisplayCategory
  if ($categories.ContainsKey($cat)) {
    $bucket[$key].DisplayCategoryLabel = $categories[$cat]
  } else {
    $bucket[$key].DisplayCategoryLabel = $cat
  }
}

$ordered = [ordered]@{}
foreach ($key in ($bucket.Keys | Sort-Object)) {
  $ordered[$key] = $bucket[$key]
}

$payload = [ordered]@{
  exportedAt   = (Get-Date).ToUniversalTime().ToString('o')
  sourceRoot   = $RimWorldRoot
  filesScanned = $fileList.Count
  totalGenes   = $ordered.Count
  geneEditRates = [ordered]@{
    complexity = 100
    metabolism = 250
    archite    = 1000
    note       = 'From CommandSettings geneedit CustomData; site estimate uses abs(cpx)*100 + abs(met)*250 + arc*1000'
  }
  items        = $ordered
}

$outPath = Join-Path $root 'Genes.json'
Write-Utf8NoBom $outPath ($payload | ConvertTo-Json -Depth 8)

$archite = @($ordered.Values | Where-Object { $_.BiostatArc -gt 0 }).Count
$templated = @($ordered.Values | Where-Object { $_.FromTemplate }).Count
Write-Host ('Wrote Genes.json ({0} genes: {1} from templates, {2} archite; {3} XML files scanned)' -f $ordered.Count, $templated, $archite, $fileList.Count)
