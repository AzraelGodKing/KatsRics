# Generates docs browser data JS from repo JSON exports:
#   traits-data.js, xenotypes-data.js, incidents-data.js, weather-data.js, backstories-data.js
# Usage (from repo root): powershell -NoProfile -File scripts/generate-docs-data.ps1
# Backstories.json is produced by: powershell -NoProfile -File scripts/export-backstories.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "Traits.json"))) {
  $root = Get-Location
}

function Js-Escape([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace "\\", "\\\\" -replace "`"", "\`"" -replace "`r", "" -replace "`n", "\\n")
}

function Js-Bool($b) {
  if ($b) { "true" } else { "false" }
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Normalize-TraitDescription([string]$desc) {
  if ($null -eq $desc) { return "" }
  $desc = $desc -replace "`r", ""
  $desc = $desc.Replace("{PAWN_nameDef}", "This colonist")
  $desc = $desc.Replace("{PAWN_pronoun}", "they")
  $desc = $desc.Replace("{PAWN_possessive}", "their")
  $desc = $desc.Replace("{PAWN_objective}", "them")
  $desc = $desc.Replace("{PAWN_gender}", "")
  $desc = $desc -replace "\bThis colonist is an\b", "This colonist is an"
  $desc = $desc -replace "\bthey is\b", "they are"
  $desc = $desc -replace "\bthey has\b", "they have"
  $desc = $desc -replace "\bthey learns\b", "they learn"
  $desc = $desc -replace "\bthey gets\b", "they get"
  $desc = $desc -replace "\bthey enjoys\b", "they enjoy"
  $desc = $desc -replace "\bthey never minds\b", "they never mind"
  $desc = $desc -replace "\bthey doesn't\b", "they don't"
  $desc = $desc -replace "\bthey feels\b", "they feel"
  $desc = $desc -replace "\bthey rarely insults\b", "they rarely insult"
  $desc = $desc -replace "\bthey also never judges\b", "they also never judge"
  $desc = $desc -replace "\bthey can\b", "they can"
  $desc = $desc -replace "\b\. they\b", ". They"
  return $desc.Trim()
}

# --- Traits ---
# Row: [name, defName, degree, addPrice, removePrice, canAdd, canRemove, bypassLimit, mod, modActive, statsJoined, description]
$traits = Get-Content -Raw (Join-Path $root "Traits.json") | ConvertFrom-Json
$traitRows = New-Object System.Collections.Generic.List[string]
foreach ($p in $traits.PSObject.Properties) {
  $t = $p.Value
  $stats = @()
  if ($t.Stats) { $stats = @($t.Stats | ForEach-Object { [string]$_ }) }
  $statsJoined = ($stats -join "; ")
  $name = Js-Escape ([string]$t.Name)
  $def = Js-Escape ([string]$t.DefName)
  $mod = Js-Escape ([string]$t.ModSource)
  $statsEsc = Js-Escape $statsJoined
  $descEsc = Js-Escape (Normalize-TraitDescription ([string]$t.Description))
  $degree = [int]$t.Degree
  $add = [int]$t.AddPrice
  $rem = [int]$t.RemovePrice
  $row = "[`"$name`",`"$def`",$degree,$add,$rem,$(Js-Bool $t.CanAdd),$(Js-Bool $t.CanRemove),$(Js-Bool $t.BypassLimit),`"$mod`",$(Js-Bool $t.modactive),`"$statsEsc`",`"$descEsc`"]"
  [void]$traitRows.Add($row)
}
$traitsJs = "const TRAITS = [`n" + ($traitRows -join ",`n") + "`n];`n"
Write-Utf8NoBom (Join-Path $root "docs\traits-data.js") $traitsJs

# --- Xenotypes ---
# Row: [raceDisplayName, raceDef, xenotype, price, xenotypeEnabled, raceEnabled, modActive]
$races = Get-Content -Raw (Join-Path $root "RaceSettings.json") | ConvertFrom-Json
$xenoRows = New-Object System.Collections.Generic.List[string]
foreach ($rp in $races.PSObject.Properties) {
  $raceDef = Js-Escape $rp.Name
  $r = $rp.Value
  $display = Js-Escape ([string]$r.DisplayName)
  $raceEnabled = [bool]$r.Enabled
  $modActive = [bool]$r.ModActive
  if (-not $r.XenotypePrices) { continue }
  foreach ($xp in $r.XenotypePrices.PSObject.Properties) {
    $xeno = Js-Escape $xp.Name
    $price = [double]$xp.Value
    $xEnabled = $false
    if ($r.EnabledXenotypes -and ($r.EnabledXenotypes.PSObject.Properties.Name -contains $xp.Name)) {
      $xEnabled = [bool]$r.EnabledXenotypes.($xp.Name)
    }
    $row = "[`"$display`",`"$raceDef`",`"$xeno`",$price,$(Js-Bool $xEnabled),$(Js-Bool $raceEnabled),$(Js-Bool $modActive)]"
    [void]$xenoRows.Add($row)
  }
}
$xenoJs = "const XENOTYPES = [`n" + ($xenoRows -join ",`n") + "`n];`n"
Write-Utf8NoBom (Join-Path $root "docs\xenotypes-data.js") $xenoJs

