#!/bin/bash

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ──────────────[ HEADER ]──────────────
show_header() {
  clear
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${BLUE}     🔍 AZTEC NODE PORT & PEER ID CHECKER${NC}"
  echo -e "${BLUE}            Made by SpeedoWeb3 with ♥️${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo ""
}

# ──────────────[ CHECK DEPENDENCIES ]──────────────
check_dependencies() {
  local missing_deps=()
  
  # Check for required commands
  if ! command -v nc &>/dev/null; then
    missing_deps+=("netcat")
  fi
  
  if ! command -v docker &>/dev/null; then
    missing_deps+=("docker")
  fi
  
  if ! command -v curl &>/dev/null; then
    missing_deps+=("curl")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Missing dependencies detected!${NC}"
    echo -e "${CYAN}Installing: ${missing_deps[*]}${NC}"
    echo ""
    
    sudo apt-get update >/dev/null 2>&1
    
    for dep in "${missing_deps[@]}"; do
      case $dep in
        netcat)
          sudo apt-get install -y netcat-openbsd >/dev/null 2>&1
          ;;
        docker)
          echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
          exit 1
          ;;
        curl)
          sudo apt-get install -y curl >/dev/null 2>&1
          ;;
      esac
    done
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
    echo ""
  fi
}

# ──────────────[ PORT CHECKER ]──────────────
check_ports() {
  echo -e "${CYAN}● PORT STATUS CHECK${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  # Define ports to check
  declare -A ports=(
    ["40400/tcp"]="P2P TCP Port"
    ["40400/udp"]="P2P UDP Port"
    ["8080/tcp"]="RPC Port"
  )
  
  local all_ports_open=true
  
  for port_proto in "${!ports[@]}"; do
    IFS='/' read -r port proto <<< "$port_proto"
    description="${ports[$port_proto]}"
    
    # Check if port is open
    if [ "$proto" = "tcp" ]; then
      if nc -z -w2 127.0.0.1 "$port" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} Port ${WHITE}$port/$proto${NC} (${description}): ${GREEN}OPEN${NC}"
      else
        echo -e "${RED}❌${NC} Port ${WHITE}$port/$proto${NC} (${description}): ${RED}CLOSED${NC}"
        all_ports_open=false
      fi
    elif [ "$proto" = "udp" ]; then
      # UDP check is less reliable, checking if it's listening
      if sudo netstat -uln 2>/dev/null | grep -q ":$port " || sudo ss -uln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✅${NC} Port ${WHITE}$port/$proto${NC} (${description}): ${GREEN}LISTENING${NC}"
      else
        echo -e "${YELLOW}⚠️${NC} Port ${WHITE}$port/$proto${NC} (${description}): ${YELLOW}NOT DETECTED${NC}"
        all_ports_open=false
      fi
    fi
  done
  
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  if [ "$all_ports_open" = true ]; then
    echo -e "${GREEN}✅ All ports are properly configured!${NC}"
  else
    echo -e "${YELLOW}⚠️  Some ports may need attention${NC}"
  fi
}

# ──────────────[ PEER ID CHECKER ]──────────────
check_peer_id() {
  echo ""
  echo -e "${CYAN}● PEER ID CHECK${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  # Check if container exists and is running
  if ! sudo docker ps --format '{{.Names}}' | grep -q '^aztec-sequencer$'; then
    echo -e "${RED}❌ Aztec container is not running${NC}"
    return
  fi
  
  echo -e "${CYAN}Searching for Peer ID in logs...${NC}"
  
  # Method 1: Direct search in logs
  PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -o '"peerId":"[^"]*"' | head -n 1 | awk -F':' '{print $2}' | tr -d '"')
  
  # Method 2: Alternative pattern if first fails
  if [ -z "$PEER_ID" ]; then
    PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -i "peer.?id" | head -n 1 | grep -o '[0-9a-zA-Z]\{40,\}')
  fi
  
  # Method 3: Check for P2P identity
  if [ -z "$PEER_ID" ]; then
    PEER_ID=$(sudo docker logs aztec-sequencer 2>&1 | grep -i "p2p" | grep -i "id" | head -n 1 | grep -o '[0-9a-zA-Z]\{40,\}')
  fi
  
  if [ -n "$PEER_ID" ]; then
    echo -e "${GREEN}✅ Peer ID Found!${NC}"
    echo -e "${WHITE}Peer ID: ${AMBER}$PEER_ID${NC}"
    
    # Save to file for reference
    echo "$PEER_ID" > ~/.aztec_peer_id
    echo -e "${CYAN}Saved to: ${WHITE}~/.aztec_peer_id${NC}"
  else
    echo -e "${YELLOW}⚠️ Peer ID not found yet${NC}"
    echo -e "${CYAN}Node may still be starting up or syncing${NC}"
  fi
}

