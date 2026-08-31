# Generates Vue catalog JSON under web/public/data/:
#   items.json, traits.json, xenotypes.json, incidents.json, weather.json, backstories.json,
#   commands.json, addon-commands.json
# Usage (from repo root): powershell -NoProfile -File scripts/generate-docs-data.ps1
# Backstories.json is produced by: powershell -NoProfile -File scripts/export-backstories.ps1
# Isekai JSON is produced by: powershell -NoProfile -File scripts/generate-isekai-data.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "Traits.json"))) {
  $root = (Get-Location).Path
}

$outDir = Join-Path $root "web\public\data"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Js-Escape([string]$s) {
  if ($null -eq $s) { return "" }
  return ($s -replace "\\", "\\\\" -replace '"', '\"' -replace "`r", "" -replace "`n", "\\n")
}

function Json-Cell($v) {
  if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
  if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) { return "$v" }
  return ('"{0}"' -f (Js-Escape ([string]$v)))
}

function Write-JsonRows([string]$Name, $Rows) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("[")
  $first = $true
  foreach ($row in $Rows) {
    if (-not $first) { [void]$sb.Append(",") }
    $first = $false
    [void]$sb.Append("[")
    $inner = $true
    foreach ($cell in @($row)) {
      if (-not $inner) { [void]$sb.Append(",") }
      $inner = $false
      [void]$sb.Append((Json-Cell $cell))
    }
    [void]$sb.Append("]")
  }
  [void]$sb.Append("]")
  Write-Utf8NoBom (Join-Path $outDir "$Name.json") $sb.ToString()
}

function Normalize-TraitDescription([string]$desc) {
  if ($null -eq $desc) { return "" }
  $desc = $desc -replace "`r", ""
  $desc = $desc.Replace("{PAWN_nameDef}", "This colonist")
  $desc = $desc.Replace("{PAWN_pronoun}", "they")
  $desc = $desc.Replace("{PAWN_possessive}", "their")
  $desc = $desc.Replace("{PAWN_objective}", "them")
  $desc = $desc.Replace("{PAWN_gender}", "")
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
  $desc = $desc -replace "\b\. they\b", ". They"
  return $desc.Trim()
}

# --- Store items ---
$store = Get-Content -Raw (Join-Path $root "StoreItems.json") | ConvertFrom-Json
$itemRows = New-Object System.Collections.Generic.List[object]
foreach ($p in $store.items.PSObject.Properties) {
  $it = $p.Value
  $name = if ($it.CustomName) { [string]$it.CustomName } else { [string]$it.DefName }
  $qty = if ($null -ne $it.QuantityLimit) { [int]$it.QuantityLimit } else { 0 }
  [void]$itemRows.Add(@(
    [string]$it.Category,
    $name,
    [string]$it.DefName,
    [int]$it.BasePrice,
    $qty,
    [int][bool]$it.IsUsable,
    [int][bool]$it.IsEquippable,
    [int][bool]$it.IsWearable,
    [string]$it.Mod,
    [int][bool]$it.Enabled
  ))
}
Write-JsonRows "items" $itemRows
Write-Host ("Wrote web/public/data/items.json ({0} items)" -f $itemRows.Count)

# --- Traits ---
$traits = Get-Content -Raw (Join-Path $root "Traits.json") | ConvertFrom-Json
$traitRows = New-Object System.Collections.Generic.List[object]
foreach ($p in $traits.PSObject.Properties) {
  $t = $p.Value
  $stats = @()
  if ($t.Stats) { $stats = @($t.Stats | ForEach-Object { [string]$_ }) }
  [void]$traitRows.Add(@(
    [string]$t.Name,
    [string]$t.DefName,
    [int]$t.Degree,
    [int]$t.AddPrice,
    [int]$t.RemovePrice,
    [bool]$t.CanAdd,
    [bool]$t.CanRemove,
    [bool]$t.BypassLimit,
    [string]$t.ModSource,
    [bool]$t.modactive,
    ($stats -join "; "),
    (Normalize-TraitDescription ([string]$t.Description))
  ))
}
Write-JsonRows "traits" $traitRows
Write-Host ("Wrote web/public/data/traits.json ({0} traits)" -f $traitRows.Count)

