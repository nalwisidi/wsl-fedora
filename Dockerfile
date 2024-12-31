FROM fedora:latest

# Package groups
ARG BASE_PACKAGES="git rsync wget curl vi vim neovim zsh zoxide fzf jq yq tar unzip zip zstd top btop lf stow tmux tree fastfetch dos2unix"
ARG DEVOPS_TOOLS="docker podman kubectl k9s helm ansible terraform vault consul packer dnsmasq"
ARG NETWORK_TOOLS="net-tools telnet traceroute nmap nc bind-utils iputils"
ARG SYSTEM_TOOLS="systemd systemd-sysv systemd-container dbus passwd cmake make autoconf automake libtool"

RUN curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo && \
    dnf copr enable -y emanuelec/k9s && \
    dnf copr enable -y lsevcik/lf && \
    dnf install -y --nodocs --setopt=install_weak_deps=False $BASE_PACKAGES $DEVOPS_TOOLS $NETWORK_TOOLS $SYSTEM_TOOLS && \
    dnf clean all && \
    rm -rf /var/cache/dnf /tmp/* /var/tmp/* /usr/share/{man,info,doc} && \
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    curl -sSL -o /usr/local/bin/kubectx https://github.com/ahmetb/kubectx/releases/latest/download/kubectx && \
    curl -sSL -o /usr/local/bin/kubens https://github.com/ahmetb/kubectx/releases/latest/download/kubens && \
    chmod +x /usr/local/bin/{argocd,kubectx,kubens} && \
    echo -e "[network]\ngenerateResolvConf = true\n[boot]\nsystemd=true" > /etc/wsl.conf && \
    chsh -s $(which zsh)


# Prepare Development Kit installation tool
RUN DEST="/usr/local/bin/devkit" && tee $DEST <<EOF > /dev/null && dos2unix $DEST && chmod +x $DEST
#!/bin/bash
DEV_TOOLS="python3 python3-pip nodejs npm java-21-openjdk ruby golang perl rust buildah git-lfs subversion mysql postgresql redis sqlite"
if [[ "\$1" == "install" ]]; then
  echo "Installing tools..."
  sudo dnf update -y && sudo dnf group install -y "development-tools"
  sudo dnf install -y $DEV_TOOLS && sudo dnf clean all && sudo rm -rf /var/cache/dnf
  echo "Installation complete!"
elif [[ "\$1" == "remove" ]]; then
  echo "Removing tools..."
  sudo dnf remove -y $DEV_TOOLS && sudo dnf clean all && sudo rm -rf /var/cache/dnf
  sudo systemctl disable --now docker && sudo groupdel docker
  echo "Removal complete!"
else
  echo "Usage: devkit {install|remove}"
  exit 1
fi
EOF

# Prepare Zsh
RUN DEST="/root/.zshrc" && tee $DEST <<EOF > /dev/null && dos2unix $DEST
[ -f /root/.setup_user.sh ] && /root/.setup_user.sh && exit 0
EOF
# User Setup Script
RUN DEST="/root/.setup_user.sh" && tee $DEST <<EOF > /dev/null && dos2unix $DEST && chmod +x $DEST
#!/bin/bash
MARKER_FILE="/root/.wsl_welcome_shown"
if [[ ! -f "\$MARKER_FILE" ]]; then
  cat <<'POSTER'
🎩 Welcome to Fedora DevOps Environment 🎩

This is your fully-configured Fedora-based DevOps environment.
- Built for productivity 🛠️
- Preloaded with essential tools 🔧
- Tailored for containerization 📦 and cloud-native development ☁️

✨ Fedora DevOps Features:
- A modern, developer-focused WSL environment.
- Prebuilt DevOps tools for seamless operations.
- Enhanced productivity with advanced terminal utilities.

🚀 Introducing DevKit:
DevKit is your all-in-one toolkit for developers. It simplifies your workflow with:
- Popular programming languages (Python, Node.js, Ruby, etc.).
- Essential build tools (CMake, GCC, Make).
- Comprehensive database support (MySQL, PostgreSQL, SQLite, Redis).

📜 Available Commands:
    devkit install => Install all development tools
    devkit remove  => Remove all installed tools

💡 Tips:
- Use \`sudo dnf install <package>\` to install additional tools.
- Use \`sudo dnf update\` to keep your environment up-to-date.
- Customize your environment in \`~/.zshrc\`.

Enjoy your DevOps journey 🚀!
POSTER
  touch "\$MARKER_FILE"
  while true; do
    read -p "Enter new UNIX username: " USERNAME
    [[ -z "\$USERNAME" ]] && echo "USERNAME cannot be empty." && continue
    id "\$USERNAME" &>/dev/null && echo "User \$USERNAME exists." && continue
    useradd -m "\$USERNAME" && break || echo "Failed to create user. Try again."
  done
  while true; do
    passwd "\$USERNAME" && echo "User \$USERNAME created successfully." && break
    echo "Password setup failed. Try again."
  done
  echo "\$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  systemctl enable --now docker && sudo gpasswd -M root,$USERNAME docker
  echo -e "[user]\ndefault=\$USERNAME\n\n[network]\ngenerateResolvConf = true\n\n[boot]\nsystemd=true" > /etc/wsl.conf
  chmod 644 /etc/wsl.conf
  chsh -s $(which zsh) "\$USERNAME"
  su - "\$USERNAME" -c 'curl -fsSL https://raw.githubusercontent.com/nalwisidi/dotfiles/main/bootstrap.sh | sh'
  su - "\$USERNAME" --shell /bin/zsh -c "source ~/.zprofile && source ~/.config/zsh/.zshrc"
  su - "\$USERNAME" --shell /bin/zsh
else
  su - "\$(getent passwd | awk -F: '\$3==1000 {print \$1}')" --shell /bin/zsh
fi
EOF

CMD ["/bin/zsh"]