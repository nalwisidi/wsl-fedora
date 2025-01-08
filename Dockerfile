FROM fedora:latest

# Add repositories, install packages and configure WSL
COPY scripts/docker_build /usr/local/bin/
RUN sh /usr/local/bin/docker_build

# Prepare Zsh for Root
RUN tee /root/.zshrc <<EOF > /dev/null
[ -f /root/.initial_setup.sh ] && sh /root/.initial_setup.sh && exit 0
EOF
RUN chsh -s $(which zsh)

# Setup user environment
COPY scripts/welcome_setup /root/.initial_setup.sh

CMD ["/bin/zsh"]