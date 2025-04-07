FROM fedora:latest

# Enable optional repos
RUN curl -o /etc/yum.repos.d/hashicorp.repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo && \
  dnf copr enable -y emanuelec/k9s && \
  dnf copr enable -y lsevcik/lf

# Install essential WSL core packages
RUN dnf install -y \
  sudo passwd shadow-utils util-linux-user \
  dbus systemd systemd-container \
  iproute iputils hostname procps-ng which less man-db \
  curl wget rsync net-tools dnsutils traceroute bind-utils telnet nmap nc dnsmasq \
  zsh fzf zoxide bash-completion tzdata openssh gnupg2 \
  git git-lfs stow tree tmux htop btop unzip zip tar zstd jq yq fastfetch lf \
  vim-enhanced neovim glibc-langpack-en gum \
  && dnf clean all && rm -rf /var/cache/dnf /tmp/* /var/tmp/*

# Prepare Create User script
COPY scripts/create_user.sh /usr/local/bin/create_user
RUN chmod +x /usr/local/bin/create_user

# Set up default locale
RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8 || true && \
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# Enable ping without sudo
RUN setcap cap_net_raw+ep /bin/ping

RUN echo "[network]\ngenerateResolvConf = true\n[boot]\nsystemd=true" > /etc/wsl.conf

RUN tee -a /etc/zshrc > /dev/null <<EOF

# Run initial setup script once
if [ -f "\$HOME/.initial_setup.sh" ]; then
  bash "\$HOME/.initial_setup.sh"
  rm -f "\$HOME/.initial_setup.sh"
fi
EOF

CMD ["/bin/zsh"]
