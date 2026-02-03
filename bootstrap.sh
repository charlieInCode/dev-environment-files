#!/bin/bash

# Bootstrap Script for Dev Environment Setup
# This script installs all development tools and links configuration files using GNU stow
# Supports both macOS (local setup) and Linux (Coder workspaces)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Track what gets installed
INSTALLED_PACKAGES=()
SKIPPED_PACKAGES=()

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

brew_install() {
    local package=$1
    local cask=${2:-false}
    
    if $cask; then
        if brew list --cask "$package" &>/dev/null; then
            print_warning "$package is already installed (skipping)"
            SKIPPED_PACKAGES+=("$package")
        else
            print_info "Installing $package..."
            brew install --cask "$package"
            INSTALLED_PACKAGES+=("$package")
            print_success "$package installed"
        fi
    else
        if brew list "$package" &>/dev/null; then
            print_warning "$package is already installed (skipping)"
            SKIPPED_PACKAGES+=("$package")
        else
            print_info "Installing $package..."
            brew install "$package"
            INSTALLED_PACKAGES+=("$package")
            print_success "$package installed"
        fi
    fi
}

# Start installation
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         Dev Environment Bootstrap Installer              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Detected OS: $MACHINE"
print_info "Starting installation from: $DOTFILES_DIR"

# ==================================================
# 1. Prerequisites
# ==================================================
print_section "Installing Prerequisites"

# Install Xcode Command Line Tools (macOS only)
if [ "$MACHINE" = "Mac" ]; then
    if ! xcode-select -p &>/dev/null; then
        print_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        print_warning "Please complete the Xcode Command Line Tools installation and re-run this script"
        exit 1
    else
        print_success "Xcode Command Line Tools already installed"
    fi
else
    print_info "Skipping Xcode Command Line Tools (Linux environment)"
fi

# Install Homebrew
if ! command_exists brew; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    if [ "$MACHINE" = "Mac" ]; then
        # Apple Silicon or Intel Mac
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        # Linux
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    print_success "Homebrew installed"
    INSTALLED_PACKAGES+=("homebrew")
else
    print_success "Homebrew already installed"
    print_info "Updating Homebrew..."
    brew update
fi

# ==================================================
# 2. Core Development Tools
# ==================================================
print_section "Installing Core Development Tools"

# Terminal Emulator (macOS only)
if [ "$MACHINE" = "Mac" ]; then
    print_info "Installing WezTerm..."
    brew_install "wezterm" true
else
    print_info "Skipping WezTerm (not needed for Coder workspaces)"
fi

# Zsh plugins
print_info "Installing Zsh plugins..."
brew_install "powerlevel10k"
brew_install "zsh-autosuggestions"
brew_install "zsh-syntax-highlighting"

# CLI Tools
print_info "Installing CLI tools..."
brew_install "fzf"
brew_install "fd"
brew_install "bat"
brew_install "eza"
brew_install "ripgrep"
brew_install "delta"
brew_install "tldr"
brew_install "thefuck"
brew_install "zoxide"

# Tmux
print_info "Installing Tmux..."
brew_install "tmux"

# Clone TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    print_info "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    print_success "TPM installed"
    INSTALLED_PACKAGES+=("tpm")
else
    print_warning "TPM already installed (skipping)"
    SKIPPED_PACKAGES+=("tpm")
fi

# Neovim and dependencies
print_info "Installing Neovim and dependencies..."
brew_install "neovim"
brew_install "node"

# Install Nerd Font (macOS only)
if [ "$MACHINE" = "Mac" ]; then
    if ! brew list --cask font-meslo-lg-nerd-font &>/dev/null; then
        print_info "Installing Meslo Nerd Font..."
        brew_install "font-meslo-lg-nerd-font" true
    else
        print_warning "Meslo Nerd Font already installed (skipping)"
        SKIPPED_PACKAGES+=("font-meslo-lg-nerd-font")
    fi
else
    print_info "Skipping Nerd Font installation (configure manually in Coder or use web-based fonts)"
fi

