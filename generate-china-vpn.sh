#!/bin/bash

# OpenVPN Configuration Generator for Mainland China Services
# This script generates an .ovpn file for routing mainland China services through VPN
# Usage: ./generate-china-vpn.sh [SERVER_IP] [CLIENT_NAME]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to get server public IP
get_server_ip() {
    local server_ip=$1
    
    if [ -z "$server_ip" ]; then
        print_status "Detecting server public IP..."
        server_ip=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "")
        
        if [ -z "$server_ip" ]; then
            print_error "Could not automatically detect server public IP"
            read -p "Please enter your OpenVPN server's public IP address: " server_ip
        else
            print_status "Detected server public IP: $server_ip"
            read -p "Is this correct? (y/n): " confirm
            if [[ $confirm != [yY] ]]; then
                read -p "Please enter the correct server public IP: " server_ip
            fi
        fi
    fi
    
    echo "$server_ip"
}

# Function to get client name
get_client_name() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        # Try to get hostname
        local hostname=$(hostname 2>/dev/null || echo "client")
        read -p "Enter a name for this client configuration (default: $hostname): " input_name
        client_name=${input_name:-$hostname}
    fi
    
    echo "$client_name"
}

# Function to read China service IPs
read_china_ips() {
    local ip_file="china-service-ips.txt"
    
    if [ ! -f "$ip_file" ]; then
        print_error "China service IP file not found: $ip_file"
        exit 1
    fi
    
    print_status "Reading China service IP ranges from $ip_file..."
    
    # Read IP ranges, skip comments and empty lines
    local ips=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// }" ]]; then
            # Extract IP range (remove any description after space)
            local ip_range=$(echo "$line" | awk '{print $1}')
            if [[ "$ip_range" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
                ips+=("$ip_range")
            fi
        fi
    done < "$ip_file"
    
    echo "${ips[@]}"
}

# Function to generate OpenVPN configuration
generate_ovpn_config() {
    local server_ip=$1
    local client_name=$2
    local china_ips=($3)
    local output_file="${client_name}-china-vpn.ovpn"
    
    print_status "Generating OpenVPN configuration for $client_name..."
    print_status "Server IP: $server_ip"
    print_status "China service IP ranges: ${#china_ips[@]} ranges"
    
    # Create the OpenVPN configuration file
    cat > "$output_file" << EOF
# OpenVPN Configuration for Mainland China Services
# Generated for: $client_name
# Server: $server_ip
# Date: $(date)
# Purpose: Route mainland China services through VPN

client
dev tun
proto udp
remote $server_ip 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
key-direction 1
verb 3

# NAT Traversal settings
explicit-exit-notify 2
persist-remote-ip
persist-local-ip

# Split tunneling - only route mainland China services through VPN
route-nopull

# Mainland China service IP ranges to route through VPN
EOF

    # Add China service IP routes
    for ip_range in "${china_ips[@]}"; do
        if [[ "$ip_range" == *"/"* ]]; then
            # CIDR notation
            echo "route $ip_range" >> "$output_file"
        else
            # Single IP
            echo "route $ip_range 255.255.255.255" >> "$output_file"
        fi
    done

    # Continue with the rest of the configuration
    cat >> "$output_file" << 'EOF'

# Security settings
tls-version-min 1.2
auth SHA256
cipher AES-256-CBC

# Performance settings
comp-lzo no

# Connection stability for NAT environments
resolv-retry infinite
connect-retry 5
connect-retry-max 3
connect-timeout 30

# Client certificate and key
<ca>
# CA certificate content goes here
# Copy the content from your server's ca.crt file
</ca>
<cert>
# Client certificate content goes here
# Copy the content from your server's client certificate
</cert>
<key>
# Client private key content goes here
# Copy the content from your server's client private key
</key>
<tls-auth>
# TLS auth key content goes here
# Copy the content from your server's ta.key file
</tls-auth>
EOF

    print_status "OpenVPN configuration generated: $output_file"
    echo "$output_file"
}

# Function to create setup instructions
create_setup_instructions() {
    local output_file=$1
    local server_ip=$2
    local china_ips=($3)
    
    local instructions_file="${output_file%.ovpn}-setup-instructions.txt"
    
    cat > "$instructions_file" << EOF
=== OpenVPN Setup Instructions for Mainland China Services ===

Your OpenVPN configuration has been generated but requires manual certificate setup.

GENERATED FILES:
- OpenVPN Config: $output_file
- This Instructions File: $instructions_file

SERVER INFORMATION:
- Server IP: $server_ip
- VPN Port: UDP 1194
- China Service IP Ranges: ${#china_ips[@]} ranges

SETUP STEPS:

1. GET CERTIFICATES FROM SERVER:
   Contact your OpenVPN server administrator to get:
   - CA certificate (ca.crt)
   - Client certificate (client.crt)
   - Client private key (client.key)
   - TLS auth key (ta.key)

2. ADD CERTIFICATES TO CONFIG:
   Edit $output_file
   Replace the placeholder sections with actual certificate content:
   
   <ca>
   [Paste CA certificate content here]
   </ca>
   
   <cert>
   [Paste client certificate content here]
   </cert>
   
   <key>
   [Paste client private key content here]
   </key>
   
   <tls-auth>
   [Paste TLS auth key content here]
   </tls-auth>

3. IMPORT INTO OPENVPN CLIENT:
   - OpenVPN Connect (Windows/macOS)
   - OpenVPN for Android
   - OpenVPN for iOS
   - Import the $output_file file

4. CONNECT AND TEST:
   - Connect to the VPN
   - Test access to mainland China services
   - Verify other traffic uses direct connection

CHINA SERVICE IP RANGES INCLUDED:
EOF

    # Add China service IP ranges to instructions
    for ip_range in "${china_ips[@]}"; do
        echo "- $ip_range" >> "$instructions_file"
    done

    cat >> "$instructions_file" << 'EOF'

SPLIT TUNNELING BEHAVIOR:
- Traffic to mainland China services: Goes through VPN
- All other internet traffic: Uses direct connection
- This provides optimal performance and security

TROUBLESHOOTING:
1. Ensure server has port forwarding configured (UDP 1194)
2. Verify certificates are properly embedded
3. Check that server public IP is correct
4. Test connectivity to mainland China services

MANAGEMENT:
- To add more China service IP ranges, edit the route lines in the config
- To remove IP ranges, delete the corresponding route lines
- Restart VPN connection after making changes

SECURITY NOTES:
- Keep your client private key secure
- Don't share your configuration files
- Regularly update your certificates
- Monitor connection logs for suspicious activity

=== END OF INSTRUCTIONS ===
EOF

    print_status "Setup instructions created: $instructions_file"
}

# Function to create a summary report
create_summary_report() {
    local output_file=$1
    local server_ip=$2
    local china_ips=($3)
    local client_name=$4
    
    print_header "Configuration Summary"
    echo "Client Name: $client_name"
    echo "Server IP: $server_ip"
    echo "Output File: $output_file"
    echo "China Service IP Ranges: ${#china_ips[@]}"
    echo
    echo "China Service Providers Included:"
    echo "- Alibaba Cloud Services"
    echo "- Tencent Cloud Services"
    echo "- Baidu Services"
    echo "- WeChat/QQ Services"
    echo "- JD.com Services"
    echo "- ByteDance (TikTok/Douyin) Services"
    echo "- NetEase Services"
    echo "- Sina Weibo Services"
    echo "- Xiaomi Services"
    echo "- Meituan Services"
    echo
    echo "Next Steps:"
    echo "1. Get certificates from your OpenVPN server administrator"
    echo "2. Add certificate content to $output_file"
    echo "3. Import $output_file into your OpenVPN client"
    echo "4. Connect and test mainland China service access"
}

# Main script execution
main() {
    print_header "OpenVPN Configuration Generator for Mainland China Services"
    
    # Get command line arguments
    local server_ip=$1
    local client_name=$2
    
    # Get server IP
    server_ip=$(get_server_ip "$server_ip")
    
    # Get client name
    client_name=$(get_client_name "$client_name")
    
    # Read China service IPs
    local china_ips=($(read_china_ips))
    
    if [ ${#china_ips[@]} -eq 0 ]; then
        print_error "No valid China service IP ranges found"
        exit 1
    fi
    
    # Generate OpenVPN configuration
    local output_file=$(generate_ovpn_config "$server_ip" "$client_name" "${china_ips[*]}")
    
    # Create setup instructions
    create_setup_instructions "$output_file" "$server_ip" "${china_ips[*]}"
    
    # Create summary report
    create_summary_report "$output_file" "$server_ip" "${china_ips[*]}" "$client_name"
    
    print_header "Generation Complete"
    print_status "Files created:"
    echo "  - $output_file"
    echo "  - ${output_file%.ovpn}-setup-instructions.txt"
    echo
    print_status "You can now import $output_file into your OpenVPN client"
    print_warning "Remember to add your certificates before connecting!"
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 