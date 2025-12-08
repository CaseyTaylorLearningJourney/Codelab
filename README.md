# Codelab

> For AI related items and Initial Scripting/Programming projects.

## 🗺️ Repository Map

This repository is organized by hardware environment and tooling focus.

### 📂 AI & ML Logic
* **/mlx-lab**
    * *Target:* MacBook Pro (M1 Max).
    * *Focus:* Local inference using Apple Silicon, MLX framework experiments, and local model quantization.
* **/cuda-lab**
    * *Target:* Ubuntu VM (Proxmox/NVIDIA).
    * *Focus:* Multi-GPU setups, custom Ollama interactions, and CUDA-specific implementations.

### 📂 Tooling & Workflows
* **/CLI_Tools**
    * *Tools:* `opencode`, `gemini-cli`, `claude`.
    * *Content:* System prompts, context files, and conversation logs/templates.
* **/infrastructure**
    * *Target:* Proxmox VM.
    * *Content:* Docker Compose files (Rootless), Ollama Modelfiles, and storage configuration scripts.
* **/scripts**
    * *Content:* General purpose programming and initial scripting projects (Python/Bash) unrelated to specific AI hardware.

## 💻 Hardware Profiles

### 🍎 Local Workstation (MacBook Pro)
* **Chip:** M1 Max
* **Memory:** 64GB Unified
* **Accelerator:** Metal (MPS)

### ⚡ AI Server (Proxmox VM)
* **OS:** Ubuntu 24.04.3 LTS (VM)
* **Network:** Segmented VLAN (Isolated: No access to other local networks).
* **Compute:**
    * CPU: Intel Xeon E5-2697 v4 (2 Sockets, 5 Cores assigned)
    * RAM: 32GB Dedicated
* **Accelerators:**
    * GPU: 2x NVIDIA RTX A4000 (Passthrough)
    * VRAM: 32GB Total (16GB x2)
* **Storage:**
    * OS: 60GB
    * Data: 250GB (Mounted for Models/Weights)
* **Stack:**
    * Rootless Docker
    * Ollama + OpenWebUI
