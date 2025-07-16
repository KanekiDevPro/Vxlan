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
if ! command -v ping6 >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: ping6 not found. IPv6 ping tests may fail. Install 'iputils-ping' if needed.${RESET}"
fi

# Function to generate random name
generate_random_name() {
    tr -dc 'a-z0-9' </dev/urandom | fold -w 5 | head -n 1
}

# Function to generate or select tunnel IP (IPv4 or IPv6)
generate_tunnel_ip() {
    local ip_version="$1"
    # Remove existing ip.txt
    [[ -f /root/ip.txt ]] && rm /root/ip.txt && echo -e "${YELLOW}Removed existing /root/ip.txt${RESET}"

    if [[ "$ip_version" == "1" ]]; then
        # IPv4 logic
        # Generate 100 IPv4 templates
        templates=()
        for i in {1..100}; do templates+=("192.168.$i.%d/32"); done

        # Prompt for template number
        echo -e "${BLUE}Step 2: Select an IPv4 template${RESET}"
        echo -e "${GREEN}Enter a number (1-100) to choose a network range (e.g., 192.168.1.x). Press Enter for a random choice.${RESET}"
        echo -e "${YELLOW}Example: Enter '1' for 192.168.1.x or '50' for 192.168.50.x${RESET}"
        read -p "> " template_number
        template_number=${template_number:-$(shuf -i 1-100 -n 1)}
        if [[ ! "$template_number" =~ ^[1-9][0-9]?$|^100$ ]]; then
            echo -e "${RED}Invalid input. Please enter a number between 1 and 100.${RESET}"
            read -p "Press Enter to retry..."
            generate_tunnel_ip "$ip_version"
            return
        fi
        echo -e "${GREEN}Selected template: 192.168.$template_number.x${RESET}"

        # Check if prefix is in use
        local selected_template="${templates[$((template_number - 1))]}"
        local template_prefix=$(echo "$selected_template" | cut -d'.' -f1-3)
        if ip -4 addr show | grep -q "$template_prefix"; then
            echo -e "${RED}Error: The network $template_prefix.x is already in use on this system.${RESET}"
            echo -e "${YELLOW}Choose a different template number to avoid conflicts.${RESET}"
            read -p "Press Enter to retry..."
            generate_tunnel_ip "$ip_version"
            return
        fi

        # Generate or get custom IP
        local last_octet=$((RANDOM % 256))
        local ip_address="${selected_template//%d/$last_octet}"
        echo -e "${BLUE}Step 3: Set tunnel IPv4 address${RESET}"
        echo -e "${GREEN}Enter a custom IPv4 address for the tunnel or press Enter to use $ip_address.${RESET}"
        echo -e "${YELLOW}Example: 192.168.$template_number.100 (must be in the 192.168.$template_number.x range).${RESET}"
        read -p "> " user_ip
        ip_address=${user_ip:-$ip_address}
        if [[ ! "$ip_address" =~ ^$template_prefix\.[0-9]+/32$ ]]; then
            # اصلاح: باید چک کنیم فقط آدرس IP بدون /32 باشه چون اینجا آدرس IP است نه subnet notation
            # پس شرط درست تر میشه:
            prefix_escaped=$(echo "$template_prefix" | sed 's/\./\\./g')
            if [[ ! "$ip_address" =~ ^$prefix_escaped\.[0-9]{1,3}$ ]]; then
                echo -e "${RED}Invalid IPv4. It must be in the $template_prefix.x range.${RESET}"
                read -p "Press Enter to retry..."
                generate_tunnel_ip "$ip_version"
                return
            fi
        fi
        echo -e "${GREEN}Using tunnel IP: $ip_address${RESET}"
        echo "ip=$ip_address" > /root/ip.txt
        echo -e "${YELLOW}IP saved to /root/ip.txt${RESET}"
    else
        # IPv6 logic
        # Use fd00::/8 range for Unique Local Addresses
        local ipv6_prefix="fd$(openssl rand -hex 5)::"
        local ipv6_address="$ipv6_prefix$(openssl rand -hex 4)/128"
        echo -e "${BLUE}Step 2: Set tunnel IPv6 address${RESET}"
        echo -e "${GREEN}Enter a custom IPv6 address for the tunnel or press Enter to use $ipv6_address.${RESET}"
        echo -e "${YELLOW}Example: fd12:3456:789a::1 (must be in the fd00::/8 range).${RESET}"
        read -p "> " user_ip
        ip_address=${user_ip:-$ipv6_address}
        if [[ ! "$ip_address" =~ ^fd[0-9a-f]{2}:[0-9a-f:]+(/128)?$ ]]; then
            echo -e "${RED}Invalid IPv6. It must be in the fd00::/8 range with /128 prefix.${RESET}"
            read -p "Press Enter to retry..."
            generate_tunnel_ip "$ip_version"
            return
        fi
        # Check if IPv6 address is in use
        if ip -6 addr show | grep -q "$(echo "$ip_address" | cut -d'/' -f1)"; then
            echo -e "${RED}Error: The IPv6 address $ip_address is already in use on this system.${RESET}"
            read -p "Press Enter to retry..."
            generate_tunnel_ip "$ip_version"
            return
        fi
        echo -e "${GREEN}Using tunnel IP: $ip_address${RESET}"
        echo "ip=$ip_address" > /root/ip.txt
        echo -e "${YELLOW}IP saved to /root/ip.txt${RESET}"
    fi
}