# --- Xenotypes ---
$races = Get-Content -Raw (Join-Path $root "RaceSettings.json") | ConvertFrom-Json
$xenoRows = New-Object System.Collections.Generic.List[object]
foreach ($rp in $races.PSObject.Properties) {
  $r = $rp.Value
  $raceEnabled = [bool]$r.Enabled
  $modActive = [bool]$r.ModActive
  if (-not $r.XenotypePrices) { continue }
  foreach ($xp in $r.XenotypePrices.PSObject.Properties) {
    $xEnabled = $false
    if ($r.EnabledXenotypes -and ($r.EnabledXenotypes.PSObject.Properties.Name -contains $xp.Name)) {
      $xEnabled = [bool]$r.EnabledXenotypes.($xp.Name)
    }
    [void]$xenoRows.Add(@(
      [string]$r.DisplayName,
      [string]$rp.Name,
      [string]$xp.Name,
      [double]$xp.Value,
      [bool]$xEnabled,
      [bool]$raceEnabled,
      [bool]$modActive
    ))
  }
}
Write-JsonRows "xenotypes" $xenoRows
Write-Host ("Wrote web/public/data/xenotypes.json ({0} xenotype entries)" -f $xenoRows.Count)

# --- Incidents ---
$incidents = Get-Content -Raw (Join-Path $root "Incidents.json") | ConvertFrom-Json
$incidentRows = New-Object System.Collections.Generic.List[object]
foreach ($p in $incidents.PSObject.Properties) {
  $i = $p.Value
  [void]$incidentRows.Add(@(
    [string]$i.Label,
    [string]$i.DefName,
    [string]$i.CategoryName,
    [int]$i.BaseCost,
    [string]$i.KarmaType,
    [int]$i.EventCap,
    [bool]$i.Enabled,
    [string]$i.ModSource,
    [bool]$i.modactive,
    [bool]$i.IsRaidIncident,
    [bool]$i.IsDiseaseIncident,
    [bool]$i.IsQuestIncident,
    [bool]$i.IsWeatherIncident,
    [bool]$i.IsAvailableForCommands
  ))
}
Write-JsonRows "incidents" $incidentRows
Write-Host ("Wrote web/public/data/incidents.json ({0} incidents)" -f $incidentRows.Count)

# --- Weather ---
$weather = Get-Content -Raw (Join-Path $root "Weather.json") | ConvertFrom-Json
$weatherRows = New-Object System.Collections.Generic.List[object]
foreach ($p in $weather.PSObject.Properties) {
  $w = $p.Value
  [void]$weatherRows.Add(@(
    [string]$w.Label,
    [string]$w.DefName,
    [int]$w.BaseCost,
    [string]$w.KarmaType,
    [int]$w.EventCap,
    [bool]$w.Enabled,
    [string]$w.ModSource,
    [bool]$w.modactive
  ))
}
Write-JsonRows "weather" $weatherRows
Write-Host ("Wrote web/public/data/weather.json ({0} weather types)" -f $weatherRows.Count)

# --- Backstories ---
$backstoryPath = Join-Path $root "Backstories.json"
if (Test-Path $backstoryPath) {
  $backstories = Get-Content -Raw $backstoryPath | ConvertFrom-Json
  $bsRows = New-Object System.Collections.Generic.List[object]
  foreach ($p in $backstories.items.PSObject.Properties) {
    $b = $p.Value
    $work = ((@($b.WorkDisables) | Where-Object { $_ }) -join ", ")
    $cats = ((@($b.SpawnCategories) | Where-Object { $_ }) -join ", ")
    [void]$bsRows.Add(@(
      [string]$b.Title,
      [string]$b.DefName,
      [string]$b.Slot,
      [string]$b.TitleShort,
      [string]$b.SkillGainsJoined,
      $work,
      $cats,
      [bool]$b.Shuffleable,
      [string]$b.ModSource,
      [string]$b.Description
    ))
  }
  Write-JsonRows "backstories" $bsRows
  Write-Host ("Wrote web/public/data/backstories.json ({0} backstories)" -f $bsRows.Count)
} else {
  Write-Host "Skip backstories.json (Backstories.json not found - run scripts/export-backstories.ps1)"
}

