#!/usr/bin/env bash
# setup.sh – run with:  sudo -E ./setup.sh
set -euo pipefail

###############################
# 0. Make sure we start as root
###############################
if [[ $EUID -ne 0 ]]; then
  echo "Re-run with sudo -E ./setup.sh" >&2
  exit 1
fi

###############################
# 1. Core APT update + basics
###############################
apt update
apt install -y curl wget net-tools git zsh ca-certificates gnupg lsb-release

###############################
# 2. Switch to zsh NOW  (idempotent)
###############################
# 2a. Install Oh-My-Zsh only once
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  CHSH=no RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 2b. Make zsh the default only if it isn’t already
if [[ "$SUDO_USER" && "$(getent passwd "$SUDO_USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  usermod -s "$(command -v zsh)" "$SUDO_USER"
fi

# 2c. Re-exec into zsh if we aren’t already inside it
if [[ -z "${ZSH_VERSION:-}" ]]; then
  exec zsh "$0" "$@"
fi

###############################
# 3. Optional CLI tools – pick what you want
###############################
echo
echo "Installing extra CLI utilities…"
apt install -y \
  bat \
  eza \
  duf \
  neovim \
  unzip \
  build-essential \
  clang \
  btop

###############################
# 4. Miniconda
###############################
if ! command -v conda &>/dev/null; then
  echo "Installing Miniconda…"
  CONDA_INSTALLER="$HOME/miniconda.sh"
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$CONDA_INSTALLER"
  bash "$CONDA_INSTALLER" -b -p "$HOME/miniconda"
  rm "$CONDA_INSTALLER"
  # Add to .zshrc once
  grep -qF "miniconda/etc/profile.d/conda.sh" "$HOME/.zshrc" || \
    echo ". \"$HOME/miniconda/etc/profile.d/conda.sh\"" >> "$HOME/.zshrc"
  source "$HOME/miniconda/etc/profile.d/conda.sh"
  conda init zsh
fi

###############################
# 5. Desktop-only GUI goodies
###############################
if command -v gnome-shell &>/dev/null; then
  echo
  echo "Ubuntu Desktop detected – installing GUI applications…"

  # 1Password
  if ! command -v 1password &>/dev/null; then
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
      gpg --dearmor | tee /usr/share/keyrings/1password-archive-keyring.gpg >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
      > /etc/apt/sources.list.d/1password.list
    apt update && apt install -y 1password
  fi

  # Zen Browser (official AppImage wrapped in a .desktop file)
  ZEN_URL=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | grep browser_download_url | grep "\.AppImage" | head -n1 | cut -d'"' -f4)
  ZEN_BIN="/usr/local/bin/zen-browser"
  if [[ ! -x "$ZEN_BIN" ]]; then
    wget -q "$ZEN_URL" -O "$ZEN_BIN"
    chmod +x "$ZEN_BIN"
    # Simple .desktop file
    cat >/usr/share/applications/zen-browser.desktop <<EOF
[Desktop Entry]
Name=Zen Browser
Exec=$ZEN_BIN --no-sandbox %U
Terminal=false
Type=Application
Icon=zen-browser
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
EOF
  fi

  # Add more GUI apps here if desired
else
  echo "No desktop environment detected – skipping GUI packages."
fi

###############################
# 6. Done
###############################
echo
echo "All done! Log out and back in for the default-shell change to take effect."
