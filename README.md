# <img src="https://fedoraproject.org/favicon.ico" alt="🎩" width="25"/> Fedora DevOps Environment with WSL 🐧

This project provides a fully-configured Fedora-based DevOps environment that can be loaded into Windows Subsystem for Linux (WSL). The environment includes essential tools for development 🛠️, system administration 🔧, and containerization 📦.

---

## ✨ Features

- **♻️ Rolling-Release Model**: Fedora is a cutting-edge 🧪, rolling-release distribution offering the latest 🔥 software updates and features. It is based on Red Hat Enterprise Linux (RHEL), making it familiar to professionals 👩‍💻 accustomed to the RHEL ecosystem.
- **⚙️ Systemd Integration**: Provides a realistic Linux environment with full `systemd` support, enabling seamless management of services.
- **📋 Pre-installed DevOps Tools**: Includes popular tools for development and operations:
  - **🐳 Docker**: For containerization and application deployment.
  - **☸️ Kubernetes CLI (`kubectl`)**: For Kubernetes cluster management.
  - **📦 Helm**: A package manager for Kubernetes.
  - **🏗️ Terraform**: For infrastructure provisioning.
  - **🤖 Ansible**: For configuration management and automation.
  - **🔐 Vault and Consul**: For secrets management and service discovery.
  - **🖥️ K9s**: For managing Kubernetes clusters with a terminal-based UI.
  - **🐧 Podman** and **🔨 Buildah**: Alternatives to Docker for container creation and management.
- **💻 Comprehensive Development Stack**: Offers a wide range of development tools, including:
  - Programming languages: 🐍 Python, 🟢 Node.js, ☕ Java, 💎 Ruby, 🔵 Go, 🦀 Rust, and 🔠 Perl.
  - Build tools: 🧱 CMake, Make, and GCC.
  - Database support: 🐬 MySQL, 🐘 PostgreSQL, 🍎 Redis, and 📄 SQLite.
- **🙌 User-Friendly Environment**: Enhanced productivity with Zsh, Oh-My-Zsh, and other utilities like Vim, Htop, and Fastfetch.

---

## ❓ Why Choose Fedora for DevOps?

- **🚀 Cutting-Edge Updates**: Fedora’s rolling-release model ensures you always have access to the latest 🔥 tools and technologies.
- **🤝 Familiarity with RHEL Ecosystem**: Fedora serves as the upstream source for RHEL, making it ideal for professionals already accustomed to Red Hat environments.
- **🛠️ Rich Toolset for DevOps**: This distribution includes an extensive range of tools pre-installed, reducing the setup overhead and allowing you to focus on productivity.

---

## 🛠️ Steps to Set Up WSL with Fedora

### 1️⃣ Enable WSL and Virtual Machine Platform

1. Open a PowerShell terminal **as Administrator**.
2. Run the following command:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux,VirtualMachinePlatform -All
   ```
3. Set WSL to use version 2:
   ```powershell
   wsl --set-default-version 2
   ```

---

### 2️⃣ Prepare the Fedora Root Filesystem

1. 🛠️ Build the Docker image for the Fedora DevOps environment:
   ```powershell
   docker build -t dvp-fedora .
   ```
2. 🐳 Run a Fedora container in Docker:
   ```powershell
   docker run -d --rm --name dvp_fedora_container dvp-fedora sleep infinity
   ```
3. 📸 Commit the container's current state to an image:
   ```powershell
   docker commit dvp_fedora_container dvp-fedora
   ```
4. 🐳 Run the updated Fedora image in a new container:
   ```powershell
   docker run -d --rm --name dvp_fedora_container_desired_state dvp-fedora sleep infinity
   ```
5. 📦 Export the container's filesystem:
   ```powershell
   docker export -o dvp-fedora-rootfs.tar dvp_fedora_container_desired_state
   ```
6. 🗑️ Remove the container:
   ```powershell
   docker rm -f dvp_fedora_container dvp_fedora_container_desired_state
   ```

---

### 3️⃣ Import Fedora into WSL

1. 📂 Create a directory for WSL:
   ```powershell
   mkdir C:\WSL\Fedora
   ```
2. 📥 Import the Fedora root filesystem:
   ```powershell
   wsl --import Fedora C:\WSL\Fedora .\dvp-fedora-rootfs.tar --version 2
   ```

---

### 4️⃣ Access the Fedora WSL Instance

1. 🖥️ Launch the Fedora environment:
   ```powershell
   wsl -d Fedora
   ```

---

### 5️⃣ Add Fedora Profile to Windows Terminal

If you're using Windows Terminal, you can add a custom profile for Fedora by editing your `settings.json` file:

```json
{
  "profiles": 
  {
    "list": 
    [
      {
        "commandline": "C:\\WINDOWS\\system32\\wsl.exe -d Fedora",
        "guid": "{ce4097f8-9101-44bb-a9c7-9fd4587cdec0}",
        "hidden": false,
        "icon": "https://fedoraproject.org/favicon.ico",
        "name": "Fedora",
        "startingDirectory": "~"
      }
    ]
  }
}
```

1. Open Windows Terminal.
2. Navigate to **Settings** ⚙️ > **Open JSON File** 📄.
3. Add the above profile to the `list` array in `profiles`.
4. Save 💾 and restart 🔄 Windows Terminal.

---

## 🔧 Extensibility and Customization

- **➕ Install Additional Tools**: Use Fedora's `dnf` package manager to install additional tools as needed.
  ```bash
  sudo dnf install <package-name>
  ```
- **🔄 Update Environment**: Keep your environment up-to-date with:
  ```bash
  sudo dnf update -y
  ```
- **🖌️ Custom Configuration**: Modify configurations (e.g., `.zshrc` or `.vimrc`) to suit your workflow.

---

## 🤝 Contributing

If you have ideas 💡 for improving this project or encounter issues 🐞, feel free to contribute or open a ticket in the repository. Collaboration 🤝 is always welcome!

