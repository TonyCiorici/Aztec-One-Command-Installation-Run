#!/bin/bash

# ==================== AJ's Aztec Node Manager ====================
# Created by: AJ 💻
# ================================================================

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
    echo -e "${YELLOW}${BOLD}🚀 Starting Full Installation by AJ...${NC}"

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

    echo -e "${YELLOW}⚙️ Installing Aztec CLI...${NC}"
    curl -s https://install.aztec.network | bash

    if ! grep -q 'export PATH="$HOME/.aztec/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="$HOME/.aztec/bin:$PATH"
    echo -e "${GREEN}🔁 Running aztec-up alpha-testnet...${NC}"
    aztec-up alpha-testnet


    echo -e "${GREEN}🛡️ Configuring Firewall...${NC}"
    sudo ufw allow 22
    sudo ufw allow ssh
    sudo ufw allow 40400
    sudo ufw allow 8080
    sudo ufw --force enable

    echo -e "${YELLOW}🔐 Collecting run parameters...${NC}"
    read -p "🔹 Sepolia L1 RPC URL: " l1_rpc
    read -p "🔹 Beacon Consensus RPC URL: " beacon_rpc
    read -p "🔹 EVM Private Key (with or without 0x): " private_key
    [[ $private_key != 0x* ]] && private_key="0x$private_key"
    read -p "🔹 EVM Wallet Address: " evm_address
    node_ip=$(curl -s ifconfig.me)

    echo -e "${BLUE}📄 Creating systemd service...${NC}"
    sudo tee $AZTEC_SERVICE > /dev/null <<EOF
[Unit]
Description=Aztec Node Service
After=network.target docker.service

[Service]
User=$USER
WorkingDirectory=$HOME
ExecStart=$HOME/.aztec/bin/aztec start --node --archiver --sequencer \\
  --network alpha-testnet \\
  --l1-rpc-urls $l1_rpc \\
  --l1-consensus-host-urls $beacon_rpc \\
  --sequencer.validatorPrivateKey $private_key \\
  --sequencer.coinbase $evm_address \\
  --p2p.p2pIp $node_ip
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
}

view_logs() {
    echo -e "${YELLOW}📜 Live Aztec Logs...${NC}"
    journalctl -u aztec -f --no-pager
}

reconfigure() {
    echo -e "${YELLOW}🔧 Reconfiguring RPC URLs...${NC}"

    if [ ! -f "$AZTEC_SERVICE" ]; then
        echo -e "${RED}❌ Service file not found at $AZTEC_SERVICE${NC}"
        return
    fi

    read -p "🔹 New Sepolia RPC: " new_l1_rpc
    read -p "🔹 New Beacon RPC: " new_beacon_rpc

    echo -e "${BLUE}⛔ Stopping Aztec service...${NC}"
    sudo systemctl stop aztec

    sudo perl -i -pe "s|--l1-rpc-urls\s+\S+|--l1-rpc-urls $new_l1_rpc|g" "$AZTEC_SERVICE"
    sudo perl -i -pe "s|--l1-consensus-host-urls\s+\S+|--l1-consensus-host-urls $new_beacon_rpc|g" "$AZTEC_SERVICE"

    sudo systemctl daemon-reload
    sudo systemctl start aztec

    echo -e "${GREEN}✅ RPCs updated and node restarted!${NC}"
}

uninstall() {
    echo -e "${YELLOW}🧹 Uninstalling Aztec Node...${NC}"

    if sudo systemctl is-active --quiet aztec; then
        sudo systemctl stop aztec
    fi

    sudo systemctl disable aztec
    sudo rm -f "$AZTEC_SERVICE"
    sudo systemctl daemon-reload
    sudo rm -rf "$AZTEC_DIR"

    echo -e "${GREEN}✅ Uninstallation complete.${NC}"
}

