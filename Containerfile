FROM ghcr.io/zirconium-dev/zirconium-nvidia:latest

# ANSSI BP-028 Linux Hardening
# Point 1 & 2: Kernel/Network Hardening and Core Dumps restriction
RUN mkdir -p /usr/lib/sysctl.d /etc/security/limits.d && \
    ( \
    echo "# Kernel Hardening" && \
    echo "kernel.dmesg_restrict=1" && \
    echo "kernel.kptr_restrict=2" && \
    echo "kernel.randomize_va_space=2" && \
    echo "fs.suid_dumpable=0" && \
    echo "" && \
    echo "# Network Hardening" && \
    echo "net.ipv4.ip_forward=0" && \
    echo "net.ipv6.conf.all.forwarding=0" && \
    echo "net.ipv4.conf.all.rp_filter=1" && \
    echo "net.ipv4.conf.default.rp_filter=1" && \
    echo "net.ipv4.conf.all.accept_redirects=0" && \
    echo "net.ipv4.conf.default.accept_redirects=0" && \
    echo "net.ipv6.conf.all.accept_redirects=0" && \
    echo "net.ipv6.conf.default.accept_redirects=0" && \
    echo "net.ipv4.conf.all.send_redirects=0" && \
    echo "net.ipv4.conf.default.send_redirects=0" \
    ) > /usr/lib/sysctl.d/10-anssi-hardening.conf && \
    echo "* hard core 0" > /etc/security/limits.d/10-prevent-coredumps.conf

# Point 3: Enforce a Secure Default Umask (0027)
RUN echo "umask 0027" >> /etc/bashrc && \
    echo "umask 0027" >> /etc/profile

# Point 4: Lock Inactive/System Accounts (UID < 1000)
RUN awk -F: '($3 < 1000 && $1 != "root") {print $1}' /etc/passwd | \
    while read -r user; do \
    usermod -s /sbin/nologin "$user" 2>/dev/null || true; \
    done

#Install custom packages
RUN dnf install -y git vim firefox fish zed lynis openscap-scanner scap-security-guide dnf-plugins-core nodejs npm seahorse keepassxc && \
    dnf copr enable -y aldantanneo/jj-vcs && \
    dnf install -y jj-cli curl openfortivpn jq




RUN setcap cap_net_admin+ep /usr/bin/openfortivpn

#Clean after install
RUN dnf clean all

#Customize shell (switch to fish)
RUN usermod -s /usr/bin/fish root
RUN sed -i 's|^SHELL=.*|SHELL=/usr/bin/fish|' /etc/default/useradd

# Ensure all users are part of the vboxsf group for shared folder mounting
RUN (getent group vboxsf >/dev/null || groupadd -r vboxsf) && \
    getent passwd | cut -d: -f1 | while read -r user; do usermod -aG vboxsf "$user" 2>/dev/null || true; done && \
    mkdir -p /etc/shadow-maint/useradd-post.d && \
    ( \
    echo '#!/bin/sh' && \
    echo 'getent group vboxsf >/dev/null || groupadd -r vboxsf' && \
    echo 'usermod -aG vboxsf "$SUBJECT"' \
    ) > /etc/shadow-maint/useradd-post.d/01-vboxsf && \
    chmod +x /etc/shadow-maint/useradd-post.d/01-vboxsf

# Install Antigravity
COPY assets/Antigravity.tar.gz /tmp/
RUN tar -xzf /tmp/Antigravity.tar.gz -C /usr/lib/ && \
    mv /usr/lib/Antigravity-x64 /usr/lib/Antigravity && \
    chown root:root /usr/lib/Antigravity/chrome-sandbox && \
    chmod 4755 /usr/lib/Antigravity/chrome-sandbox && \
    ln -s /usr/lib/Antigravity/antigravity /usr/bin/antigravity && \
    rm /tmp/Antigravity.tar.gz

# Set system-wide environment variables for all users
RUN mkdir -p /usr/lib/environment.d && \
    echo "ELECTRON_OZONE_PLATFORM_HINT=auto" >> /usr/lib/environment.d/10-zirconium-custom.conf && \
    echo "ZED_ALLOW_EMULATED_GPU=1" >> /usr/lib/environment.d/10-zirconium-custom.conf && \
    echo "AZURE_EXTENSION_DIR=/usr/lib/azure-cli-extensions" >> /usr/lib/environment.d/10-zirconium-custom.conf

