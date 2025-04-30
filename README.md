# <img src="https://upload.wikimedia.org/wikipedia/commons/3/3f/Fedora_logo.svg" alt="🎩" width="25"/> WSL Fedora — A Clean and Flexible Base for Power Users

This project offers a minimal, customizable Fedora image for use with Windows Subsystem for Linux (WSL). It’s built to provide a native-like experience out of the box, while staying flexible enough for power users to define their own stack.

---

## 🧩 What's Included

- **Vanilla Fedora** with systemd enabled
- **WSL-friendly defaults** like non-root `ping` support and locale fixes
- **User creation on first launch**, similar to Ubuntu on WSL
- **Optional interactive bootstrap script** for selecting roles (DevOps, Developer, DBA, Minimal) and installing packages accordingly
- Clean login experience with no unnecessary clutter

---

## 🛠 Installation

Run the following in PowerShell to fetch the latest image and install it as a WSL distro:

```powershell
powershell -Command "& { (iwr 'https://raw.githubusercontent.com/nalwisidi/wsl-fedora/main/install_fedora.ps1').Content | iex }"
```

This will:
- Download the latest release (or chunks)
- Verify its hash
- Import it into WSL
- Prompt you to create a user
- Set that user as default for login

---

## 📦 Bootstrap (Optional)

After installation, you will be prompted with bootstrap script inside WSL to install packages and customize your environment based on your needs:

This script is interactive and uses `gum` for CLI UI. Feel free to explore more:

```bash
scripts/bootstrap.sh
```

---

## ❌ Uninstalling WSL Fedora

If you decide to remove WSL Fedora from your system, follow these simple steps:

1. **Unregister the distro** from WSL (this deletes all files and users for that distro):

   ```powershell
   wsl --unregister Fedora
   ```

   Replace `Fedora` with your custom distro name if you provided one during setup.

2. **Remove the Windows Terminal profile** (optional, for cleanup):

   - Open Windows Terminal settings:
     - Press `Ctrl` + `,` or click the dropdown arrow ▾ and choose "Settings"
   - If using the GUI:
     - Find the profile named *Fedora* (or your custom name)
     - Click the trash icon 🗑️ to delete it
   - If editing the JSON manually:
     - Open the JSON settings file (`settings.json`)
     - Delete the object in the `profiles.list` array where `"name"` matches your distro name

That’s it — WSL Fedora is now removed from your system.

---

## 🧰 Project Layout

- `/scripts` – includes the create_user and bootstrap scripts
- `/Dockerfile` – builds the base image
- `/install-fedora.ps1` – handles setup and import on Windows

---

## 🔍 Notes

- No services are enabled by default
- The base image avoids bloat — you choose what gets installed
- Systemd is pre-enabled via `/etc/wsl.conf`

---

## 📄 License

MIT — see [LICENSE](./LICENSE) for details.
