# Maxing out Ram on AMD Strix Halo (Ryzen AI Max+ 395)

**Target Hardware:** AMD Ryzen AI Max+ 395 (Strix Halo) with 128 GB LPDDR5X with currently targeting Sixunited AXB35 variants (This is the NIMO, Aifut, GMKtec EVO-x2, Bosgame M5 & FEVM FA-EX9 for reference)
**Result:** ~120 GB of system RAM exposed as GPU-accessible VRAM/GTT  
**Applies To:** llama.cpp, vLLM, Ollama, Lemonade, ExLlamaV2 or any ROCm-based inference engine
**Current OS Applied** CachyOS with Linux 6.19.11-1-cachyos kernel
**Deployment Mode:** Headless (`multi-user.target`, no GUI) — local inference via llama-swap → OpenWebUI (or llama-swap's built-in web UI)

---

## How It Works

Strix Halo uses a **Unified Memory Architecture (UMA)** — the CPU and iGPU (Radeon 8060S, 40 RDNA 3.5 CUs) share the same physical 256 GB/s LPDDR5X memory pool. There is no separate VRAM; the GPU accesses slices of system RAM through the **GTT (Graphics Translation Table)**.

By default, the AMD driver caps GPU-accessible memory — on modern kernels the default GTT limit is roughly **50% of system RAM**. The changes below raise those caps, letting the GPU see **up to ~95–97% of total RAM (~120–124 GB on a 128 GB system)**.

> [!IMPORTANT]
> These steps are split into two parts: **Foundation** (universal, OS/driver level — do this once) and **Per-Engine** (software-specific env vars — set whichever applies to your inference engine).

---

## Deployment & Frontend

This system runs headless — the default systemd target is set to **`multi-user.target`** (no desktop environment, no display server, no compositor). This frees up several GB of RAM that would otherwise be consumed by a GUI, giving the GPU memory pool as much headroom as possible.

```bash
# Strip the GUI — boot to CLI only
sudo systemctl set-default multi-user.target
# Reboot to apply (or just stop the display manager for the current session)
```

The inference stack is:

```
┌──────────────────────────────────────────────┐
│  Frontend (pick one)                         │
│  ┌────────────────┐  ┌─────────────────────┐ │
│  │   OpenWebUI     │  │  llama-swap Web UI  │ │
│  │  (full-featured │  │  (built-in, zero    │ │
│  │   chat UI)      │  │   extra install)    │ │
│  └───────┬────────┘  └────────┬────────────┘ │
│          │    OpenAI-compatible API    │      │
│          └──────────┬─────────────────┘      │
│                     ▼                        │
│  ┌──────────────────────────────────────────┐ │
│  │         llama-swap (port 8080)           │ │
│  │   Model gateway / hot-swap manager      │ │
│  │   Spawns llama-server per model          │ │
│  └──────────────────────────────────────────┘ │
│                     ▼                        │
│  ┌──────────────────────────────────────────┐ │
│  │    llama.cpp (llama-server)              │ │
│  │    ROCm/HIP → 120 GB UMA pool           │ │
│  └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

**Two frontend options:**

| Option | What It Is | When to Use |
|---|---|---|
| **llama-swap Web UI** | Built into llama-swap — no extra install. Access at `http://<host>:8080`. | Quick and simple. Just want to chat or test models with zero additional setup. |
| **OpenWebUI** | Full-featured ChatGPT-style interface. Connect it to llama-swap's OpenAI-compatible API at `http://<host>:8080/v1`. | Want conversation history, multi-model switching, user accounts, RAG, etc. |

> [!TIP]
> With no GUI consuming resources, the entire ~120 GB pool is dedicated to whichever model is currently loaded. llama-swap handles hot-swapping — when you switch models, it unloads the current one and loads the new one into the full memory pool.

---

## Part 1: Universal Foundation (One-Time Setup)

These steps operate at the firmware and kernel level. They make the memory available to **all** software, regardless of inference engine.

### Step 1: BIOS / UEFI Settings

Enter your BIOS and change:

| Setting | Value | Why |
|---|---|---|
| **VRAM / UMA Frame Buffer** | **Auto** (or minimum, e.g. 512 MB / 1 GB) | Prevents firmware from carving out a large fixed VRAM reservation. Lets the GPU claim RAM dynamically via GTT. A large carveout is *wasted* — it's hidden from the OS and the GPU can reach system RAM through GTT regardless. |
| **Power / TDP Profile** | **Performance** (85W+ if your chassis/cooling allows; 54W minimum) | Ensures the iGPU has enough power budget for sustained inference. Higher TDP = faster tokens/sec. |
| **IOMMU** | **Off** (or `amd_iommu=off` at boot) | ~6% memory-bandwidth improvement for LLM inference and better stability on gfx1151. See Step 2 boot params. |

> [!TIP]
> Some BIOS versions label this as "GFX Configuration" → "iGPU Memory" or "UMA_AUTO". Set it to the **smallest** value or **Auto** — do NOT set it to a large fixed value like 64 GB.

### Step 2: Linux Kernel Boot Parameters

These kernel parameters remove the TTM (Translation Table Manager) caps and tell the GPU driver how much system RAM it's allowed to use as GTT.

> [!WARNING]
> **Kernel Version Matters — a lot.** For Strix Halo (gfx1151):
> - **Kernel 6.18.4+ is the minimum recommended stable version.** The upstream AMD KFD patches that fix queue creation and memory-availability checks for gfx1151 landed in 6.18.4. Older kernels have gfx1151 stability bugs and should be avoided for compute.
> - **Kernel 6.19.x** works well but **misidentifies gfx1151 as gfx1100 for ROCm**, causing ROCm binaries to segfault unless you set `HSA_OVERRIDE_GFX_VERSION=11.5.1` and `HSA_ENABLE_SDMA=0` (see Part 2). This system runs 6.19.11, so those vars are **required** for the ROCm path.
> - **Parameter names:** `ttm.pages_limit` is the primary GTT control on all current kernels. On kernels **< 6.16** the TTM module was shipped as `amdttm` (use `amdttm.pages_limit`, `amdttm.page_pool_size`). `amdgpu.gttsize` still works and is commonly set alongside `ttm.pages_limit` — it is *not* required but is harmless.
> 
> Check your kernel: `uname -r`

> [!CAUTION]
> **Firmware:** Avoid `linux-firmware-20251125` — it is reported to break ROCm on Strix Halo (instability/crashes). Pin to a known-good firmware version if you hit random ROCm crashes after an update.

#### For Kernel < 6.16 (Legacy Method)

Add these to your bootloader (GRUB, systemd-boot, etc.):

```
amdttm.pages_limit=0
amdttm.page_pool_size=0
amdgpu.gttsize=122880
```

| Parameter | Value | Purpose |
|---|---|---|
| `amdttm.pages_limit` | `0` | Removes the TTM page limit — no artificial cap on GPU memory allocation |
| `amdttm.page_pool_size` | `0` | Removes the TTM page pool size restriction |
| `amdgpu.gttsize` | `122880` | Sets GTT ceiling to 122,880 MB ≈ **120 GB** (95% of 128 GB) |

**Calculating `amdgpu.gttsize` for your RAM size:**
```bash
# Formula: 95% of total RAM in MB
echo $(( $(free -m | awk '/^Mem:/{print $2}') * 95 / 100 ))
```

#### For Kernel ≥ 6.16 (Modern Method — recommended)

Add this to your bootloader:

```
amd_iommu=off amdgpu.gttsize=122880 ttm.pages_limit=31457280
```

| Parameter | Value | Purpose |
|---|---|---|
| `amd_iommu=off` | — | Disables the AMD IOMMU for ~6% memory-bandwidth gain and better stability on gfx1151. (`iommu=pt` is an alternative if you need the IOMMU on.) |
| `amdgpu.gttsize` | `122880` | GTT window in MB (120 GB). Optional but commonly paired with `ttm.pages_limit`; harmless on modern kernels. |
| `ttm.pages_limit` | `31457280` | Primary control: max number of 4KB pages TTM may map for GPU use. 120 GB = 31,457,280 pages. |

**Calculating for your RAM size:**
```bash
# ttm.pages_limit — 95% of total RAM, converted to 4KB pages
TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
echo $(( TOTAL_KB * 95 / 100 / 4 ))

# amdgpu.gttsize — same target, in MB
echo $(( $(free -m | awk '/^Mem:/{print $2}') * 95 / 100 ))
```

> [!NOTE]
> `ttm.pages_limit` is the parameter that actually matters. `amdgpu.gttsize` is optional — set it alongside `ttm.pages_limit` (as most current Strix Halo setups do) or omit it. On some kernels it may log a deprecation-style warning; that is cosmetic. Just make sure the two values describe the **same** target size.

#### How to Apply (Distro-Specific)

**Fedora (grubby):**
```bash
sudo grubby --update-kernel=ALL --args="amd_iommu=off amdgpu.gttsize=122880 ttm.pages_limit=31457280"
```

**Arch / CachyOS / Manjaro (GRUB):**
```bash
# Edit /etc/default/grub — append to GRUB_CMDLINE_LINUX_DEFAULT
sudo nano /etc/default/grub
# Then regenerate:
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Ubuntu / Debian (GRUB):**
```bash
sudo nano /etc/default/grub
# Add params to GRUB_CMDLINE_LINUX_DEFAULT="..."
sudo update-grub
```

**systemd-boot (e.g., CachyOS default):**
```bash
# Edit the appropriate entry in /boot/loader/entries/*.conf
# Append params to the "options" line
```

**Reboot required after applying.**

### Step 3: Swap File (Recommended)

A large swap file on NVMe acts as a safety net for peak memory usage and prevents OOM kills:

```bash
sudo dd if=/dev/zero of=/swapfile bs=1G count=64 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
```

Set low swappiness to prefer RAM:
```bash
echo "vm.swappiness = 10" | sudo tee /etc/sysctl.d/99-ai-swap.conf
sudo sysctl --system
```

### Step 4: Verify

After rebooting, confirm the GPU can map ~120–124 GB of GTT:

```bash
# Most reliable: check the GTT total directly (this is what matters for compute)
cat /sys/class/drm/card*/device/mem_info_gtt_total
# ~120 GB ≈ 128849018880 bytes ; 124 GiB ≈ 133143986176 bytes
# (mem_info_vram_total will show the small BIOS framebuffer — that's expected)

# Check the TTM page limit
cat /sys/module/ttm/parameters/pages_limit     # Kernel ≥ 6.16
# or
cat /sys/module/amdttm/parameters/pages_limit  # Kernel < 6.16

# Overview (VRAM shown here is the framebuffer, not GTT)
rocm-smi

# Confirm kernel params took effect
cat /proc/cmdline | tr ' ' '\n' | grep -E "amdttm|amdgpu|ttm|iommu"
```

> [!CAUTION]
> Don't panic if `rocm-smi`/`mem_info_vram_total` shows only 512 MB–1 GB of VRAM — that's just the BIOS framebuffer. What matters is **`mem_info_gtt_total`**. If *GTT* is also tiny, the kernel boot parameters aren't taking effect: double-check your bootloader config and reboot.

---

## Part 2: Per-Engine Environment Variables

The foundation (Part 1) makes the memory available at the OS level. Each inference engine then needs its own configuration to actually **use** that memory pool. Set the relevant variables for your engine.

> [!TIP]
> **Backend choice on gfx1151.** For llama.cpp, the current community consensus is that **Vulkan (Mesa RADV) is the most stable and compatible backend** and reaches the full unified pool. Prefer it for general LLM inference. Use **ROCm/HIP** when you specifically need it (PyTorch stacks like vLLM/ExLlamaV2/ComfyUI, or long-context tuning) — and on kernel 6.19.x remember ROCm needs the `HSA_OVERRIDE_GFX_VERSION` fix below.

### llama.cpp / llama-swap

**ROCm / HIP backend:**
```bash
export GGML_CUDA_ENABLE_UNIFIED_MEMORY=1   # hipMallocManaged — bypasses the ~8 GB hipMalloc cap
export HSA_ENABLE_SDMA=0                    # Prevent DMA hangs on gfx1151
export HSA_OVERRIDE_GFX_VERSION=11.5.1      # REQUIRED on kernel 6.19.x (ROCm misdetects gfx1151 as gfx1100 → segfault)
export ROCBLAS_USE_HIPBLASLT=1             # Better GEMM performance on gfx1151
```

If running via systemd service:
```ini
[Service]
Environment="GGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
Environment="HSA_ENABLE_SDMA=0"
Environment="HSA_OVERRIDE_GFX_VERSION=11.5.1"
Environment="ROCBLAS_USE_HIPBLASLT=1"
```

**Vulkan (RADV) backend — most stable on gfx1151:**
```bash
# No HSA_* / ROCm vars needed. Just build/run the Vulkan backend of llama.cpp.
# RADV reaches the full ~120–124 GiB GTT pool directly.
```

**Launch flags (both backends):**
- `--n-gpu-layers 999` (not 0) to actually offload all layers to the GPU.
- `--no-mmap` on the **ROCm** backend — ROCm's mmap path above ~64 GB is very slow on gfx1151 (page-fault stalls). `--no-mmap` loads weights straight into GPU-accessible memory. (On Vulkan, mmap is fine; weights live in host RAM either way.)

> [!NOTE]
> If you build llama.cpp yourself for ROCm, use `-DGPU_TARGETS=gfx1151` (or `-DAMDGPU_TARGETS=gfx1151`). Some builds are more stable with `-DGGML_HIP_NO_VMM=ON`.

---

### vLLM (PyTorch / ROCm)

```bash
export HSA_XNACK=1                      # Enable unified memory page migration
export HSA_ENABLE_SDMA=0                # Prevent DMA hangs on gfx1151
export HSA_OVERRIDE_GFX_VERSION=11.5.1  # REQUIRED on kernel 6.19.x to avoid ROCm segfault
export PYTORCH_ROCM_ARCH=gfx1151
export VLLM_TARGET_DEVICE=rocm
```

> [!NOTE]
> vLLM on Strix Halo (gfx1151) is still bleeding-edge. You may need to build from source or use community forks like `lemonade-sdk/vllm-rocm`. Requires Linux kernel **6.16+** and ROCm **7.x+**.

---

### Ollama

```bash
export HSA_ENABLE_SDMA=0
export HSA_OVERRIDE_GFX_VERSION=11.5.1   # Needed on kernel 6.19.x for the ROCm path
export GPU_MAX_ALLOC_PERCENT=100          # Allow full memory pool utilization
export OLLAMA_FLASH_ATTENTION=true
```

**Alternative (Vulkan backend — often more stable on Strix Halo):**
```bash
export OLLAMA_VULKAN=1
```

> [!WARNING]
> Ollama is the **least reliable** option on Strix Halo — it has a history of under-detecting the UMA pool and lagging behind on gfx1151/Vulkan support. If you hit limited-VRAM or OOM behavior, switch to standalone **llama.cpp with the Vulkan (RADV) backend** (or ROCm), which gives far better access to the full unified pool on this hardware.

---

### Lemonade (AMD)

Lemonade auto-detects AMD hardware and selects the best backend. The kernel-level GTT changes (Part 1) are usually sufficient. If needed:

```bash
export HSA_ENABLE_SDMA=0
```

Lemonade wraps backends like `llama.cpp`, `whisper.cpp`, and `sd.cpp` — the backend-specific vars above may also apply depending on which backend Lemonade selects.

---

### ExLlamaV2 (PyTorch / ROCm)

```bash
export HSA_ENABLE_SDMA=0
export HSA_OVERRIDE_GFX_VERSION=11.5.1   # REQUIRED on kernel 6.19.x
export PYTORCH_ROCM_ARCH=gfx1151
```

If you encounter `HIP out of memory` despite having ample RAM, use cache quantization:
```bash
python exllamav2_server.py --cache_q4 ...
```

> [!IMPORTANT]
> **Kernel 6.19.x regression:** ROCm misidentifies gfx1151 as gfx1100 and segfaults on init (`ggml_cuda_init`/HIP reports `gfx1100`). Setting `HSA_OVERRIDE_GFX_VERSION=11.5.1` together with `HSA_ENABLE_SDMA=0` fixes it. Earlier guidance that "ROCm 7.x has native gfx1151 support so you don't need the override" **no longer holds on 6.19.x kernels** — this system runs 6.19.11, so the override is required.

---

### Quick Reference: Universal Variables

These are safe to set globally in `/etc/environment` or your shell profile — they benefit all ROCm apps:

```bash
# /etc/environment or ~/.bashrc
HSA_ENABLE_SDMA=0                 # Prevent DMA hangs (gfx1151-specific)
HSA_OVERRIDE_GFX_VERSION=11.5.1   # Required for ROCm on kernel 6.19.x (gfx1151 misdetection fix)
ROCBLAS_USE_HIPBLASLT=1           # Better GEMM performance on gfx1151
GPU_MAX_ALLOC_PERCENT=100         # Don't artificially limit GPU memory allocation
```

> [!NOTE]
> `HSA_OVERRIDE_GFX_VERSION=11.5.1` is only needed for the ROCm/HIP path on affected kernels (6.19.x). It's harmless for the Vulkan backend, which ignores HSA vars.

---

## Summary Checklist

```
┌─────────────────────────────────────────────────────────────┐
│                    FOUNDATION (do once)                      │
├─────────────────────────────────────────────────────────────┤
│ ☐ Kernel 6.18.4+ (6.19.x OK; needs HSA override for ROCm)  │
│ ☐ BIOS: UMA Frame Buffer → Auto / minimum (512 MB–1 GB)    │
│ ☐ BIOS: TDP → Performance (85W+ if cooling allows)         │
│ ☐ BIOS: IOMMU → Off (or amd_iommu=off at boot)            │
│ ☐ Kernel boot params (modern kernels):                     │
│     amd_iommu=off amdgpu.gttsize=122880 \                  │
│     ttm.pages_limit=31457280      (120 GB target)          │
│     → for 124 GiB: gttsize=126976 pages_limit=32505856     │
│ ☐ Create 64 GB NVMe swap file                              │
│ ☐ Set vm.swappiness = 10                                    │
│ ☐ Reboot                                                    │
│ ☐ Verify: rocm-smi / mem_info_gtt_total shows ~120–124 GB  │
├─────────────────────────────────────────────────────────────┤
│                PER-ENGINE (set as needed)                    │
├─────────────────────────────────────────────────────────────┤
│ ☐ llama.cpp:  GGML_CUDA_ENABLE_UNIFIED_MEMORY=1 + --no-mmap │
│               (or Vulkan RADV — most stable)               │
│ ☐ vLLM:       HSA_XNACK=1                                  │
│ ☐ Ollama:     GPU_MAX_ALLOC_PERCENT=100 (least reliable)   │
│ ☐ All ROCm:   HSA_ENABLE_SDMA=0                            │
│ ☐ ROCm 6.19.x: HSA_OVERRIDE_GFX_VERSION=11.5.1            │
└─────────────────────────────────────────────────────────────┘
```

---

## Going to 124 GiB (Aggressive — ~4 GB left for OS + Swap)

The 120 GB target above leaves ~8 GB for the OS, page cache, and headroom — a safe default. If you're **headless** (no GUI, `multi-user.target`) and want to squeeze out the maximum, you can push the GTT ceiling to **124 GiB**, leaving only ~4 GB for the operating system.

> [!WARNING]
> **This is aggressive.** ~4 GB for the OS is workable *only* on a lean headless node. If you run extra services (containers, monitoring, databases, a browser, a desktop), you will OOM. A generous NVMe swap file (Step 3) becomes **mandatory**, not optional, at this level — it's your safety net when a model + KV cache momentarily spikes past the ceiling.

**Boot parameters for 124 GiB:**
```
amd_iommu=off amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

| Parameter | Value | Meaning |
|---|---|---|
| `amdgpu.gttsize` | `126976` | 126,976 MiB ÷ 1024 = **124 GiB** GTT window |
| `ttm.pages_limit` | `32505856` | 32,505,856 × 4 KiB = 126,976 MiB = **124 GiB** pinned-page cap |

Optionally pre-allocate the page pool to reduce fragmentation (this memory becomes reserved for the GPU and unavailable to the CPU):
```
ttm.page_pool_size=32505856
```

**Who should use 124 GiB vs 120 GB:**

| Target | OS Headroom | Best For |
|---|---|---|
| **120 GB** (`gttsize=122880`, `pages_limit=31457280`) | ~8 GB | Default. Safe for most setups, including light extra services. |
| **124 GiB** (`gttsize=126976`, `pages_limit=32505856`) | ~4 GB | Lean headless inference-only node where every GB of model/KV-cache space counts. Requires a large swap file. |

> [!TIP]
> Verify after reboot with `cat /sys/class/drm/card*/device/mem_info_gtt_total` — 124 GiB ≈ `133143986176` bytes. If the box starts OOM-killing `llama-server`, step back down to 120 GB.

---

## Scaling to Other RAM Sizes

This guide uses 128 GB as the example, but the formula works for any Strix Halo system:

| Total RAM | Target | `amdgpu.gttsize` (MiB) | `ttm.pages_limit` (4KB pages) |
|---|---|---|---|
| 32 GB | ~30 GB | 30720 | 7,864,320 |
| 64 GB | ~61 GB | 61440 | 15,728,640 |
| 96 GB | ~91 GB | 92160 | 23,592,960 |
| 128 GB | ~120 GB (safe) | 122880 | 31,457,280 |
| 128 GB | ~124 GiB (aggressive) | 126976 | 32,505,856 |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| ROCm segfaults on init; reports `gfx1100` instead of `gfx1151` | Kernel 6.19.x misdetects the GPU | Set `HSA_OVERRIDE_GFX_VERSION=11.5.1` **and** `HSA_ENABLE_SDMA=0` |
| GPU compute fails to initialize / only ~15.5 GB usable | Kernel older than 6.18.4 (missing KFD patches) | Upgrade to kernel **6.18.4+** |
| `rocm-smi` shows tiny VRAM (512 MB / 1 GB) | That's the BIOS framebuffer, not GTT | Check GTT instead: `cat /sys/class/drm/card*/device/mem_info_gtt_total`. If GTT is also small, kernel boot params didn't apply — check `/proc/cmdline`, regenerate bootloader, reboot |
| `HIP out of memory` on large models | Engine not using unified memory | Set the engine-specific env var (see Part 2) |
| Slow model loading / stalls on ROCm | ROCm mmap path above ~64 GB is slow on gfx1151 | Add `--no-mmap` to the llama.cpp launch |
| Random ROCm crashes after a system update | Bad firmware (`linux-firmware-20251125`) | Pin/downgrade to a known-good `linux-firmware` |
| GPU hangs / DMA errors | SDMA engine issue on gfx1151 | Ensure `HSA_ENABLE_SDMA=0` is set |
| Kernel warning about `amdgpu.gttsize` | Cosmetic on modern kernels | Ignore, or drop `amdgpu.gttsize` and keep only `ttm.pages_limit` |
| System freezes / OOM-kills `llama-server` | No swap, or 124 GiB target too aggressive | Create NVMe swap file (Step 3); step back to the 120 GB target |
| Poor performance despite GPU offload | TDP set to low-power mode | Set BIOS TDP to Performance (85W+ if cooling allows) |
| ROCm unreliable / won't detect gfx1151 | Backend maturity | Use the **Vulkan (RADV)** backend of llama.cpp instead |

---

*Guide based on a production AMD Ryzen AI Max+ 395 (Strix Halo) 128 GB multi-user node running CachyOS/Fedora with llama.cpp, llama-swap, and OpenWebUI.*