# Function to get local IP
get_local_ip() {
    local ip_version="$1"
    if [[ "$ip_version" == "1" ]]; then
        local ip=$(hostname -I | awk '{for(i=1;i<=NF;i++) if($i~/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {print $i; exit}}')
        [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip" || { echo -e "${RED}No valid IPv4 found. Ensure your network is configured correctly.${RESET}"; exit 1; }
    else
        local ip=$(hostname -I | awk '{for(i=1;i<=NF;i++) if($i~/^[0-9a-f:]+$/ && $i!~/^fe80/) {print $i; exit}}')
        [[ "$ip" =~ ^[0-9a-f:]+$ && "$ip" != fe80* ]] && echo "$ip" || { echo -e "${RED}No valid global IPv6 found. Ensure your network is configured correctly.${RESET}"; exit 1; }
    fi
}

# Function to create VXLAN tunnel
create_vxlan_tunnel() {
    echo -e "${BLUE}=== Creating a new VXLAN tunnel ===${RESET}"

    # Step 1: Get service name
    local default_name=$(generate_random_name)
    echo -e "${BLUE}Step 1: Set service name${RESET}"
    echo -e "${GREEN}Enter a name for the tunnel service (e.g., vxlan-myTunnel) or press Enter for a default name (vxlan-$default_name).${RESET}"
    echo -e "${YELLOW}This name identifies the tunnel in the system (systemd). Avoid spaces or special characters.${RESET}"
    read -p "> " service_name
    service_name=${service_name:-vxlan-$default_name}
    [[ ! "$service_name" =~ ^vxlan- ]] && service_name="vxlan-$service_name"
    local service_file="/usr/lib/systemd/system/$service_name.service"
    if [[ -f "$service_file" ]]; then
        echo -e "${RED}Error: A service named $service_name already exists. Choose a different name.${RESET}"
        return 1
    fi
    echo -e "${GREEN}Using service name: $service_name${RESET}"

    # Step 2: Get VNI
    echo -e "${BLUE}Step 2: Set VXLAN Network Identifier (VNI)${RESET}"
    echo -e "${GREEN}Enter a VNI (1-16777215) or press Enter for default (100).${RESET}"
    echo -e "${YELLOW}VNI is a unique number for this tunnel. Use the same VNI on both servers to connect them, or a different VNI to separate tunnels.${RESET}"
    echo -e "${YELLOW}Example: 100, 2000, or 50000${RESET}"
    read -p "> " vni
    vni=${vni:-100}
    if [[ ! "$vni" =~ ^[0-9]+$ || "$vni" -lt 1 || "$vni" -gt 16777215 ]]; then
        echo -e "${RED}Invalid VNI. Must be a number between 1 and 16777215.${RESET}"
        return 1
    fi
    echo -e "${GREEN}Using VNI: $vni${RESET}"

    # Step 3: Get IP version
    echo -e "${BLUE}Step 3: Select IP version for tunnel${RESET}"
    echo -e "${GREEN}1. IPv4\n2. IPv6\nEnter 1 or 2 (default: 1):${RESET}"
    read -p "> " ip_version
    ip_version=${ip_version:-1}
    if [[ ! "$ip_version" =~ ^[1-2]$ ]]; then
        echo -e "${RED}Invalid choice. Choose 1 (IPv4) or 2 (IPv6).${RESET}"
        return 1
    fi
    echo -e "${GREEN}Using IP version: IPv$ip_version${RESET}"

    # Step 4: Get local IP
    local local_ip=$(get_local_ip "$ip_version")
    echo -e "${BLUE}Step 4: Set local public IP or domain${RESET}"
    echo -e "${GREEN}Enter the public IP or domain of this server or press Enter to use $local_ip.${RESET}"
    if [[ "$ip_version" == "1" ]]; then
        example_ip="203.0.113.1"
    else
        example_ip="2001:db8::1"
    fi
    echo -e "${YELLOW}This is the IP/domain that the remote server will use to connect to this tunnel. Example: $example_ip or server1.example.com${RESET}"
    read -p "> " user_input
    user_input=${user_input:-$local_ip}
    if [[ "$ip_version" == "1" ]]; then
        if [[ "$user_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            local_ip="$user_input"
        else
            local_ip=$(dig +short "$user_input" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
            if [[ -z "$local_ip" ]]; then
                echo -e "${RED}Invalid domain or IPv4. Ensure the domain resolves to a valid IPv4.${RESET}"
                return 1
            fi
        fi
    else
        if [[ "$user_input" =~ ^[0-9a-f:]+$ ]]; then
            local_ip="$user_input"
        else
            local_ip=$(dig +short -t AAAA "$user_input" | grep -E '^[0-9a-f:]+$' | head -1)
            if [[ -z "$local_ip" ]]; then
                echo -e "${RED}Invalid domain or IPv6. Ensure the domain resolves to a valid IPv6.${RESET}"
                return 1
            fi
        fi
    fi
    echo -e "${GREEN}Using local IP: $local_ip${RESET}"

    # Step 5: Generate tunnel IP
    generate_tunnel_ip "$ip_version" || return 1
    source /root/ip.txt

    # Step 6: Get remote IP
    echo -e "${BLUE}Step 6: Set remote public IP or domain${RESET}"
    echo -e "${GREEN}Enter the public IP or domain of the remote server.${RESET}"
    if [[ "$ip_version" == "1" ]]; then
        example_remote_ip="198.51.100.1"
    else
        example_remote_ip="2001:db8::2"
    fi
    echo -e "${YELLOW}This is the IP/domain of the other server this tunnel will connect to. Example: $example_remote_ip${RESET}"
    read -p "> " remote_input
    if [[ "$ip_version" == "1" ]]; then
        if [[ "$remote_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            remote_ip="$remote_input"
        else
            remote_ip=$(dig +short "$remote_input" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
            if [[ -z "$remote_ip" ]]; then
                echo -e "${RED}Invalid domain or IPv4. Ensure the domain resolves to a valid IPv4.${RESET}"
                return 1
            fi
        fi
    else
        if [[ "$remote_input" =~ ^[0-9a-f:]+$ ]]; then
            remote_ip="$remote_input"
        else
            remote_ip=$(dig +short -t AAAA "$remote_input" | grep -E '^[0-9a-f:]+$' | head -1)
            if [[ -z "$remote_ip" ]]; then
                echo -e "${RED}Invalid domain or IPv6. Ensure the domain resolves to a valid IPv6.${RESET}"
                return 1
            fi
        fi
    fi
    echo -e "${GREEN}Using remote IP: $remote_ip${RESET}"

    # Step 7: Get route network
    echo -e "${BLUE}Step 7: Set remote local IP for routing${RESET}"
    echo -e "${GREEN}Enter the tunnel IP of the remote server (e.g., ${ip_version == 1 ? '192.168.1.100' : 'fd12:3456:789a::1'}).${RESET}"
    if [[ "$ip_version" == "1" ]]; then
        example_route_ip="192.168.1.100"
    else
        example_route_ip="fd12:3456:789a::1"
    fi
    echo -e "${YELLOW}This is the IP used inside the VXLAN tunnel on the remote server, as set in its configuration.${RESET}"
    echo -e "${YELLOW}Example: $example_route_ip${RESET}"
    read -p "> " route_network
    if [[ -z "$route_network" ]]; then
        echo -e "${RED}Remote local IP is required.${RESET}"
        return 1
    fi
    if [[ "$ip_version" == "1" && ! "$route_network" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP format for IPv4.${RESET}"
        return 1
    elif [[ "$ip_version" == "2" && ! "$route_network" =~ ^[0-9a-f:]+$ ]]; then
        echo -e "${RED}Invalid IP format for IPv6.${RESET}"
        return 1
    fi
    echo -e "${GREEN}Using route: $route_network${RESET}"

    # Step 8: Select network interface
    echo -e "${BLUE}Step 8: Select network interface${RESET}"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"))
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo -e "${RED}No network interfaces found. Check your network configuration.${RESET}"
        return 1
    fi
    echo -e "${GREEN}Select the network interface for the tunnel (default: ${interfaces[0]}):${RESET}"
    echo -e "${YELLOW}This is the physical network interface on your server (e.g., eth0, ens3).${RESET}"
    for i in "${!interfaces[@]}"; do echo "$((i+1)). ${interfaces[i]}"; done
    read -p "> " choice
    choice=${choice:-1}
    if [[ ! "$choice" =~ ^[0-9]+$ || $choice -lt 1 || $choice -gt ${#interfaces[@]} ]]; then
        echo -e "${RED}Invalid interface. Choose a number between 1 and ${#interfaces[@]}.${RESET}"
        return 1
    fi
    eth="${interfaces[$((choice-1))]}"
    echo -e "${GREEN}Using interface: $eth${RESET}"

    # Step 9: Create systemd service
    echo -e "${BLUE}Step 9: Creating tunnel service${RESET}"
    ip_cmd="ip"
    if [[ "$ip_version" == "2" ]]; then
        ip_cmd="ip -6"
    fi
    cat <<EOF > "$service_file"
[Unit]
Description=VXLAN Tunnel $service_name
After=network.target

[Service]
Type=simple
ExecStart=$ip_cmd link add $service_name type vxlan id $vni dev $eth remote $remote_ip dstport 4789 local $local_ip
ExecStartPost=$ip_cmd addr add $ip addr add $ip dev $service_name
ExecStartPost=$ip_cmd link set up dev $service_name
ExecStop=$ip_cmd link del $service_name
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Fix ExecStartPost (double ip addr add)
    sed -i "/ExecStartPost=ip addr add/d" "$service_file"
    echo "ExecStartPost=$ip_cmd addr add $ip dev $service_name" >> "$service_file"

    # Enable and start service
    systemctl daemon-reload
    systemctl enable "$service_name"
    systemctl start "$service_name"

    echo -e "${GREEN}VXLAN tunnel $service_name created and started successfully.${RESET}"
    echo -e "Tunnel IP: $ip"
    echo -e "Remote IP: $remote_ip"
    echo -e "Route IP: $route_network"
    echo -e "Interface: $eth"
    echo -e "VNI: $vni"
}

# Main menu
while true; do
    echo -e "${BLUE}VXLAN Tunnel Management Script${RESET}"
    echo "1) Create new VXLAN tunnel"
    echo "0) Exit"
    read -p "Choose an option: " choice
    case $choice in
        1) create_vxlan_tunnel ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid choice, try again.${RESET}" ;;
    esac
done