# ==================================================
# 3. Window Manager & UI (macOS only)
# ==================================================
if [ "$MACHINE" = "Mac" ]; then
    print_section "Installing Window Manager & UI Components"

    # Aerospace
    if ! brew list --cask aerospace &>/dev/null; then
        print_info "Installing Aerospace..."
        brew install --cask nikitabobko/tap/aerospace
        print_success "Aerospace installed"
        INSTALLED_PACKAGES+=("aerospace")
    else
        print_warning "Aerospace already installed (skipping)"
        SKIPPED_PACKAGES+=("aerospace")
    fi

    # Sketchybar
    print_info "Installing Sketchybar and dependencies..."
    if ! brew list sketchybar &>/dev/null; then
        brew tap FelixKratz/formulae
        brew_install "sketchybar"
    else
        print_warning "Sketchybar already installed (skipping)"
        SKIPPED_PACKAGES+=("sketchybar")
    fi

    # SF Pro Font
    if ! brew list --cask font-sf-pro &>/dev/null; then
        print_info "Installing SF Pro Font..."
        brew_install "font-sf-pro" true
    else
        print_warning "SF Pro Font already installed (skipping)"
        SKIPPED_PACKAGES+=("font-sf-pro")
    fi

    # SF Symbols
    brew_install "sf-symbols" true

    # Sketchybar App Font
    if [ ! -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ]; then
        print_info "Installing Sketchybar App Font..."
        curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v1.0.16/sketchybar-app-font.ttf -o "$HOME/Library/Fonts/sketchybar-app-font.ttf"
        print_success "Sketchybar App Font installed"
        INSTALLED_PACKAGES+=("sketchybar-app-font")
    else
        print_warning "Sketchybar App Font already installed (skipping)"
        SKIPPED_PACKAGES+=("sketchybar-app-font")
    fi
else
    print_section "Skipping Window Manager & UI Components (Linux environment)"
fi

# JQ is useful on both platforms
brew_install "jq"

# ==================================================
# 4. Optional Tools
# ==================================================
print_section "Installing Optional Tools"

# iTerm2 (macOS only)
if [ "$MACHINE" = "Mac" ]; then
    brew_install "iterm2" true
else
    print_info "Skipping iTerm2 (not needed for Coder workspaces)"
fi

# Cross-platform tools
brew_install "yazi"
brew_install "lazygit"

# ==================================================
# 5. Additional Setup
# ==================================================
print_section "Additional Setup"

# Clone fzf-git.sh
if [ ! -d "$HOME/fzf-git.sh" ]; then
    print_info "Cloning fzf-git.sh..."
    git clone https://github.com/junegunn/fzf-git.sh "$HOME/fzf-git.sh"
    print_success "fzf-git.sh cloned"
    INSTALLED_PACKAGES+=("fzf-git.sh")
else
    print_warning "fzf-git.sh already exists (skipping)"
    SKIPPED_PACKAGES+=("fzf-git.sh")
fi

# Install GNU Stow
brew_install "stow"

# ==================================================
# 6. Stow Configuration Files
# ==================================================
print_section "Linking Configuration Files with GNU Stow"

cd "$DOTFILES_DIR"

print_info "Using stow to symlink dotfiles from $DOTFILES_DIR to $HOME..."

# Use stow to create symlinks
print_info "Attempting to symlink dotfiles..."

# Try stow first without adopting
if stow -t "$HOME" . 2>/dev/null; then
    print_success "Configuration files successfully linked!"
    print_info "The following files/directories are now symlinked:"
    echo "  • ~/.zshrc"
    echo "  • ~/.tmux.conf"
    echo "  • ~/.wezterm.lua"
    echo "  • ~/.config/"
    echo "  • ~/coolnight.itermcolors"
    echo "  • ~/qmk/"
else
    print_warning "Conflicts detected! Backing up existing files..."
    
    # Backup conflicting files instead of adopting them
    BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup common conflicting files
    for file in .zshrc .tmux.conf .wezterm.lua; do
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            print_info "Backing up ~/$file"
            mv "$HOME/$file" "$BACKUP_DIR/"
        fi
    done
    
    # Try stow again
    if stow -t "$HOME" . 2>/dev/null; then
        print_success "Configuration files linked! Backups saved to: $BACKUP_DIR"
    else
        print_error "Failed to link dotfiles. Manual intervention needed."
        print_info "Backup location: $BACKUP_DIR"
        exit 1
    fi
fi

# ==================================================
# Installation Summary
# ==================================================
print_section "Installation Summary"

echo -e "${GREEN}✓ Installation Complete!${NC}\n"

