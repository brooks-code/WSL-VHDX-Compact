<#
.SYNOPSIS
Packages a PowerShell script into a self-extracting .exe using the built-in Windows IExpress tool.

.DESCRIPTION
It uses IExpress (bundled with every Windows install) to build a self-extracting archive that, 
when run, extracts the script to a temp folder and immediately launches it via "powershell.exe -File",
forwarding any command-line arguments through to it (-DistroName, -All, etc. all still work). 
This keeps 100% of the script's original behavior, including the interactive menu and Read-Host prompts,
since it's still genuinely running through powershell.exe under the hood 
- IExpress is just acting as the delivery wrapper.

.PARAMETER ScriptPath
Path to the .ps1 file to package.

.PARAMETER OutputPath
Path (including .exe filename) where the packaged executable should be written.

.PARAMETER FriendlyName
Display name embedded in the package. Defaults to the script's base name.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$ScriptPath,

  [Parameter(Mandatory)]
  [string]$OutputPath,

  [string]$FriendlyName
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
  throw "Script not found: $ScriptPath"
}

$ScriptPath  = (Resolve-Path -LiteralPath $ScriptPath).ProviderPath
$scriptName  = Split-Path -Leaf $ScriptPath
if (-not $FriendlyName) { $FriendlyName = [IO.Path]::GetFileNameWithoutExtension($scriptName) }

$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outDir     = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Stage the script in its own clean folder - IExpress packages whatever is in SourceFiles0.
$stageDir = Join-Path ([IO.Path]::GetTempPath()) ("iexpress-stage-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Item -LiteralPath $ScriptPath -Destination (Join-Path $stageDir $scriptName) -Force

$sedPath = Join-Path $stageDir 'package.sed'

# %* forwards through any arguments the user passed to the generated .exe (e.g. -All, -DistroName).
$appLaunched = "cmd.exe /c powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$scriptName`" %*"

$sedContent = @"
[Version]
Class=IEXPRESS
SEDVersion=3

[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles

[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$OutputPath
FriendlyName=$FriendlyName
AppLaunched=$appLaunched
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="$scriptName"

[SourceFiles]
SourceFiles0=$stageDir\

[SourceFiles0]
%FILE0%=
"@

Set-Content -LiteralPath $sedPath -Value $sedContent -Encoding ASCII

Write-Host "Building $OutputPath from $scriptName via IExpress..." -ForegroundColor Cyan
& iexpress.exe /N /Q $sedPath
if ($LASTEXITCODE -ne 0) {
  throw "iexpress.exe failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $OutputPath)) {
  throw "iexpress.exe reported success but '$OutputPath' was not created."
}

Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Created $OutputPath" -ForegroundColor Green