show_peer_id() {
    echo -e "${BLUE}🔍 Extracting Peer ID...${NC}"
    PEER_ID=$(journalctl -u aztec -n 10000 --no-pager | grep -i "peerId" | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)
    [[ -z "$PEER_ID" ]] && echo -e "${RED}❌ Peer ID not found.${NC}" || echo -e "${GREEN}✅ Peer ID: $PEER_ID${NC}"
}

update_node() {
    echo -e "${YELLOW}🔄 Updating Aztec Node...${NC}"
    sudo systemctl stop aztec
    export PATH="$PATH:$HOME/.aztec/bin"
    aztec-up latest
    sudo systemctl start aztec
    echo -e "${GREEN}✅ Node updated & restarted!${NC}"
}

generate_start_command() {
    echo -e "${YELLOW}⚙️ Generating aztec start command...${NC}"
    
    CONFIG="$HOME/.aztec/config.env"
    
    if [ ! -f "$CONFIG" ]; then
        echo -e "${RED}❌ Config file not found! Please run install first.${NC}"
        return
    fi

    source "$CONFIG"

    [[ $PRIVATE_KEY != 0x* ]] && PRIVATE_KEY="0x$PRIVATE_KEY"

    PUBLIC_IP=$(curl -s ifconfig.me)

    echo -e "${GREEN}🟢 Use the following command to run manually:${NC}"
    echo ""
    echo -e "${BLUE}aztec start --node --archiver --sequencer \\"
    echo "  --network alpha-testnet \\"
    echo "  --l1-rpc-urls $L1_RPC \\"
    echo "  --l1-consensus-host-urls $BEACON_RPC \\"
    echo "  --sequencer.validatorPrivateKey $PRIVATE_KEY \\"
    echo "  --sequencer.coinbase $EVM_ADDRESS \\"
    echo "  --p2p.p2pIp $PUBLIC_IP${NC}"
    echo ""
}

run_node() {
    clear
    show_header
    echo -e "${BLUE}🚀 Starting Aztec Node in Auto-Restart Mode...${NC}"

    sudo systemctl daemon-reload
    sudo systemctl restart aztec

    if sudo systemctl is-active --quiet aztec; then
        echo -e "${GREEN}✅ Aztec Node started successfully with auto-restart enabled.${NC}"
        echo -e "${YELLOW}📄 View logs: journalctl -fu aztec${NC}"
    else
        echo -e "${RED}❌ Failed to start the Aztec Node. Check your configuration.${NC}"
    fi
}

show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│  ██╗░░██╗██╗░░░██╗░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████╗░██████╗░░█████╗░██████╗░░██████╗  │"
    echo "│  ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝  │"
    echo "│  ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██████╔╝██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░  │"
    echo "│  ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗  │"
    echo "│  ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝  │"
    echo "│  ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░  │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW}                  🚀 Aztec Node Manager by AJ 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

# ===================== MENU ==========================
while true; do
    clear
    show_header
    echo -e "${BLUE}${BOLD}================ AZTEC NODE MANAGER BY AJ 💖 =================${NC}"
    echo -e " 1️⃣  Full Install"
    echo -e " 2️⃣  Run Node"
    echo -e " 3️⃣  View Logs"
    echo -e " 4️⃣  Reconfigure RPC"
    echo -e " 5️⃣  Uninstall Node"
    echo -e " 6️⃣  Show Peer ID"
    echo -e " 7️⃣  Update Node"
    echo -e " 8️⃣  Generate Start Command"
    echo -e " 9️⃣  Exit"
    echo -e "${BLUE}============================================================================${NC}"
    read -p "👉 Choose option (1-7): " choice

    case $choice in
        1) install_full ;;
        2) run_node ;;
        3) view_logs ;;
        4) reconfigure ;;
        5) uninstall ;;
        6) show_peer_id ;;
        7) update_node ;;
        8) generate_start_command ;;
        9) echo -e "${GREEN}👋 Exiting... Stay decentralized, AJ!${NC}"; break ;;
        *) echo -e "${RED}❌ Invalid option. Try again.${NC}"; sleep 1 ;;
    esac

    read -p "🔁 Press Enter to return to menu..."
done
