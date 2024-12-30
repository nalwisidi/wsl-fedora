# Stage 1: Builder
FROM fedora:latest AS builder

# Add repositories
RUN curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo && \
    dnf copr enable -y emanuelec/k9s && \
    dnf copr enable -y lsevcik/lf

# Define package groups
ARG BASE_PACKAGES="git rsync wget curl vi vim neovim zsh zoxide fzf jq yq tar unzip zip zstd top btop lf stow tmux tree fastfetch dos2unix"
ARG DEVOPS_TOOLS="podman kubectl k9s helm ansible terraform vault consul packer dnsmasq"
ARG NETWORK_TOOLS="net-tools telnet traceroute nmap nc bind-utils iputils"
ARG SYSTEM_TOOLS="systemd systemd-sysv systemd-container dbus passwd"

RUN dnf update -y && \
    dnf install -y $BASE_PACKAGES $DEVOPS_TOOLS $NETWORK_TOOLS $SYSTEM_TOOLS && \
    dnf clean all && rm -rf /var/cache/dnf /tmp/* /var/tmp/*

# Install ArgoCD CLI, KubeCTX & KubeNS
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    curl -sSL -o /usr/local/bin/kubectx https://github.com/ahmetb/kubectx/releases/latest/download/kubectx && \
    curl -sSL -o /usr/local/bin/kubens https://github.com/ahmetb/kubectx/releases/latest/download/kubens && \
    chmod +x /usr/local/bin/{argocd,kubectx,kubens}

# Stage 2: Runtime
FROM fedora:latest AS runtime

# Copy installed tools from the builder stage
COPY --from=builder /usr /usr
COPY --from=builder /etc /etc

# Modify your username & password per your preference
ARG USERNAME=dvp
ARG PASSWORD=password

# Create a new user and set it up
RUN useradd -m -s /bin/zsh $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "$USERNAME:$PASSWORD" | chpasswd

# Configure WSL settings
RUN echo -e "[user]\ndefault=$USERNAME\n[network]\ngenerateResolvConf = true\n[boot]\nsystemd=true" > /etc/wsl.conf

# Prepare Development Kit installation tool
RUN DEST="/usr/local/bin/devkit" && tee $DEST <<EOF > /dev/null && dos2unix $DEST && chmod +x $DEST
#!/bin/bash
DEV_TOOLS="python3 python3-pip nodejs npm java-21-openjdk ruby golang perl rust docker buildah git-lfs subversion mysql postgresql redis sqlite"
EXTRA_TOOLS="cmake make autoconf automake libtool"
if [[ "\$1" == "install" ]]; then
  echo "Installing tools..."
  sudo dnf update -y && sudo dnf group install -y "development-tools"
  sudo dnf install -y $DEV_TOOLS $EXTRA_TOOLS && sudo dnf clean all && sudo rm -rf /var/cache/dnf
  sudo systemctl enable --now docker && sudo gpasswd -M root,$USER docker
  echo "Installation complete!"
elif [[ "\$1" == "remove" ]]; then
  echo "Removing tools..."
  sudo dnf remove -y $DEV_TOOLS $EXTRA_TOOLS && sudo dnf clean all && sudo rm -rf /var/cache/dnf
  sudo systemctl disable --now docker && sudo groupdel docker
  echo "Removal complete!"
else
  echo "Usage: devkit {install|remove}"
  exit 1
fi
EOF

# Switch to the new user by default
USER $USERNAME

# Setup dotfiles
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/nalwisidi/dotfiles/main/bootstrap.sh)"

# Set ZSH as the default shell
RUN sudo chsh -s $(which zsh)

# Prepare NvChad (nvim)
RUN echo "Installing NvChad plugins and tools..." && nvim --headless "+Lazy! sync" +qa

# Prepare Tmux
ENV TMUX_PLUGIN_MANAGER_PATH="/home/${USERNAME}/.config/tmux/plugins"
RUN sh ${TMUX_PLUGIN_MANAGER_PATH}/tpm/scripts/install_plugins.sh

# Expose common ports for services (optional)
EXPOSE 22 80 443 3306 5432 6379

# Set default command to show the poster and then start zsh
CMD ["/bin/zsh"]