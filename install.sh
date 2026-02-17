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
mkdir -p "$HOME/porfo"
cd "$HOME/porfo"
export PYENV_VERSION=3.12
python -m venv .venv
spinner_stop

source .venv/bin/activate

spinner_start "Installing Porfo"

wget -O /usr/bin
if [ "$opt" == "Client" ]; then
    sudo wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/porfo-client.sh -O /usr/bin/porfo-client.sh
    sudo chmod +x /usr/bin/porfo-client.sh
    sudo mv frp*/frpc /usr/bin/porfo-frpc
    sudo chmod +x /usr/bin/porfo-frpc

elif [ "$opt" == "Server" ]; then
    sudo wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/porfo-server.sh -O /usr/bin/porfo-server.sh
    sudo chmod +x /usr/bin/porfo-server.sh
    sudo mv frp*/frps /usr/bin/porfo-frps
    sudo chmod +x /usr/bin/porfo-frps
else
    echo "Option Invalid, Exiting..."
    exit
fi

spinner_stop


# Check for systemd
# Maybe also Cron in the future, but i havent used cron like ever


if command -v systemctl >/dev/null 2>&1; then
if [ "$opt" == "Client" ]; then
    cat > /etc/systemd/system/porfo-client.service <<EOF
[Unit]
Description=Porfo Client Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash /usr/bin/porfo-client.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable porfo-client.service
sudo systemctl start porfo-client.service
sudo systemctl status porfo-client.service
fi
if [ "$opt" == "Server" ]; then
    cat > /etc/systemd/system/porfo-server.service <<EOF
[Unit]
Description=Porfo Server Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash /usr/bin/porfo-server.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable porfo-server.service
sudo systemctl start porfo-server.service
sudo systemctl status porfo-server.service
fi
else
    echo "systemd is NOT installed"
fi

if [ "$opt" == "Client" ]; then
wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/client.py -O "$HOME/porfo/client.py"
fi
if [ "$opt" == "Server" ]; then
wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/server.py -O "$HOME/porfo/server.py"
fi