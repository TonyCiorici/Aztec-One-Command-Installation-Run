# 🚀 Aztec Node Setup Guide

Welcome to the **Aztec Node Manager**! This guide will help you set up, manage, and monitor your Aztec node with ease. Follow the steps below to get started.

---

## 🛠️ One-Command Full Menu Setup

Run this command in your terminal to launch the interactive menu:

```bash
bash <(curl -fsSL https://github.com/HustleAirdrops/Aztec-One-Command-Installation-Run/raw/main/menu.sh)
```

> **Note:** During setup, you’ll need to enter your **Sepolia RPC**, **Beacon RPC**, **Private Key**, and **Wallet Address**. Provide these details whenever prompted.
>
> Your **wallet** must have Sepolia testnet ETH. You can get free testnet ETH from [https://sepolia-faucet.pk910.de/](https://sepolia-faucet.pk910.de/).

### 📋 Menu Options Explained

| Option | Description |
|--------|-------------|
| 1️⃣ Full Install         | Installs the Aztec node from scratch. |
| 2️⃣ Run Node            | Starts your Aztec node. |
| 3️⃣ View Logs           | Shows real-time logs for troubleshooting. |
| 4️⃣ Reconfigure RPC     | Change your RPC endpoint settings. |
| 5️⃣ Uninstall Node      | Completely removes the node from your system. |
| 6️⃣ Show Peer ID        | Displays your node's Peer ID (needed for rewards). |
| 7️⃣ Update Node         | Updates your node to the latest version. |
| 8️⃣ Generate Start Command | Creates a command to start your node easily. |
| 9️⃣ Exit                | Closes the menu. |

---

## 📄 Check Node Logs

Monitor your node logs with:
```bash
journalctl -u aztec -n 100 --no-pager --output cat
journalctl -u aztec -f --no-pager --output cat
```

---

## 🔑 Get Sepolia & Beacon API Keys

You’ll need API keys for Sepolia & Beacon. Get them from:

- [Rockx](https://access.rockx.com/)
- [BlockPi](https://blockpi.io/)
- [Drpc](https://drpc.org/)
- [Chainstack](https://console.chainstack.com/projects/)
- [Ankr](https://www.ankr.com/)
- [Tenderly](https://dashboard.tenderly.co/)

Or create your own RPC 👉 [Private RPC Guide](https://github.com/HustleAirdrops/Private-RPC-For-Aztec/)

---

## 🛡️ Get Guardian Role (After Snapshot)

1. Run your node for at least **one week**.
2. After the snapshot, check your role:
    - Go to the **#Upgrade-Role** channel.
    - Type `/checkip` and enter your IP & ETH address.

---

## 🏆 Check Your Node Status & Uptime

- Go to [@AztecChecker_bot](https://t.me/AztecChecker_bot) on Telegram.
- Send `/add` and your **Peer ID** to track rewards.

---

## ❓ FAQ

For frequently asked questions, [click here](FAQ.md).

---

## 💬 Need Help?

- **Support:** [@Legend_Aashish](https://t.me/Legend_Aashish)
- **Guides, Videos & Updates:** [@Hustle_Airdrops](https://t.me/Hustle_Airdrops)

> 🚀 **Stay ahead — join the channel now!**

---

✨ **Happy Node Running!** ✨
