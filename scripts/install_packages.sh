#!/bin/bash

BASE_PACKAGES="git rsync wget curl vi vim neovim zsh zoxide fzf jq yq tar unzip zip zstd top btop lf stow tmux tree fastfetch dos2unix"
DEVOPS_TOOLS="docker podman kubectl k9s helm ansible terraform vault consul packer dnsmasq"
NETWORK_TOOLS="net-tools telnet traceroute nmap nc bind-utils iputils"
SYSTEM_TOOLS="systemd systemd-sysv systemd-container dbus passwd cmake make autoconf automake libtool"

echo "Installing packages..."
curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
dnf copr enable -y emanuelec/k9s
dnf copr enable -y lsevcik/lf
dnf install -y --nodocs --setopt=install_weak_deps=False $BASE_PACKAGES $DEVOPS_TOOLS $NETWORK_TOOLS $SYSTEM_TOOLS
dnf clean all
rm -rf /var/cache/dnf /tmp/* /var/tmp/* /usr/share/{man,info,doc}

# Install additional tools
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
curl -sSL -o /usr/local/bin/kubectx https://github.com/ahmetb/kubectx/releases/latest/download/kubectx
curl -sSL -o /usr/local/bin/kubens https://github.com/ahmetb/kubectx/releases/latest/download/kubens
chmod +x /usr/local/bin/{argocd,kubectx,kubens}

# Remove the install_packages.sh file
rm -f /usr/local/bin/install_packages.sh