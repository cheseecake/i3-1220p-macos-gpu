# Intel UHD Graphics (i3-1220P) on macOS Tahoe — NootedGreen driver port

Kernel + user-space graphics driver for the **Intel UHD Graphics of the Core i3-1220P (Alder Lake-P, 64 EU, 8086:46B3)** on **macOS Tahoe 26.7.1 (25G241)**.

There is no Apple driver for Alder Lake. This project runs **Apple's own driver for Tiger Lake Iris Xe** (GPUDriversIntel 16.0.32, written for Macs that never shipped) on the newer GPU. Both GPUs share the Xe-LP (Gen12) architecture. A modified **NootedGreen** Lilu plugin bridges the generation gap in the kernel, and a set of user-space patches bridges the gap between that 2020-era driver and Tahoe's Metal stack.

> ⚠️ **Experimental.** Expect occasional GPU hangs and kernel panics. Keep a second bootable disk around. Read [docs/STATUS.md](docs/STATUS.md) before you start.
>
> 🔧 **EFI is not shipped.** This is a driver project, not an OpenCore distribution. You bring your own EFI: OpenCore + **WhateverGreen** handles the Tiger Lake device-id spoof (`device-id=9A49`, `AAPL,ig-platform-id=0x9A490000`) and frame-buffer setup. See [docs/PORT-I3-1220P.md](docs/PORT-I3-1220P.md) for the exact DeviceProperties and boot-args.

---

## What this repo is