if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${GREEN}Newly Installed (${#INSTALLED_PACKAGES[@]}):${NC}"
    for pkg in "${INSTALLED_PACKAGES[@]}"; do
        echo "  ✓ $pkg"
    done
    echo ""
fi

if [ ${#SKIPPED_PACKAGES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Skipped (already installed) (${#SKIPPED_PACKAGES[@]}):${NC}"
    for pkg in "${SKIPPED_PACKAGES[@]}"; do
        echo "  • $pkg"
    done
    echo ""
fi

# ==================================================
# Post-Installation Instructions
# ==================================================
print_section "Post-Installation Steps"

if [ "$MACHINE" = "Mac" ]; then
    echo -e "${YELLOW}Manual steps required (macOS):${NC}\n"
    echo -e "1. ${BLUE}Powerlevel10k Configuration:${NC}"
    echo -e "   Run: ${GREEN}p10k configure${NC}"
    echo -e "   This will guide you through customizing your prompt\n"
    
    echo -e "2. ${BLUE}Tmux Plugins:${NC}"
    echo -e "   - Open tmux: ${GREEN}tmux${NC}"
    echo -e "   - Press: ${GREEN}Ctrl+a then Shift+I${NC} (capital I) to install plugins"
    echo -e "   - Wait for plugins to finish installing\n"
    
    echo -e "3. ${BLUE}Neovim Setup:${NC}"
    echo -e "   - Open Neovim: ${GREEN}nvim${NC}"
    echo -e "   - Plugins will auto-install via lazy.nvim"
    echo -e "   - Language servers will auto-install via Mason"
    echo -e "   - Be patient on first launch (may take a few minutes)\n"
    
    echo -e "4. ${BLUE}Start Services:${NC}"
    echo -e "   ${GREEN}brew services start sketchybar${NC}"
    echo -e "   ${GREEN}brew services start aerospace${NC}\n"
    
    echo -e "5. ${BLUE}Restart Your Terminal:${NC}"
    echo -e "   Close and reopen your terminal for all changes to take effect"
    echo -e "   Or run: ${GREEN}source ~/.zshrc${NC}\n"
    
    echo -e "6. ${BLUE}Optional - Configure Aerospace:${NC}"
    echo -e "   Edit ~/.config/aerospace/aerospace.toml to customize keybindings\n"
    
    echo -e "7. ${BLUE}Optional - Configure Sketchybar:${NC}"
    echo -e "   Your sketchybar config is in ~/.config/sketchybar/"
    echo -e "   Restart sketchybar: ${GREEN}brew services restart sketchybar${NC}\n"
    
    echo -e "${GREEN}Enjoy your new development environment! 🚀${NC}\n"
    echo -e "${YELLOW}Note:${NC} Your original dotfiles have been symlinked, not copied."
    echo -e "Any changes you make to files in $DOTFILES_DIR will be reflected immediately.\n"
else
    echo -e "${YELLOW}Manual steps required (Coder/Linux):${NC}\n"
    echo -e "1. ${BLUE}Powerlevel10k Configuration:${NC}"
    echo -e "   Run: ${GREEN}p10k configure${NC}"
    echo -e "   This will guide you through customizing your prompt\n"
    
    echo -e "2. ${BLUE}Tmux Plugins:${NC}"
    echo -e "   - Open tmux: ${GREEN}tmux${NC}"
    echo -e "   - Press: ${GREEN}Ctrl+a then Shift+I${NC} (capital I) to install plugins"
    echo -e "   - Wait for plugins to finish installing\n"
    
    echo -e "3. ${BLUE}Neovim Setup:${NC}"
    echo -e "   - Open Neovim: ${GREEN}nvim${NC}"
    echo -e "   - Plugins will auto-install via lazy.nvim"
    echo -e "   - Language servers will auto-install via Mason"
    echo -e "   - Be patient on first launch (may take a few minutes)\n"
    
    echo -e "4. ${BLUE}Restart Your Shell:${NC}"
    echo -e "   Exit and reconnect to your workspace, or run: ${GREEN}source ~/.zshrc${NC}\n"
    
    echo -e "5. ${BLUE}Coder-Specific:${NC}"
    echo -e "   - Configure your Coder template to use a Nerd Font for proper icon display"
    echo -e "   - Some features (aerospace, sketchybar) are macOS-only and were skipped\n"
    
    echo -e "${GREEN}Enjoy your new development environment! 🚀${NC}\n"
    echo -e "${YELLOW}Note:${NC} Your dotfiles have been symlinked, not copied."
    echo -e "Any changes you make to files in $DOTFILES_DIR will be reflected immediately.\n"
fi

print_info "Bootstrap complete! Follow the manual steps above to finish setup."
