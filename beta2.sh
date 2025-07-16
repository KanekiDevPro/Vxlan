#!/bin/bash

# Define colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'

# Check for required tools
for cmd in ip dig zip; do
    command -v $cmd >/dev/null 2>&1 || { echo -e "${RED}Error: $cmd is required but not installed. Install it using your package manager (e.g., 'sudo apt install $cmd').${RESET}"; exit 1; }
done

# Function to generate random name
generate_random_name() {
    tr -dc 'a-z0-9' </dev/urandom | fold -w 5 | head -n 1
}

# Function to generate or select IPv4 address
generate_random_ipv4() {
    [[ -f /root/ipv4.txt ]] && rm /root/ipv4.txt && echo -e "${YELLOW}Removed existing /root/ipv4.txt${RESET}"
    templates=()
    for i in {1..100}; do templates+=("192.168.$i.%d/32"); done
    echo -e "${BLUE}Step 1: Select an IPv4 template${RESET}"
    echo -e "${GREEN}Enter a number (1-100) to choose a network range. Press Enter for a random choice.${RESET}"
    read -p "> " template_number
    template_number=${template_number:-$(shuf -i 1-100 -n 1)}
    if [[ ! "$template_number" =~ ^[1-9][0-9]?$|^100$ ]]; then echo -e "${RED}Invalid input.${RESET}"; read -p "Enter..."; generate_random_ipv4; return; fi
    local selected_template="${templates[$((template_number - 1))]}"
    local template_prefix=$(echo "$selected_template" | cut -d'.' -f1-3)
    if ip -4 addr show | grep -q "$template_prefix"; then echo -e "${RED}Conflict with existing network.${RESET}"; read -p "Enter..."; generate_random_ipv4; return; fi
    local last_octet=$((RANDOM % 256))
    local ipv4_address="${selected_template//%d/$last_octet}"
    echo -e "${BLUE}Step 2: Set tunnel IP${RESET}"
    read -p "> " user_ipv4
    ipv4_address=${user_ipv4:-$ipv4_address}
    echo "ipv4=$ipv4_address" > /root/ipv4.txt
    echo -e "${YELLOW}Saved: $ipv4_address${RESET}"
}

get_local_ip() { hostname -I | awk '{print $1}'; }

create_vxlan_tunnel() {
    echo -e "${BLUE}=== Creating VXLAN ===${RESET}"
    local default_name=$(generate_random_name)
    echo -e "${BLUE}Step 1: Set service name${RESET}"
    read -p "> " service_name
    service_name=${service_name:-vxlan-$default_name}
    [[ ! "$service_name" =~ ^vxlan- ]] && service_name="vxlan-$service_name"
    local service_file="/usr/lib/systemd/system/$service_name.service"
    [[ -f "$service_file" ]] && { echo -e "${RED}Service exists.${RESET}"; return 1; }
    echo -e "${GREEN}Using: $service_name${RESET}"

    echo -e "${BLUE}Step 2: Set VNI${RESET}"
    read -p "> " vni
    vni=${vni:-100}

    local local_ip=$(get_local_ip)
    echo -e "${BLUE}Step 3: Set local IP or domain${RESET}"
    read -p "> " user_input
    user_input=${user_input:-$local_ip}
    local_ip=$(dig +short "$user_input" | grep -E '^[0-9.]+' || echo "$user_input")
    echo -e "${GREEN}Using: $local_ip${RESET}"

    echo -e "${BLUE}Step 4: Tunnel IP${RESET}"
    generate_random_ipv4 || return 1
    source /root/ipv4.txt

    echo -e "${BLUE}Step 5: Remote IP or domain${RESET}"
    read -p "> " remote_input
    remote_ip=$(dig +short "$remote_input" | grep -E '^[0-9.]+' || echo "$remote_input")

    echo -e "${BLUE}Step 6: Remote tunnel IP${RESET}"
    read -p "> " route_network

    echo -e "${BLUE}Step 7: Network interface${RESET}"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))
    for i in "${!interfaces[@]}"; do echo "$((i+1)). ${interfaces[i]}"; done
    read -p "> " choice
    eth="${interfaces[$((choice-1))]}"

    echo -e "${BLUE}Step 8: Creating service${RESET}"
    cat <<EOF > "$service_file"
[Unit]
Description=VXLAN $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/sbin/ip link add $service_name type vxlan id $vni dev $eth local $local_ip remote $remote_ip && /sbin/ip addr add $ipv4 dev $service_name && /sbin/ip link set $service_name up && /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip link del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$service_name" && echo -e "${GREEN}Started!${RESET}" || echo -e "${RED}Failed.${RESET}"
    read -p "Enter to continue..."
}

configure_haproxy() {
    echo -e "${BLUE}=== Configure HAProxy for Multi-Port Forwarding ===${RESET}"
    if ! command -v haproxy &>/dev/null; then
        echo -e "${YELLOW}Installing HAProxy...${RESET}"
        apt update && apt install -y haproxy || { echo -e "${RED}Failed.${RESET}"; return 1; }
    fi

    echo -e "${GREEN}Tunnel IP (e.g. 192.168.1.100):${RESET}"
    read -p "> " tunnel_ip
    [[ -z "$tunnel_ip" ]] && { echo -e "${RED}Required.${RESET}"; return 1; }

    echo -e "${GREEN}Ports to forward (e.g. 443 2087 80):${RESET}"
    read -p "> " ports_input
    [[ -z "$ports_input" ]] && { echo -e "${RED}Required.${RESET}"; return 1; }

    config_path="/etc/haproxy/haproxy.cfg"
    cp "$config_path" "$config_path.bak"

    cat <<EOF > "$config_path"
global
    daemon
    maxconn 256
    log /dev/log local0

defaults
    mode tcp
    timeout connect 10s
    timeout client 1m
    timeout server 1m
EOF

    for port in $ports_input; do
        cat <<EOF >> "$config_path"

frontend fe_$port
    bind *:$port
    default_backend be_$port

backend be_$port
    server server1 $tunnel_ip:$port check
EOF
    done

    systemctl restart haproxy && echo -e "${GREEN}HAProxy restarted.${RESET}" || echo -e "${RED}Failed.${RESET}"
    read -p "Enter to continue..."
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== VXLAN Tunnel + HAProxy Manager ===${RESET}"
    echo -e "${GREEN}1. Create VXLAN tunnel${RESET}"
    echo -e "${GREEN}2. Configure HAProxy for multi-port forwarding${RESET}"
    echo -e "${RED}0. Exit${RESET}"
    read -p "Choose: " choice

    case $choice in
        1) create_vxlan_tunnel ;;
        2) configure_haproxy ;;
        0) echo -e "${YELLOW}Goodbye.${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid.${RESET}"; sleep 1 ;;
    esac
done
