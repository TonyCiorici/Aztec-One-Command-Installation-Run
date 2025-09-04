#!/bin/bash

# ==================== Aashish's Aztec Node Manager ====================
# Created by: Aashish 💻
# ======================================================================

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

AZTEC_SERVICE="/etc/systemd/system/aztec.service"
AZTEC_DIR="$HOME/.aztec"
AZTEC_DATA_DIR="$AZTEC_DIR/alpha-testnet"

install_full() {
    clear
    echo -e "${YELLOW}${BOLD}🚀 Starting Full Installation by Aashish...${NC}"

    echo -e "${GREEN}🔄 Updating system and installing dependencies...${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt update
    sudo apt install -y nodejs
    sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev screen ufw apt-transport-https ca-certificates software-properties-common

    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo rm -rf /var/lib/apt/lists/* && sudo apt clean && sudo apt update --allow-insecure-repositories
    sudo apt install -y docker-ce
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER

    echo -e "${BLUE}📦 Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo -e "${BLUE}📦 Making sure Docker is running...${NC}"
    sudo systemctl restart docker
    sleep 3

    echo -e "${YELLOW}⚙️ Installing Aztec CLI (inside docker group shell)...${NC}"
    newgrp docker <<EONG
    echo -e "${BLUE}📥 Running Aztec Installer...${NC}"
    bash <(curl -s https://install.aztec.network)

    echo 'export PATH="\$HOME/.aztec/bin:\$PATH"' >> \$HOME/.bashrc
    source \$HOME/.bashrc
    export PATH="\$HOME/.aztec/bin:\$PATH"

    if ! command -v aztec-up &> /dev/null; then
        echo -e "${RED}❌ CLI install failed or aztec-up not found. Exiting.${NC}"
        exit 1
    fi

    echo -e "${GREEN}🔁 Running aztec-up alpha-testnet...${NC}"
    aztec-up latest
EONG

    echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc

    echo -e "${GREEN}🛡️ Configuring Firewall...${NC}"
    sudo ufw allow 22
    sudo ufw allow ssh
    sudo ufw allow 40400
    sudo ufw allow 8080
    sudo ufw --force enable

    echo -e "${YELLOW}🔐 Collecting run parameters...${NC}"

    # ✅ Check if user already has aztec.service in HOME directory
    if [[ -f "$HOME/aztec.service" ]]; then
        echo -e "${BLUE}📄 Reading existing aztec.service file...${NC}"
        exec_line=$(grep "ExecStart=" "$HOME/aztec.service" | head -n 1)

        private_key=$(echo "$exec_line" | grep -oP '(?<=--sequencer.validatorPrivateKeys )\S+')
        evm_address=$(echo "$exec_line" | grep -oP '(?<=--sequencer.coinbase )\S+')

        if [[ -n "$private_key" && -n "$evm_address" ]]; then
            echo -e "${GREEN}✅ Found existing key & address:${NC}"
            echo -e "   🔑 Private Key: ${YELLOW}$private_key${NC}"
            echo -e "   🪙 Address: ${YELLOW}$evm_address${NC}"
        else
            echo -e "${RED}⚠️ Could not parse private key or address from aztec.service. Falling back to manual input.${NC}"
            read -p "🔹 EVM Private Key (with or without 0x): " private_key
            [[ $private_key != 0x* ]] && private_key="0x$private_key"
            read -p "🔹 EVM Wallet Address: " evm_address
        fi
    else
        echo -e "${RED}⚠️ aztec.service not found in home directory, asking manually...${NC}"
        read -p "🔹 EVM Private Key (with or without 0x): " private_key
        [[ $private_key != 0x* ]] && private_key="0x$private_key"
        read -p "🔹 EVM Wallet Address: " evm_address
    fi

    node_ip=$(curl -s ifconfig.me)
    echo -e "${BLUE}📄 Creating systemd service...${NC}"
    sudo tee $AZTEC_SERVICE > /dev/null <<EOF
[Unit]
Description=Aztec Node Service
After=network.target docker.service

[Service]
User=$USER
WorkingDirectory=$HOME
ExecStart=/bin/bash -c '$HOME/.aztec/bin/aztec start --node --archiver --sequencer \
  --network alpha-testnet \
  --l1-rpc-urls http://38.102.86.215:8545 \
  --l1-consensus-host-urls http://38.102.86.215:3500 \
  --sequencer.validatorPrivateKeys $private_key \
  --sequencer.coinbase $evm_address \
  --p2p.p2pIp $node_ip'
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable aztec
    sudo systemctl start aztec

    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo -e "${YELLOW}➡ To check status: systemctl status aztec"
    echo -e "${BLUE}📄 View logs live: journalctl -fu aztec${NC}"

    fix_failed_fetch
}

fix_failed_fetch() {
    rm -rf ~/.aztec/alpha-testnet/data/archiver
    rm -rf ~/.aztec/alpha-testnet/data/world-tree
    rm -rf ~/.bb-crs
    ls ~/.aztec/alpha-testnet/data
    docker-compose down
    rm -rf ./data/archiver ./data/world_state
    docker-compose up -d
}

install_full
