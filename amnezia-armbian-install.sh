#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# Color Definitions
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ==========================================
# Environment & Privilege Checks
# ==========================================
function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		echo -e "${RED}This script must be run as root.${NC}"
		exit 1
	fi
}

function checkOS() {
	IS_ARMBIAN=false
	if [ -f /etc/armbian-release ]; then
		IS_ARMBIAN=true
	elif [ -f /etc/os-release ] && grep -qi "armbian" /etc/os-release; then
		IS_ARMBIAN=true
	fi

	if [ "$IS_ARMBIAN" = false ]; then
		echo -e "${RED}[ERROR] This device does not appear to be running Armbian!${NC}"
		echo "Installation aborted."
		exit 1
	fi
}

# ==========================================
# Installation Function
# ==========================================
function install_amneziawg() {
	# Step 1
	echo -e "${GREEN}[1/8] Enabling deb-src repository...${NC}"
	SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
	if [ -f "$SOURCES_FILE" ]; then
		sed -i 's/^Types: deb$/Types: deb deb-src/' "$SOURCES_FILE"
		echo -e "  ${GREEN}✓${NC} deb-src successfully added to $SOURCES_FILE"
	else
		echo -e "  ${YELLOW}! File $SOURCES_FILE not found, skipping...${NC}"
	fi

	# Step 2
	echo -e "\n${GREEN}[2/8] Updating repositories and installing initial dependencies...${NC}"
	apt update
	apt install -y gnupg curl nano

	# Step 3
	echo -e "\n${GREEN}[3/8] Downloading and saving Amnezia GPG Key...${NC}"
	curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x57290828" | gpg --dearmor -o /etc/apt/trusted.gpg.d/amnezia.gpg

	# Step 4
	echo -e "\n${GREEN}[4/8] Adding Amnezia PPA Repository...${NC}"
	echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | tee /etc/apt/sources.list.d/amnezia.list
	echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | tee -a /etc/apt/sources.list.d/amnezia.list

	# Step 5
	echo -e "\n${GREEN}[5/8] Updating repositories and installing AmneziaWG...${NC}"
	apt update
	apt install -y amneziawg

	# Step 6
	echo -e "\n${GREEN}[6/8] Enabling Permanent IP Forwarding...${NC}"
	echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/99-amneziawg.conf
	sysctl -p /etc/sysctl.d/99-amneziawg.conf

	# Step 7
	echo -e "\n${GREEN}[7/8] Setting up Configuration Directory...${NC}"
	CONFIG_DIR="/etc/amnezia/amneziawg"
	CONFIG_FILE="$CONFIG_DIR/awg0.conf"

	mkdir -p "$CONFIG_DIR"
	chmod 700 "$CONFIG_DIR"

	echo -e "\n${CYAN}-----------------------------------------------------${NC}"
	echo -e " ${BOLD}${YELLOW}PASTE YOUR CLIENT awg0.conf CONFIGURATION IN NANO${NC}"
	echo -e " ${ORANGE}1. Paste your configuration text into nano.${NC}"
	echo -e " ${ORANGE}2. Press CTRL+O -> ENTER to save, then CTRL+X to exit.${NC}"
	echo -e "${CYAN}-----------------------------------------------------${NC}\n"

	read -rp "$(echo -e "${CYAN}Press any key to open nano editor...${NC}")" -n1

	nano "$CONFIG_FILE"

	# Validation check
	if [ ! -s "$CONFIG_FILE" ]; then
		echo -e "\n${RED}[ERROR] Configuration file $CONFIG_FILE is empty or missing!${NC}"
		exit 1
	fi

	# Clean Windows CRLF formatting & set permissions
	sed -i 's/\r$//' "$CONFIG_FILE"
	chmod 600 "$CONFIG_FILE"
	echo -e "  ${GREEN}✓${NC} Configuration saved and secured."

	# Step 8
	echo -e "\n${GREEN}[8/8] Starting AmneziaWG Interface & Enabling Autostart...${NC}"

	# Start AmneziaWG interface
	awg-quick up awg0

	# Enable autostart on system boot
	systemctl enable awg-quick@awg0

	# Summary Output
	echo -e "\n${CYAN}=====================================================${NC}"
	echo -e " ${BOLD}${GREEN}✔ AmneziaWG Successfully Installed & Running!${NC}"
	echo -e "${CYAN}=====================================================${NC}\n"

	echo -e "${BOLD}${YELLOW}[ Current status of awg0 interface ]${NC}\n"
	awg show
	echo ""
}

