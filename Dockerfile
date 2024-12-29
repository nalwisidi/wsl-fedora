# Base image
FROM fedora:latest

# Modify your username & password
ARG USERNAME=dvp
ARG PASSWORD=password

# Add the HashiCorp repository
RUN curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

# Add the K9s repository
RUN dnf copr enable -y emanuelec/k9s

# Add the LF repository
RUN dnf copr enable -y lsevcik/lf

# Define package groups
ARG BASE_PACKAGES="rsync wget curl vi vim neovim zsh zoxide fzf bash-completion tar unzip zip zstd top btop lf stow tmux tree fastfetch"
ARG DEV_LANGUAGES="python3 python3-pip nodejs npm java-21-openjdk ruby golang perl rust"
ARG CONTAINER_TOOLS="docker podman buildah"
ARG DEVOPS_TOOLS="kubectl k9s helm ansible terraform vault consul packer dnsmasq"
ARG NETWORK_TOOLS="net-tools telnet traceroute nmap nc bind-utils iputils"
ARG SCM_TOOLS="git git-lfs subversion"
ARG BUILD_TOOLS="cmake make autoconf automake libtool"
ARG DATABASE_TOOLS="mysql postgresql redis sqlite"
ARG JSON_TOOLS="jq yq"
ARG SYSTEM_TOOLS="systemd systemd-sysv systemd-container dbus passwd"

# Install core OS components using groups e.g. ("core" "system-tools")
RUN dnf update -y && \
    dnf group install -y "development-tools"

# Update and install all packages
RUN dnf install -y \
    $BASE_PACKAGES \
    $DEV_LANGUAGES \
    $CONTAINER_TOOLS \
    $DEVOPS_TOOLS \
    $NETWORK_TOOLS \
    $SCM_TOOLS \
    $BUILD_TOOLS \
    $DATABASE_TOOLS \
    $JSON_TOOLS \
    $SYSTEM_TOOLS && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Configure WSL settings
RUN echo -e "[user]\ndefault=$USERNAME\n[network]\ngenerateResolvConf = true\n[boot]\nsystemd=true" > /etc/wsl.conf

# Install ArgoCD CLI
RUN curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    chmod +x /usr/local/bin/argocd

# Create a new user and set it up
RUN useradd -m -s /bin/zsh $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "$USERNAME:$PASSWORD" | chpasswd

# Configure Docker (enable service and add root & local user to the Docker group)
RUN systemctl enable docker && \
    gpasswd -M root,$USERNAME docker

# Expose common ports for services (optional)
EXPOSE 22 80 443 3306 5432 6379

# Switch to the new user by default
USER $USERNAME

# Setup dotfiles
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/nalwisidi/dotfiles/main/bootstrap.sh)"

# Set ZSH as the default shell
RUN sudo chsh -s $(which zsh)

# Prepare NvChad (nvim)
RUN echo "Installing NvChad plugins and tools..." && \
    nvim --headless "+Lazy! sync" +qa

# Prepare Tmux
ENV TMUX_PLUGIN_MANAGER_PATH="/home/${USERNAME}/.config/tmux/plugins"
RUN sh ${TMUX_PLUGIN_MANAGER_PATH}/tpm/scripts/install_plugins.sh

# Default command
CMD ["/bin/zsh"]