# Building the Fedora DevOps Environment for WSL

This document provides detailed steps to build the Fedora DevOps environment, package it as a WSL-compatible tarball, and import it into WSL.

---

## 🔧 Prerequisites

- Docker installed on your system.
- Basic knowledge of PowerShell and WSL.

---

## 1️⃣ Enable WSL and Virtual Machine Platform

1. Open a PowerShell terminal **as Administrator**.
2. Enable WSL and the Virtual Machine Platform:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux,VirtualMachinePlatform -All
   ```
3. Set WSL to use version 2:
   ```powershell
   wsl --set-default-version 2
   ```

---

## 2️⃣ Build the Fedora Root Filesystem

1. **Build the Docker image**:
   ```powershell
   docker build -t dvp-fedora .
   ```
2. **Run a Fedora container**:
   ```powershell
   docker run -d --rm --name dvp_fedora_container dvp-fedora sleep infinity
   ```
3. **Commit the container's state**:
   ```powershell
   docker commit dvp_fedora_container dvp-fedora
   ```
4. **Export the container's filesystem**:
   ```powershell
   docker export -o dvp-fedora-rootfs.tar dvp_fedora_container
   ```

---

## 3️⃣ Import Fedora into WSL

1. **Create a directory for WSL**:
   ```powershell
   mkdir C:\WSL\Fedora
   ```
2. **Import the Fedora root filesystem**:
   ```powershell
   wsl --import Fedora C:\WSL\Fedora .\dvp-fedora-rootfs.tar --version 2
   ```

---

## 4️⃣ Optional: Add a Profile to Windows Terminal

1. Open Windows Terminal and navigate to `Settings` > `Open JSON file`.
2. Add the following profile to the `list` array under `profiles`:
   ```json
   {
     "name": "Fedora",
     "commandline": "wsl.exe -d Fedora",
     "icon": "https://fedoraproject.org/favicon.ico",
     "startingDirectory": "~",
     "hidden": false
   }
   ```
3. Save and restart Windows Terminal.

---

## 5️⃣ Run Fedora WSL

1. Launch the Fedora environment:
   ```powershell
   wsl -d Fedora
   ```
2. Enjoy your fully-configured Fedora-based DevOps environment!

---

## 🔧 Customization and Extensibility

- Install additional tools:
  ```bash
  sudo dnf install <package-name>
  ```
- Update the environment:
  ```bash
  sudo dnf update -y
  ```
- Customize `.zshrc` or other configuration files to suit your workflow.

---

## 🤝 Contributing

Contributions are welcome! Feel free to submit pull requests or open issues with suggestions.
