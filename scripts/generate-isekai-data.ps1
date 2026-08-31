# Extract Isekai RPG Leveling stats/classes/keystones into web/public/data/*.json
# Source: Steam workshop ISEKAI RPG LEVELING (3657580708)
# Usage: powershell -NoProfile -File scripts/generate-isekai-data.ps1
$ErrorActionPreference = "Stop"

$treesDir = "C:\Program Files (x86)\Steam\steamapps\workshop\content\294100\3657580708\Defs\PassiveTrees"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "web\public"))) { $root = (Get-Location).Path }

$outDir = Join-Path $root "web\public\data"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not (Test-Path $treesDir)) {
  throw "Isekai PassiveTrees not found at: $treesDir"
}

function Clean([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s.Replace([char]0x2013, [char]0x2D).Replace([char]0x2014, [char]0x2D).Replace([char]0x2015, [char]0x2D)
  $s = $s.Replace([char]0x2018, [char]0x27).Replace([char]0x2019, [char]0x27)
  $s = $s.Replace([char]0x201C, [char]0x22).Replace([char]0x201D, [char]0x22)
  $s = $s.Replace([string][char]0x2026, "...").Replace([string][char]0x2192, "->")
  $s = [regex]::Replace($s, "\s+", " ")
  return $s.Trim()
}

function Js-Escape([string]$s) {
  $s = Clean $s
  $s = $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", "").Replace("`n", " ")
  return $s
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Write-JsonRows([string]$Name, $Rows) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("[")
  $first = $true
  foreach ($row in $Rows) {
    if (-not $first) { [void]$sb.Append(",") }
    $first = $false
    [void]$sb.Append($row)
  }
  [void]$sb.Append("]")
  Write-Utf8NoBom (Join-Path $outDir "$Name.json") $sb.ToString()
}

$classRows = New-Object System.Collections.Generic.List[string]
$keyRows = New-Object System.Collections.Generic.List[string]

foreach ($file in Get-ChildItem $treesDir -Filter "*.xml") {
  [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $tree = $null
  foreach ($child in $xml.Defs.ChildNodes) {
    if ($child.LocalName -like "*PassiveTreeDef") { $tree = $child; break }
  }
  if (-not $tree) { continue }

  $label = [string]$tree.label
  $class = [string]$tree.treeClass
  $desc = [string]$tree.treeDescription
  $gimName = [string]$tree.classGimmickName
  $gimDesc = [string]$tree.classGimmickDescription
  $nodes = @($tree.nodes.li)
  $keystones = @($nodes | Where-Object { $_.nodeType -eq "Keystone" })

  $row = '["{0}","{1}","{2}","{3}","{4}",{5},{6}]' -f `
    (Js-Escape $label), (Js-Escape $class), (Js-Escape $desc), `
    (Js-Escape $gimName), (Js-Escape $gimDesc), $nodes.Count, $keystones.Count
  [void]$classRows.Add($row)

  foreach ($k in $keystones) {
    $bonuses = New-Object System.Collections.Generic.List[string]
    if ($k.bonuses -and $k.bonuses.li) {
      foreach ($b in @($k.bonuses.li)) {
        $bt = [string]$b.bonusType
        $bv = [string]$b.value
        $num = 0.0
        if ([double]::TryParse($bv, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num) `
            -and [math]::Abs($num) -lt 5 -and $bv.Contains(".")) {
          $pct = [math]::Round($num * 100, 1)
          $sign = if ($pct -gt 0) { "+" } else { "" }
          [void]$bonuses.Add(("{0} {1}{2}%" -f $bt, $sign, $pct))
        } else {
          [void]$bonuses.Add(("{0} {1}" -f $bt, $bv))
        }
      }
    }
    $cost = 1
    if ($k.cost) { $cost = [int]$k.cost }
    $krow = '["{0}","{1}","{2}","{3}",{4},"{5}"]' -f `
      (Js-Escape $label), (Js-Escape ([string]$k.label)), (Js-Escape ([string]$k.nodeId)), `
      (Js-Escape ([string]$k.description)), $cost, (Js-Escape (($bonuses -join "; ")))
    [void]$keyRows.Add($krow)
  }
}

$statRows = @(
  '["STR","Strength","Increases melee damage and carry capacity."]',
  '["DEX","Dexterity","Improves movement speed, melee dodge, shooting accuracy, melee hit chance, aiming speed, and ranged damage."]',
  '["VIT","Vitality","Boosts injury healing, toxic resistance, damage reduction, natural armor, pain shock threshold, bleed resistance, and rest efficiency."]',
  '["INT","Intelligence","Enhances work speed, research speed, learning rate, and hacking speed. Affects psychic sensitivity with WIS."]',
  '["WIS","Wisdom","Improves mental stability, meditation focus, neural heat recovery, and psyfocus efficiency. Affects psychic sensitivity with INT."]',
  '["CHA","Charisma","Improves social impact, negotiation ability, trade prices, animal taming, and arrest success."]'
)

Write-JsonRows "isekai-stats" $statRows
Write-JsonRows "isekai-classes" $classRows
Write-JsonRows "isekai-keystones" $keyRows

Write-Host ("Wrote web/public/data/isekai-stats.json (6 stats)")
Write-Host ("Wrote web/public/data/isekai-classes.json ({0} classes)" -f $classRows.Count)
Write-Host ("Wrote web/public/data/isekai-keystones.json ({0} keystones)" -f $keyRows.Count)
