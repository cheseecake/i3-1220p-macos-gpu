# Changelog

Every change is tested on the real XPS 13 Plus 9320 before it is marked **confirmed**. Status values:
**confirmed** (works on hardware), **testing** (built and installed, being evaluated), **reverted**.
The full story behind each item is in [docs/HISTORY.md](docs/HISTORY.md).

## Unreleased

| Date | Change | Status |
|---|---|---|
| 2026-10-21 | **i3-1220P port**: project reframed as an Alder Lake-P (i3-1220P, 64 EU UHD) driver fork. GT topology NumSubSlices 12→8 at both `f3bbb`/`r3bbb` and `getGPUInfo()`, overridable via `ngreensubslices`/`ngreenmaxeu`/`ngreenl3banks` (defaults = i3-1220P); platform debug SYSLOG. EFI/OpenCore/ACPI/other kexts removed — bring your own (WhateverGreen does the 9A49 spoof). `macos/` + `tools/` kept. New `docs/PORT-I3-1220P.md`; README + INSTALL rewritten | testing |
| 2026-10-21 | **CI build**: `.github/workflows/build-kext.yml` builds `NootedGreen.kext` on a GitHub macOS runner (cross-compiled x86_64) and uploads it as an artifact — no local Mac needed for the kext | confirmed (build path) |
| 2026-10-20 | **Input without polling**: trackpad on a GPIO interrupt, touchscreen on an APIC interrupt; `-vi2c-force-polling` removed. Fixes the intermittent keyboard/trackpad/touchscreen freezes (I2C bus stuck while polling). Three pieces: VoodooGPIO built from current source with Tiger Lake-LP support (`build-voodoogpio.sh`) plus an upstream bug fix (`patches/voodoogpio-tigerlakelp-start.diff`); `SSDT-XPS-I2C` now returns the firmware's own resources (`acpi/SSDT-XPS-I2C.dsl`) | confirmed |
| 2026-10-20 | **XE-FBDPMS**: display sleep only turns the backlight off; the pipe/transcoder/DDI path to the panel is never torn down, so the display wakes again (the TGL framebuffer cannot retrain the eDP link on display 13). Hooks `AppleIntelFramebuffer::setFramebufferPowerState`; `-ngreenfbdpms` disables | confirmed |
| 2026-10-20 | XE-NODPMS (register-write filter for the same problem): broke the framebuffer's own mode sets (spinlock timeout at boot); kept as opt-in `-ngreennodpms` only | reverted |
| 2026-10-20 | `tools/xe-sleep-diag.sh`, `tools/xe-modeset-diag.sh`: display register snapshots around display sleep / mode changes (need XeShim) | — |
| 2026-10-20 | **MTL18**: `mtl17-patches.json` no longer rewrites `0x7ff77`/`0x80253`. The v11 L3 patch had turned two `movb` instructions in `IntelState::IntelState()` into `rolb`/`rorb` | testing |
| 2026-10-20 | `make-efi.sh` (EFI with your own SMBIOS) and `install.sh` (check, fetch, build, install, uninstall) | confirmed (build path) |
| 2026-10-20 | Deep documentation: HISTORY, EXPERIMENTS, CATALOG | — |

## v0.1 — 2026-10-20 (first public snapshot)

| Area | Change | Status |
|---|---|---|
| Kernel | XE-GTFREQ: GPU frequency floor (1100 MHz) — the GPU was stuck at 100 MHz | confirmed |
| Kernel | PLANES2: IOSurface plane count read at `+0x98` (Tahoe) → HEIC/YUV no longer green | confirmed |
| Kernel | XE-NOGVA: hide hardware video decode → VideoToolbox uses software decode | confirmed (Chrome) |
| Kernel | XE-NOORPHAN, XE-RESFREE, XE-NODEPTH: memory/resolve panics | confirmed |
| Metal | libxedrv v15: copy zero-copy textures at unaligned offsets → app icons and image layers visible | confirmed |
| Repo | reproducible MTL17 patcher and shader-compiler build; EFI without serials | confirmed |

See [docs/STATUS.md](docs/STATUS.md) for what works and the known problems.
