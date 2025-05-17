#!/bin/bash
set -euo pipefail

LOG_FILE="$HOME/.bootstrap.log"

# Save original stdout/stderr
exec 3>&1 4>&2

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "──────────────────────────────────────────────"
echo "🛠️ Bootstrapping Fedora WSL Environment"
echo "📄 Logging to: $LOG_FILE"
echo "──────────────────────────────────────────────"

# ──[ Temporarily disable logging for gum ]──
exec 1>&3 2>&4  # Restore stdout/stderr

ROLES=$(gum choose --no-limit --header "🎯 Pick your roles (multi-select):" \
  "DevOps" "Developer" "DBA" "Minimal")

# ──[ Resume logging ]──
exec > >(tee -a "$LOG_FILE") 2>&1

echo "✅ Selected roles: $ROLES"

# 2. Define role-based packages
BASE_PACKAGES="cmake make autoconf automake libtool python3 python3-pip"
DEVOPS_PACKAGES="gh glab docker podman buildah kubectl helm k9s ansible terraform vault consul packer"
DEVELOPER_PACKAGES="nodejs npm java-21-openjdk ruby golang perl rust"
DBA_PACKAGES="mysql postgresql sqlite redis"

# 3. Minimal-only mode
if [[ "$ROLES" == "Minimal" ]]; then
  echo "ℹ️ 'Minimal' selected — skipping package installation."
else
  # 4. Build install list
  ROLE_PACKAGES=""
  for role in $ROLES; do
    case "$role" in
      "DevOps") ROLE_PACKAGES+=" $DEVOPS_PACKAGES" ;;
      "Developer") ROLE_PACKAGES+=" $DEVELOPER_PACKAGES" ;;
      "DBA") ROLE_PACKAGES+=" $DBA_PACKAGES" ;;
    esac
  done

  # 5. Install packages
  if gum confirm "📦 Install selected packages?"; then
    echo "🔧 Installing base + role packages..."
    sudo dnf install -y $BASE_PACKAGES $ROLE_PACKAGES
  else
    echo "⏭️ Skipping package installation."
  fi

  # 6. Extra DevOps tools
  if echo "$ROLES" | grep -q "DevOps"; then
    echo "🔩 Setting up additional DevOps tools..."

    echo "📥 Installing argocd, kubectx, and kubens..."
    sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo curl -sSL -o /usr/local/bin/kubectx https://github.com/ahmetb/kubectx/releases/latest/download/kubectx
    sudo curl -sSL -o /usr/local/bin/kubens https://github.com/ahmetb/kubectx/releases/latest/download/kubens
    sudo chmod +x /usr/local/bin/{argocd,kubectx,kubens}

    echo "📥 Installing OCI CLI..."
    pip install oci-cli

    echo "📥 Installing AWS CLI..."
    pip install awscli

    echo "🔧 Configuring Google Cloud CLI repo..."
    sudo tee /etc/yum.repos.d/google-cloud-sdk.repo > /dev/null <<EOF
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

    echo "📥 Installing Google Cloud CLI..."
    sudo dnf install -y google-cloud-cli --nogpgcheck
  fi
fi

# 7. Ensure Zsh is installed and fallback configured
echo "🛠️ Ensuring zsh is installed..."

if ! command -v zsh &> /dev/null; then
  echo "📦 Installing zsh..."
  sudo dnf install -y zsh
fi

ZSHRC="$HOME/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
  echo "📄 Creating fallback .zshrc with simple prompt..."
  cat > "$ZSHRC" <<'EOF'
# Fallback prompt: current path then >
PROMPT='%~\n> '
EOF
else
  echo "⏩ .zshrc already exists — skipping fallback prompt setup."
fi

if [[ "$SHELL" != "$(which zsh)" ]]; then
  echo "🔄 Changing default shell to zsh..."
  chsh -s "$(which zsh)" || echo "⚠️  Could not change shell automatically. Run: chsh -s $(which zsh)"
fi

# 8. Environment customization
if gum confirm "🎨 Customize environment? (neovim, tmux, zsh, git, etc.)"; then
  echo "✨ Applying dotfiles..."
  curl -fsSL https://raw.githubusercontent.com/nalwisidi/dotfiles/main/bootstrap.sh | sh
else
  echo "⏩ Skipping customization."
fi

echo "🏁 Bootstrap finished at $(date)"