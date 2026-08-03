# Scrapes RimWorld BackstoryDef / AlienBackstoryDef XML into Backstories.json
# Usage (from repo root):
#   powershell -NoProfile -File scripts/export-backstories.ps1

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

function Get-ListItems([System.Xml.XmlNode]$parent, [string]$name) {
  $out = @()
  if ($null -eq $parent) { return $out }
  $node = $parent.SelectSingleNode($name)
  if ($null -eq $node) { return $out }
  foreach ($li in $node.SelectNodes('li')) {
    $t = Get-InnerText $li
    if ($t) { $out += $t }
  }
  if ($out.Count -eq 0) {
    $raw = Get-InnerText $node
    if ($raw -and $raw -ne 'None') {
      foreach ($part in ($raw -split '[, ]+')) {
        if ($part -and $part -ne 'None') { $out += $part }
      }
    }
  }
  return $out
}

function Get-SkillGainStrings([System.Xml.XmlNode]$parent) {
  $joined = @()
  $raw = @()
  $node = $parent.SelectSingleNode('skillGains')
  if ($null -eq $node) { return @{ joined = ''; raw = @() } }
  foreach ($child in $node.ChildNodes) {
    if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    $skill = $null
    $amt = $null
    if ($child.Name -eq 'li') {
      $skill = Get-ChildText $child 'key'
      if (-not $skill) { $skill = Get-ChildText $child 'skill' }
      $amt = Get-ChildText $child 'value'
      if (-not $amt) { $amt = Get-ChildText $child 'amount' }
    } else {
      $skill = $child.Name
      $amt = Get-InnerText $child
    }
    if (-not $skill) { continue }
    if ($amt -notmatch '^-?\d+$') { continue }
    $n = [int]$amt
    $sign = if ($n -gt 0) { '+' } else { '' }
    $joined += ('{0} {1}{2}' -f $skill, $sign, $n)
    $raw += ('{0}:{1}' -f $skill, $n)
  }
  return @{
    joined = ($joined -join '; ')
    raw = $raw
  }
}

function Get-ForcedTraits([System.Xml.XmlNode]$parent) {
  $out = @()
  $node = $parent.SelectSingleNode('forcedTraits')
  if ($null -eq $node) { return $out }
  foreach ($child in $node.ChildNodes) {
    if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($child.Name -eq 'li') {
      $def = Get-ChildText $child 'def'
      if (-not $def) { $def = Get-InnerText $child }
      $deg = Get-ChildText $child 'degree'
      if ($def) {
        if ($deg) { $out += ('{0}@{1}' -f $def, $deg) } else { $out += $def }
      }
      continue
    }
    $deg = Get-InnerText $child
    if ($deg -match '^-?\d+$') { $out += ('{0}@{1}' -f $child.Name, $deg) }
    else { $out += $child.Name }
  }
  return $out
}

function Normalize-Description([string]$desc) {
  if (-not $desc) { return '' }
  $desc = $desc.Replace('\n', "`n")
  $desc = $desc.Replace('[PAWN_nameDef]', 'This colonist')
  $desc = $desc.Replace('[PAWN_pronoun]', 'they')
  $desc = $desc.Replace('[PAWN_possessive]', 'their')
  $desc = $desc.Replace('[PAWN_objective]', 'them')
  $desc = $desc.Replace('[PAWN_gender]', '')
  # Fix common grammar after placeholder substitution
  $desc = $desc -replace '\bThey was\b', 'They were'
  $desc = $desc -replace '\bThis colonist was\b', 'This colonist was'
  $desc = $desc -replace '\bthey was\b', 'they were'
  return $desc.Trim()
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

function Find-BackstoryXmlFiles([string]$contentRoot) {
  $defs = Join-Path $contentRoot 'Defs'
  if (-not (Test-Path -LiteralPath $defs)) { return @() }
  $files = [IO.Directory]::GetFiles($defs, '*.xml', [IO.SearchOption]::AllDirectories)
  $hit = New-Object System.Collections.Generic.List[string]
  foreach ($f in $files) {
    try {
      $sample = [IO.File]::ReadAllText($f)
      if ($sample.Contains('BackstoryDef')) { [void]$hit.Add($f) }
    } catch {}
  }
  return @($hit)
}

function Parse-BackstoryFile([string]$file, [string]$modName, [hashtable]$bucket) {
  try {
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.XmlResolver = $null
    $xml.Load($file)
  } catch {
    Write-Warning ('Skip unreadable XML: {0} - {1}' -f $file, $_.Exception.Message)
    return
  }

  $xpath = '//*[contains(name(),''BackstoryDef'')]'
  $nodes = $xml.SelectNodes($xpath)
  if ($null -eq $nodes) { return }

  foreach ($n in $nodes) {
    $defName = Get-ChildText $n 'defName'
    if (-not $defName) { continue }

    $slot = Get-ChildText $n 'slot'
    if (-not $slot) { $slot = 'Unknown' }

    $title = Get-ChildText $n 'title'
    if (-not $title) { $title = $defName }
    $titleShort = Get-ChildText $n 'titleShort'
    if (-not $titleShort) { $titleShort = $title }

    $shuffleRaw = Get-ChildText $n 'shuffleable'
    $shuffleable = $true
    if ($shuffleRaw -eq 'False' -or $shuffleRaw -eq 'false') { $shuffleable = $false }

  $desc = Normalize-Description (Get-ChildText $n 'description')
  $skills = Get-SkillGainStrings $n

  $entry = [ordered]@{
    DefName          = $defName
    Title            = $title
    TitleShort       = $titleShort
    Slot             = $slot
    Description      = $desc
    SkillGains       = @($skills.raw)
    SkillGainsJoined = [string]$skills.joined
    WorkDisables     = @(Get-ListItems $n 'workDisables')
    SpawnCategories  = @(Get-ListItems $n 'spawnCategories')
    ForcedTraits     = @(Get-ForcedTraits $n)
    Shuffleable      = $shuffleable
    ModSource        = $modName
  }

    if (-not $bucket.ContainsKey($defName)) {
      $bucket[$defName] = $entry
    }
  }
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

$bucket = @{}
$filesScanned = 0
foreach ($src in $sources) {
  foreach ($f in (Find-BackstoryXmlFiles $src.Root)) {
    $filesScanned++
    Parse-BackstoryFile $f $src.Name $bucket
  }
}

$ordered = [ordered]@{}
foreach ($key in ($bucket.Keys | Sort-Object)) {
  $ordered[$key] = $bucket[$key]
}

$payload = [ordered]@{
  exportedAt       = (Get-Date).ToUniversalTime().ToString('o')
  sourceRoot       = $RimWorldRoot
  filesScanned     = $filesScanned
  totalBackstories = $ordered.Count
  items            = $ordered
}

$outPath = Join-Path $root 'Backstories.json'
Write-Utf8NoBom $outPath ($payload | ConvertTo-Json -Depth 8)

$child = @($ordered.Values | Where-Object { $_.Slot -eq 'Childhood' }).Count
$adult = @($ordered.Values | Where-Object { $_.Slot -eq 'Adulthood' }).Count
Write-Host ('Wrote Backstories.json ({0} total: {1} childhood, {2} adulthood; {3} XML files scanned)' -f $ordered.Count, $child, $adult, $filesScanned)
