<#
.SYNOPSIS
  Compact a WSL2 ext4.vhdx the automated way.

.AUTHOR
  41°41′N 70°12′W

.DESCRIPTION
  1. Enumerates installed WSL2 distros via registry.
  2. If -DistroName is supplied, uses it directly.
  3. Otherwise, prompts you to pick one if more than one exists.
  4. Resolves the distro BasePath from the registry.
  5. Trims free space inside WSL.
  6. Shuts down WSL and compacts ext4.vhdx using Optimize-VHD.
  7. Falls back to diskpart if Optimize-VHD is unavailable or fails.

.NOTES
  Must run as Administrator.
  On Windows Pro with Hyper-V, Optimize-VHD is preferred.
  On systems without the Hyper-V module, diskpart is used as fallback.

.USAGE
In an elevated terminal.

  Interactive:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wsl_compactor.ps1

  Non-interactive:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wsl_compactor.ps1 -DistroName Ubuntu
#>

[CmdletBinding()]
param(
  [string]$DistroName
)

#------------------------------------------------------------
# Step 0 - Admin check
#------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
  throw "This script must be run as Administrator."
}

#------------------------------------------------------------
# Step 1 - Enumerate distros from the registry
#------------------------------------------------------------
$lxssKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'

# Grab all subkeys that have a DistributionName value
$distros = Get-ChildItem $lxssKey |
           ForEach-Object {
             $props = Get-ItemProperty $_.PSPath
             [PSCustomObject]@{
               Name        = $props.DistributionName
               BasePath    = $props.BasePath
               VhdFileName = $props.VhdFileName
               WSLVer      = $props.Version
             }
           }

if ($distros.Count -eq 0) {
  throw "No WSL distros found in the registry."
}

#------------------------------------------------------------
# Step 2 - Select distro
#------------------------------------------------------------
if ($DistroName) {
  $selected = $distros | Where-Object { $_.Name -ieq $DistroName } | Select-Object -First 1
  if (-not $selected) {
    $available = ($distros | Select-Object -ExpandProperty Name) -join ', '
    throw "Distro '$DistroName' was not found. Available distros: $available"
  }
}
elseif ($distros.Count -gt 1) {
  Write-Host "Multiple distros detected. Please choose one to compact:`n" -ForegroundColor Cyan
  for ($i = 0; $i -lt $distros.Count; $i++) {
    Write-Host ("[{0}] {1} (WSL{2})" -f ($i + 1), $distros[$i].Name, $distros[$i].WSLVer)
  }

  do {
    $choice = Read-Host "`nEnter the number (1-$($distros.Count)) of the distro to compact"
    $valid = ($choice -as [int]) -and ($choice -ge 1) -and ($choice -le $distros.Count)
    if (-not $valid) {
      Write-Warning "Please enter a valid integer between 1 and $($distros.Count)."
    }
  } until ($valid)

  $selected = $distros[[int]$choice - 1]
}
else {
  $selected = $distros[$distros.Count - 1]
}

$distro = $selected.Name

#------------------------------------------------------------
# Step 3 - Resolve BasePath from selected Distro
#------------------------------------------------------------
$basePath = $selected.BasePath
if ($basePath -like '\\?\*') { $basePath = $basePath.Substring(4) }

Write-Host "`nSelected distro: $distro" -ForegroundColor DarkYellow
Write-Host "BasePath: $basePath"

if (-not (Test-Path -LiteralPath $basePath)) {
  throw "BasePath '$basePath' does not exist on disk."
}

#------------------------------------------------------------
# Step 4 - Locate vhdx file
#------------------------------------------------------------
if ($selected.VhdFileName) {
  $candidate = Join-Path $basePath $selected.VhdFileName
  if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    $vhdx = $candidate
  }
}

