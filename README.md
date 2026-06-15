# Zirconium Hardened Dev Workspace Image

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Image Version](https://img.shields.io/badge/container--registry-ghcr.io-blue?logo=github)](https://github.com/QuentinRob/zirconium-image-config/pkgs/container/zirconium-image-config)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](https://makeapullrequest.com)
[![Hardened: ANSSI BP-028](https://img.shields.io/badge/Security-ANSSI%20BP--028-red.svg)](https://cyber.gouv.fr/publications/recommandations-de-securite-relatives-au-deploiement-dun-systeme-de-fichiers)
[![Shell: Fish](https://img.shields.io/badge/Shell-Fish-blue.svg?logo=fish)](https://fishshell.com/)

An opinionated, production-grade, hardened developer workspace container image built for **Zirconium OS** (bootable container-based Linux distribution).

[Report Bug](https://github.com/QuentinRob/zirconium-image-config/issues) · [Request Feature](https://github.com/QuentinRob/zirconium-image-config/issues)

</div>

---

## 🚀 Overview

This repository contains the `Containerfile` configuration to build a custom, secure, and fully equipped development environment bootable container image. Derived from `ghcr.io/zirconium-dev/zirconium-nvidia:latest`, it integrates top-tier hardening policies alongside pre-packaged DevOps, Kubernetes, AI-Assisted development tools, and user experience enhancements.

---

## ✨ Features

### 🛡️ Security Hardening (ANSSI BP-028)
- **Kernel/Network Hardening**: Strict kernel parameter configuration via `sysctl` (`kernel.dmesg_restrict`, `kernel.kptr_restrict`, `kernel.randomize_va_space`).
- **Core Dump Restrictions**: Disabled core dumps for unprivileged accounts (`fs.suid_dumpable=0`).
- **Network Hardening**: IP forwarding disabled, redirect acceptance blocked, and reverse path filtering (RPF) enforced.
- **Secure Default Permissions**: System-wide default `umask` set to `0027` in shell profiles.
- **Account Locking**: Locked out shell access for system accounts (UID < 1000) by default (except `root`).
- **Audit Tooling**: Comes pre-installed with `lynis`, `openscap-scanner`, and `scap-security-guide` for immediate compliance checks.

### 🛠️ Developer Ecosystem & AI IDEs
- **Core Package Toolkit**: `git`, `vim`, `firefox`, `nodejs`/`npm`, `jq`, `curl`, and `pandoc`.
- **Infrastructure & Cloud Platforms**: Fully loaded with `kubectl`, `helm`, `azure-cli`, `kubelogin`, and **Terraform**.
- **Terminal Workspace & Shells**: Pre-installed **Zellij** terminal multiplexer.
- **AI-Assisted Coding**:
  - Includes **Antigravity IDE** (AI-powered agentic development platform) with a preconfigured system-wide launcher.
  - Includes **OpenAI Codex CLI** and the **Zed Editor Codex ACP** adapter.
- **Next-Gen Version Control**: Pre-installed and configured Jujutsu (`jj-cli`) VCS.

### 🐚 Custom Shell & Prompt Settings
- **Default Shell**: Fully configured **Fish shell** set system-wide.
- **Custom Prompts**: Preloaded prompt configurations featuring Git & Jujutsu status tracking (`fish_prompt.fish`, `fish_jj_prompt.fish`).
- **Kubernetes Integrations**: Native fish functions (`k8s_resources.fish`) to query cluster resources dynamically.

### 🌐 Secure Remote Connectivity
- **OpenFortiVPN**: Pre-configured with elevated network capability permissions (`cap_net_admin`).
- **DankBar Widget Integration**: OpenFortiVPN connection widget integrated for quickshell control.

---

## 📁 Repository Structure

```text
.
├── Containerfile              # Core container build definition
├── Widgets/                   # Quickshell/DankBar UI plugins (VPN widget)
│   ├── plugin.json
│   ├── VpnSettings.qml
│   └── VpnWidget.qml
├── fish_prompt.fish           # Base prompt layout
├── fish_jj_prompt.fish        # Jujutsu-aware shell prompt functions
├── k8s_resources.fish         # Kubernetes helper functions for Fish
└── README.md                  # This documentation
```

---

## 🛠️ Getting Started

### Prerequisites
Make sure you have Podman or Docker installed:
```bash
# Verify installation
podman --version
# or
docker --version
```

### Building the Image
You will need the `Antigravity` installation package located in the directory root to build:

```bash
# Build the container image
podman build -t zirconium-image-config:latest -f Containerfile .
```

### Running the Environment
To run the container interactively:
```bash
podman run -it --name zirconium-dev zirconium-image-config:latest /usr/bin/fish
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to open issues or submit Pull Requests.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`jj commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`jj git push --bookmark feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information (if applicable).
