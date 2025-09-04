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
    echo -e "${YELLOW}🔐 Validating and copying aztec.service from home directory...${NC}"
    if [ -f "$HOME/aztec.service" ]; then
        # Check for required parameters in aztec.service
        if grep -q -- "--l1-rpc-urls" "$HOME/aztec.service" && \
           grep -q -- "--l1-consensus-host-urls" "$HOME/aztec.service" && \
           grep -q -- "--sequencer.validatorPrivateKeys" "$HOME/aztec.service" && \
           grep -q -- "--sequencer.coinbase" "$HOME/aztec.service" && \
           grep -q -- "--p2p.p2pIp" "$HOME/aztec.service"; then
            # Basic cleanup: Remove any trailing "1" or unexpected characters
            sudo sed -i 's/[[:space:]]*1$//' "$HOME/aztec.service"
            sudo cp "$HOME/aztec.service" "$AZTEC_SERVICE"
            echo -e "${GREEN}✅ Service file copied successfully!${NC}"
        else
            echo -e "${RED}❌ aztec.service is missing required parameters (l1-rpc-urls, l1-consensus-host-urls, validatorPrivateKeys, coinbase, or p2pIp). Please check the file and try again.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ aztec.service not found in home directory ($HOME). Exiting.${NC}"
        exit 1
    fi
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable aztec
    sudo systemctl start aztec
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo -e "${YELLOW}➡ To check status: systemctl status aztec"
    echo -e "${BLUE}📄 View logs live: journalctl -fu aztec${NC}"
    rm -rf ~/.aztec/alpha-testnet/data/archiver
    rm -rf ~/.aztec/alpha-testnet/data/world-tree
    rm -rf ~/.bb-crs
    ls ~/.aztec/alpha-testnet/data
    docker-compose down
    rm -rf ./data/archiver ./data/world_state
    docker-compose up -d
}

# Execute the install_full function
install_full
