#!/bin/bash


set -e

# Check if sudo is available
if command -v sudo >/dev/null 2>&1; then
  echo "🔐 Sudo detected. Will use sudo where necessary."
else
  echo "⚠️  Sudo not found. You must have permissions to write to DEV_HOME and install packages."
  echo "💡 If you are a non-root user, please ensure necessary tools are pre-installed or contact your administrator."
fi

if [[ -z "$DEV_HOME" ]]; then
  if [[ -t 0 ]]; then
    read -p "📁 Enter your DEV_HOME path (default: /u01/dev): " INPUT_DEV_HOME
    export DEV_HOME="${INPUT_DEV_HOME:-/u01/dev}"
  else
    export DEV_HOME="/u01/dev"
    echo "📁 Non-interactive mode: Using default DEV_HOME: $DEV_HOME"
  fi
fi

# Check and fallback if not writable
if [[ ! -w "$(dirname "$DEV_HOME")" ]]; then
  echo "⚠️ DEV_HOME ($DEV_HOME) is not writable without sudo."
  if command -v sudo >/dev/null 2>&1; then
    echo "🔐 Attempting to create $DEV_HOME with sudo..."
    sudo mkdir -p "$DEV_HOME"
    sudo chown -R $(whoami):$(whoami) "$DEV_HOME"
  else
    echo "❌ Cannot write to $DEV_HOME and no sudo available. Exiting."
    exit 1
  fi
else
  mkdir -p "$DEV_HOME"
fi
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
