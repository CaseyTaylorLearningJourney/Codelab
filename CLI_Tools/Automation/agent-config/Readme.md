<div align="center">

# 🛠️ Codelab: Agent Config

> **Agent configuration setup to help focus models a little bit better**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![npm version](https://badge.fury.io/js/%40google%2Fgemini-cli.svg)](https://badge.fury.io/js/%40google%2Fgemini-cli)

</div>

---

# 🔧 Setup

## Prerequisites

Before installing, ensure you have the following installed on your system:

* **npm** (Node Package Manager)
* **curl** (Command line tool for transferring data)

---

## 💻 Installation

Choose the CLI solution that matches your workflow.

### Option 1: Gemini CLI (via npm)

Run the following command to install the Gemini CLI globally:

```bash
npm install -g @google/gemini-cli
```

> [!IMPORTANT]
> **Using `sudo`?**
> If you run the install command using `sudo`, keep in mind that you are installing under the root context.
>
> You will need to manually run the update command with `sudo` in the future to avoid permission errors:
>
> ```bash
> sudo npm update -g @google/gemini-cli
> ```

### Option 2: OpenCode (via CURL)

To install OpenCode, run the following script:

```bash
curl -fsSL https://opencode.ai/install | bash
```
---

# 📂 Project Structure

This repository is organized to facilitate automatic configuration injection into new project folders.

```text
agent-config/
├── inject-requirements.sh # Watcher script that detects new folders (I keep this running under a systemd service)
|                          # For linux permissions make sure that your sh file is in /usr/local/bin
├── requirements.md        # The standard requirements prompt to be injected
├── gemini.md              # The model-specific config (or opencode.md)
└── README.md              # This documentation