# ==========================================
# Check Status Function
# ==========================================
function check_status() {
	echo -e "\n${CYAN}-----------------------------------------------------${NC}"
	echo -e " ${BOLD}${YELLOW}AmneziaWG Status Check${NC}"
	echo -e "${CYAN}-----------------------------------------------------${NC}\n"
	
	if command -v awg &> /dev/null; then
		echo -e "${GREEN}Service Autostart Status:${NC}"
		systemctl is-enabled awg-quick@awg0 2>/dev/null || echo "Disabled / Not active"
		echo -e "\n${GREEN}Interface Status (awg show):${NC}"
		awg show || echo -e "${RED}Interface awg0 is currently down.${NC}"
	else
		echo -e "${RED}AmneziaWG is not installed on this system.${NC}"
	fi
	echo ""
}

# ==========================================
# Clean Uninstall Function
# ==========================================
function uninstall_amneziawg() {
	echo -e "\n${CYAN}-----------------------------------------------------${NC}"
	echo -e " ${BOLD}${RED}Uninstalling AmneziaWG & Restoring Configs...${NC}"
	echo -e "${CYAN}-----------------------------------------------------${NC}\n"

	# Stop interface & disable autostart
	echo -e "${GREEN}[1/6] Stopping AmneziaWG service...${NC}"
	systemctl stop awg-quick@awg0 2>/dev/null || true
	systemctl disable awg-quick@awg0 2>/dev/null || true
	if command -v awg-quick &> /dev/null; then
		awg-quick down awg0 2>/dev/null || true
	fi

	# Remove package
	echo -e "${GREEN}[2/6] Removing AmneziaWG package...${NC}"
	apt purge -y amneziawg || true
	apt autoremove -y

	# Remove repositories & GPG keys
	echo -e "${GREEN}[3/6] Removing Amnezia PPA repository & keys...${NC}"
	rm -f /etc/apt/sources.list.d/amnezia.list
	rm -f /etc/apt/trusted.gpg.d/amnezia.gpg

	# Restore deb-src config in debian.sources if modified
	echo -e "${GREEN}[4/6] Restoring debian.sources repository config...${NC}"
	SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
	if [ -f "$SOURCES_FILE" ]; then
		sed -i 's/^Types: deb deb-src$/Types: deb/' "$SOURCES_FILE"
		echo -e "  ${GREEN}✓${NC} Restored original Types in $SOURCES_FILE"
	fi

	# Restore sysctl setting
	echo -e "${GREEN}[5/6] Restoring sysctl IP forward settings...${NC}"
	if [ -f /etc/sysctl.d/99-amneziawg.conf ]; then
		rm -f /etc/sysctl.d/99-amneziawg.conf
		sysctl --system >/dev/null 2>&1 || true
		echo -e "  ${GREEN}✓${NC} Removed /etc/sysctl.d/99-amneziawg.conf"
	fi

	# Remove configuration directories
	echo -e "${GREEN}[6/6] Deleting configuration files...${NC}"
	rm -rf /etc/amnezia/amneziawg
	rm -rf /etc/amnezia

	apt update
	echo -e "\n${GREEN}✔ Clean uninstall completed successfully!${NC}\n"
}

# ==========================================
# Interactive Main Menu
# ==========================================
clear
echo -e "${CYAN}=====================================================${NC}"
echo -e "   ${BOLD}${GREEN}AmneziaWG Client Manager${NC} - ${BOLD}Armbian OS${NC}"
echo -e "${CYAN}=====================================================${NC}\n"

isRoot
checkOS

echo -e " Please select an option:"
echo -e "  ${GREEN}1)${NC} Install AmneziaWG"
echo -e "  ${GREEN}2)${NC} Check Status"
echo -e "  ${GREEN}3)${NC} Clean Uninstall"
echo -e "  ${GREEN}4)${NC} Exit\n"

read -rp "$(echo -e "${CYAN}Your choice [1-4]: ${NC}")" choice

case $choice in
	1)
		install_amneziawg
		;;
	2)
		check_status
		;;
	3)
		read -rp "$(echo -e "${RED}Are you sure you want to uninstall AmneziaWG? (y/N): ${NC}")" confirm
		if [[ "$confirm" =~ ^[Yy]$ ]]; then
			uninstall_amneziawg
		else
			echo -e "${YELLOW}Uninstall process aborted.${NC}"
		fi
		;;
	4)
		echo -e "${GREEN}Done.${NC}"
		exit 0
		;;
	*)
		echo -e "${RED}Invalid option!${NC}"
		exit 1
		;;
esac