# Porting NootedGreen to Intel Core i3-1220P (Alder Lake-P)

This branch ports the NootedGreen kernel extension (Lilu plugin) from the source RPL-P
i7-1360P machine to the i3-1220P laptop. **Only the kext is ported** — the EFI, the `macos/`
user-space stack and `tools/` are out of scope here (see "Dependencies" below for what the kext
needs from them).

The kext built from this branch is the only deliverable. The build script and Info.plist are
unchanged — this is a source-data port, not a structural one.

## Source vs target

| | Source (main) | Target (this branch) |
|---|---|---|
| CPU | i7-1360P (RPL-P) | i3-1220P (ADL-P, model 0x9A) |
| iGPU device-id | 0xA7A0 (real) | 0x4628 (real, UNVERIFIED — read from your machine) |
| EU | 96 (6 DSS) | 64 (4 DSS) |
| NumSubSlices (SS) | 12 | 8 |
| MaxEU/SS | 8 | 8 |
| L3BankCount | 8 | 8 |
| RP0 (max GPU MHz) | 1500 | 1100 |
| Display engine | 13 (RPL-P) | 13 (ADL-P) |
| Device-id spoof | 0x9A49 (TGL) | 0x9A49 (TGL) — unchanged |

The i3-1220P is UHD Graphics (64 EU, 4 DSS). i3-1220P GPU max dynamic frequency is 1.1 GHz
(= RP0 = 1100 MHz), confirmed against Intel ARK.

## What changed and why (classification)

Every fork patch was classified into: **(a)** hardware-independent (Tahoe/TGL-driver gap),
**(b)** RPL-specific (device ID / PCI match / platform ID / gen checks),
**(c)** config-dependent (EU/subslice/slice counts, fuse/slice masks, GT config, GuC, GPU freq, display/DDI/eDP).

| Patch / code | Class | Action for i3-1220P | Why |
|---|---|---|---|
| `f3`/`r3` SKU/device-id panic bypass | b | **unchanged** | spoofed 0x9A49 is not in the TGL whitelist on any spoofed platform; ADL-P needs it too |
| `isRealTGL` (CPU model 0x8C/0x8D) | b | **unchanged** | ADL-P = 0x9A → false → spoofed path, same as RPL |
| `f3b`/`r3b` L3BankCount=8 | c | **unchanged** | Gen12 GT2 L3 = 8 on both RPL-P and ADL-P |
| `f3bb`/`r3bb` MaxEUPerSubSlice=8 | c | **unchanged** | 16 EU/DSS ÷ 2 = 8 for all Gen12 LP |
| `f3bbb`/`r3bbb` NumSubSlices | c | **12 → 8** (default); `ngreensubslices=N` override | 4 DSS × 2 = 8 SS on i3-1220P 64 EU |
| `getGPUInfo()` topology override | c | **12 SS / 96 EU → 8 SS / 64 EU**; overridable | the field (0x1158/0x1124) must match the SKU |
| `getGPUInfoICL()` (ICL fallback) | c | unchanged (already 8/64) | ICL path not used unless `-ngreenicl` |
| Device-id spoof 0x9A49 (configRead hook + EFI) | b | **unchanged** | the TGL driver must see 9A49; real ADL-P id is invisible behind the hook |
| DMC firmware `ngreen-dmc=adlp` | c | **unchanged** | ADL-P DMC blob already shipped; needed by ADL-P |
| ADL-P DP link training (IntelDPLinkTraining) | c | **unchanged** | already ADL-P-aware |
| Display engine 13 fixes (DPT/DBUF/GAMMA/FMT/BLR/FBDPMS) | a | **unchanged** | display 13 shared by RPL-P and ADL-P |
| XE-GTFREQ floor (default 1100) | c | **unchanged** | floor == i3-1220P RP0, so busy→RP0, idle→RC6; cap 1500 is never hit at default |
| XE-* scheduler/memory patches (CSBGUARD, SAMETAIL, ELSQ*, POOL2, PAGEONGUARD, RESFREE, etc.) | a | **unchanged** | Tahoe/IOAF2 workarounds, generation-agnostic |
| `kern_start.cpp` KernelVersion::Tahoe | a | **unchanged** | already Tahoe-min |
| `getBranding()` device tables (`kern_model.hpp`) | c | **likely unchanged** (0x4628 already in `g12_adl`); cosmetic only |

**Net code change: 2 lines of logic** (NumSubSlices 12→8 in two places) + boot-arg configurability + a platform debug log. The TGL driver, display path, DMC, link training, device-id spoof and frequency control are all generation-agnostic or already ADL-P-aware.

## Patch-classification — config-dependent (the only thing that varies per SKU)

Two code points set NumSubSlices:

1. **`f3bbb`/`r3bbb`** (`kern_gen11.cpp` ~L1976) — byte patch applied at load that writes IGAccelDevice+0x1158.
   Replace byte index 4 changed from `0x0c` (12) to `0x08` (8). Find pattern unchanged (matches original Apple binary).
2. **`getGPUInfo()`** (`kern_gen11.cpp` ~L5974) — runtime override of the topology fields (0x1158/0x1124/0x116c/mirrors). `numSubSlices` default 12→8, `totalEU` = 8×8 = 64. `maxEUPerSubSlice` and `l3BankCount` default 8 (unchanged).

Both default to 8 (i3-1220P) and accept boot-args. `getGPUInfo()` runs on `!wegCoexist`, so the release boot-args route it and its value wins at runtime.

Device-id and isRealTGL stay as-is:
- `isRealTGL` = false for ADL-P (0x9A), so the spoofed/patched path is taken (same as RPL).
- The 0x9A49 spoof is enforced by the `configRead16/32` hook (`kern_green.cpp`) and the EFI DeviceProperties; the real ADL-P PCI id never reaches the TGL driver. So the real device-id is cosmetic (only affects the `getBranding` log label).

## Config-dependent-but-safe: these stay byte-for-byte identical

- `f3b`/`r3b` (L3BankCount=8): GT2 L3 is 8 across Gen12 LP.
- `f3bb`/`r3bb` (MaxEUPerSubSlice=8): 16 EU/DSS ÷ 2 = 8 across Gen12 LP.
- The 0x9A49 spoof and `f3` SKU bypass.

## XE-GTFREQ on the i3-1220P (no change)

`wrapSetGTFrequencyMMIO` never lets the GPU request below `ngreengtfreq` (default 1100 MHz, capped at 1500). The i3-1220P's RP0 is 1100, so the default floor = RP0: the GPU runs at its real max when busy and still enters RC6 when idle. The 1500 cap is never hit at default floor. No frequency change required; `ngreengtfreq` can be raised only if a future SKU can sustain a higher RP0.

## Dependencies (what the kext needs but you do not port here)

The kext boots and drives the display on its own. **Metal/GPU acceleration requires the `macos/` user-space stack** that this branch does not touch:

- The **Apple TGL driver bundles** (`AppleIntelTGLGraphics*.kext`/`.bundle`, the `16.0.32` set from upstream sgiammori/NootedGreen) — NootedGreen loads and patches these. They are not in this repo; `install.sh` clones them. You need them installed.
- The **patched Metal driver, libxedrv and shader compiler** built by `macos/build-all.sh` — without these, `MTLDevice` is nil and there is no hardware acceleration.

**So: the kext built here cannot, on its own, give you hardware acceleration.** It boots the machine and lights the panel (compositor-only, no Metal acceleration) on its own. For Metal/acceleration you must run the source repo's `macos/` build/install steps against the TGL bundles, then copy this kext over the one it produced. The kext's display/2D path works without the user-space stack; the 3D/Metal path does not.

`tools/` (diagnostics, kcsyms/kcdis) is optional and useful for debugging; not required to boot or accelerate.

## EFI prerequisites (you set these — not shipped here)

This repo does **not** ship an EFI. The kext assumes your own OpenCore already spoofs the iGPU as Tiger Lake via
WhateverGreen or DeviceProperties on the IGPU device (`PciRoot(0x0)/Pci(0x2,0x0)`):
- `device-id` = `0x9A49` (base64 `SZoAAA==`)
- `AAPL,ig-platform-id` = `0x9A490000` (base64 `AABJmg==`)

Boot-args (same as the source release — the i3-1220P uses the defaults):
```
IGLogLevel=3 msgbuf=400000 -ngreentglwithgfx -allow3d -disablegfxfirmware ngreen-dmc=adlp
-ngreenv189 -ngreenkeepefi -ngreenxefix -ngreenfixbootmode amfi_get_out_of_my_way=1 ngreenSched=4 ngreenV142=3
ngreenblmax=48000
```
Lilu truncates at ~228 chars — keep it short.

## Data to collect from your i3-1220P machine

Mark UNVERIFIED → confirm on the actual hardware. The kext's *functionality* only depends on NumSubSlices (8) which matches the i3-1220P; everything below is for confidence/labeling only.

```bash
# Real PCI device-id (expect 0x4628 / "UHD" for 64 EU ADL-P; NOT 0x46B3)
gfxutil -f IGPU
ioreg -r -c IOPCIDevice -n IGPU -d 1 | grep -E 'device-id|revision-id|vendor-id'
# EU count / topology from the loaded driver (once NootedGreen loads):
ioreg -r -c IntelAccelerator -d 1 | grep -iE 'EU|slice|sub-slice|subslice'
# eDP panel EDID
ioreg -r -c IODisplayConnect -d 1
# BIOS version / model
system_profiler SPHardwareDataType
```

