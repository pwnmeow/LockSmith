#!/bin/bash

# ==========================================
# GitHub-Based SSH Key Vault
# ==========================================
set -e  # Exit on error

# === Configuration ===
GITHUB_USER="pwnmeow"
REPO_NAME="ssh-key-vault"
REPO_URL="git@github.com:$GITHUB_USER/$REPO_NAME.git"
VAULT_DIR="$HOME/.ssh/keyvault"
KEYS_DIR="$VAULT_DIR/keys"
DB_FILE="$VAULT_DIR/keys.db"
CONFIG_FILE="$HOME/.ssh/config"
CRON_JOB="0 * * * * $VAULT_DIR/locksmith.sh sync"


# ==========================================
# Function: List SSH Keys 
# ==========================================
list_keys() {
    echo "🔍 Listing stored SSH keys..."
    
    if [[ ! -s "$DB_FILE" ]]; then
        echo "⚠️ No keys found in the vault."
    else
        echo "========================================="
        echo "  🔑 Stored SSH Keys in the Vault"
        echo "========================================="
        printf "%-25s %-15s %-15s\n" "Hostname" "Host IP" "Username"
        echo "-----------------------------------------"
        
        while IFS="|" read -r host_ip hostname username key_name || [[ -n "$host_ip" ]]; do
            if [[ -n "$host_ip" && -n "$hostname" && -n "$username" ]]; then
                printf "%-25s %-15s %-15s\n" "$hostname" "$host_ip" "$username"
            fi
        done < "$DB_FILE"
        
        echo "========================================="
    fi

    read -p "🔙 Press Enter to return to the main menu..."
}

# ==========================================
# Function: Delete SSH Key 
# ==========================================
delete_key() {
    list_keys  # Show available keys first

    read -p "❌ Enter Hostname or IP to delete: " search_key

    temp_file=$(mktemp)
    deleted=false

    cd "$VAULT_DIR"

    while IFS="|" read -r host_ip hostname username key_name || [[ -n "$host_ip" ]]; do
        if [[ "$hostname" == "$search_key" || "$host_ip" == "$search_key" ]]; then
            echo "🗑️ Deleting key: $key_name"
            git rm -f "$KEYS_DIR/$key_name" "$KEYS_DIR/$key_name.pub" 2>/dev/null || true
            deleted=true
        else
            echo "$host_ip|$hostname|$username|$key_name" >> "$temp_file"
        fi
    done < "$DB_FILE"

    mv "$temp_file" "$DB_FILE"

    if [[ "$deleted" == true ]]; then
        git add "$DB_FILE"
        git commit -m "Deleted SSH key: $search_key"
        git push
        update_ssh_config  # Refresh SSH config after deletion
        echo "✅ Key deleted successfully and removed from GitHub!"
    else
        echo "⚠️ No key found for $search_key."
    fi

    read -p "🔙 Press Enter to return to the main menu..."
}



# ==========================================
# Function: Backup Existing SSH Keys
# ==========================================
backup_keys() {
    local backup_file="$HOME/.ssh/backup_$(date +%Y%m%d_%H%M%S).zip"
    echo "🔐 Backing up existing SSH keys..."
    zip -r "$backup_file" "$HOME/.ssh" -x "*.zip" "config" "known_hosts"
    echo "✅ Backup saved at: $backup_file"
}

# ==========================================
# Function: Initialize Vault
# ==========================================
initialize_vault() {
    echo "🔧 Initializing SSH Key Vault..."
    backup_keys  

    if gh api repos/$GITHUB_USER/$REPO_NAME &>/dev/null; then
        echo "⚠️ Repository already exists on GitHub. Skipping creation."
    else
        echo "✅ Creating new private repository: $REPO_NAME"
        gh repo create "$REPO_NAME" --private
    fi

    echo "🔄 Verifying GitHub SSH Access..."
    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "❌ SSH authentication failed. Please check your SSH key and GitHub settings."
        exit 1
    fi
    echo "✅ SSH authentication successful."

    GIT_REMOTE_URL="git@github.com:$GITHUB_USER/$REPO_NAME.git"

    if [ ! -d "$VAULT_DIR/.git" ]; then
        echo "🔄 Cloning repository into $VAULT_DIR..."
        git clone "$GIT_REMOTE_URL" "$VAULT_DIR"
    else
        echo "⚠️ Local repository already exists."
        cd "$VAULT_DIR"
        git remote set-url origin "$GIT_REMOTE_URL"
        git fetch origin

        if git ls-remote --exit-code origin &>/dev/null; then
            git reset --hard origin/main
            git pull --rebase
        else
            echo "⚠️ Remote repository is empty. Adding an initial commit."
            touch .gitkeep
            git add .gitkeep
            git commit -m "Initial commit to set up repository"
            git push -u origin main
        fi
    fi

    mkdir -p "$KEYS_DIR"

    if [ ! -f "$DB_FILE" ]; then
        touch "$DB_FILE"
    fi

    (crontab -l 2>/dev/null | grep -v "$VAULT_DIR/ssh-key-vault.sh sync"; echo "$CRON_JOB") | crontab -

    echo "✅ Initialization complete!"
}