if (-not $vhdx) {
  if ((Test-Path -LiteralPath $basePath -PathType Leaf) -and $basePath -match '\.vhdx$') {
    $vhdx = $basePath
  }
  else {
    $vhdx = @(
      Join-Path $basePath 'ext4.vhdx'
      Join-Path $basePath 'LocalState\ext4.vhdx'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $vhdx) {
      $vhdx = Get-ChildItem -LiteralPath $basePath -Filter '*.vhdx' -File -ErrorAction SilentlyContinue |
              Sort-Object Length -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
  }
}
if (-not $vhdx) {
  throw "No .vhdx file found at or under '$basePath'."
}

Write-Host "`nAbout to compact this WSL distro:" -ForegroundColor Magenta
Write-Host "  Distro   : $distro"
Write-Host "  BasePath : $basePath"
Write-Host "  VHDX file: $vhdx`n"

$prev_size = (Get-Item $vhdx).Length

if (-not $DistroName) {
  Write-Host "Are you sure you want to proceed? (Y/N)".Trim() -ForegroundColor DarkCyan -NoNewline
  $answer = Read-Host
  if ($answer.ToUpper() -ne 'Y') {
    Write-Warning "Operation canceled."
    exit
  }
}
else {
  Write-Host "'-DistroName' was supplied : Non-interactive mode enabled" -ForegroundColor Gray
}

#------------------------------------------------------------
# Step 5 - Optional fstrim
#------------------------------------------------------------
Write-Host "Preparation: logical cleanup with fstrim to discard unused blocks..." -ForegroundColor Cyan
& wsl.exe -d "$distro" -u root -- fstrim -av
if ($LASTEXITCODE -ne 0) {
  Write-Warning "fstrim returned a non-zero exit code. Continuing anyway."
}

#------------------------------------------------------------
# Step 6 - Shutdown WSL
#------------------------------------------------------------
Write-Host "Shutting down WSL..." -ForegroundColor Cyan
& wsl.exe --shutdown
if ($LASTEXITCODE -ne 0) {
  throw "Failed to shut down WSL."
}

#------------------------------------------------------------
# Step 7 - Hyper-V Optimize-VHD first, fallback to diskpart
#------------------------------------------------------------
$optimized = $false
$hypervAvailable = $false

try {
  Import-Module Hyper-V -ErrorAction Stop
  $hypervAvailable = $true
}
catch {
  $hypervAvailable = $false
}

if ($hypervAvailable) {
  try {
    Write-Host "Compacting: optimizing VHDX using Hyper-V Optimize-VHD..." -ForegroundColor Cyan
    Write-Host "This might take a while." -ForegroundColor Gray
    Optimize-VHD -Path $vhdx -Mode Full -ErrorAction Stop
    $optimized = $true
  }
  catch {
    Write-Warning "Optimize-VHD failed. Falling back to diskpart."
  }
}
else {
  Write-Warning "Hyper-V module is not available. Compacting with diskpart."
}

if (-not $optimized) {
  $dpScript = @"
select vdisk file="$vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@

  $tempFile = [IO.Path]::GetTempFileName()
  Set-Content -LiteralPath $tempFile -Value $dpScript -Encoding ASCII

  Write-Host "Running DiskPart to compact the VHDX..." -ForegroundColor Cyan
  $lastPct = -1

  try {
    & diskpart /s $tempFile | ForEach-Object {
        if ($_ -match '(\d+)\s+percent') {  
            $pct = [int]$Matches[1]
        if ($pct -ne $lastPct) {
          Write-Host "$pct% completed"
          $lastPct = $pct
        }
      }
      elseif ($_ -match '\S') {
        Write-Host $_
      }
    }
    $optimized = $true
  }
  finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
  }
}

#------------------------------------------------------------
# Step 8 – Report result
#------------------------------------------------------------
$current_size = (Get-Item $vhdx).Length
$savedBytes = $prev_size - $current_size

Write-Host ("Previous VHDX size: {0:N0} bytes ({1:N2} GB)" -f $prev_size, ($prev_size / 1GB)) -ForegroundColor Gray
Write-Host ("Current VHDX size: {0:N0} bytes ({1:N2} GB)" -f $current_size, ($current_size / 1GB)) -ForegroundColor Gray
Write-Host ("Saved: {0:N0} bytes ({1:N2} GB)" -f $savedBytes, ($savedBytes / 1GB)) -ForegroundColor Green

if ($optimized) {
  Write-Host "Done." -ForegroundColor Green
}
else {
  Write-Warning "The compaction step did not complete successfully."
}
