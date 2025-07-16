#!/bin/bash

# Define colors
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Check for required tools
for cmd in ip dig zip; do
    command -v $cmd >/dev/null 2>&1 || { echo -e "${RED}Error: $cmd is required but not installed. Exiting...${RESET}"; exit 1; }
done

# Function to generate random name
generate_random_name() {
    tr -dc 'a-z0-9' </dev/urandom | fold -w 5 | head -n 1
}

# Function to generate or select IPv4 address
generate_random_ipv4() {
    # Remove existing ipv4.txt
    [[ -f /root/ipv4.txt ]] && rm /root/ipv4.txt && echo -e "${YELLOW}Removed existing /root/ipv4.txt${RESET}"

    # Generate 100 IPv4 templates
    templates=()
    for i in {1..100}; do templates+=("192.168.$i.%d/32"); done

    # Prompt for template number
    echo -e "${GREEN}Enter template number (1-100) or press Enter for random:${RESET}"
    read -p "> " template_number
    template_number=${template_number:-$(shuf -i 1-100 -n 1)}
    if [[ ! "$template_number" =~ ^[1-9][0-9]?$|^100$ ]]; then
        echo -e "${RED}Invalid input. Choose 1-100.${RESET}"
        return 1
    fi
    echo -e "${GREEN}Selected template: $template_number${RESET}"

    # Check if prefix is in use
    local selected_template="${templates[$((template_number - 1))]}"
    local template_prefix=$(echo "$selected_template" | cut -d'.' -f1-3)
    if ip -4 addr show | grep -q "$template_prefix"; then
        echo -e "${RED}Prefix $template_prefix already in use. Try again.${RESET}"
        read -p "Press Enter to retry..."
        generate_random_ipv4
        return
    fi

    # Generate or get custom IP
    local last_octet=$((RANDOM % 256))
    local ipv4_address="${selected_template//%d/$last_octet}"
    echo -e "${GREEN}Enter custom IPv4 or press Enter for $ipv4_address:${RESET}"
    read -p "> " user_ipv4
    ipv4_address=${user_ipv4:-$ipv4_address}
    echo -e "${YELLOW}Using IPv4: $ipv4_address${RESET}"

    # Save to file
    echo "ipv4=$ipv4_address" > /root/ipv4.txt
    echo -e "${YELLOW}IPv4 saved to /root/ipv4.txt${RESET}"
}

# Function to get local IP
get_local_ip() {
    local ip=$(hostname -I | awk '{print $1}')
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" || { echo -e "${RED}No valid local IP found.${RESET}"; exit 1; }
}

