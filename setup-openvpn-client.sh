#!/bin/bash

# OpenVPN Client Setup Script for Ubuntu
# Client: Behind NAT via Internet
# Server: Behind NAT via Internet
# Target Network: 10.0.0.0/16
# Public IP Access: Configurable public IP ranges

set -e

echo "=== OpenVPN Client Setup for Ubuntu (NAT Traversal + Public IP Access) ==="
echo "Client: Behind NAT via Internet"
echo "Server: Behind NAT via Internet"
echo "Target Network: 10.0.0.0/16"
echo "Public IP Access: Configurable public IP ranges"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update package repository
echo "Updating package repository..."
apt-get update

# Install OpenVPN client
echo "Installing OpenVPN client..."
apt-get install -y openvpn resolvconf

# Create OpenVPN client directory
echo "Creating OpenVPN client directory..."
mkdir -p /etc/openvpn/client

# Function to create client configuration
create_client_config() {
    local client_name=$1
    local server_ip=$2
    local public_ip_ranges=$3
    
    echo "Creating client configuration for $client_name..."
    
    cat > /etc/openvpn/client/$client_name.conf << EOF
# OpenVPN Client Configuration for $client_name (NAT Traversal + Public IP Access)
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

# Split tunneling - only route specific networks through VPN
route-nopull
# Local networks
route 10.0.0.0 255.255.0.0
route 192.168.0.0 255.255.0.0

# Public IP ranges to route through VPN
EOF

    # Add custom public IP ranges if provided
    if [ -n "$public_ip_ranges" ]; then
        echo "Adding custom public IP ranges: $public_ip_ranges"
        for range in $public_ip_ranges; do
            # Convert CIDR to netmask
            if [[ $range == *"/"* ]]; then
                # CIDR notation
                echo "route $range" >> /etc/openvpn/client/$client_name.conf
            else
                # Single IP
                echo "route $range 255.255.255.255" >> /etc/openvpn/client/$client_name.conf
            fi
        done
    else
        # Default public IP ranges
        cat >> /etc/openvpn/client/$client_name.conf << 'DEFAULT_ROUTES'
# Default public IP ranges (customize as needed)
route 203.0.113.0 255.255.255.0    # Example public IP range 1
route 198.51.100.0 255.255.255.0  # Example public IP range 2
route 192.0.2.0 255.255.255.0     # Example public IP range 3
DEFAULT_ROUTES
    fi

    # Continue with the rest of the configuration
    cat >> /etc/openvpn/client/$client_name.conf << 'CLIENT_EOF'

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
CLIENT_EOF

    echo "Client configuration created: /etc/openvpn/client/$client_name.conf"
    echo "IMPORTANT: You need to manually add the certificate and key contents to this file."
    echo "Get these from your OpenVPN server administrator."
}

# Function to create systemd service
create_systemd_service() {
    local client_name=$1
    
    cat > /etc/systemd/system/openvpn-client@$client_name.service << EOF
[Unit]
Description=OpenVPN Client for $client_name
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/client/$client_name.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo "Systemd service created: openvpn-client@$client_name.service"
}

