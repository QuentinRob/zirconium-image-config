#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURATION & PACKAGE LISTS
# ==============================================================================
RAW_GITHUB_BASE_URL="https://raw.githubusercontent.com/QuentinRob/zirconium-image-config/main"

# List of DNF packages to install (Edit here for easy maintenance)
PACKAGES=(
  git
  vim
  fish
  lynis
  openscap-scanner
  scap-security-guide
  dnf-plugins-core
  nodejs
  npm
  jj-cli
  curl
  jq
  google-cloud-cli
  libxcrypt-compat
  chromium
)

# List of Fish function scripts to install
FISH_FILES=(
  "fish_prompt.fish"
  "fish_jj_prompt.fish"
  "k8s_resources.fish"
)

echo "=================================================="
echo "   Fedora 44 WSL Automated Package Setup Script   "
echo "=================================================="

# 1. Repositories Setup
echo "[1/6] Setting up RPM repositories (Google Cloud CLI & Jujutsu COPR)..."
sudo tee /etc/yum.repos.d/google-cloud-sdk.repo > /dev/null << 'EOM'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el10-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg
EOM

sudo dnf copr enable -y aldantanneo/jj-vcs

# 2. DNF Core & Developer Packages Installation
echo "[2/6] Installing DNF packages..."
sudo dnf install -y "${PACKAGES[@]}"

# 3. Golang Installation
echo "[3/6] Installing Golang 1.26.4..."
sudo rm -rf /usr/local/go
sudo mkdir -p /usr/local
curl -sSL https://go.dev/dl/go1.26.4.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -

sudo mkdir -p /etc/profile.d /etc/fish/conf.d
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh > /dev/null
echo 'fish_add_path /usr/local/go/bin' | sudo tee /etc/fish/conf.d/golang.fish > /dev/null

# 4. Standalone Tools Installation (klog, kubelogin, Herdr, uv)
echo "[4/6] Installing standalone tools (klog, kubelogin, Herdr, uv)..."

# klog time tracker CLI
curl -sSL -o /tmp/klog.zip https://github.com/jotaen/klog/releases/latest/download/klog-linux.zip
sudo python3 -c "import zipfile; zipfile.ZipFile('/tmp/klog.zip').extract('klog', '/usr/bin')"
sudo chmod +x /usr/bin/klog
rm -f /tmp/klog.zip

# kubelogin CLI
curl -sSL -o /tmp/kubelogin.zip https://github.com/Azure/kubelogin/releases/download/v0.1.7/kubelogin-linux-amd64.zip
sudo python3 -c "import zipfile; zipfile.ZipFile('/tmp/kubelogin.zip').extract('bin/linux_amd64/kubelogin', '/usr/bin')"
sudo mv /usr/bin/bin/linux_amd64/kubelogin /usr/bin/kubelogin 2>/dev/null || true
sudo rmdir /usr/bin/bin/linux_amd64 /usr/bin/bin 2>/dev/null || true
sudo chmod +x /usr/bin/kubelogin
rm -f /tmp/kubelogin.zip

# Herdr multiplexer
curl -fsSL https://herdr.dev/install.sh | sudo HERDR_INSTALL_DIR=/usr/bin sh

# Python uv package manager
curl -LsSf https://astral.sh/uv/install.sh | sudo env HOME=/tmp UV_NO_MODIFY_PATH=1 UV_INSTALL_DIR="/usr/bin" sh

# 5. Shell & Fish Helper Functions Configuration
echo "[5/6] Configuring Fish shell functions & prompts..."
sudo mkdir -p /usr/share/fish/vendor_functions.d/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}" 2>/dev/null)" && pwd || echo "")"
LOCAL_SHELL_DIR="${SCRIPT_DIR}/../shell"

for file in "${FISH_FILES[@]}"; do
    if [ -n "$SCRIPT_DIR" ] && [ -f "${LOCAL_SHELL_DIR}/${file}" ]; then
        echo "  -> Copying ${file} from local workspace..."
        sudo cp "${LOCAL_SHELL_DIR}/${file}" /usr/share/fish/vendor_functions.d/
    else
        echo "  -> Downloading ${file} from GitHub remote..."
        sudo curl -sSL "${RAW_GITHUB_BASE_URL}/shell/${file}" -o "/usr/share/fish/vendor_functions.d/${file}"
    fi
done

# 6. Default Shell Configuration
echo "[6/6] Setting default shell..."
echo "Setting fish as default shell for user '$USER'..."
sudo usermod -s /usr/bin/fish "$USER" || true

echo ""
echo "=================================================="
echo "   Setup Finished Successfully!                   "
echo "=================================================="
