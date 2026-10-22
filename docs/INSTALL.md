# Installation guide

> **Short path:** `zsh build-nootedgreen.sh` (kext) then `zsh install.sh` (full acceleration stack). This guide is the
> manual procedure behind those scripts. The kext-only port rationale is in [PORT-I3-1220P.md](PORT-I3-1220P.md).

Target: **Intel Core i3-1220P (Alder Lake-P, 64 EU UHD, 8086:46B3)**, **macOS Tahoe 26.7.1 (25G241)**. Other Alder
Lake / Raptor Lake laptops may work with adjusted topology (`ngreensubslices`), but the patches were only tested here.

> 🔧 This repo does **not** ship an EFI. You need your own OpenCore with **WhateverGreen** (or DeviceProperties)
> presenting the iGPU as Tiger Lake: `device-id=0x9A49`, `AAPL,ig-platform-id=0x9A490000`, plus the boot-args in
> [PORT-I3-1220P.md](PORT-I3-1220P.md#efi-prerequisites-you-set-these-not-ported). ACPI, USB map and input devices
> are your own — out of scope here.

## 0. What you need

- A bootable macOS Tahoe 26.7.1 (25G241) install reached through your own EFI (above). Keep a second bootable disk.
- The Command Line Tools: `xcode-select --install`.
- The `sle_Internal/le` and `sle_Internal/sle` folders of [NootedGreen](https://github.com/sgiammori/NootedGreen)
  (Apple's 16.0.32 Tiger Lake driver bundles). `install.sh` fetches these automatically.

## 1. BIOS

Use the usual hackintosh settings (storage in AHCI/NVMe mode, not RAID/VMD; Secure Boot off). Change one setting at a
time and keep a way to boot back.

## 2. EFI (your own)

Set the GPU DeviceProperties on `PciRoot(0x0)/Pci(0x2,0x0)`:

- `device-id` = `0x9A49` (base64 `SZoAAA==`)
- `AAPL,ig-platform-id` = `0x9A490000` (base64 `AABJmg==`)

WhateverGreen can inject these (and apply frame-buffer patches). The NootedGreen kext also enforces the 9A49 read via
its `configRead16/32` hook, so the spoof holds even if a tool reads the PCI config directly.

For a first install / recovery, disable NootedGreen in your `config.plist` (or omit it) and boot verbose — the
installer runs on the firmware framebuffer, without acceleration.

## 3. Install macOS

1. Make a Tahoe 26.7.1 installer: `softwareupdate --fetch-full-installer --full-installer-version 26.7.1`, or download
   `InstallAssistant.pkg` with gibMacOS, then use `createinstallmedia`.
2. Boot your OpenCore with NootedGreen **off** (verbose). The installer runs without acceleration.
3. Install, finish Setup Assistant, then install the Command Line Tools: `xcode-select --install`.

## 4. Kernel side

```sh
zsh build-nootedgreen.sh                 # -> build/NootedGreen.kext
```

(Or download `NootedGreen.kext.zip` from a [build-kext](../.github/workflows/build-kext.yml) workflow run's release — tag `v*` or the `build-<run number>` prerelease.)

Put `build/NootedGreen.kext` in your EFI's `OC/Kexts/` and enable it in your `config.plist` with the boot-args from
[PORT-I3-1220P.md](PORT-I3-1220P.md#efi-prerequisites-you-set-these-not-ported). Verify the topology picked up:

```sh
log show --last 5m --predicate 'eventMessage CONTAINS "ngreen"' | grep -E 'platform|getGPUInfo'
# expect: subslices=8 ... totalEU=64, isRealTGL=0 ... dmcIsAdlp=1
```

## 5. User-space side (Metal acceleration)

```sh
zsh macos/build-all.sh /path/to/sle_Internal/sle
sudo zsh macos/install-macos.sh /path/to/sle_Internal/sle /path/to/sle_Internal/le
```

Approve the extension in **System Settings › Privacy & Security** if asked, and reboot.

## 6. After the first accelerated boot

- Resolution / UI scale: `tools/xe-res` (list) and `tools/xe-res w1680` (HiDPI 1680 pt wide). Avoid
  **System Settings › Displays**.
- Brightness: build `tools/XeShim` (`zsh tools/build-kext.sh XeShim`), load it, then `xe-brilho 70`.
- Check: `system_profiler SPDisplaysDataType` shows **Metal Support** and the chipset model you set.

## Recovery

- Boot your OpenCore with NootedGreen **off** to reach the desktop without acceleration.
- Each kernel patch can be turned off with its boot-arg ([KERNEL-PATCHES.md](KERNEL-PATCHES.md)).
- Remove the user-space pieces: delete `/Library/GPUBundles/AppleIntelTGL*`, `/System/Library/Caches/xe.bundle`
  and the TGL kexts in `/Library/Extensions`, then run `sudo kmutil load -z` again.
