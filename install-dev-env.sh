#!/bin/bash

set -e

read -p "📁 Enter your preferred DEV_HOME directory (default: /u01/dev): " INPUT_DEV_HOME
DEV_HOME="${INPUT_DEV_HOME:-/u01/dev}"
BIN_DIR="$DEV_HOME/bin"
PYENV_ROOT="$DEV_HOME/.pyenv"

mkdir -p "$BIN_DIR"

add_env_to_shell() {
  for file in ~/.bashrc ~/.bash_profile ~/.zshrc; do
    grep -q "$DEV_HOME" "$file" 2>/dev/null || {
      echo -e "\n# Dev Environment" >> "$file"
      echo "export DEV_HOME=\"$DEV_HOME\"" >> "$file"
      echo "export PYENV_ROOT=\"$PYENV_ROOT\"" >> "$file"
      echo "export PATH=\"$BIN_DIR:\$PYENV_ROOT/bin:\$PATH\"" >> "$file"
      echo 'eval "$(pyenv init -)"' >> "$file"
      echo 'eval "$(pyenv virtualenv-init -)"' >> "$file"
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$file"
    }
  done
}

OS="$(uname -s)"
ARCH="$(uname -m)"
echo "🖥️  Detected OS: $OS, Architecture: $ARCH"

install_linux_packages() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian|kali)
        sudo apt update && sudo apt install -y build-essential curl git zlib1g-dev libssl-dev \
          libbz2-dev libreadline-dev libsqlite3-dev llvm libncurses5-dev libffi-dev liblzma-dev xz-utils fzf
        ;;
      rhel|centos|ol|fedora)
        echo "📦 Installing dev packages for RHEL/OEL..."
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y zlib-devel bzip2 bzip2-devel readline-devel \
          sqlite sqlite-devel openssl-devel xz xz-devel libffi-devel wget make

        if ! command -v fzf &>/dev/null; then
          echo "📦 Installing fzf manually..."
          git clone --depth 1 https://github.com/junegunn/fzf.git "$DEV_HOME/.fzf"
          "$DEV_HOME/.fzf/install" --all
          ln -s "$DEV_HOME/.fzf/bin/fzf" "$BIN_DIR/fzf" 2>/dev/null || true
        fi
        ;;
    esac
  fi
}

install_brew() {
  if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    echo "✅ Homebrew already installed"
  fi
}

install_tools() {
  brew install pyenv pipenv poetry fzf git
}

deploy_mkpyenv() {
  echo "📥 Installing mkpyenv to $BIN_DIR"
  curl -sSL https://raw.githubusercontent.com/r0han-raj/dev-tools/main/mkpyenv -o "$BIN_DIR/mkpyenv"
  chmod +x "$BIN_DIR/mkpyenv"
}

mkdir -p "$DEV_HOME"
cd "$DEV_HOME"

if [[ "$OS" == "Linux" ]]; then
  install_linux_packages
  install_brew
elif [[ "$OS" == "Darwin" ]]; then
  echo "🍎 macOS detected. Installing with brew..."
  install_brew
else
  echo "⚠️ Unsupported OS: $OS"
  exit 1
fi

install_tools
add_env_to_shell
deploy_mkpyenv

echo "✅ All set. Restart your terminal or run: source ~/.bashrc"
echo "🚀 Use 'mkpyenv' to create Python environments in $DEV_HOME"d