# Create desktop entry for Antigravity launcher
RUN mkdir -p /usr/share/applications && \
    ( \
    echo "[Desktop Entry]" && \
    echo "Name=Antigravity" && \
    echo "Comment=AI-powered agentic development platform" && \
    echo "Exec=antigravity --ozone-platform-hint=auto" && \
    echo "Icon=system-run" && \
    echo "Terminal=false" && \
    echo "Type=Application" && \
    echo "Categories=Development;IDE;" \
    ) > /usr/share/applications/antigravity.desktop

# Install DankBar widget (openfortivpn) and system-wide default settings
COPY Widgets/ /etc/xdg/quickshell/dms-plugins/openfortivpn/
COPY config/settings.json /usr/share/zirconium/zdots/dot_config/DankMaterialShell/settings.json
COPY scripts/niri-macos-maximize.py /usr/bin/niri-macos-maximize.py
RUN chmod +x /usr/bin/niri-macos-maximize.py
COPY config/local.kdl /usr/share/zirconium/zdots/dot_config/niri/local.kdl
COPY config/foot/foot.ini /usr/share/zirconium/zdots/dot_config/foot/foot.ini




RUN dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo && \
    dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
RUN dnf install -y glab gh terraform && dnf clean all

# Install OpenAI Codex CLI and Zed ACP adapter
RUN HOME=/tmp npm install -g --prefix=/usr @openai/codex @zed-industries/codex-acp

# Install Kubernetes tools, Azure CLI, Pandoc, and Azure CLI extensions
RUN echo -e "[kubernetes]\nname=Kubernetes\nbaseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/\nenabled=1\ngpgcheck=1\ngpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key" > /etc/yum.repos.d/kubernetes.repo && \
    echo -e "[google-cloud-cli]\nname=Google Cloud CLI\nbaseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el10-x86_64\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=0\ngpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key-v10.gpg" > /etc/yum.repos.d/google-cloud-sdk.repo && \
    dnf install -y azure-cli google-cloud-cli kubectl helm pandoc libxcrypt-compat gcc python3-devel python3-pip libsodium-devel && \
    echo -e "[global]\nbreak-system-packages = true" > /etc/pip.conf && \
    mkdir -p /usr/lib/azure-cli-extensions && \
    AZURE_EXTENSION_DIR=/usr/lib/azure-cli-extensions HOME=/tmp az extension add --name k8s-extension && \
    AZURE_EXTENSION_DIR=/usr/lib/azure-cli-extensions HOME=/tmp az extension add --name connectedk8s && \
    curl -L -o /tmp/kubelogin.zip https://github.com/Azure/kubelogin/releases/download/v0.2.18/kubelogin-linux-amd64.zip && \
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/kubelogin.zip').extract('bin/linux_amd64/kubelogin', '/tmp')" && \
    mv /tmp/bin/linux_amd64/kubelogin /usr/bin/kubelogin && \
    rm -rf /tmp/kubelogin.zip /tmp/bin /etc/pip.conf && \
    dnf remove -y gcc python3-devel python3-pip libsodium-devel && \
    dnf autoremove -y && \
    dnf clean all

# Copy system-wide fish prompt configuration and helper functions
COPY shell/fish_prompt.fish shell/fish_jj_prompt.fish shell/k8s_resources.fish /usr/share/fish/vendor_functions.d/

# Install Zellij
RUN curl -L https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/bin

# Install klog CLI tool
RUN curl -L -o /tmp/klog.zip https://github.com/jotaen/klog/releases/latest/download/klog-linux.zip && \
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/klog.zip').extract('klog', '/usr/bin')" && \
    chmod +x /usr/bin/klog && \
    rm /tmp/klog.zip

# Install klog Zed extension system-wide for new user profiles
RUN git clone https://github.com/QuentinRob/klog-zed-extension.git /usr/share/zirconium/zdots/dot_local/share/zed/extensions/installed/klog

# Install Golang manually
RUN rm -rf /usr/lib/go && \
    curl -L https://go.dev/dl/go1.26.4.linux-amd64.tar.gz | tar -C /usr/lib -xzf -

# Add Go to system-wide PATH for bash/sh and fish
RUN mkdir -p /etc/profile.d /etc/fish/conf.d && \
    echo 'export PATH=$PATH:/usr/lib/go/bin' > /etc/profile.d/golang.sh && \
    echo 'fish_add_path /usr/lib/go/bin' > /etc/fish/conf.d/golang.fish

# Install herdr
RUN curl -fsSL https://herdr.dev/install.sh | HERDR_INSTALL_DIR=/usr/bin sh