# Function to create VXLAN tunnel
create_vxlan_tunnel() {
    # Get service name
    local default_name=$(generate_random_name)
    echo -e "${GREEN}Enter service name (default: vxlan-$default_name):${RESET}"
    read -p "> " service_name
    service_name=${service_name:-vxlan-$default_name}
    [[ ! "$service_name" =~ ^vxlan- ]] && service_name="vxlan-$service_name"
    local service_file="/usr/lib/systemd/system/$service_name.service"

    # Check if service exists
    [[ -f "$service_file" ]] && { echo -e "${RED}Service $service_name already exists.${RESET}"; return 1; }

    # Get VNI
    echo -e "${GREEN}Enter VNI (default: 100, range: 1-16777215):${RESET}"
    read -p "> " vni
    vni=${vni:-100}
    [[ ! "$vni" =~ ^[0-9]+$ || "$vni" -lt 1 || "$vni" -gt 16777215 ]] && { echo -e "${RED}Invalid VNI.${RESET}"; return 1; }

    # Get local IP
    local local_ip=$(get_local_ip)
    echo -e "${GREEN}Enter local IP or domain (default: $local_ip):${RESET}"
    read -p "> " user_input
    user_input=${user_input:-$local_ip}
    if [[ "$user_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local_ip="$user_input"
    else
        local_ip=$(dig +short "$user_input" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        [[ -z "$local_ip" ]] && { echo -e "${RED}Invalid domain or IP.${RESET}"; return 1; }
    fi

    # Generate IPv4
    generate_random_ipv4 || return 1
    source /root/ipv4.txt

    # Get remote IP
    echo -e "${GREEN}Enter remote IP or domain:${RESET}"
    read -p "> " remote_input
    if [[ "$remote_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        remote_ip="$remote_input"
    else
        remote_ip=$(dig +short "$remote_input" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        [[ -z "$remote_ip" ]] && { echo -e "${RED}Invalid remote domain or IP.${RESET}"; return 1; }
    fi

    # Get route network
    echo -e "${GREEN}Enter remote local IPv4 for routing:${RESET}"
    read -p "> " route_network
    [[ -z "$route_network" ]] && { echo -e "${RED}Route network required.${RESET}"; return 1; }

    # Select network interface
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"))
    [[ ${#interfaces[@]} -eq 0 ]] && { echo -e "${RED}No network interfaces found.${RESET}"; return 1; }
    echo -e "${GREEN}Select interface (default: 1):${RESET}"
    for i in "${!interfaces[@]}"; do echo "$((i+1)). ${interfaces[i]}"; done
    read -p "> " choice
    choice=${choice:-1}
    [[ ! "$choice" =~ ^[0-9]+$ || $choice -lt 1 || $choice -gt ${#interfaces[@]} ]] && { echo -e "${RED}Invalid interface.${RESET}"; return 1; }
    eth="${interfaces[$((choice-1))]}"

    # Create systemd service
    cat <<EOF > "$service_file"
[Unit]
Description=VXLAN Tunnel $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/sbin/ip link add $service_name type vxlan id $vni dev $eth local $local_ip remote $remote_ip && /sbin/ip addr add $ipv4 dev $service_name && /sbin/ip link set $service_name up && /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip link del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable --now "$service_name"
    echo -e "${GREEN}Tunnel $service_name created and started.${RESET}"
    read -p "Press Enter to continue..."
}

# Function to manage tunnels
manage_tunnels() {
    tunnels=($(ls /usr/lib/systemd/system/vxlan-*.service 2>/dev/null | xargs -n 1 basename | sed 's/\.service$//'))
    [[ ${#tunnels[@]} -eq 0 ]] && { echo -e "${RED}No VXLAN tunnels found.${RESET}"; read -p "Press Enter..."; return 1; }

    echo -e "${GREEN}Available tunnels:${RESET}"
    for i in "${!tunnels[@]}"; do echo "$((i+1)). ${tunnels[i]}"; done
    echo -e "${GREEN}Select a tunnel:${RESET}"
    read -p "> " choice
    [[ ! "$choice" =~ ^[0-9]+$ || $choice -lt 1 || $choice -gt ${#tunnels[@]} ]] && { echo -e "${RED}Invalid choice.${RESET}"; return 1; }

    local selected_tunnel="${tunnels[$((choice-1))]}"
    local service_file="/usr/lib/systemd/system/$selected_tunnel.service"

    # Extract IPs
    local route_ip=$(grep -oP '(?<=route\sadd\s)(\d+\.\d+\.\d+\.\d+)' "$service_file")
    local remote_ip=$(grep -oP '(?<=remote\s)(\d+\.\d+\.\d+\.\d+)' "$service_file")
    local local_ip=$(grep -oP '(?<=local\s)(\d+\.\d+\.\d+\.\d+)' "$service_file")
    local tunnel_ip=$(grep -oP '(?<=ip addr add\s)(\d+\.\d+\.\d+\.\d+)' "$service_file")

    echo -e "${GREEN}Tunnel: $selected_tunnel${RESET}"
    echo -e "Local Public IP: $local_ip\nTunnel IP: $tunnel_ip\nRemote Public IP: $remote_ip\nRemote Local IP: $route_ip"

    echo -e "${GREEN}Actions:${RESET}\n1. Start\n2. Stop\n3. Restart\n4. Enable at boot\n5. Disable at boot\n6. Status\n7. Remove\n8. Edit\n9. Change remote IP\n10. Ping remote\n0. Back"
    read -p "Choose action: " action

    case $action in
        1) systemctl start "$selected_tunnel"; echo -e "${GREEN}Started.${RESET}" ;;
        2) systemctl stop "$selected_tunnel"; systemctl daemon-reload; echo -e "${GREEN}Stopped.${RESET}" ;;
        3) systemctl restart "$selected_tunnel"; systemctl daemon-reload; echo -e "${GREEN}Restarted.${RESET}" ;;
        4) systemctl enable "$selected_tunnel"; systemctl daemon-reload; echo -e "${GREEN}Enabled at boot.${RESET}" ;;
        5) systemctl disable "$selected_tunnel"; systemctl daemon-reload; echo -e "${GREEN}Disabled at boot.${RESET}" ;;
        6) systemctl status "$selected_tunnel" ;;
        7) systemctl stop "$selected_tunnel"; systemctl disable "$selected_tunnel"; rm "$service_file"; systemctl daemon-reload; echo -e "${GREEN}Removed.${RESET}" ;;
        8) nano "$service_file"; systemctl daemon-reload; systemctl restart "$selected_tunnel" ;;
        9)
            echo -e "${GREEN}Enter new remote IP:${RESET}"
            read -p "> " new_ip
            [[ -z "$new_ip" ]] && { echo -e "${RED}No IP entered.${RESET}"; return 1; }
            sed -i "s/remote [0-9.]\+/remote $new_ip/" "$service_file"
            systemctl daemon-reload
            systemctl restart "$selected_tunnel"
            echo -e "${GREEN}Remote IP updated to $new_ip.${RESET}"
            ;;
        10)
            echo -e "${GREEN}Pinging remote local IP ($route_ip)...${RESET}"
            ping -c 4 -W 3 "$route_ip" && echo -e "${GREEN}Ping successful.${RESET}" || echo -e "${RED}Ping failed.${RESET}"
            echo -e "${GREEN}Pinging remote public IP ($remote_ip)...${RESET}"
            ping -c 4 -W 3 "$remote_ip" && echo -e "${GREEN}Ping successful.${RESET}" || echo -e "${RED}Ping failed.${RESET}"
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid option.${RESET}" ;;
    esac
    read -p "Press Enter to continue..."
}

# Function to manage all tunnels
manage_all_tunnels() {
    tunnels=($(ls /usr/lib/systemd/system/vxlan-*.service 2>/dev/null | xargs -n 1 basename | sed 's/\.service$//'))
    [[ ${#tunnels[@]} -eq 0 ]] && { echo -e "${RED}No VXLAN tunnels found.${RESET}"; read -p "Press Enter..."; return 1; }

    case $1 in
        start)
            for t in "${tunnels[@]}"; do systemctl enable --now "$t"; done
            echo -e "${GREEN}All tunnels started.${RESET}"
            ;;
        stop)
            for t in "${tunnels[@]}"; do systemctl stop "$t"; done
            systemctl daemon-reload
            echo -e "${GREEN}All tunnels stopped.${RESET}"
            ;;
        restart)
            for t in "${tunnels[@]}"; do systemctl restart "$t"; done
            systemctl daemon-reload
            echo -e "${GREEN}All tunnels restarted.${RESET}"
            ;;
    esac
    read -p "Press Enter to continue..."
}

# Function to backup files
backup_files() {
    files=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_vxlan_update.sh")
    dirs=("/root/vxlan")
    service_files="/usr/lib/systemd/system/vxlan-*.service"
    zip_file="/root/backup_$(date +%Y-%m-%d_%H-%M).zip"

    items=()
    for f in "${files[@]}" "${dirs[@]}" $service_files; do [[ -e "$f" ]] && items+=("$f"); done
    [[ ${#items[@]} -eq 0 ]] && { echo -e "${RED}No files to backup.${RESET}"; return 1; }

    zip -r "$zip_file" "${items[@]}" >/dev/null && echo -e "${GREEN}Backup created: $zip_file${RESET}" || echo -e "${RED}Backup failed.${RESET}"
    read -p "Press Enter to continue..."
}

# Function to transfer files
transfer_files() {
    files=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_vxlan_update.sh")
    dirs=("/root/vxlan")
    service_files="/usr/lib/systemd/system/vxlan-*.service"

    echo -e "${GREEN}Enter SSH details:${RESET}"
    read -p "Remote User (default: root): " user
    user=${user:-root}
    read -p "Remote Host IP: " host
    read -p "Remote Port (default: 22): " port
    port=${port:-22}

    # Check SSH connectivity
    ssh -o StrictHostKeyChecking=no -p "$port" "$user@$host" exit 2>/dev/null || { echo -e "${RED}SSH connection failed. Ensure SSH keys are set up.${RESET}"; return 1; }

    for f in "${files[@]}" "${dirs[@]}" $service_files; do
        if [[ -e "$f" ]]; then
            dest_dir=$(dirname "$f")
            scp -P "$port" -r "$f" "$user@$host:$dest_dir/" && echo -e "${GREEN}Transferred $f${RESET}" || echo -e "${RED}Failed to transfer $f${RESET}"
        fi
    done
    backup_files
}

# Main menu
while true; do
    clear
    echo -e "${GREEN}=== VXLAN Tunnel Manager ===${RESET}"
    echo -e "1. Create VXLAN Tunnel"
    echo -e "2. Manage Tunnels"
    echo -e "3. Start All Tunnels"
    echo -e "4. Stop All Tunnels"
    echo -e "5. Restart All Tunnels"
    echo -e "6. Backup Files"
    echo -e "7. Transfer Files"
    echo -e "0. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1) create_vxlan_tunnel ;;
        2) manage_tunnels ;;
        3) manage_all_tunnels start ;;
        4) manage_all_tunnels stop ;;
        5) manage_all_tunnels restart ;;
        6) backup_files ;;
        7) transfer_files ;;
        0) echo -e "${YELLOW}Exiting...${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid option.${RESET}"; sleep 1 ;;
    esac
done
