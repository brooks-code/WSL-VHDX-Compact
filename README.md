# WSL2 ext4.vhdx compactor

**♫ Garbage - Only Happy When It Rains (1995) ♪**

![Banner Image](</img/compactor.png> "A custom tshirt with a mysterious teaser message").<br>*Declutter your WSL - the easy way. (Photograph by Gerald Herbert/AP)*

## Description

This PowerShell script automates the process of compacting WSL2 `ext4.vhdx` files, which can help free up **a lot** of disk space on your Windows system.

## Why?

Windows Subsystem for Linux (WSL 2) uses a virtualization platform to install Linux distributions alongside the host Windows operating system. For that, it creates a Virtual Hard Disk (VHD) to store files for each of the Linux distributions that you install. These VHDs use the ext4 file system type and are represented on your Windows hard drive as an `ext4.vhdx` file.

WSL 2 automatically resizes these VHD files to meet storage needs. This means that the VHD file starts small and grows as needed. Initially, it may only take up a few gigabytes, but as you install applications and create files within your Linux environment, the VHD expands to accommodate the additional data.

### The big issue

>[!NOTE]
>When you delete files or uninstall applications, **the VHD does not automatically shrink**.

This is a bit problematic, especially when you deal with a lot of data and dependencies in your workflow (data science..). Furthermore, the process of regaining the lost space is a bit cumbersome.

>[!TIP]
>It's probably a matter of time before the issue is solved. Microsoft rolled out some new experimental features dealing with that, but careful, some users testing it have complained about data loss. More about this on [superuser](https://superuser.com/questions/1606213/how-do-i-get-back-unused-disk-space-from-ubuntu-on-wsl2#1612289).

Until then you can freely use this script :)

## Benefits

- **Storage efficiency**: helps recover unused space in WSL2 distributions without hassle.
- **Automated process**: no need to manually locate and compact the ext4.vhdx file!
- **User-Friendly**: simple interface.

## Requirements

- **Administrator privileges**: the script needs to be run with administrative rights.
- **PowerShell**: ensure you have PowerShell installed on your system (by default on Windows 10/11).
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

## Algorithm

The script performs the following actions:

1. Enumerates installed WSL2 distributions using `wsl.exe`.
2. Prompts you to select a distribution if more than one is installed.
3. Identifies the base path and locates the `ext4.vhdx` file.
4. Shuts down WSL and uses DISKPART to compact the `ext4.vhdx` file.

A comprehensive tutorial is provided on [fCC News](https://www.freecodecamp.org/news/how-to-free-up-and-automatically-manage-disk-space-for-wsl-on-windows-1011/).

## Notes

- If multiple distributions are installed, you'll be prompted to select one.
- The script will confirm the selected distribution before proceeding with the compaction.
- The script will exit with an error message if no WSL2 distributions are found.
- If there is a lot of compacting ahead, **the script might take a while to execute**.

>[!WARNING]
> As always when dealing with important data: make sure to have backups!

## Compatibility

This script is compatible with Windows systems that have WSL2 installed. It has been tested on Windows 10 and Windows 11.

## Contributing

Contributions are welcome! If you have any improvements or bug fixes, feel free to submit them via GitHub.

## License

This script is released under the [Unlicense](https://unlicense.org/) license.

