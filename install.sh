#!/usr/bin/env bash
set -e

options=("Client" "Server" "Quit")

echo "Select Install Type (Setup Server before Client):"
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
                INSTALL_TYPE="$opt"
                break
            else
                echo "Invalid selection."
            fi
            ;;
    esac
done

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
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
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

spinner_start "Updating System Packages"
sudo apt update  > /dev/null 2>&1
sudo apt upgrade -y > /dev/null 2>&1
spinner_stop

VERSION="0.67.0"

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
mkdir -p "$HOME/porfo"

cd "$HOME/porfo"

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

FRP_DIR="frp_${VERSION}_${OS}_${ARCH}"

# Move FRP binary to /usr/bin before changing directories
spinner_start "Installing FRP Binary"
if [ "$INSTALL_TYPE" == "Client" ]; then
    sudo mv "${FRP_DIR}/frpc" /usr/bin/porfo-frpc
    sudo chmod +x /usr/bin/porfo-frpc
elif [ "$INSTALL_TYPE" == "Server" ]; then
    sudo mv "${FRP_DIR}/frps" /usr/bin/porfo-frps
    sudo chmod +x /usr/bin/porfo-frps
fi

# Cleanup downloaded artifacts
rm -f "$FILE"
rm -rf "$FRP_DIR"
spinner_stop

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
    curl https://pyenv.run | bash  > /dev/null 2>&1
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi
spinner_stop

# Initialize pyenv for this shell session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

run_with_spinner "Installing Python" pyenv install -s 3.12

# Create Venv
spinner_start "Creating Virtual Environment"
export PYENV_VERSION=3.12
pyenv local 3.12
python -m venv .venv  > /dev/null 2>&1
spinner_stop

source .venv/bin/activate

spinner_start "Installing Porfo"

if [ "$INSTALL_TYPE" == "Client" ]; then
    sudo wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/porfo-client.sh -O /usr/bin/porfo-client.sh
    sudo chmod +x /usr/bin/porfo-client.sh

elif [ "$INSTALL_TYPE" == "Server" ]; then
    sudo wget https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/porfo-server.sh -O /usr/bin/porfo-server.sh
    sudo chmod +x /usr/bin/porfo-server.sh
else
    echo "Option Invalid, Exiting..."
    exit
fi

spinner_stop


# Check for systemd
# Maybe also Cron in the future, but i havent used cron like ever


if command -v systemctl >/dev/null 2>&1; then
spinner_start "Configuring Systemd Service"
if [ "$INSTALL_TYPE" == "Client" ]; then
sudo tee /etc/systemd/system/porfo-client.service > /dev/null <<EOF
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
sudo systemctl status porfo-client.service > /dev/null 2>&1
fi
if [ "$INSTALL_TYPE" == "Server" ]; then
sudo tee /etc/systemd/system/porfo-server.service > /dev/null <<EOF
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
sudo systemctl status porfo-server.service > /dev/null 2>&1
fi
spinner_stop
else
    echo "systemd is NOT installed"
fi

spinner_start "Downloading Porfo Scripts"
if [ "$INSTALL_TYPE" == "Client" ]; then
    wget -q https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/client.py -O "$HOME/porfo/client.py"
fi
if [ "$INSTALL_TYPE" == "Server" ]; then
    wget -q https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/server.py -O "$HOME/porfo/server.py"
fi
spinner_stop


spinner_start "Configuring Porfo"
if [ "$INSTALL_TYPE" == "Client" ]; then
    read -p "Please enter the token the server generated, if you don't have it please run cat $HOME/porfo/token: " SERVER_GENERATED_TOKEN_CLIENT
    DECODED_TOKEN=$(echo "$SERVER_GENERATED_TOKEN_CLIENT"| base64 --decode)
    IFS=';' read -r SERVER_IP SERVER_SECRET <<< "$DECODED_TOKEN"
    sudo tee "$HOME/porfo/config.toml" > /dev/null <<EOF
serverAddr = "$SERVER_IP"
serverPort = 7000
auth.method = "token"
auth.token = "$SERVER_SECRET"
EOF

fi
if [ "$INSTALL_TYPE" == "Server" ]; then
    EXTERNAL_IP=$(curl ifconfig.me)
    RANDOM_SECRET=$(openssl rand -hex 32)
    sudo tee "$HOME/porfo/config.toml" > /dev/null <<EOF
{
auth.method = "token"
auth.token = "$RANDOM_SECRET"
bindPort = 7000
EOF
    sudo tee "$HOME/porfo/token" > /dev/null <<EOF
$(echo -n "$EXTERNAL_IP;$RANDOM_SECRET" | base64 -w 0)
    echo "Server Generated Token: $(echo -n "$EXTERNAL_IP;$RANDOM_SECRET" | base64 -w 0)"
EOF
fi
spinner_stop



if [ "$INSTALL_TYPE" == "Client" ]; then
    wget -q https://raw.githubusercontent.com/eodevx/porfo/refs/heads/main/client.py -O "$HOME/porfo/client.py"
fi