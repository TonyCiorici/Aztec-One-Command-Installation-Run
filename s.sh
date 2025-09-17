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
AZTEC_DATA_DIR="$AZTEC_DIR/testnet"

unzip_files_aztec() {
    ZIP_FILE=$(find "$HOME" -maxdepth 1 -type f -name "*.zip" | head -n 1)

    if [ -n "$ZIP_FILE" ]; then
        log "INFO" "📂 Found ZIP file: $ZIP_FILE, unzipping to $HOME ..."

        # Ensure unzip is installed
        if ! command -v unzip &>/dev/null; then
            log "INFO" "📦 'unzip' not found, installing..."
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y unzip
            elif command -v yum &>/dev/null; then
                sudo yum install -y unzip
            elif command -v apk &>/dev/null; then
                sudo apk add unzip
            else
                log "ERROR" "❌ Could not install 'unzip' (unknown package manager)."
                return 1
            fi
        fi

        # Unzip to home
        unzip -o "$ZIP_FILE" -d "$HOME" >/dev/null 2>&1

        if [ -f "$HOME/aztec.service" ]; then
            log "INFO" "✅ Extracted aztec.service to $HOME"
        else
            log "WARN" "⚠️ No aztec.service found in ZIP"
        fi

        ls -l "$HOME"
        if [ -f "$HOME/aztec.service" ]; then
            log "INFO" "✅ Successfully extracted AZTEC files from $ZIP_FILE"
        else
            log "WARN" "⚠️ No expected aztec.service file found in $ZIP_FILE"
        fi
    else
        log "WARN" "⚠️ No ZIP file found in $HOME, proceeding without unzipping"
    fi
}



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

    echo -e "${YELLOW}📂 Unzipping Aztec service files...${NC}"
    unzip_files_aztec
    
    echo -e "${YELLOW}🔐 Collecting run parameters...${NC}"
    # Define aztec.service file path
    AZTEC_SERVICE_FILE="$HOME/aztec.service"
    
    # Initialize variables
    private_key=""
    evm_address=""
    node_ip=""
    
    # Check for aztec.service file
    if [ -f "$AZTEC_SERVICE_FILE" ]; then
        log "INFO" "✅ Found aztec.service file at $AZTEC_SERVICE_FILE, attempting to extract parameters..."
        
        # Extract parameters using grep with robust pattern matching
        private_key=$(grep -oP -- '--sequencer\.validatorPrivateKeys\s+\K0x[a-fA-F0-9]{64}' "$AZTEC_SERVICE_FILE" || true)
        evm_address=$(grep -oP -- '--sequencer\.coinbase\s+\K0x[a-fA-F0-9]{40}' "$AZTEC_SERVICE_FILE" || true)
        node_ip=$(grep -oP -- '--p2p\.p2pIp\s+\K[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$AZTEC_SERVICE_FILE" || true)

        # Validate extracted parameters
        if [[ -n "$private_key" && "$private_key" =~ ^0x[a-fA-F0-9]{64}$ ]] && 
           [[ -n "$evm_address" && "$evm_address" =~ ^0x[a-fA-F0-9]{40}$ ]] && 
           [[ -n "$node_ip" && "$node_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log "INFO" "✅ Successfully extracted parameters from aztec.service"
            echo -e "${GREEN}🔑 Extracted parameters:${NC}"
            echo -e "${GREEN}  Private Key: $private_key${NC}"
            echo -e "${GREEN}  EVM Address: $evm_address${NC}"
            echo -e "${GREEN}  Node IP: $node_ip${NC}"
        else
            log "WARN" "⚠️ Failed to extract valid parameters from aztec.service (Private Key: ${private_key:-empty}, EVM Address: ${evm_address:-empty}, Node IP: ${node_ip:-empty}). Prompting user..."
            echo -e "${YELLOW}⚠️ Invalid or missing parameters in aztec.service. Please provide manually:${NC}"
            private_key=""
            evm_address=""
            node_ip=""
        fi
    else
        log "WARN" "⚠️ No aztec.service file found at $AZTEC_SERVICE_FILE. Prompting user for parameters..."
        echo -e "${YELLOW}⚠️ aztec.service file not found. Please provide parameters manually:${NC}"
    fi

    # Prompt user if any parameter is missing or invalid
    if [ -z "$private_key" ]; then
        while true; do
            read -p "🔹 EVM Private Key (with or without 0x, 64 hex chars): " private_key
            [[ $private_key != 0x* ]] && private_key="0x$private_key"
            if [[ "$private_key" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
                break
            else
                echo -e "${RED}❌ Invalid private key! Must be 64 hexadecimal characters (with 0x prefix). Try again.${NC}"
            fi
        done
    fi

    if [ -z "$evm_address" ]; then
        while true; do
            read -p "🔹 EVM Wallet Address (40 hex chars with 0x): " evm_address
            if [[ "$evm_address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                break
            else
                echo -e "${RED}❌ Invalid EVM address! Must be 40 hexadecimal characters with 0x prefix. Try again.${NC}"
            fi
        done
    fi

    if [ -z "$node_ip" ]; then
        node_ip=$(curl -s ifconfig.me 2>/dev/null || echo "")
        if [[ ! "$node_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            while true; do
                read -p "🔹 Node IP (IPv4 format, e.g., 192.168.1.1): " node_ip
                if [[ "$node_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    break
                else
                    echo -e "${RED}❌ Invalid IP address! Must be in IPv4 format (e.g., 192.168.1.1). Try again.${NC}"
                fi
            done
        fi
    fi

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
    sudo rm -rf "$HOME/.aztec/alpha-testnet/data" && sudo mkdir -p "$HOME/.aztec/alpha-testnet" && sudo wget https://files5.blacknodes.net/aztec/aztec-alpha-testnet.tar.lz4 -O /root/aztec-alpha-testnet.tar.lz4 && sudo lz4 -d /root/aztec-alpha-testnet.tar.lz4 | sudo tar x -C "$HOME/.aztec/alpha-testnet" && sudo rm /root/aztec-alpha-testnet.tar.lz4 && sudo chown -R "$USER":"$USER" "$HOME/.aztec/alpha-testnet" && sudo systemctl restart aztec
    
}

view_logs() {
    echo -e "${YELLOW}📜 Showing last 100 Aztec logs...${NC}"
    journalctl -u aztec -n 100 --no-pager --output cat

    echo -e "\n${YELLOW}📡 Streaming live logs... Press Ctrl+C to stop.${NC}\n"
    journalctl -u aztec -f --no-pager --output cat
}


reconfigure() {
    echo -e "${YELLOW}🔧 Reconfiguring RPC URLs...${NC}"

    if [ ! -f "$AZTEC_SERVICE" ]; then
        echo -e "${RED}❌ Service file not found at $AZTEC_SERVICE${NC}"
        return
    fi

    echo -e "${BLUE}📄 Reading current RPCs from service file...${NC}"
    
    old_l1_rpc=$(grep -oP '(?<=--l1-rpc-urls\s)[^\s\\]+' "$AZTEC_SERVICE")
    old_beacon_rpc=$(grep -oP '(?<=--l1-consensus-host-urls\s)[^\s\\]+' "$AZTEC_SERVICE")

    echo -e "${GREEN}🔎 Current RPCs:"
    echo -e "   🛰️ Sepolia L1 RPC       : ${YELLOW}$old_l1_rpc${NC}"
    echo -e "   🌐 Beacon Consensus RPC : ${YELLOW}$old_beacon_rpc${NC}"

    echo ""
    read -p "🔹 Enter NEW Sepolia L1 RPC: " new_l1_rpc
    read -p "🔹 Enter NEW Beacon RPC: " new_beacon_rpc

    echo -e "\n${BLUE}⛔ Stopping Aztec service...${NC}"
    sudo systemctl stop aztec

    echo -e "${YELLOW}🛠️ Replacing values in service file...${NC}"
    sudo perl -i -pe "s|--l1-rpc-urls\s+\S+|--l1-rpc-urls $new_l1_rpc|g" "$AZTEC_SERVICE"
    sudo perl -i -pe "s|--l1-consensus-host-urls\s+\S+|--l1-consensus-host-urls $new_beacon_rpc|g" "$AZTEC_SERVICE"

    echo -e "${BLUE}🔄 Reloading systemd and restarting service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl start aztec

    echo -e "${GREEN}✅ RPCs updated successfully!"
    echo -e "   🆕 New Sepolia RPC       : ${YELLOW}$new_l1_rpc${NC}"
    echo -e "   🆕 New Beacon RPC        : ${YELLOW}$new_beacon_rpc${NC}"
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
    clear
    peerid=$(sudo docker logs $(docker ps -q --filter "name=aztec" | head -1) 2>&1 | \
      grep -m 1 -ai 'DiscV5 service started' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$peerid" ]; then
      container_id=$(sudo docker ps --filter "ancestor=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep aztec | head -1)" -q | head -1)
      if [ ! -z "$container_id" ]; then
        peerid=$(sudo docker logs $container_id 2>&1 | \
          grep -m 1 -ai 'DiscV5 service started' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4)
      fi
    fi

    if [ -z "$peerid" ]; then
      peerid=$(sudo docker logs $(docker ps -q --filter "name=aztec" | head -1) 2>&1 | \
        grep -m 1 -ai '"peerId"' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4)
    fi

    label=" ● PeerID"
    peerline="✓ $peerid"
    width=${#peerline}
    [ ${#label} -gt $width ] && width=${#label}
    line=$(printf '=%.0s' $(seq 1 $width))

    if [ -n "$peerid" ]; then
      echo "$line"
      echo -e "$label"
      echo -e "\e[1;32m$peerline\e[0m"
      echo "$line"
      echo

      echo -e "\e[1;34mFetching stats from Nethermind Aztec Explorer...\e[0m"
      response=$(curl -s "https://aztec.nethermind.io/api/peers?page_size=30000&latest=true")

      stats=$(echo "$response" | jq -r --arg peerid "$peerid" '
        .peers[] | select(.id == $peerid) |
        [
          .last_seen,
          .created_at,
          .multi_addresses[0].ip_info[0].country_name,
          (.multi_addresses[0].ip_info[0].latitude | tostring),
          (.multi_addresses[0].ip_info[0].longitude | tostring)
        ] | @tsv
      ')

      if [ -n "$stats" ]; then
        IFS=$'\t' read -r last first country lat lon <<<"$stats"
        last_local=$(date -d "$last" "+%Y-%m-%d - %H:%M" 2>/dev/null || echo "$last")
        first_local=$(date -d "$first" "+%Y-%m-%d - %H:%M" 2>/dev/null || echo "$first")
        printf "%-12s: %s\n" "Last Seen"   "$last_local"
        printf "%-12s: %s\n" "First Seen"  "$first_local"
        printf "%-12s: %s\n" "Country"     "$country"
        printf "%-12s: %s\n" "Latitude"    "$lat"
        printf "%-12s: %s\n" "Longitude"   "$lon"
      else
        echo -e "\e[1;31mNo stats found for this PeerID on Nethermind Aztec Explorer.\e[0m"
      fi
    else
      echo -e "\e[1;31m❌ No Aztec PeerID found.${NC}"
    fi

    echo -e "\n${YELLOW}🔁 Press Enter to return to menu...${NC}"
    read
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


update_node() {
    echo -e "${YELLOW}🔄 Updating Aztec Node...${NC}"
    sudo systemctl stop aztec
    export PATH="$PATH:$HOME/.aztec/bin"
    aztec-up latest
    sudo rm -rf /tmp/aztec-world-state-*
    sudo systemctl start aztec
    echo -e "${GREEN}✅ Node updated & restarted!${NC}"
}

generate_start_command() {
    echo -e "${YELLOW}⚙️ Generating aztec start command from systemd service...${NC}"

    SERVICE_FILE="/etc/systemd/system/aztec.service"

    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${RED}❌ Systemd service not found at $SERVICE_FILE. Run install first.${NC}"
        return
    fi

    L1_RPC=$(grep -oP '(?<=--l1-rpc-urls )\S+' "$SERVICE_FILE")
    BEACON_RPC=$(grep -oP '(?<=--l1-consensus-host-urls )\S+' "$SERVICE_FILE")
    PRIVATE_KEY=$(grep -oP '(?<=--sequencer.validatorPrivateKeys )\S+' "$SERVICE_FILE")
    EVM_ADDRESS=$(grep -oP '(?<=--sequencer.coinbase )\S+' "$SERVICE_FILE")
    PUBLIC_IP=$(grep -oP '(?<=--p2p.p2pIp )\S+' "$SERVICE_FILE")

    echo -e "${GREEN}🟢 Use the following command to run manually:${NC}"
    echo ""
    echo -e "${BLUE}aztec start --node --archiver --sequencer \\"
    echo "  --network alpha-testnet \\"
    echo "  --l1-rpc-urls $L1_RPC \\"
    echo "  --l1-consensus-host-urls $BEACON_RPC \\"
    echo "  --sequencer.validatorPrivateKeys $PRIVATE_KEY \\"
    echo "  --sequencer.coinbase $EVM_ADDRESS \\"
    echo -e "  --p2p.p2pIp $PUBLIC_IP${NC}"
    echo ""
}


run_node() {
    clear
    show_header
    echo -e "${BLUE}🚀 Starting Aztec Node in Auto-Restart Mode...${NC}"
    sudo rm -rf /tmp/aztec-world-state-*
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
    echo -e "${YELLOW}                  🚀 Aztec Node Manager by Aashish 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

# ===================== MENU ==========================
while true; do
    clear
    show_header
    echo -e "${BLUE}${BOLD}================ AZTEC NODE MANAGER BY Aashish 💖 =================${NC}"
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
        9) echo -e "${GREEN}👋 Exiting... Stay decentralized, Aashish!${NC}"; break ;;
        *) echo -e "${RED}❌ Invalid option. Try again.${NC}"; sleep 1 ;;
    esac

    read -p "🔁 Press Enter to return to menu..."
done