# ==========================================
# Function: Add New SSH Key 
# ==========================================
add_ssh_key() {
    read -p "🌐 Enter Hostname (e.g., example.com): " hostname
    read -p "🖥️ Enter Host IP (e.g., 192.168.1.100): " host_ip
    read -p "👤 Enter Username: " username

    key_name="${hostname}-${host_ip}"
    key_path="$KEYS_DIR/$key_name"

    ssh-keygen -t ed25519 -f "$key_path" -N ""

    echo "$host_ip|$hostname|$username|$key_name" >> "$DB_FILE"

    cd "$VAULT_DIR"
    git add "keys/$key_name"*
    git add "$DB_FILE"
    git commit -m "Added new key: $key_name"
    git push

    update_ssh_config
    echo "✅ Key added and pushed to GitHub!"
}
# ==========================================
# Function: Update SSH Config File from Database
# ==========================================
update_ssh_config() {
    echo "🔄 Updating SSH Config..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

    echo "# SSH Config Generated by SSH Key Vault" > "$CONFIG_FILE"

    while IFS="|" read -r host_ip hostname username key_name; do
        if [[ -f "$KEYS_DIR/$key_name" ]]; then
            echo -e "\nHost $hostname\n  HostName $host_ip\n  User $username\n  IdentityFile $KEYS_DIR/$key_name" >> "$CONFIG_FILE"
        fi
    done < "$DB_FILE"

    echo "✅ SSH Config Updated!"
}


# ==========================================
# Function: Sync Local to Remote (GitHub) 
# ==========================================
sync_to_github() {
    echo "🔄 Syncing local keys and database to GitHub..."
    cd "$VAULT_DIR"

    # Detect and commit unstaged changes before pulling
    if [[ -n $(git status --porcelain) ]]; then
        echo "⚠️ Unstaged changes detected. Staging and committing them..."
        git add -A  # Stage all changes, including deletions
        git commit -m "🔄 Auto-commit before syncing changes"
    fi

    # Pull latest changes and push local updates
    git pull --rebase
    git push

    echo "✅ Sync completed successfully!"
}

# ==========================================
# Function: Sync Remote to Local (GitHub) & Update SSH Config
# ==========================================
sync_from_github() {
    echo "🔄 Pulling latest keys and database from GitHub..."
    backup_keys
    cd "$VAULT_DIR"
    git pull --rebase
    mkdir -p "$KEYS_DIR"
    update_ssh_config
    echo "✅ Remote-to-local sync complete!"
}

# ==========================================
# Function: Uninstall (Clean Everything)
# ==========================================
uninstall_vault() {
    echo "⚠️ WARNING: This will remove SSH Key Vault. Are you sure? (y/N)"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "🚀 Removing SSH Key Vault..."
        rm -rf "$VAULT_DIR"
        crontab -l | grep -v "$VAULT_DIR/ssh-key-vault.sh sync" | crontab -
        echo "✅ Uninstallation complete!"
    else
        echo "❌ Uninstallation aborted."
    fi
}

# ==========================================
# Function: Interactive Menu
# ==========================================
show_menu() {
    while true; do
        clear
        echo "========================================"
        echo "   🔐 SSH Key Vault Management System   "
        echo "========================================"
        echo "1️⃣  Install Vault"
        echo "2️⃣  Add SSH Key"
        echo "3️⃣  List Stored Keys"
        echo "4️⃣  Delete an SSH Key"
        echo "5️⃣  Sync Local to Remote (GitHub)"
        echo "6️⃣  Sync Remote to Local (GitHub)"
        echo "7️⃣  Update SSH Config"
        echo "8️⃣  Uninstall Vault"
        echo "9️⃣  Exit"
        echo "========================================"
        read -p "Select an option: " option

        case $option in
            1) initialize_vault ;;
            2) add_ssh_key ;;
            3) list_keys ;;
            4) delete_key ;;
            5) sync_to_github ;;
            6) sync_from_github ;;
            7) update_ssh_config ;;
            8) uninstall_vault ;;
            9) exit 0 ;;
            *) echo "❌ Invalid option! Try again."; sleep 2 ;;
        esac
    done
}

# ==========================================
# Main Execution (Run Menu by Default)
# ==========================================
show_menu



