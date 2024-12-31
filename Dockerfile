FROM fedora:latest

# Modify username & password
ARG USERNAME=dvp
ARG PASSWORD=password

# Package groups
ARG BASE_PACKAGES="git rsync wget curl vi vim neovim zsh zoxide fzf jq yq tar unzip zip zstd top btop lf stow tmux tree fastfetch dos2unix"
ARG DEVOPS_TOOLS="podman kubectl k9s helm ansible terraform vault consul packer dnsmasq"
ARG NETWORK_TOOLS="net-tools telnet traceroute nmap nc bind-utils iputils"
ARG SYSTEM_TOOLS="systemd systemd-sysv systemd-container dbus passwd"

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
    useradd -m -s /bin/zsh $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "$USERNAME:$PASSWORD" | chpasswd && \
    echo -e "[user]\ndefault=$USERNAME\n[network]\ngenerateResolvConf = true\n[boot]\nsystemd=true" > /etc/wsl.conf && \
    find /home/${USERNAME}/ -mindepth 1 ! -name '.zprofile' -exec rm -f {} +

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

# Prepare Zsh
RUN DEST="/home/${USERNAME}/.zsh" && tee $DEST <<EOF > /dev/null && dos2unix $DEST
sh -c "$(curl -fsSL https://raw.githubusercontent.com/nalwisidi/dotfiles/main/bootstrap.sh)"
source ~/.zshrc
EOF

USER $USERNAME

CMD ["/bin/zsh"]