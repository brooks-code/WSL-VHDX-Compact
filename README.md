# WSL2 ext4.vhdx compactor

**♫ Garbage - Only Happy When It Rains (1995) ♪**

![Banner Image](</img/compactor.png> "A custom tshirt with a mysterious teaser message").<br>*Declutter your WSL - the easy way. (Photograph by Gerald Herbert/AP)*

## Description

This PowerShell script automates the process of compacting WSL2 `ext4.vhdx` files, which can help free up **a lot** of disk space on your Windows system.

## Learning

>[!NOTE]
> The [initial release](https://github.com/hyperphantasia/WSL-VHDX-Compact/blob/c5c2e346ab0dd1a8dbc6130f8d372af8022ddd60/wsl_compactor.ps1) is the subject of a tutorial designed as a practical introduction to PowerShell. It is available on [fCC News](https://www.freecodecamp.org/news/how-to-free-up-and-automatically-manage-disk-space-for-wsl-on-windows-1011/).

## Table of contents

<details>
<summary>Contents - click to expand</summary>

- [WSL2 ext4.vhdx compactor](#wsl2-ext4vhdx-compactor)
  - [Description](#description)
  - [Learning](#learning)
  - [Table of contents](#table-of-contents)
  - [Why?](#why)
    - [The big issue](#the-big-issue)
  - [The Windows .exe](#the-windows-exe)
  - [Benefits](#benefits)
  - [Requirements](#requirements)
  - [Usage](#usage)
    - [The executable](#the-executable)
    - [PowerShell gallery](#powershell-gallery)
  - [Algorithm](#algorithm)
  - [Notes](#notes)
    - [Exit codes \& errors](#exit-codes--errors)
    - [Misc](#misc)
  - [Compatibility](#compatibility)
  - [Changelog](#changelog)
    - [v1.1.1 (May 2026) - latest](#v111-may-2026---latest)
    - [v1.1 (April/May 2026)](#v11-aprilmay-2026)
    - [v1.0 (August 2025)](#v10-august-2025)
  - [Contributing](#contributing)
  - [License](#license)

</details>

## Why?

Windows Subsystem for Linux (WSL 2) uses a virtualization platform to install Linux distributions alongside the host Windows operating system. For that, it creates a Virtual Hard Disk (VHD) to store files for each of the Linux distributions that you install. These VHDs use the ext4 file system type and are represented on your Windows hard drive as an `ext4.vhdx` file.

WSL 2 automatically resizes these VHD files to meet storage needs. This means that the VHD file starts small and grows as needed. Initially, it may only take up a few gigabytes, but as you install applications and create files within your Linux environment, the VHD expands to accommodate the additional data.

### The big issue

>[!NOTE]
>When you delete files or uninstall applications, **the VHD does not automatically shrink**.

This is a bit problematic, especially when you deal with a lot of data and dependencies in your workflow (data science..). Furthermore, the process of regaining the lost space is a bit cumbersome.

>[!TIP]
>It's probably a matter of time before the issue is solved. Microsoft rolled out some new experimental features dealing with that, but careful, some users testing it have complained about data loss.
> More about this on [superuser](https://superuser.com/questions/1606213/how-do-i-get-back-unused-disk-space-from-ubuntu-on-wsl2#1612289).

Until then you are free to use this script :)

## The Windows .exe

WSL-VHDX-Compact is now also a Windows executable! Check the [release](https://github.com/hyperphantasia/WSL-VHDX-Compact/releases/tag/v1.0.1) section. Reclaiming disk space has never been so easy :)
The binary has been compiled with [PS2Exe](https://github.com/MScholtes/PS2EXE), and yes, since **you don't know me** (and you will be prompted to run a powershell script with elevated rights), be rigorous and check what the *.exe* contains. After installing PS2Exe like this:

```powershell
Install-Module -Name ps2exe -Scope CurrentUser
```

You can unpack the `.exe` :

```powershell
Import-Module ps2exe
Invoke-PS2EXE -extract .\wsl2compact.exe -OutPath .\extracted
```

And then inspect its content :)

The only difference with [wsl_compactor.ps1](https://github.com/hyperphantasia/WSL-VHDX-Compact/blob/main/wsl_compactor.ps1) script should be the two lines added at the end (to keep the terminal screen active and exit on user input).

```powershell
Write-Host "`nPress any key to exit..." -ForegroundColor DarkCyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
```

## Benefits

- **Storage efficiency**: helps recover unused space in WSL2 distributions without hassle.
- **Fast and universal**: prefers `Optimize‑VHD` on Hyper‑V systems (faster, more robust), with a `diskpart` fallback for broader compatibility.
- **Automation-friendly**: no need to manually locate and compact the `ext4.vhdx file`! Possibility to pass the distro name as an argument.
- **User-friendly**: simple interface with basic reporting.

## Requirements

- **Administrator privileges**: the script needs to be run with administrative rights.
- **PowerShell**: make sure you have PowerShell installed on your system (by default on Windows 10/11).
- **WSL2**: this script is designed only for WSL2 distributions.

## Usage

To run the script, follow these steps:

1. Download or clone this repository.
2. Open Command Prompt or PowerShell **as an administrator**.
3. Navigate to the directory containing the `wsl_compactor.ps1` file.
4. Execute the script with the following  command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wsl_compactor.ps1
```

Non-interactive mode:

>[!TIP]
> You can list the distros available from your system with:

```powershell
wsl.exe --list
```

When `-DistroName` is supplied the script runs without confirmation prompt.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\wsl_compactor.ps1 -DistroName Ubuntu
```

### The executable

Easy! Just click (you will be prompted for an Admin elevation). See the [section above](https://github.com/hyperphantasia/WSL-VHDX-Compact#the-windows-exe) and the [release](https://github.com/hyperphantasia/WSL-VHDX-Compact/releases/tag/v1.0.1) section. 

### PowerShell gallery

The script is also available in the [PowerShell gallery](https://www.powershellgallery.com/packages/wsl2compact/1.0.5). This can simplify automation tasks.
It is advised to use at least PowerShell 5.1 In an elevated PowerShell terminal (run as Administrator). 

Make sure `PowerShellGet` and and `PackageManagement` are available on the system:

```powershell
Install-Module -Name PowerShellGet -Force -AllowClobber
Install-Module -Name PackageManagement -Force -AllowClobber
```

>[!NOTE]
> You might also be prompted to install NuGet.

Installation:

```powershell
Install-Script -Name wsl2compact
```

>[!TIP]
> You can install system-wide by appending the following argument `-Scope AllUsers` (by default the scope is `CurrentUser`) to the installation comand.
>
> If you get an ExecutionPolicy warning, you can precede the installation command and run PowerShell with `powershell.exe -NoProfile -ExecutionPolicy Bypass` or set a temporary policy `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force`

Run the script:

>[!NOTE]
> `Get-Command wsl2compact` helps you locate the script on your system.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $((Get-Command wsl2compact).Source)
```

or optionally, specify a `-DistroName` to run in non-interactive mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $((Get-Command wsl2compact).Source)
 -DistroName Ubuntu
```

## Algorithm

The script performs the following actions:

1. Verifies Administrator privileges.
2. Enumerates installed WSL2 distributions (from the registry).
3. Selects a distribution (via `-DistroName`, interactive menu if multiple, or the single installed distro).
4. Identifies the base path and locates the `ext4.vhdx` file.
5. Runs `fstrim` inside the distro to discard unused blocks.
6. Shuts down WSL.
7. Attempts to compact using Hyper‑V `Optimize-VHD -Mode Full`; if Hyper‑V is unavailable or `Optimize‑VHD` fails, falls back to the `diskpart` method.
8. Reports previous size, current size, and saved disk space.

## Notes

### Exit codes & errors

- The script throws errors on missing admin rights, missing registry entries, missing ext4.vhdx file, or failed WSL shutdown.
- When `fstrim` fails it logs a warning and continues.

### Misc

- If multiple distributions are installed, you'll be prompted to select one.
- In **interactive mode** (no `-DistroName` argument passed) The script will confirm the selected distribution before proceeding with compaction.
- `Optimize‑VHD` is preferred on machines with Hyper‑V (Windows Pro/Enterprise). `diskpart` works on broader editions but may be slower.
- *Be patient*. If there is a lot of compacting ahead, **the script might take a while to execute**.

>[!WARNING]
> As always when dealing with important data: make sure to have backups!

## Compatibility

This script is compatible with Windows systems that have WSL2 installed. It has been tested on Windows 10 and Windows 11.

## Changelog

### v1.1.1 (May 2026) - Latest

- **Bugfixes**: fixed distro enumeration listing and early exit error. [PR#4](https://github.com/hyperphantasia/WSL-VHDX-Compact/pull/4) by @AlexanderDoerr
- **Updated**: [WSL2Compact v1.0.1](https://github.com/hyperphantasia/WSL-VHDX-Compact/releases/tag/v1.0.1) Windows executable.

### v1.1 ( April & May 2026)

- **Added**: prefer `Optimize-VHD` (Hyper‑V module) with automatic fallback to diskpart if Hyper‑V is unavailable or Optimize‑VHD fails [issue#2](https://github.com/hyperphantasia/WSL-VHDX-Compact/issues/2).
- **Added**: `-DistroName` parameter for easier automation.
- **Added**: `fstrim` inside the distro prior to compaction to discard unused blocks [issue#2](https://github.com/hyperphantasia/WSL-VHDX-Compact/issues/2).
- **Added**: more explicit admin check (throws early if not elevated).
- **Added**: reporting of previous/current sizes and bytes saved. [PR#1](https://github.com/hyperphantasia/WSL-VHDX-Compact/pull/1) by @lrotova.
- **Released**: [WSL2Compact v1.0.0](https://github.com/hyperphantasia/WSL-VHDX-Compact/releases/tag/v1.0.0) Windows executable.

### v1.0 (August 2025)

- Initial release.

## Contributing

Contributions are welcome! If you have any improvements or bug fixes, feel free to submit them via GitHub.

## License

Do what you want with the code, this script is released under the [Unlicense](https://unlicense.org/) license.
