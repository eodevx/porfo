#!/usr/bin/env bash
set -e

sudo apt update  > /dev/null 2>&1

options=("Client" "Server" "Quit")

echo "Select architecture:"
select opt in "${options[@]}"; do
    case $opt in
        "Quit")
            echo "Exiting..."
            exit
            break
            ;;
        *)
            if [[ -n "$opt" ]]; then
                echo "You selected: $opt"
                ARCH="$opt"
                break
            else
                echo "Invalid selection."
            fi
            ;;
    esac
done




VERSION="0.67.0"

# Spinner
SPINNER_DEFAULT='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_LINE='▁▂▃▄▅▆▇█▇▆▅▄▃▂'

spinner_start() {
    local msg="${1:-Loading...}"
    local style="${2:-$SPINNER_DEFAULT}"

    SPINNER_MSG="$msg"
    SPINNER_STYLE="$style"

    (
        i=0
        while :; do
            char="${SPINNER_STYLE:i++%${#SPINNER_STYLE}:1}"
            printf "\r%s %s" "$char" "$SPINNER_MSG"
            sleep 0.1
        done
    ) &

    SPINNER_PID=$!
    disown
}

# Spinner Stop
spinner_stop() {
    if [ -n "$SPINNER_PID" ]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        printf "\r✔ %s\n" "$SPINNER_MSG"
        unset SPINNER_PID
    fi
}

# Cleanup on exit
trap spinner_stop EXIT

run_with_spinner() {
    local msg="$1"
    shift

    spinner_start "$msg"
    "$@" > /dev/null 2>&1
    local status=$?
    spinner_stop

    return $status
}



# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ "$OS" != "linux" ]; then
  echo "Only Linux is supported in this script"
  exit 1
fi

# Detect Architecture
spinner_start "Detecting Architecture"

RAW_ARCH=$(uname -m)

case "$RAW_ARCH" in
  x86_64)
    ARCH="amd64"
    ;;

  i386 | i486 | i586 | i686)
    ARCH="386"
    ;;

  aarch64 | arm64)
    ARCH="arm64"
    ;;

  armv7l)
    ARCH="arm_hf"
    ;;

  armv6l | armv5*)
    ARCH="arm"
    ;;

  arm*)
    ARCH="arm"
    ;;

  mips)
    ARCH="mips"
    ;;

  mips64)
    ARCH="mips64"
    ;;

  mips64el)
    ARCH="mips64le"
    ;;

  mipsel)
    ARCH="mipsle"
    ;;

  riscv64)
    ARCH="riscv64"
    ;;

  loongarch64)
    ARCH="loong64"
    ;;

  *)
    echo "Unsupported architecture: $RAW_ARCH"
    exit 1
    ;;
esac
spinner_stop

# Build download URL
FILE="frp_${VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/${FILE}"

echo "Detected OS: $OS"
echo "Detected Arch: $ARCH"
echo "Downloading: $FILE"

# Download
run_with_spinner "Downloading FRP" curl -L -o "$FILE" "$URL"  > /dev/null 2>&1

# Extract
run_with_spinner "Extracting FRP" tar -xzf "$FILE"  > /dev/null 2>&1
 
echo "Done."

# Install Essentials
spinner_start "Installing Essentials"
sudo apt update > /dev/null 2>&1
sudo apt install -y build-essential curl git \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libffi-dev liblzma-dev tk-dev > /dev/null 2>&1
spinner_stop

# Install Pyenv
spinner_start "Installing Pyenv"
PYENV_DIR="$HOME/.pyenv"
if [ ! -d "$PYENV_DIR" ]; then
    curl https://pyenv.run | bash
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi
spinner_stop

# Initialize pyenv for this shell session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

run_with_spinner "Installing Python" pyenv install 3.12

# Create Venv
spinner_start "Creating Virtual Environment"
export PYENV_VERSION=3.12
python -m venv .venv
spinner_stop

echo "✔ Virtual environment created"
echo ""
echo "Setup complete! To activate the environment, run:"
echo "  source .venv/bin/activate"

source .venv/bin/activate

cat > myfile.txt <<EOF

EOF

# Check for systemd
# Maybe also Cron in the future, but i havent used cron like ever

if command -v systemctl >/dev/null 2>&1; then
    echo "systemd is installed (systemctl available)"
else
    echo "systemd is NOT installed"
fi

wget -O /usr/bin