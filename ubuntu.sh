#!/usr/bin/env bash
# setup.sh  –  sudo -E ./setup.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo -E" >&2; exit 1; }

apt -qq update
apt -qq install -y curl wget git zsh ca-certificates gnupg lsb-release

# oh-my-zsh setup
[[ -d $HOME/.oh-my-zsh ]] ||
  CHSH=no RUNZSH=no KEEP_ZSHRC=yes \
  bash <(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended
# default shell
[[ $(getent passwd "$SUDO_USER" | cut -d: -f7) == "$(command -v zsh)" ]] ||
  usermod -s "$(command -v zsh)" "$SUDO_USER"
# re-exec into zsh
[[ -n "${ZSH_VERSION:-}" ]] || exec zsh "$0" "$@"


# CLI tools
apt -qq install -y bat eza duf neovim unzip build-essential clang btop


# miniconda
if ! command -v conda &>/dev/null; then
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
  bash ~/miniconda.sh -b -p $HOME/miniconda && rm ~/miniconda.sh
  grep -qF miniconda/etc/profile.d/conda.sh ~/.zshrc 2>/dev/null ||
    echo '. "$HOME/miniconda/etc/profile.d/conda.sh"' >>~/.zshrc
  source "$HOME/miniconda/etc/profile.d/conda.sh"
  conda init -q zsh
fi


# Docker
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


# desktop extras
command -v gnome-shell &>/dev/null || exit 0

# 1password
if ! command -v 1password &>/dev/null; then
  curl -sS https://downloads.1password.com/linux/keys/1password.asc |
    gpg --dearmor | tee /usr/share/keyrings/1password-archive-keyring.gpg >/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    >/etc/apt/sources.list.d/1password.list
  apt -qq update && apt -qq install -y 1password
fi


# zen-browser
ZEN_DIR=$HOME/Applications/zen-browser
[[ -x $ZEN_DIR/zen-bin ]] || {
  mkdir -p ~/Applications
  wget -qO- https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz |
    tar -xJ -C ~/Applications
  mv ~/Applications/zen.linux-x86_64 "$ZEN_DIR"
}
grep -qF 'alias zen=' ~/.zshrc 2>/dev/null ||
  echo "alias zen='$ZEN_DIR/zen/zen-bin'" >>~/.zshrc

mkdir -p ~/.local/share/applications
cat >~/.local/share/applications/zen-browser.desktop <<EOF
[Desktop Entry]
Name=Zen Browser
Exec=$ZEN_DIR/zen-bin --no-sandbox %u
Icon=$ZEN_DIR/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
EOF
update-desktop-database ~/.local/share/applications &>/dev/null


# cursor cli
curl https://cursor.com/install -fsS | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc


echo "Done. Log out/in for the new shell to activate."
