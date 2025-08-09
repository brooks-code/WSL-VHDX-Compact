<# .SYNOPSIS Compact a WSL2 ext4.vhdx the automated way.
.AUTHOR 41°41′N 70°12′W
.DESCRIPTION

1. Enumerates installed WSL2 distros via wsl.exe.
2. If more than one, prompts you to pick one.
3. Reads the distro's BasePath and uses its virtual disk path.
4. Shuts down WSL and compacts ext4.vhdx (with DISKPART).

.NOTES Must run as Administrator and ignore execution policy (see below).
.USAGE Go to the script directory and, as admin, in cmd or powershell run: 
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wsl_compactor.ps1 #>

[CmdletBinding()]
param()

function Throw-And-Exit {
    param([string]$Message)
    Write-Error $Message
    Exit 1
}


#------------------------------------------------------------
# Step 1 – Enumerate distros from the registry
#------------------------------------------------------------
$lxssKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'

# Grab all subkeys that have a DistributionName value
$distros = Get-ChildItem $lxssKey |
           ForEach-Object {
             $props = Get-ItemProperty $_.PSPath
             [PSCustomObject]@{
               Name     = $props.DistributionName
               BasePath = $props.BasePath
             }
           }

if ($distros.Count -eq 0) {
  Throw-And-Exit "No WSL distros found in the registry."
}


#------------------------------------------------------------
# Step 2 – If >1 distro, show a menu; else auto-select the only one
#------------------------------------------------------------
if ($distros.Count -gt 1) {
  Write-Host "Multiple distros detected. Please choose one to compact:`n" -ForegroundColor Cyan

  for ($i = 0; $i -lt $distros.Count; $i++) {
    $nr = $i + 1
    Write-Host "[$nr] $($distros[$i].Name)"
  }

  do {
    $choice = Read-Host "`nEnter the number (1-$($distros.Count)) of the distro to compact"
    $valid  = ($choice -as [int]) -and 
              ($choice -ge 1) -and 
              ($choice -le $distros.Count)
    if (-not $valid) {
      Write-Warning "Please enter a valid integer between 1 and $($distros.Count)."
    }
  } until ($valid)

  # zero-based index
  $selected = $distros[[int]$choice - 1]
}
else {
  # only one distro installed → pick it
  $selected = $distros[0]
}

$distro   = $selected.Name
$basePath = $selected.BasePath

Write-Host "`nSelected distro: $distro" -ForegroundColor DarkYellow
Write-Host "BasePath: $basePath"

if (-not (Test-Path $basePath)) {
  Throw-And-Exit "BasePath '$basePath' does not exist on disk."
}


#------------------------------------------------------------
# Step 3 – Locate the ext4.vhdx
#------------------------------------------------------------
$possible = @(
  Join-Path $basePath 'ext4.vhdx'
  Join-Path $basePath 'LocalState\ext4.vhdx'
)
$vhdx = $possible | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $vhdx) {
  Throw-And-Exit "No ext4.vhdx found under '$basePath' or 'LocalState'."
}
# Confirmation prompt

Write-Host "`nAbout to compact this WSL distro:" -ForegroundColor Magenta
Write-Host "  Distro   : $distro"
Write-Host "  BasePath : $basePath"
Write-Host "  VHDX file: $vhdx`n"

# Color trick
# Print the question in yellow without a newline
Write-Host "Are you sure you want to proceed? (Y/N) " -ForegroundColor DarkCyan -NoNewline

# Then read the response
$answer = Read-Host
if ($answer.ToUpper() -ne 'Y') {
  Write-Warning "Operation canceled"
  exit
}


#------------------------------------------------------------
# Step 4 – Shutdown WSL & Compact
#------------------------------------------------------------
Write-Host "Shutting down WSL..." -ForegroundColor Cyan
wsl.exe --shutdown
if ($LASTEXITCODE -ne 0) {
  Throw-And-Exit "Failed to shut down WSL. Are you running as Administrator?"
}

# Build and run diskpart script
$dpScript = @"
select vdisk file="$vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@

$tempFile = [IO.Path]::GetTempFileName()
Set-Content -LiteralPath $tempFile -Value $dpScript -Encoding ASCII

Write-Host "Running DiskPart to compact the VHDX. Be patient, this might take a while..." -ForegroundColor Cyan

# Avoids to print too many same lines
# Keep track of the last % we printed
$lastPct = -1

diskpart /s $tempFile | ForEach-Object {
  # Does this line look like "20 percent completed"? 
  if ($_ -match '(\d+)\s+percent') {
    $pct = [int]$Matches[1]
    if ($pct -ne $lastPct) {
      Write-Host "$pct% completed"
      $lastPct = $pct
    }
  }
  else {
    # non‐percent lines we print verbatim
    if ($_ -match '\S') {
      Write-Host $_
    }
  }
}

# Clean up
Remove-Item $tempFile -ErrorAction SilentlyContinue