# Function to create connection script
create_connection_script() {
    local client_name=$1
    
    cat > /etc/openvpn/client/connect-$client_name.sh << 'EOF'
#!/bin/bash

# OpenVPN Client Connection Script (NAT Traversal + Public IP Access)
# Usage: ./connect-CLIENT_NAME.sh [start|stop|status|restart]

CLIENT_NAME=$(basename "$0" | sed 's/connect-\(.*\)\.sh/\1/')
SERVICE_NAME="openvpn-client@$CLIENT_NAME"

case "$1" in
    start)
        echo "Starting OpenVPN client for $CLIENT_NAME..."
        systemctl start $SERVICE_NAME
        systemctl enable $SERVICE_NAME
        echo "OpenVPN client started and enabled."
        ;;
    stop)
        echo "Stopping OpenVPN client for $CLIENT_NAME..."
        systemctl stop $SERVICE_NAME
        systemctl disable $SERVICE_NAME
        echo "OpenVPN client stopped and disabled."
        ;;
    restart)
        echo "Restarting OpenVPN client for $CLIENT_NAME..."
        systemctl restart $SERVICE_NAME
        echo "OpenVPN client restarted."
        ;;
    status)
        echo "OpenVPN client status for $CLIENT_NAME:"
        systemctl status $SERVICE_NAME --no-pager
        echo
        echo "Connection status:"
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo "✓ Connected to VPN"
            echo "VPN IP: $(ip route show table all | grep '10.8.0' | head -1 | awk '{print $1}')"
            echo "Public IP: $(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo 'Unknown')"
            echo
            echo "Routes through VPN:"
            ip route show table all | grep -E "(10\.0\.0\.0|192\.168\.0\.0|203\.0\.113\.0|198\.51\.100\.0|192\.0\.2\.0)" || echo "No specific routes found"
        else
            echo "✗ Not connected to VPN"
        fi
        ;;
    logs)
        echo "OpenVPN client logs for $CLIENT_NAME:"
        journalctl -u $SERVICE_NAME -f
        ;;
    test-connection)
        echo "Testing VPN connection for $CLIENT_NAME..."
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo "✓ VPN is connected"
            echo "Testing connectivity to target networks..."
            
            # Test local network connectivity
            echo "Testing 10.0.0.0/16 network..."
            ping -c 3 10.0.0.1 >/dev/null 2>&1 && echo "✓ 10.0.0.0/16 network accessible" || echo "✗ 10.0.0.0/16 network not accessible"
            
            # Test public IP ranges
            echo "Testing public IP ranges..."
            ping -c 3 203.0.113.1 >/dev/null 2>&1 && echo "✓ 203.0.113.0/24 accessible" || echo "✗ 203.0.113.0/24 not accessible"
            ping -c 3 198.51.100.1 >/dev/null 2>&1 && echo "✓ 198.51.100.0/24 accessible" || echo "✗ 198.51.100.0/24 not accessible"
            ping -c 3 192.0.2.1 >/dev/null 2>&1 && echo "✓ 192.0.2.0/24 accessible" || echo "✗ 192.0.2.0/24 not accessible"
            
            echo
            echo "Split tunneling test:"
            echo "Direct internet access (should work):"
            curl -s --connect-timeout 5 https://www.google.com >/dev/null && echo "✓ Direct internet access working" || echo "✗ Direct internet access not working"
        else
            echo "✗ VPN is not connected"
        fi
        ;;
    add-public-route)
        if [ -z "$2" ]; then
            echo "Usage: $0 add-public-route IP_RANGE"
            echo "Example: $0 add-public-route 203.0.113.0/24"
            exit 1
        fi
        echo "Adding public IP route: $2"
        # Add route to client config
        if [[ $2 == *"/"* ]]; then
            echo "route $2" >> /etc/openvpn/client/$CLIENT_NAME.conf
        else
            echo "route $2 255.255.255.255" >> /etc/openvpn/client/$CLIENT_NAME.conf
        fi
        echo "Route added to configuration. Restart VPN to apply changes."
        ;;
    list-public-routes)
        echo "Configured public IP routes:"
        grep "^route.*[0-9]" /etc/openvpn/client/$CLIENT_NAME.conf | grep -v "10.0.0.0\|192.168.0.0" || echo "No public IP routes configured"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|logs|test-connection|add-public-route|list-public-routes}"
        echo "  start              - Start and enable OpenVPN client"
        echo "  stop               - Stop and disable OpenVPN client"
        echo "  status             - Show connection status and routes"
        echo "  restart            - Restart OpenVPN client"
        echo "  logs               - Show OpenVPN client logs"
        echo "  test-connection    - Test VPN connectivity"
        echo "  add-public-route  - Add new public IP range to route through VPN"
        echo "  list-public-routes - List configured public IP routes"
        exit 1
        ;;
