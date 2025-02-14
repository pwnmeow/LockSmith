# LockSmith
---

## **🔐 SSH Key Vault**
**A GitHub-based SSH Key Vault for secure SSH key storage, management, and automatic configuration updates.**

### **🚀 Features**
- 🔑 **Securely store SSH keys** in a private GitHub repository.
- 📁 **Auto-sync keys** between local and remote.
- 🔄 **Generate and update `~/.ssh/config`** dynamically.
- 🔍 **List and delete keys** with an interactive menu.
- 🛡️ **Enhanced security** with automatic key shredding and Git purge.

---

## **📌 Prerequisites**
### **System Requirements**
- 🐧 **Linux / macOS** (Tested on Ubuntu, macOS)
- 🛠️ **Dependencies:** `git`, `gh (GitHub CLI)`, `ssh-keygen`, `zip`

### **GitHub Setup**
1. Ensure you have a **GitHub account**.
2. Set up **SSH authentication** with GitHub:
   ```sh
   ssh-keygen -t ed25519 -C "your-email@example.com"
   cat ~/.ssh/id_ed25519.pub  # Add this to GitHub SSH settings
   ```
3. Install GitHub CLI:
   ```sh
   sudo apt install gh  # Linux
   brew install gh      # macOS
   ```
4. Authenticate:
   ```sh
   gh auth login
   ```

---

## **⚡ Installation**
```sh
git clone https://github.com/your-username/ssh-key-vault.git
cd ssh-key-vault
chmod +x ssh-key-vault.sh
```
To start the SSH Key Vault, run:
```sh
./ssh-key-vault.sh
```

---

## **🛠️ Usage**
Run the script and navigate the interactive menu:
```sh
./ssh-key-vault.sh
```
### **📜 Main Menu**
```
========================================
   🔐 SSH Key Vault Management System   
========================================
1️⃣  Install Vault
2️⃣  Add SSH Key
3️⃣  List Stored Keys
4️⃣  Delete an SSH Key
5️⃣  Sync Local to Remote (GitHub)
6️⃣  Sync Remote to Local (GitHub)
7️⃣  Update SSH Config
8️⃣  Uninstall Vault
9️⃣  Exit
========================================
```

### **1️⃣ Install Vault**
Creates the GitHub repository (`ssh-key-vault`) and sets up the local environment.

### **2️⃣ Add SSH Key**
Prompts for:
- Hostname (e.g., `example.com`)
- Host IP (e.g., `192.168.1.100`)
- Username (e.g., `ubuntu`)

Automatically:
- Generates an SSH key: `keys/Hostname-IP.key`
- Stores key details in `keys.db`
- Syncs with GitHub

### **3️⃣ List Stored Keys**
Displays all stored SSH keys:
```
========================================
  🔑 Stored SSH Keys in the Vault
========================================
Hostname                Host IP         Username
----------------------------------------
example.com             192.168.1.100   ubuntu
server1                 10.0.0.5        root
========================================
```

### **4️⃣ Delete an SSH Key**
- Removes **local and remote key files**.
- Updates `keys.db`.
- Purges the deleted key from **Git history**.

### **5️⃣ Sync Local to Remote (GitHub)**
- Stages **unstaged changes automatically**.
- Pulls latest changes and pushes local updates.

### **6️⃣ Sync Remote to Local (GitHub)**
- Fetches latest keys from GitHub.
- Updates `~/.ssh/config`.

### **7️⃣ Update SSH Config**
Regenerates `~/.ssh/config`:
```sh
Host example.com
  HostName 192.168.1.100
  User ubuntu
  IdentityFile ~/.ssh/keyvault/keys/example.com-192.168.1.100
```

### **8️⃣ Uninstall Vault**
Removes **all local files** and **disables sync cron job**.

---

## **🔒 Security Best Practices**
✅ **SSH Key Permissions**: Keys are stored with:
   ```sh
   chmod 600 keys/*.key
   chmod 644 keys/*.pub
   ```
✅ **Git Purge on Deletion**: Deleted keys are **completely removed** from history.
✅ **Auto-Sync Handling**: Detects and **stages unstaged changes** before pulling.

---

## **🌍 Contributing**
### **💡 Want to Improve SSH Key Vault?**
1. Fork the repository.
2. Create a feature branch:  
   ```sh
   git checkout -b feature-your-feature
   ```
3. Commit and push:
   ```sh
   git commit -m "🚀 Added new feature"
   git push origin feature-your-feature
   ```
4. Open a **pull request**!

---

## **📜 License**
This project is licensed under the **MIT License**.

---

## **🤝 Credits**
Developed by **@pwnmeow**.  
Inspired by **secure SSH key management needs**.

---

### **🚀 Ready to Go?**
Run:
```sh
./ssh-key-vault.sh
```
Enjoy **secure SSH key management** with GitHub automation! 🔐🔥
