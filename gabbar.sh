#!/bin/bash

# === GABBARIPCHANGER v1.0 ===

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

# Fancy banner
banner() {
  clear
  if ! command -v toilet &>/dev/null; then
    echo "📦 Installing toilet (fancy text banner)..."
    apt update && apt install -y toilet || echo "⚠️ Failed to install toilet"
  fi

  if command -v toilet &>/dev/null; then
    toilet -f mono12 -F metal "GABBAR"
    toilet -f mono12 -F metal "IP"
    toilet -f mono12 -F metal "ROTATOR"
  else
    echo "=== GABBARIPCHANGER v1.0 ==="
  fi
  echo -e "🔄 TOR IP ROTATOR\n"
}

# GPG key fix for Kali Linux
fix_kali_gpg() {
  if grep -qi "kali" /etc/os-release; then
    echo "🔐 Fixing Kali GPG key..."
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ED65462EC8D5E4C5
  fi
}

# Dependency install
install_deps() {
  echo "📦 Installing required packages: curl, tor, jq, netcat..."
  fix_kali_gpg
  apt update
  apt install -y curl jq toilet gnupg lsb-release netcat-openbsd || apt install -y netcat-traditional

  if ! apt install -y tor; then
    echo "⚠️ Tor not found in default repos. Adding Tor Project repo..."
    echo "deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/tor.list
    curl https://deb.torproject.org/torproject.org/pubkey.gpg | gpg --dearmor > /usr/share/keyrings/tor-archive-keyring.gpg
    apt update && apt install -y tor
  fi
}

# Tor config setup
setup_tor_control() {
  echo -e "\n🔐 Setting up Tor control port..."
  read -rsp "🧩 Enter a password for Tor control access: " torpass
  echo

  hashed_pass=$(tor --hash-password "$torpass" | grep "^16:")
  echo "$torpass" > ~/.torpass
  chmod 600 ~/.torpass

  torrc="/etc/tor/torrc"
  mkdir -p "$(dirname "$torrc")"

  grep -q "^ControlPort" "$torrc" || echo "ControlPort 9051" >> "$torrc"
  sed -i '/^HashedControlPassword/d' "$torrc"
  echo "HashedControlPassword $hashed_pass" >> "$torrc"

  systemctl restart tor || echo "⚠️ Failed to restart tor.service"
  sleep 5
}

# Fetch IP via Tor
show_ip() {
  ip=$(curl -s --socks5-hostname 127.0.0.1:9050 https://checkip.amazonaws.com)
  geo=$(curl -s --socks5-hostname 127.0.0.1:9050 "http://ip-api.com/json/$ip?fields=country,regionName,city")
  echo -e "🌐 New IP: \033[1;32m$ip\033[0m"
  echo "📍 Location: $geo"
}

# Change IP using Tor control
change_ip() {
  echo -e "\n🔄 Requesting new Tor identity..."
  {
    echo "authenticate \"$(cat ~/.torpass)\""
    echo "signal newnym"
    echo "quit"
  } | nc 127.0.0.1 9051 > /dev/null
  sleep 6
  show_ip
}

# Main loop
main_loop() {
  read -rp "⏱ Interval between IP changes (in seconds): " interval
  read -rp "🔁 How many times to change IP? (0 = infinite): " count

  if [ "$count" -eq 0 ]; then
    i=1
    while true; do
      echo -e "\n♻️ Change $i"
      change_ip
      sleep "$interval"
      ((i++))
    done
  else
    for ((i=1; i<=count; i++)); do
      echo -e "\n♻️ Change $i of $count"
      change_ip
      sleep "$interval"
    done
  fi
}

# Full Execution
banner
install_deps
systemctl enable tor
systemctl start tor || { echo "❌ Failed to start tor.service"; exit 1; }

if [ ! -f ~/.torpass ]; then
  setup_tor_control
fi

main_loop
