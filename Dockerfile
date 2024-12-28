# Base image
FROM fedora:latest

# Modify your username & password
ARG USERNAME=devops
ARG PASSWORD=password

# Add the HashiCorp repository
RUN curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

# Add the K9s repository
RUN dnf copr enable emanuelec/k9s -y

# Define package groups
ARG BASE_PACKAGES="rsync wget curl vim zsh bash-completion tar unzip zip zstd htop tmux tree fastfetch"
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
RUN echo -e "[user]\ndefault=$USERNAME\n[network]\ngenerateResolvConf = false\n[boot]\nsystemd=true" > /etc/wsl.conf

# Disable resolv.conf generation
RUN systemctl disable systemd-resolved

# Create a systemd service with embedded script logic (Workaround to make DNS work out of the box in WSL)
RUN tee /etc/systemd/system/fix-resolv.service <<EOF
[Unit]
Description=Fix /etc/resolv.conf if empty or missing
After=network.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
  if [[ ! -f "/etc/resolv.conf" || ! -s "/etc/resolv.conf" ]]; then \
    echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 169.254.169.254" > /etc/resolv.conf; \
    echo "DNS configuration updated in /etc/resolv.conf."; \
  else \
    echo "/etc/resolv.conf already exists and is not empty. No changes made."; \
  fi'
[Install]
WantedBy=multi-user.target
EOF

# Enable the service
RUN systemctl enable fix-resolv.service

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

# Set Zsh as the default shell and install Oh-My-Zsh
RUN sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)" && \
    sudo chsh -s $(which zsh)

# Default command
CMD ["/bin/zsh"]