# --- Incidents ---
# Row: [label, defName, category, baseCost, karmaType, eventCap, enabled, mod, modActive, isRaid, isDisease, isQuest, isWeatherIncident, availableForCommands]
$incidents = Get-Content -Raw (Join-Path $root "Incidents.json") | ConvertFrom-Json
$incidentRows = New-Object System.Collections.Generic.List[string]
foreach ($p in $incidents.PSObject.Properties) {
  $i = $p.Value
  $label = Js-Escape ([string]$i.Label)
  $def = Js-Escape ([string]$i.DefName)
  $cat = Js-Escape ([string]$i.CategoryName)
  $karma = Js-Escape ([string]$i.KarmaType)
  $mod = Js-Escape ([string]$i.ModSource)
  $cost = [int]$i.BaseCost
  $cap = [int]$i.EventCap
  $row = "[`"$label`",`"$def`",`"$cat`",$cost,`"$karma`",$cap,$(Js-Bool $i.Enabled),`"$mod`",$(Js-Bool $i.modactive),$(Js-Bool $i.IsRaidIncident),$(Js-Bool $i.IsDiseaseIncident),$(Js-Bool $i.IsQuestIncident),$(Js-Bool $i.IsWeatherIncident),$(Js-Bool $i.IsAvailableForCommands)]"
  [void]$incidentRows.Add($row)
}
$incidentsJs = "const INCIDENTS = [`n" + ($incidentRows -join ",`n") + "`n];`n"
Write-Utf8NoBom (Join-Path $root "docs\incidents-data.js") $incidentsJs

# --- Weather ---
# Row: [label, defName, baseCost, karmaType, eventCap, enabled, mod, modActive]
$weather = Get-Content -Raw (Join-Path $root "Weather.json") | ConvertFrom-Json
$weatherRows = New-Object System.Collections.Generic.List[string]
foreach ($p in $weather.PSObject.Properties) {
  $w = $p.Value
  $label = Js-Escape ([string]$w.Label)
  $def = Js-Escape ([string]$w.DefName)
  $karma = Js-Escape ([string]$w.KarmaType)
  $mod = Js-Escape ([string]$w.ModSource)
  $cost = [int]$w.BaseCost
  $cap = [int]$w.EventCap
  $row = "[`"$label`",`"$def`",$cost,`"$karma`",$cap,$(Js-Bool $w.Enabled),`"$mod`",$(Js-Bool $w.modactive)]"
  [void]$weatherRows.Add($row)
}
$weatherJs = "const WEATHER = [`n" + ($weatherRows -join ",`n") + "`n];`n"
Write-Utf8NoBom (Join-Path $root "docs\weather-data.js") $weatherJs

# --- Backstories (read-only catalog from Backstories.json) ---
# Row: [title, defName, slot, titleShort, skillsJoined, workDisablesJoined, categoriesJoined, shuffleable, mod, description]
$backstoryPath = Join-Path $root "Backstories.json"
if (Test-Path $backstoryPath) {
  $backstories = Get-Content -Raw $backstoryPath | ConvertFrom-Json
  $bsRows = New-Object System.Collections.Generic.List[string]
  $items = $backstories.items
  foreach ($p in $items.PSObject.Properties) {
    $b = $p.Value
    $title = Js-Escape ([string]$b.Title)
    $def = Js-Escape ([string]$b.DefName)
    $slot = Js-Escape ([string]$b.Slot)
    $short = Js-Escape ([string]$b.TitleShort)
    $skills = Js-Escape ([string]$b.SkillGainsJoined)
    $work = Js-Escape ((@($b.WorkDisables) | Where-Object { $_ }) -join ", ")
    $cats = Js-Escape ((@($b.SpawnCategories) | Where-Object { $_ }) -join ", ")
    $mod = Js-Escape ([string]$b.ModSource)
    $desc = Js-Escape ([string]$b.Description)
    $row = "[`"$title`",`"$def`",`"$slot`",`"$short`",`"$skills`",`"$work`",`"$cats`",$(Js-Bool $b.Shuffleable),`"$mod`",`"$desc`"]"
    [void]$bsRows.Add($row)
  }
  $bsJs = "const BACKSTORIES = [`n" + ($bsRows -join ",`n") + "`n];`n"
  Write-Utf8NoBom (Join-Path $root "docs\backstories-data.js") $bsJs
  Write-Host ("Wrote docs/backstories-data.js ({0} backstories)" -f $bsRows.Count)
} else {
  Write-Host "Skip backstories-data.js (Backstories.json not found - run scripts/export-backstories.ps1)"
}

Write-Host ("Wrote docs/traits-data.js ({0} traits)" -f $traitRows.Count)
Write-Host ("Wrote docs/xenotypes-data.js ({0} xenotype entries)" -f $xenoRows.Count)
Write-Host ("Wrote docs/incidents-data.js ({0} incidents)" -f $incidentRows.Count)
Write-Host ("Wrote docs/weather-data.js ({0} weather types)" -f $weatherRows.Count)