Confirm:
1. Real device-id (and that it's listed in `kern_model.hpp` `g12_adl`; `0x4628` is). If it's not listed, the log label falls back harmlessly — functionality is unaffected.
2. EU count = 64 (so NumSubSlices = 8 is the right default). If your EU differs (80 = 5 DSS → 10 SS), set `ngreensubslices=10`.
3. Panel EDID/resolution and link-rate/lane-count. The XE-FBDPMS backlight-only sleep and the `keepefi`/`-ngreenkeepefi` logic assume an internal eDP panel trained by UEFI/GOP, like the source's. If your panel differs (e.g. 4-lane HBR3 vs the source's), check the display/EDID collection step.

If your EU count differs from 64, the kext still boots (compositor-only) with the default; set `ngreensubslices=N` before enabling acceleration. The EU count must equal `ngreenmaxeu × ngreensubslices` exactly.

## Build (on macOS, Command Line Tools only)

This kext cannot be built on Windows — it needs `clang -mkernel`, the MacKernelSDK and Mach-O `codesign`/`kmutil`. Build on the i3-1220P Hackintosh itself (or any Mac with CLT):

```bash
cd /path/to/Hackintosh-XPS13Plus-IrisXe-Tahoe
zsh build-nootedgreen.sh      # → build/NootedGreen.kext
```

`build-nootedgreen.sh` clones MacKernelSDK + Lilu (DEBUG) and compiles `src/NootedGreen` with no dependency on `macos/` or `tools/`. Output: `build/NootedGreen.kext`.

### Verify the built kext

```bash
# Loads in kernel collection (Info.plist OSBundleLibraries valid)
kmutil load -p build/NootedGreen.kext
# Signed (ad-hoc) and architecture
codesign -dv build/NootedGreen.kext
file build/NootedGreen.kext/Contents/MacOS/NootedGreen
# Topology picked up (defaults = i3-1220P)
log show --last 5m --predicate 'eventMessage CONTAINS "ngreen"' | grep -E 'platform|getGPUInfo'
```

`Info.plist` `OSBundleLibraries`: `as.vit9696.Lilu 1.6.4`, IOKit/libkern kpi 10.0.0. `OSBundleRequired = Safe Boot`, so it loads in recovery too. `kern_start.cpp` min kernel = Ventura, max = Tahoe.

## Test plan

1. **Boot, compositor-only** (no `macos/` stack, NootedGreen Enabled): machine boots, internal panel lights, no kernel panic. Check `ioreg -r -c IntelAccelerator` for the accelerator and the topology SYSLOG.
2. **Topology values**: confirm `getGPUInfo:` line shows `subslices=8 ... totalEU=64`, and the platform line shows `isRealTGL=0 ... dmcIsAdlp=1`. The `platform:` SYSLOG is the new debug surface added by this port.
3. **Recovery fallback** (disable NootedGreen in your `config.plist`, or remove it from `OC/Kexts/`): still boots to desktop with no acceleration.
4. **Build verify**: `kmutil load`, `codesign`, `file` as above. `Info.plist` OSBundleLibraries unbroken.
5. **Acceleration (requires `macos/` stack)**: after installing the TGL bundles + patched Metal driver + libxedrv + shader compiler, run `system_profiler SPDisplaysDataType` and look for "Metal Support"; resample the panel at native res. Report failures via the `xeEv`/`-ngreenevlog` diagnostic.

## Rollback plan

The port branch only changes `kern_gen11.cpp` (and docs). Reverting is `git checkout main -- src/NootedGreen/kern_gen11.cpp` (or disable NootedGreen in your `config.plist`). The original RPL 96EU values are restored instantly; no EFI change required because the device-id spoof is unchanged.

## License (TNSP 1.0)

NootedGreen is Thou Shalt Not Profit 1.0; forks inherit it. License headers and credits in `src/NootedGreen/*.cpp/.hpp` are unchanged.

## UNVERIFIED items (need your machine)

- Real ADL-P device-id (stated 0x46B3, expected 0x4628). Cosmetic-only for the kext; does not change behavior.
- EU count = 64 (drives NumSubSlices=8). If different, set `ngreensubslices=N`.
- i3-1220P RP0 = 1100 MHz (XE-GTFREQ default). If your BIOS allows a different max, adjust `ngreengtfreq`.
- L3BankCount = 8, MaxEU/SS = 8 for ADL-P GT2 (assumed same as RPL; UNVERIFIED against i915 for this exact SKU). Override via `ngreenl3banks`/`ngreenmaxeu` if wrong.