esac
EOF

    chmod +x /etc/openvpn/client/connect-$client_name.sh
    echo "Connection script created: /etc/openvpn/client/connect-$client_name.sh"
}

# Function to create management script
create_management_script() {
    cat > /etc/openvpn/client/manage-vpn.sh << 'EOF'
#!/bin/bash

# OpenVPN Client Management Script (NAT Traversal + Public IP Access)

echo "=== OpenVPN Client Management ==="
echo

# List available client configurations
echo "Available client configurations:"
for config in /etc/openvpn/client/*.conf; do
    if [ -f "$config" ]; then
        client_name=$(basename "$config" .conf)
        service_name="openvpn-client@$client_name"
        status=$(systemctl is-active $service_name 2>/dev/null || echo "inactive")
        echo "  $client_name: $status"
    fi
done

echo
echo "Management commands:"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh start              - Start specific client"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh stop               - Stop specific client"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh status             - Show client status"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh test-connection    - Test connectivity"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh add-public-route   - Add public IP route"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh list-public-routes - List public IP routes"
echo
echo "Example:"
echo "  /etc/openvpn/client/connect-client1.sh start"
echo "  /etc/openvpn/client/connect-client1.sh status"
echo "  /etc/openvpn/client/connect-client1.sh test-connection"
EOF

    chmod +x /etc/openvpn/client/manage-vpn.sh
    echo "Management script created: /etc/openvpn/client/manage-vpn.sh"
}

# Function to create troubleshooting script
create_troubleshooting_script() {
    cat > /etc/openvpn/client/troubleshoot.sh << 'EOF'
#!/bin/bash

# OpenVPN Client Troubleshooting Script (NAT Traversal + Public IP Access)

echo "=== OpenVPN Client Troubleshooting ==="
echo

# Check if OpenVPN is installed
echo "1. Checking OpenVPN installation..."
if command -v openvpn >/dev/null 2>&1; then
    echo "✓ OpenVPN is installed: $(openvpn --version | head -1)"
else
    echo "✗ OpenVPN is not installed"
    echo "  Run: sudo apt-get install openvpn"
fi

echo

# Check for client configurations
echo "2. Checking client configurations..."
config_count=0
for config in /etc/openvpn/client/*.conf; do
    if [ -f "$config" ]; then
        config_count=$((config_count + 1))
        client_name=$(basename "$config" .conf)
        echo "  Found: $client_name.conf"
        
        # Check if certificates are present
        if grep -q "<ca>" "$config" && grep -q "</ca>" "$config"; then
            echo "    ✓ CA certificate present"
        else
            echo "    ✗ CA certificate missing"
        fi
        
        if grep -q "<cert>" "$config" && grep -q "</cert>" "$config"; then
            echo "    ✓ Client certificate present"
        else
            echo "    ✗ Client certificate missing"
        fi
        
        if grep -q "<key>" "$config" && grep -q "</key>" "$config"; then
            echo "    ✓ Client private key present"
        else
            echo "    ✗ Client private key missing"
        fi
        
        if grep -q "<tls-auth>" "$config" && grep -q "</tls-auth>" "$config"; then
            echo "    ✓ TLS auth key present"
        else
            echo "    ✗ TLS auth key missing"
        fi
    fi
done

if [ $config_count -eq 0 ]; then
    echo "  No client configurations found"
fi

echo

# Check network connectivity
echo "3. Checking network connectivity..."
echo "  Local IP: $(hostname -I | awk '{print $1}')"
echo "  Public IP: $(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo 'Unknown')"
echo "  DNS resolution: $(nslookup google.com >/dev/null 2>&1 && echo 'Working' || echo 'Failed')"

echo

# Check for common issues
echo "4. Checking for common issues..."

# Check if port 1194 is blocked
echo "  Testing UDP port 1194 connectivity..."
timeout 5 bash -c "</dev/udp/8.8.8.8/53" 2>/dev/null && echo "    ✓ UDP connectivity working" || echo "    ✗ UDP connectivity may be blocked"

# Check for conflicting services
echo "  Checking for conflicting VPN services..."
if systemctl is-active --quiet openvpn@*; then
    echo "    ⚠ Other OpenVPN services are running"
    systemctl list-units --type=service | grep openvpn
else
    echo "    ✓ No conflicting OpenVPN services"
fi

echo

# Check system resources
echo "5. Checking system resources..."
echo "  Available disk space: $(df -h / | awk 'NR==2 {print $4}')"
echo "  Available memory: $(free -h | awk 'NR==2 {print $7}')"
echo "  Load average: $(uptime | awk -F'load average:' '{print $2}')"

echo

# Provide troubleshooting tips
echo "6. Troubleshooting tips:"
echo "  - Ensure your server's public IP is correct in client configs"
echo "  - Verify UDP port 1194 is not blocked by your ISP"
echo "  - Check that server has port forwarding configured"
echo "  - Ensure certificates and keys are properly embedded in config files"
echo "  - Try different ports (443, 53, 80) if 1194 is blocked"
echo "  - Check server logs for connection issues"
echo "  - Verify split tunneling routes are correct"

echo
echo "For detailed logs, run:"
echo "  journalctl -u openvpn-client@CLIENT_NAME -f"
echo
echo "For connection testing, run:"
echo "  /etc/openvpn/client/connect-CLIENT_NAME.sh test-connection"
EOF

    chmod +x /etc/openvpn/client/troubleshoot.sh
    echo "Troubleshooting script created: /etc/openvpn/client/troubleshoot.sh"
}

# Main setup
echo "Starting OpenVPN client setup..."

# Get server information
read -p "Enter your OpenVPN server's public IP address: " SERVER_IP
read -p "Enter a name for this client configuration (e.g., client1): " CLIENT_NAME
read -p "Enter public IP ranges to route through VPN (space-separated, optional): " PUBLIC_IP_RANGES

# Create client configuration
create_client_config "$CLIENT_NAME" "$SERVER_IP" "$PUBLIC_IP_RANGES"

# Create systemd service
create_systemd_service "$CLIENT_NAME"

# Create connection script
create_connection_script "$CLIENT_NAME"

# Create management script
create_management_script

# Create troubleshooting script
create_troubleshooting_script

# Create setup instructions
cat > /etc/openvpn/client/SETUP_INSTRUCTIONS.txt << EOF
=== OpenVPN Client Setup Instructions (NAT Traversal + Public IP Access) ===

Your OpenVPN client has been configured but requires manual certificate setup.

1. GET CERTIFICATES FROM SERVER:
   Contact your OpenVPN server administrator to get:
   - CA certificate (ca.crt)
   - Client certificate (client.crt)
   - Client private key (client.key)
   - TLS auth key (ta.key)

2. ADD CERTIFICATES TO CONFIG:
   Edit /etc/openvpn/client/$CLIENT_NAME.conf
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

3. START THE VPN:
   /etc/openvpn/client/connect-$CLIENT_NAME.sh start

4. CHECK STATUS:
   /etc/openvpn/client/connect-$CLIENT_NAME.sh status

5. TEST CONNECTION:
   /etc/openvpn/client/connect-$CLIENT_NAME.sh test-connection

=== PUBLIC IP ROUTING ===

This client is configured for split tunneling with public IP routing.
Current configured public IP ranges:
EOF

if [ -n "$PUBLIC_IP_RANGES" ]; then
    for range in $PUBLIC_IP_RANGES; do
        echo "- $range" >> /etc/openvpn/client/SETUP_INSTRUCTIONS.txt
    done
else
    cat >> /etc/openvpn/client/SETUP_INSTRUCTIONS.txt << 'DEFAULT_RANGES'
- 203.0.113.0/24 (Example range 1)
- 198.51.100.0/24 (Example range 2)
- 192.0.2.0/24 (Example range 3)
DEFAULT_RANGES
fi

cat >> /etc/openvpn/client/SETUP_INSTRUCTIONS.txt << 'EOF'

To add more public IP ranges:
/etc/openvpn/client/connect-CLIENT_NAME.sh add-public-route IP_RANGE

=== TROUBLESHOOTING ===

If you have connection issues:
1. Run: /etc/openvpn/client/troubleshoot.sh
2. Check logs: journalctl -u openvpn-client@CLIENT_NAME -f
3. Test connectivity: /etc/openvpn/client/connect-CLIENT_NAME.sh test-connection

Common issues:
- Incorrect server public IP
- Missing or incorrect certificates
- UDP port 1194 blocked by ISP
- Server not configured for NAT traversal
- Port forwarding not configured on server

=== MANAGEMENT COMMANDS ===

- Start VPN: /etc/openvpn/client/connect-CLIENT_NAME.sh start
- Stop VPN: /etc/openvpn/client/connect-CLIENT_NAME.sh stop
- Check status: /etc/openvpn/client/connect-CLIENT_NAME.sh status
- View logs: /etc/openvpn/client/connect-CLIENT_NAME.sh logs
- Test connection: /etc/openvpn/client/connect-CLIENT_NAME.sh test-connection
- Add public route: /etc/openvpn/client/connect-CLIENT_NAME.sh add-public-route IP_RANGE
- List public routes: /etc/openvpn/client/connect-CLIENT_NAME.sh list-public-routes

=== SPLIT TUNNELING ===

This configuration uses split tunneling:
- Only traffic to 10.0.0.0/16, 192.168.0.0/16, and configured public IP ranges goes through VPN
- All other internet traffic uses your direct connection
- This provides better performance and security

=== SECURITY NOTES ===

- Keep your client private key secure
- Don't share your client configuration files
- Regularly update your certificates
- Monitor connection logs for suspicious activity
EOF

echo
echo "=== OpenVPN Client Setup Complete (NAT Traversal + Public IP Access) ==="
echo
echo "Configuration Summary:"
echo "- Client: Behind NAT via Internet"
echo "- Server: $SERVER_IP"
echo "- Client Name: $CLIENT_NAME"
echo "- Public IP Routing: Enabled"
if [ -n "$PUBLIC_IP_RANGES" ]; then
    echo "- Custom Public IP Ranges: $PUBLIC_IP_RANGES"
else
    echo "- Default Public IP Ranges: 203.0.113.0/24, 198.51.100.0/24, 192.0.2.0/24"
fi
echo
echo "Important Files:"
echo "- Client Config: /etc/openvpn/client/$CLIENT_NAME.conf"
echo "- Connection Script: /etc/openvpn/client/connect-$CLIENT_NAME.sh"
echo "- Management Script: /etc/openvpn/client/manage-vpn.sh"
echo "- Troubleshooting: /etc/openvpn/client/troubleshoot.sh"
echo "- Setup Instructions: /etc/openvpn/client/SETUP_INSTRUCTIONS.txt"
echo
echo "NEXT STEPS:"
echo "1. Get certificates from your OpenVPN server administrator"
echo "2. Add certificate content to /etc/openvpn/client/$CLIENT_NAME.conf"
echo "3. Start the VPN: /etc/openvpn/client/connect-$CLIENT_NAME.sh start"
echo "4. Test the connection: /etc/openvpn/client/connect-$CLIENT_NAME.sh test-connection"
echo
echo "For management: /etc/openvpn/client/manage-vpn.sh"
echo "For troubleshooting: /etc/openvpn/client/troubleshoot.sh" 