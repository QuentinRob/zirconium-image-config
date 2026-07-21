#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "   Fedora 44 WSL Automated Package Setup Script   "
echo "=================================================="

# 1. Google Cloud CLI Repository Setup
echo "[1/7] Setting up Google Cloud SDK RPM repository..."
sudo tee /etc/yum.repos.d/google-cloud-sdk.repo > /dev/null << 'EOM'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el10-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg
EOM

# 2. Jujutsu COPR Repository Setup
echo "[2/7] Enabling Jujutsu VCS COPR repository..."
sudo dnf copr enable -y aldantanneo/jj-vcs

# 3. DNF Core & Developer Packages Installation
echo "[3/7] Installing core DNF packages..."
sudo dnf install -y \
  git vim firefox fish zed lynis \
  openscap-scanner scap-security-guide dnf-plugins-core \
  nodejs npm seahorse keepassxc jj-cli curl openfortivpn jq \
  google-cloud-cli libxcrypt-compat chromium

# 4. OpenFortiVPN Network Capability Setup
echo "[4/7] Setting network capabilities for openfortivpn..."
sudo setcap cap_net_admin+ep /usr/bin/openfortivpn

# 5. Golang Installation
echo "[5/7] Installing Golang 1.26.4..."
sudo rm -rf /usr/local/go
sudo mkdir -p /usr/local
curl -sSL https://go.dev/dl/go1.26.4.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -

sudo mkdir -p /etc/profile.d /etc/fish/conf.d
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh > /dev/null
echo 'fish_add_path /usr/local/go/bin' | sudo tee /etc/fish/conf.d/golang.fish > /dev/null

# 6. Standalone Tools Installation (Zellij, klog, kubelogin, Herdr, uv)
echo "[6/7] Installing standalone tools (Zellij, klog, kubelogin, Herdr, uv)..."

# Zellij multiplexer
curl -sSL https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | sudo tar -xz -C /usr/bin

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

# 7. Shell & Fish Helper Functions Configuration
echo "[7/7] Configuring Fish shell functions & prompts..."
sudo mkdir -p /usr/share/fish/vendor_functions.d/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../shell" ]; then
    sudo cp "$SCRIPT_DIR/../shell/fish_prompt.fish" \
            "$SCRIPT_DIR/../shell/fish_jj_prompt.fish" \
            "$SCRIPT_DIR/../shell/k8s_resources.fish" \
            /usr/share/fish/vendor_functions.d/ 2>/dev/null || true
fi

# Set default shell to fish for current user
echo "Setting fish as default shell for user '$USER'..."
sudo usermod -s /usr/bin/fish "$USER" || true

echo ""
echo "=================================================="
echo "   Setup Finished Successfully!                   "
echo "=================================================="
