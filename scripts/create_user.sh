#!/bin/bash

echo -n "Enter new UNIX username: "
read username

useradd -m -s /bin/zsh "$username"
echo "Set password for $username:"
passwd "$username"
usermod -aG wheel "$username"
echo "$username" > /username_created

cat <<'EOF' > "/home/$username/.initial_setup.sh"
#!/bin/bash
echo "[bootstrap] running initial setup..."
curl -fsSL https://raw.githubusercontent.com/nalwisidi/wsl-fedora/main/scripts/bootstrap.sh | bash
EOF

chmod +x "/home/$username/.initial_setup.sh"
chown "$username:$username" "/home/$username/.initial_setup.sh"
#!/bin/bash

echo -n "Enter new UNIX username: "
read username

useradd -m -s /bin/zsh "$username"
echo "Set password for $username:"
passwd "$username"
usermod -aG wheel "$username"
echo "$username" > /username_created

cat <<'EOF' > "/home/$username/.initial_setup.sh"
#!/bin/bash
echo "[bootstrap] running initial setup..."
curl -fsSL https://raw.githubusercontent.com/nalwisidi/wsl-fedora/main/scripts/bootstrap.sh | bash
EOF

chmod +x "/home/$username/.initial_setup.sh"
chown "$username:$username" "/home/$username/.initial_setup.sh"