# --- RICS Commands ---
# Row: [key, label, description, permission, cost, cooldown, enabled, supportsCost, alias]
$cmds = Get-Content -Raw (Join-Path $root "CommandSettings.json") | ConvertFrom-Json
$cmdRows = New-Object System.Collections.Generic.List[object]
foreach ($p in $cmds.PSObject.Properties) {
  $c = $p.Value
  [void]$cmdRows.Add(@(
    [string]$p.Name,
    [string]$c.Label,
    [string]$c.CommandDescription,
    [string]$c.PermissionLevel,
    [int]$c.Cost,
    [int]$c.CooldownSeconds,
    [bool]$c.Enabled,
    [bool]$c.SupportsCost,
    [string]$c.CommandAlias
  ))
}
Write-JsonRows "commands" $cmdRows
Write-Host ("Wrote web/public/data/commands.json ({0} commands)" -f $cmdRows.Count)

# --- Addon commands (curated; RICS Addon workshop 3760183125 not always installed locally) ---
# Row: [key, usage, description, integration]
$addonRows = @(
  @("zone", "!zone", "Look and change pawn zones", "General"),
  @("pickup", "!pickup", "Interact with items by picking, using, equipping, wearing and dropping", "General"),
  @("work", "!work", "Force your pawn to work a certain job", "General"),
  @("draft", "!draft", "Draft and undraft your pawn", "General"),
  @("position", "!position", "Save positions for later use with !move", "General"),
  @("move", "!move", "Move your pawn", "General"),
  @("gizmo", "!gizmo", "Activate certain pawn skills/gear (e.g. firefoam poppacks)", "General"),
  @("medpolicy", "!medpolicy", "Change pawn medicine assignment", "General"),
  @("hostility", "!hostility", "Change pawn hostility response (flee, attack, or ignore)", "General"),
  @("attack", "!attack", "Select a pawn to attack", "General"),
  @("sethead", "!sethead", "Change head", "Pawn Customization"),
  @("setbody", "!setbody", "Change body", "Pawn Customization"),
  @("sethair", "!sethair", "Change hair", "Pawn Customization"),
  @("setbeard", "!setbeard", "Change beard", "Pawn Customization"),
  @("dyehair", "!dyehair", "Dye hair", "Pawn Customization"),
  @("settattoo", "!settattoo", "Change tattoos", "Pawn Customization"),
  @("setskin", "!setskin", "Choose skin color", "Pawn Customization"),
  @("setstyle", "!setstyle", "Choose ideology style for gear", "Pawn Customization"),
  @("harcosmetic", "!harcosmetic", "Tweak HAR pawn cosmetics (e.g. horns)", "Pawn Customization"),
  @("geneedit", "!geneedit", "Add genes or change xenotype", "Pawn Customization"),
  @("expertise", "!expertise", "View and choose expertise", "Vanilla Expanded Skills"),
  @("mages", "!mages", "List mages in the colony", "RimWorld of Magic"),
  @("fighters", "!fighters", "List fighters in the colony", "RimWorld of Magic"),
  @("class", "!class", "View your class", "RimWorld of Magic"),
  @("spendpoints", "!spendpoints", "Assign level points to spells and skills", "RimWorld of Magic"),
  @("spells", "!spells", "View your spells and skills", "RimWorld of Magic"),
  @("cast", "!cast", "Cast your spells and skills", "RimWorld of Magic"),
  @("autocast", "!autocast", "Toggle autocasts", "RimWorld of Magic"),
  @("sidearms", "!sidearms", "View, equip, and drop sidearms", "Simple Sidearms"),
  @("isekai", "!isekai", 'View, level stats, and choose aura - e.g. !isekai level "stat" "amount"', "ISEKAI RPG LEVELING"),
  @("constellation", "!constellation", "Choose and level isekai class / path / nodes - unlock -> path -> learn", "ISEKAI RPG LEVELING"),
  @("autocombat", "!autocombat", "Turn Search and Destroy autocombat on/off", "Search and Destroy"),
  @("facialanimation", "!facialanimation", "Change face parts", "NL Facial Animation"),
  @("layered", "!layered", "Manage cosmetic apparel", "Layered Apparel")
)
Write-JsonRows "addon-commands" $addonRows
Write-Host ("Wrote web/public/data/addon-commands.json ({0} addon commands)" -f $addonRows.Count)
