# <img src="https://fedoraproject.org/favicon.ico" alt="🎩" width="25"/> Fedora DevOps Environment with WSL 🐧

This project provides a fully-configured Fedora-based DevOps environment that can be loaded into Windows Subsystem for Linux (WSL). It includes essential tools for development, system administration, and containerization.

---

## ✨ Features

- **Systemd Integration**: Full `systemd` support for a realistic Linux experience.
- **Pre-installed DevOps Tools**: Includes Docker, Kubernetes CLI (`kubectl`), Helm, Terraform, Ansible, Vault, Consul, and more.
- **Cutting-Edge Updates**: Based on Fedora's rolling-release model for the latest tools and technologies.
- **Developer-Friendly Environment**: Zsh, Vim, Fastfetch, and other productivity tools.

---

## 🚀 How to Install

To install the Fedora DevOps Environment in WSL, simply run the following command in PowerShell:

```powershell
powershell -Command "& { (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nalwisidi/dvp-install/main/install_fedora.ps1').Content | powershell -ExecutionPolicy Bypass - }"
```

---

## 🔧 Building the Environment

If you’re interested in understanding how this environment is built or want to customize it, check out the detailed [Build Documentation](./docs/BUILD.md).

---

## 🤝 Contributing

Contributions are welcome! If you have ideas for improvement or find issues, open a pull request or an issue.

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
