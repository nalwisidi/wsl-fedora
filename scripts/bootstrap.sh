#!/bin/bash
set -euo pipefail

LOG_FILE="$HOME/.bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "──────────────────────────────────────────────"
echo "🛠️  Starting WSL Fedora Bootstrap"
echo "Log file: $LOG_FILE"
echo "──────────────────────────────────────────────"

# 1. Role selection (multi-select)
ROLES=$(gum choose --no-limit --header "[?] Pick your roles (multi-select):" \
  "DevOps" "Developer" "DBA" "Minimal")

echo "[+] Selected roles: $ROLES"

# 2. Define role-based packages
BASE_PACKAGES="cmake make autoconf automake libtool"
DEVOPS_PACKAGES="kubectl helm k9s ansible terraform vault packer"
DEVELOPER_PACKAGES="nodejs npm python3 python3-pip java-21-openjdk ruby golang perl rust"
DBA_PACKAGES="mysql postgresql sqlite redis"

# 3. Check if only "Minimal" was selected
if [[ "$ROLES" == "Minimal" ]]; then
  echo "[i] 'Minimal' selected — skipping package installation."
  echo "✅ Bootstrap completed."
  exit 0
fi

# 4. Aggregate selected role packages
ROLE_PACKAGES=""

for role in $ROLES; do
  case "$role" in
    "DevOps") ROLE_PACKAGES+=" $DEVOPS_PACKAGES" ;;
    "Developer") ROLE_PACKAGES+=" $DEVELOPER_PACKAGES" ;;
    "DBA") ROLE_PACKAGES+=" $DBA_PACKAGES" ;;
  esac
done

# 5. Install role-based packages
if gum confirm "→ Install selected role packages?"; then
  echo "[+] Installing: $BASE_PACKAGES $ROLE_PACKAGES"
  sudo dnf install -y $BASE_PACKAGES $ROLE_PACKAGES
else
  echo "[-] Skipped role package installation."
fi

# 6. Additional DevOps setup
if echo "$ROLES" | grep -q "DevOps"; then
  echo "[+] Running additional DevOps setup..."

  echo "[+] Installing argocd, kubectx, and kubens..."
  sudo url -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo curl -sSL -o /usr/local/bin/kubectx https://github.com/ahmetb/kubectx/releases/latest/download/kubectx
  sudo curl -sSL -o /usr/local/bin/kubens https://github.com/ahmetb/kubectx/releases/latest/download/kubens
  sudo chmod +x /usr/local/bin/{argocd,kubectx,kubens}

  echo "[+] Installing OCI CLI via pip..."
  pip install oci-cli

  echo "[+] Installing AWS CLI via pip..."
  pip install awscli

  echo "[+] Configuring and installing Google Cloud CLI..."
  sudo tee /etc/yum.repos.d/google-cloud-sdk.repo > /dev/null <<EOF
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

  sudo dnf install -y google-cloud-cli --nogpgcheck
fi

# # 7. Customize environment
# if gum confirm "[?] Customize your environment? (neovim, tmux, zsh, git, k9s, lf, and more..)"; then
#   # TODO
# else
#   echo "[-] Skipping customization."
# fi

echo "✅ Bootstrap completed at $(date)"