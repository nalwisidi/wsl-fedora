FROM fedora:latest

# Add repositories and install packages
COPY scripts/install_packages.sh /usr/local/bin/
RUN sh /usr/local/bin/install_packages.sh

# Configure WSL
RUN tee /etc/wsl.conf <<EOF > /dev/null
[network]
generateResolvConf = true
[boot]
systemd=true
EOF

# Add DevKit installation tool
COPY scripts/devkit /usr/local/bin/devkit
RUN chmod +x /usr/local/bin/devkit

# Prepare Zsh for Root
RUN tee /root/.zshrc <<EOF > /dev/null
[ -f /root/.initial_setup.sh ] && sh /root/.initial_setup.sh && exit 0
EOF
RUN chsh -s $(which zsh)

# Setup user environment
COPY scripts/setup /root/.initial_setup.sh

CMD ["/bin/zsh"]