# ──────────────[ NETWORK INFO ]──────────────
check_network_info() {
  echo ""
  echo -e "${CYAN}● NETWORK INFORMATION${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  # Get public IP
  PUBLIC_IP=$(curl -s ipv4.icanhazip.com)
  if [ -n "$PUBLIC_IP" ]; then
    echo -e "${WHITE}Public IP:${NC} ${AMBER}$PUBLIC_IP${NC}"
    echo -e "${WHITE}P2P Endpoint:${NC} ${AMBER}$PUBLIC_IP:40400${NC}"
  else
    echo -e "${RED}Unable to detect public IP${NC}"
  fi
  
  # Check container status
  if sudo docker ps --format '{{.Names}}' | grep -q '^aztec-sequencer$'; then
    UPTIME=$(sudo docker ps --filter "name=aztec-sequencer" --format "table {{.Status}}" | tail -n 1)
    echo -e "${WHITE}Container Status:${NC} ${GREEN}Running${NC}"
    echo -e "${WHITE}Uptime:${NC} ${AMBER}$UPTIME${NC}"
  else
    echo -e "${WHITE}Container Status:${NC} ${RED}Not Running${NC}"
  fi
}

# ──────────────[ DETAILED DIAGNOSTICS ]──────────────
run_diagnostics() {
  echo ""
  echo -e "${CYAN}● DETAILED DIAGNOSTICS${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  # Check Docker service
  if systemctl is-active docker >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC} Docker service is running"
  else
    echo -e "${RED}❌${NC} Docker service is not running"
  fi
  
  # Check if aztec directory exists
  if [ -d "$HOME/aztec" ]; then
    echo -e "${GREEN}✅${NC} Aztec directory exists"
    
    # Check for docker-compose.yml
    if [ -f "$HOME/aztec/docker-compose.yml" ]; then
      echo -e "${GREEN}✅${NC} docker-compose.yml found"
    else
      echo -e "${RED}❌${NC} docker-compose.yml not found"
    fi
    
    # Check for .env file
    if [ -f "$HOME/aztec/.env" ]; then
      echo -e "${GREEN}✅${NC} .env configuration found"
    else
      echo -e "${RED}❌${NC} .env configuration not found"
    fi
  else
    echo -e "${RED}❌${NC} Aztec directory not found"
  fi
  
  # Check firewall status
  if command -v ufw &>/dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
      echo -e "${GREEN}✅${NC} Firewall is active"
      
      # Check specific port rules
      if sudo ufw status | grep -q "40400"; then
        echo -e "${GREEN}✅${NC} Port 40400 is allowed in firewall"
      else
        echo -e "${YELLOW}⚠️${NC} Port 40400 not found in firewall rules"
      fi
      
      if sudo ufw status | grep -q "8080"; then
        echo -e "${GREEN}✅${NC} Port 8080 is allowed in firewall"
      else
        echo -e "${YELLOW}⚠️${NC} Port 8080 not found in firewall rules"
      fi
    else
      echo -e "${YELLOW}⚠️${NC} Firewall is inactive"
    fi
  fi
}

# ──────────────[ MAIN MENU ]──────────────
main_menu() {
  while true; do
    show_header
    
    echo -e "${AMBER}1) Quick Check (Ports + Peer ID)${NC}"
    echo -e "${AMBER}2) Port Status Only${NC}"
    echo -e "${AMBER}3) Peer ID Only${NC}"
    echo -e "${AMBER}4) Network Information${NC}"
    echo -e "${AMBER}5) Full Diagnostics${NC}"
    echo -e "${AMBER}6) Exit${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
    read -p "$(echo -e "${AMBER}Choose option (1-6): ${NC}")" choice
    
    case $choice in
      1)
        show_header
        check_ports
        check_peer_id
        check_network_info
        echo ""
        read -p "$(echo -e "${AMBER}Press Enter to continue...${NC}")"
        ;;
      2)
        show_header
        check_ports
        echo ""
        read -p "$(echo -e "${AMBER}Press Enter to continue...${NC}")"
        ;;
      3)
        show_header
        check_peer_id
        echo ""
        read -p "$(echo -e "${AMBER}Press Enter to continue...${NC}")"
        ;;
      4)
        show_header
        check_network_info
        echo ""
        read -p "$(echo -e "${AMBER}Press Enter to continue...${NC}")"
        ;;
      5)
        show_header
        check_ports
        check_peer_id
        check_network_info
        run_diagnostics
        echo ""
        read -p "$(echo -e "${AMBER}Press Enter to continue...${NC}")"
        ;;
      6)
        echo ""
        echo -e "${GREEN}Thank you for using Aztec Port Checker!${NC}"
        echo -e "${GREEN}Made with ♥️ by SpeedoWeb3${NC}"
        echo ""
        break
        ;;
      *)
        echo -e "${RED}Invalid option. Please try again.${NC}"
        sleep 2
        ;;
    esac
  done
}

# ──────────────[ SCRIPT START ]──────────────
check_dependencies
main_menu
