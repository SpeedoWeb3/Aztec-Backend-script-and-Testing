#!/bin/bash
set -u   # Exit on undefined variables

# ──────────────[ COLORS ]──────────────
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m'

# ──────────────[ HEADER ]──────────────
show_header() {
  clear
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e "${BLUE}     🔍 AZTEC NODE PORT & PEER ID CHECKER${NC}"
  echo -e "${BLUE}            Made by SpeedoWeb3 with ♥️${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
  echo -e ""
}

# ──────────────[ CHECK DEPENDENCIES ]──────────────
check_dependencies() {
  if ! command -v nc &>/dev/null; then
    sudo apt-get update -qq >/dev/null 2>&1
    sudo apt-get install -y netcat-openbsd -qq >/dev/null 2>&1
  fi
  
  if ! command -v netstat &>/dev/null && ! command -v ss &>/dev/null; then
    sudo apt-get install -y net-tools -qq >/dev/null 2>&1
  fi
}

# ──────────────[ PORT CHECKER ]──────────────
check_ports() {
  show_header
  echo -e "${CYAN}● PORT STATUS CHECK${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  echo -e ""
  
  # TCP Port 40400
  printf "Port 40400/tcp (P2P): "
  if nc -z -w2 127.0.0.1 40400 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OPEN${NC}"
  else
    echo -e "${RED}❌ CLOSED${NC}"
  fi
  
  # UDP Port 40400
  printf "Port 40400/udp (P2P): "
  if sudo netstat -uln 2>/dev/null | grep -q ":40400 " || sudo ss -uln 2>/dev/null | grep -q ":40400 "; then
    echo -e "${GREEN}✅ LISTENING${NC}"
  else
    echo -e "${YELLOW}⚠️ NOT DETECTED${NC}"
  fi
  
  # TCP Port 8080
  printf "Port 8080/tcp (RPC):  "
  if nc -z -w2 127.0.0.1 8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OPEN${NC}"
  else
    echo -e "${RED}❌ CLOSED${NC}"
  fi
  
  echo -e ""
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  
  # Firewall check
  echo -e ""
  echo -e "${CYAN}● FIREWALL STATUS${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  echo -e ""
  
  if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "")
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
      printf "Port 40400: "
      if echo "$UFW_STATUS" | grep -q "40400"; then
        echo -e "${GREEN}✅ Allowed${NC}"
      else
        echo -e "${RED}❌ Not Allowed${NC}"
      fi
      
      printf "Port 8080:  "
      if echo "$UFW_STATUS" | grep -q "8080"; then
        echo -e "${GREEN}✅ Allowed${NC}"
      else
        echo -e "${RED}❌ Not Allowed${NC}"
      fi
    else
      echo -e "${YELLOW}Firewall is inactive${NC}"
    fi
  else
    echo -e "${YELLOW}UFW not installed${NC}"
  fi
  
  echo -e ""
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
}

# ──────────────[ PEER ID CHECKER ]──────────────
check_peer_id() {
  show_header
  echo -e "${CYAN}● PEER ID CHECK${NC}"
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
  echo -e ""
  
  # Initialize variables
  CONTAINER_ID=""
  PEER_ID=""
  
  # Get container ID dynamically
  CONTAINER_ID=$(sudo docker ps -q --filter "ancestor=aztecprotocol/aztec" 2>/dev/null | head -n 1)
  
  # Fallback to container name
  if [ -z "$CONTAINER_ID" ]; then
    if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^aztec-sequencer$'; then
      CONTAINER_ID="aztec-sequencer"
    fi
  fi
  
  if [ -z "$CONTAINER_ID" ]; then
    echo -e "${RED}❌ No Aztec container running${NC}"
    echo -e ""
    echo -e "${AMBER}───────────────────────────────────────────────${NC}"
    return
  fi
  
  # Get peer ID using the requested command
  PEER_ID=$(sudo docker logs "$CONTAINER_ID" 2>&1 | grep -i "peerId" | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)
  
  # Fallback method
  if [ -z "$PEER_ID" ]; then
    PEER_ID=$(sudo docker logs "$CONTAINER_ID" 2>&1 | grep -o '16Uiu2[A-Za-z0-9]*' | head -n 1)
  fi
  
  if [ -n "$PEER_ID" ]; then
    echo -e "${WHITE}Peer ID:${NC}"
    echo -e "${AMBER}$PEER_ID${NC}"
  else
    echo -e "${YELLOW}⚠️ Peer ID not found${NC}"
    echo -e "${CYAN}Node may still be initializing${NC}"
  fi
  
  echo -e ""
  echo -e "${AMBER}───────────────────────────────────────────────${NC}"
}

#──────────────[ MAIN MENU ]──────────────

main_menu() {
local choice=""

while true; do
show_header

echo -e "${AMBER}1) Check Ports${NC}"  
echo -e "${AMBER}2) Check Peer ID${NC}"  
echo -e "${AMBER}3) Back to Main Menu${NC}"  
echo -e ""  
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"  
echo -e ""  
  
printf "Select option (1-3): "  
read -r choice  
  
case "${choice:-}" in  
  1)  
    check_ports  
    echo -e ""  
    printf "Press Enter to continue..."  
    read -r  
    ;;  
  2)  
    check_peer_id  
    echo -e ""  
    printf "Press Enter to continue..."  
    read -r  
    ;;  
  3)  
    echo -e ""  
    echo -e "${GREEN}Returning to Main Menu...${NC}"  
    echo -e ""  
    break  
    ;;  
  *)  
    echo -e "${RED}Invalid option. Please select 1, 2, or 3.${NC}"  
    sleep 2  
    ;;  
esac

done
}

#──────────────[ SCRIPT START ]──────────────

check_dependencies
main_menu
