FROM fedora:latest

# Add repositories, install packages and configure WSL
COPY scripts/docker_build.sh /usr/local/bin/
RUN sh /usr/local/bin/docker_build.sh

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