| Piece | Provided here? | What it does |
|---|---|---|
| **NootedGreen.kext** (Lilu plugin) | ✅ `src/NootedGreen/` | kernel patches: display engine 13, GuC-less scheduler, IOSurface/Tahoe layout, GT topology for 64 EU, GPU frequency |
| **macos/ user-space stack** | ✅ `macos/` | patched TGL Metal driver, `libxedrv` adapter, shader compiler — required for Metal acceleration |
| **tools/** | ✅ `tools/` | `xe-res` (resolution/DPI), `xe-brilho` (brightness), XeShim/xectl, diagnostics |
| **EFI / OpenCore / ACPI / other kexts** | ❌ | your own — WhateverGreen does the device-id spoof + ig-platform-id |

The kext **boots and lights the panel on its own** (compositor-only, no Metal). **Metal/GPU acceleration requires the `macos/` user-space stack** built and installed on top — see [Dependencies](docs/PORT-I3-1220P.md#dependencies-what-the-kext-needs-but-you-do-not-port-here).

## What works (GPU)

| Area | Status |
|---|---|
| Desktop, Dock, windows, blur | ✅ GPU-accelerated through Metal (with `macos/` stack) |
| GPU clock | ✅ 1100 MHz floor while busy (`ngreengtfreq`), idles in RC6 — equals the i3-1220P's RP0 |
| HEIC / YUV images (wallpapers, photos) | ✅ |
| App/Finder icons, thumbnails | ✅ |
| YouTube | ✅ in Chrome with GPU compositing off · ❌ Safari |
| Hardware video decode (H.264/HEVC) | ❌ disabled on purpose, decoded on the CPU |
| System Settings › Displays | ⚠️ may panic, change resolution with `tools/xe-res` |
| Long sessions | ⚠️ occasional GPU hang → WindowServer watchdog reboot |

Everything else about the laptop (Wi-Fi, Bluetooth, keyboard/trackpad/touchscreen, NVMe, battery) is a regular OpenCore setup in **your own EFI** — out of scope here.

## Build the kext

You do **not** need a Mac to build the kext — it builds on GitHub.

### Option A — GitHub Actions (no Mac needed)

Push to `main` or `port-i3-1220p` (or run the workflow manually from the Actions tab). The [build-kext](.github/workflows/build-kext.yml) workflow compiles `src/NootedGreen` on a macOS runner and publishes to **[Releases](../../releases)** — tag `v*` → that tag's release; any other run → a `build-<run number>` prerelease. Each release carries `NootedGreen.kext.zip` and the full `IrisXe-i3-1220P-tahoe.zip` installer. There are no Actions artifacts.

### Option B — local build (Command Line Tools only, on any Mac)

```sh
xcode-select --install          # once
zsh build-nootedgreen.sh        # -> build/NootedGreen.kext
```

`build-nootedgreen.sh` fetches MacKernelSDK + Lilu (DEBUG) and compiles with `clang -mkernel`. Output: `build/NootedGreen.kext`. Verify with `kmutil load -p build/NootedGreen.kext`, `codesign -dv`, `file` — see [docs/PORT-I3-1220P.md](docs/PORT-I3-1220P.md#verify-the-built-kext).

This kext cannot be built on Windows/Linux (needs `clang -mkernel`, MacKernelSDK, Mach-O `codesign`).

## Full acceleration stack (Metal)

The kext alone is compositor-only. Two ways to get Metal:

**No build (recommended)** — download `IrisXe-i3-1220P-tahoe.zip` from [Releases](../../releases), unzip, and
double-click `install.command` on the i3-1220P Hackintosh. It asks for your password, removes any previous
install, then copies the prebuilt stack into place. Nothing is compiled and no Xcode is needed. Put the
package's `NootedGreen.kext` in your EFI's `OC/Kexts/`, reboot.

**From source** — build and install the user-space stack on the i3-1220P Hackintosh itself:

```sh
zsh install.sh                  # checks, fetches Apple's 16.0.32 TGL bundles via NootedGreen, builds, installs
```

Then copy `build/NootedGreen.kext` into your EFI's `OC/Kexts/` (this repo's kext replaces the one `install.sh` built), approve the extension if asked, and reboot. `zsh install.sh --check` runs only the checks; `zsh install.sh --uninstall` removes the stack.

Either way, upgrading later is the same two moves: replace `NootedGreen.kext` in your EFI, re-run the installer (it clears the old install first), reboot.

Prerequisites your EFI must already provide: device-id `0x9A49`, `AAPL,ig-platform-id=0x9A490000`, and the boot-args listed in [docs/PORT-I3-1220P.md](docs/PORT-I3-1220P.md#efi-prerequisites-you-set-these-not-ported).

## Repository layout

```
src/NootedGreen/         the modified NootedGreen source (Lilu plugin), ported to 64 EU / 8 subslices
build-nootedgreen.sh     builds src/NootedGreen with only the Command Line Tools
.github/workflows/       CI: builds the kext + Metal stack on a macOS runner, publishes to Releases
patches/                 diff of this fork against upstream NootedGreen 95f8189
macos/                   user-space stack: Metal driver patcher, libxedrv, shader compiler, installer
tools/                   xe-res (resolution/DPI), xe-brilho (brightness), XeShim + xectl, diagnostics/
docs/                    port guide, patch catalogs, status, debugging notes
```

Documentation: [PORT-I3-1220P](docs/PORT-I3-1220P.md) · [INSTALL](docs/INSTALL.md) · [STATUS](docs/STATUS.md) ·
[KERNEL-PATCHES](docs/KERNEL-PATCHES.md) · [METAL](docs/METAL.md) · [DEBUGGING](docs/DEBUGGING.md) ·
[HISTORY](docs/HISTORY.md) · [EXPERIMENTS](docs/EXPERIMENTS.md) · [CATALOG](docs/CATALOG.md)

## Porting notes (i3-1220P)

This branch changes **only GT topology** relative to the upstream RPL-P 96-EU fork: `NumSubSlices` 12 → 8 (4 DSS × 2 = 8 SS, 64 EU). Everything else — the 9A49 device-id spoof, `isRealTGL` (ADL-P = 0x9A → spoofed path), display engine 13, the ADL-P DMC blob, ADL-P DP link training, and the XE-GTFREQ frequency floor (1100 = the i3-1220P's RP0) — is generation-agnostic or already ADL-P-aware. Topology is overridable via `ngreensubslices`/`ngreenmaxeu`/`ngreenl3banks` boot-args. Full classification table and UNVERIFIED items in [docs/PORT-I3-1220P.md](docs/PORT-I3-1220P.md).

## Credits

- **NootedGreen** by StezzaPilot ([sgiammori/NootedGreen](https://github.com/sgiammori/NootedGreen)): the base of the kernel plugin and the source of the 16.0.32 driver bundles. Licensed under the *Thou Shalt Not Profit License 1.0*, which also covers the fork in `src/`.
- **WhateverXe** and **OpenCore Legacy Patcher fork** by b00t0x: reference for Gen12 on macOS.
- **IntelIGPU-Tahoe**: reference for running the TGL Metal driver on Tahoe.
- **acidanthera** (OpenCore, Lilu, WhateverGreen, VirtualSMC, MacKernelSDK), **VoodooI2C**.

## License

[Thou Shalt Not Profit License 1.0](LICENSE), the license of NootedGreen, which this project derives from. No Apple binaries are included in this repo: see [NOTICE.md](NOTICE.md).
