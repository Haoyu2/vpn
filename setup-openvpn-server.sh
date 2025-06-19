#!/bin/bash

# OpenVPN Server Setup Script for Ubuntu
# Server: Behind NAT via Internet
# Client Network: Behind NAT via Internet  
# Target Network: 10.0.0.0/16
# Public IP Access: Configurable public IP ranges

set -e

echo "=== OpenVPN Server Setup for Ubuntu (NAT Traversal + Public IP Access) ==="
echo "Server: Behind NAT via Internet"
echo "Client Network: Behind NAT via Internet"
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

# Install OpenVPN and Easy-RSA
echo "Installing OpenVPN and dependencies..."
apt-get install -y openvpn easy-rsa iptables-persistent

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Create OpenVPN directory structure
echo "Creating OpenVPN directory structure..."
mkdir -p /etc/openvpn/{server,client-configs,keys}
cd /etc/openvpn

# Copy Easy-RSA to OpenVPN directory
cp -r /usr/share/easy-rsa /etc/openvpn/

# Configure Easy-RSA
echo "Configuring Easy-RSA..."
cd /etc/openvpn/easy-rsa
./easyrsa init-pki

# Create CA certificate
echo "Creating CA certificate..."
./easyrsa build-ca nopass << EOF
VPN-CA
EOF

# Create server certificate and key
echo "Creating server certificate..."
./easyrsa build-server-full server nopass

# Create Diffie-Hellman parameters
echo "Generating Diffie-Hellman parameters..."
./easyrsa gen-dh

# Generate HMAC key for additional security
echo "Generating HMAC key..."
openvpn --genkey secret /etc/openvpn/ta.key

# Copy certificates and keys to server directory
echo "Copying certificates and keys..."
cp pki/ca.crt /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/private/server.key /etc/openvpn/server/
cp pki/dh.pem /etc/openvpn/server/
cp /etc/openvpn/ta.key /etc/openvpn/server/

# Set proper permissions
chmod 600 /etc/openvpn/server/*
chmod 644 /etc/openvpn/server/ca.crt

# Get server's public IP (for client configuration)
echo "Detecting server's public IP..."
PUBLIC_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "YOUR_PUBLIC_IP")
echo "Detected public IP: $PUBLIC_IP"
echo "If this is incorrect, please update the client configurations manually."

# Create server configuration with NAT traversal and public IP routing
echo "Creating OpenVPN server configuration with NAT traversal and public IP routing..."
cat > /etc/openvpn/server/server.conf << EOF
# OpenVPN Server Configuration (NAT Traversal + Public IP Access)
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA256
cipher AES-256-CBC
ncp-ciphers AES-256-GCM:AES-256-CBC
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
key-direction 0
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1

# NAT Traversal settings
explicit-exit-notify 2
push "explicit-exit-notify 2"

# Split tunneling - route specific networks through VPN
# Local networks
push "route 10.0.0.0 255.255.0.0"
push "route 192.168.0.0 255.255.0.0"

# Public IP ranges to route through VPN (customize as needed)
# Example: Route specific public IP ranges through VPN
push "route 203.0.113.0 255.255.255.0"    # Example public IP range 1
push "route 198.51.100.0 255.255.255.0"  # Example public IP range 2
push "route 192.0.2.0 255.255.255.0"     # Example public IP range 3

# Security settings
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
auth SHA256
cipher AES-256-CBC

# Performance settings
comp-lzo no
push "comp-lzo no"

# NAT Traversal and connection stability
persist-remote-ip
persist-local-ip

# Logging
log-append /var/log/openvpn.log
EOF

# Create client configuration template with NAT traversal and public IP routing
echo "Creating client configuration template with NAT traversal and public IP routing..."
mkdir -p /etc/openvpn/client-configs/files

cat > /etc/openvpn/client-configs/base.conf << EOF
# OpenVPN Client Configuration Template (NAT Traversal + Public IP Access)
client
dev tun
proto udp
remote $PUBLIC_IP 1194
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

# Public IP ranges to route through VPN (customize as needed)
# Example: Route specific public IP ranges through VPN
route 203.0.113.0 255.255.255.0    # Example public IP range 1
route 198.51.100.0 255.255.255.0  # Example public IP range 2
route 192.0.2.0 255.255.255.0     # Example public IP range 3

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
EOF

# Create client certificate generation script
echo "Creating client certificate generation script..."
cat > /etc/openvpn/client-configs/make_config.sh << 'EOF'
#!/bin/bash

# OpenVPN Client Configuration Generator (NAT Traversal + Public IP Access)
# Usage: ./make_config.sh CLIENT_NAME [PUBLIC_IP_RANGES]

if [ -z "$1" ]; then
    echo "Usage: $0 CLIENT_NAME [PUBLIC_IP_RANGES]"
    echo "Example: $0 client1"
    echo "Example: $0 client1 '203.0.113.0/24 198.51.100.0/24'"
    exit 1
fi

CLIENT_NAME=$1
PUBLIC_IP_RANGES="$2"
cd /etc/openvpn/easy-rsa

# Generate client certificate
./easyrsa build-client-full $CLIENT_NAME nopass

# Create client configuration directory
mkdir -p /etc/openvpn/client-configs/files

# Get server's public IP
PUBLIC_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "YOUR_PUBLIC_IP")

# Generate client configuration
cat > /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn << CLIENT_EOF
# OpenVPN Client Configuration for $CLIENT_NAME (NAT Traversal + Public IP Access)
client
dev tun
proto udp
remote $PUBLIC_IP 1194
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
if [ -n "$PUBLIC_IP_RANGES" ]; then
    echo "Adding custom public IP ranges: $PUBLIC_IP_RANGES"
    for range in $PUBLIC_IP_RANGES; do
        # Convert CIDR to netmask
        if [[ $range == *"/"* ]]; then
            # CIDR notation
            echo "route $range" >> /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn
        else
            # Single IP
            echo "route $range 255.255.255.255" >> /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn
        fi
    done
else
    # Default public IP ranges
    cat >> /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn << 'DEFAULT_ROUTES'
# Default public IP ranges (customize as needed)
route 203.0.113.0 255.255.255.0    # Example public IP range 1
route 198.51.100.0 255.255.255.0  # Example public IP range 2
route 192.0.2.0 255.255.255.0     # Example public IP range 3
DEFAULT_ROUTES
fi

# Continue with the rest of the configuration
cat >> /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn << CLIENT_EOF

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
$(cat pki/ca.crt)
</ca>
<cert>
$(cat pki/issued/$CLIENT_NAME.crt)
</cert>
<key>
$(cat pki/private/$CLIENT_NAME.key)
</key>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
CLIENT_EOF

echo "Client configuration created: /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn"
echo "Server public IP: $PUBLIC_IP"
if [ -n "$PUBLIC_IP_RANGES" ]; then
    echo "Custom public IP ranges: $PUBLIC_IP_RANGES"
fi
echo "Copy this file to your client device and import it into OpenVPN client."
echo "IMPORTANT: Ensure UDP port 1194 is forwarded to this server in your router/firewall."
EOF

chmod +x /etc/openvpn/client-configs/make_config.sh

# Configure iptables for NAT and forwarding
echo "Configuring iptables rules for NAT traversal and public IP routing..."

# Save current iptables rules
iptables-save > /etc/iptables-backup.rules

# Allow OpenVPN traffic
iptables -A INPUT -p udp --dport 1194 -j ACCEPT

# Allow forwarding between VPN and local network
iptables -A FORWARD -s 10.8.0.0/24 -d 10.0.0.0/16 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/16 -d 10.8.0.0/24 -j ACCEPT

# Allow forwarding for public IP ranges (customize as needed)
iptables -A FORWARD -s 10.8.0.0/24 -d 203.0.113.0/24 -j ACCEPT
iptables -A FORWARD -s 203.0.113.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -d 198.51.100.0/24 -j ACCEPT
iptables -A FORWARD -s 198.51.100.0/24 -d 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -d 192.0.2.0/24 -j ACCEPT
iptables -A FORWARD -s 192.0.2.0/24 -d 10.8.0.0/24 -j ACCEPT

# NAT rules for VPN clients to access local network and public IPs
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.0.0.0/16 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 203.0.113.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 198.51.100.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 192.0.2.0/24 -j MASQUERADE

# Save iptables rules
netfilter-persistent save

# Enable and start OpenVPN service
echo "Enabling and starting OpenVPN service..."
systemctl enable openvpn@server
systemctl start openvpn@server

# Create management script
echo "Creating management script..."
cat > /etc/openvpn/manage-vpn.sh << 'EOF'
#!/bin/bash

# OpenVPN Management Script (NAT Traversal + Public IP Access)

case "$1" in
    status)
        systemctl status openvpn@server
        echo
        echo "Connected clients:"
        cat /var/log/openvpn-status.log 2>/dev/null | grep "CLIENT_LIST" || echo "No clients connected"
        echo
        echo "Server public IP:"
        curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "Could not detect public IP"
        echo
        echo "Configured public IP routes:"
        grep "^push.*route.*[0-9]" /etc/openvpn/server/server.conf | grep -v "10.0.0.0\|192.168.0.0" || echo "No public IP routes configured"
        ;;
    restart)
        systemctl restart openvpn@server
        echo "OpenVPN server restarted"
        ;;
    add-client)
        if [ -z "$2" ]; then
            echo "Usage: $0 add-client CLIENT_NAME [PUBLIC_IP_RANGES]"
            echo "Example: $0 add-client client1"
            echo "Example: $0 add-client client1 '203.0.113.0/24 198.51.100.0/24'"
            exit 1
        fi
        /etc/openvpn/client-configs/make_config.sh "$2" "$3"
        ;;
    list-clients)
        echo "Available client configurations:"
        ls -la /etc/openvpn/client-configs/files/*.ovpn 2>/dev/null || echo "No client configurations found"
        ;;
    public-ip)
        echo "Server public IP:"
        curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "Could not detect public IP"
        ;;
    add-public-route)
        if [ -z "$2" ]; then
            echo "Usage: $0 add-public-route IP_RANGE"
            echo "Example: $0 add-public-route 203.0.113.0/24"
            exit 1
        fi
        echo "Adding public IP route: $2"
        # Add to server config
        echo "push \"route $2\"" >> /etc/openvpn/server/server.conf
        # Add iptables rules
        iptables -A FORWARD -s 10.8.0.0/24 -d $2 -j ACCEPT
        iptables -A FORWARD -s $2 -d 10.8.0.0/24 -j ACCEPT
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d $2 -j MASQUERADE
        netfilter-persistent save
        echo "Route added. Restart OpenVPN server to apply changes."
        ;;
    list-public-routes)
        echo "Configured public IP routes:"
        grep "^push.*route.*[0-9]" /etc/openvpn/server/server.conf | grep -v "10.0.0.0\|192.168.0.0" || echo "No public IP routes configured"
        ;;
    *)
        echo "Usage: $0 {status|restart|add-client|list-clients|public-ip|add-public-route|list-public-routes}"
        echo "  status           - Show server status and connected clients"
        echo "  restart          - Restart OpenVPN server"
        echo "  add-client       - Generate new client configuration"
        echo "  list-clients     - List available client configurations"
        echo "  public-ip        - Show server's public IP address"
        echo "  add-public-route - Add new public IP range to route through VPN"
        echo "  list-public-routes- List configured public IP routes"
        exit 1
        ;;
esac
EOF

chmod +x /etc/openvpn/manage-vpn.sh

# Create initial client configuration
echo "Creating initial client configuration..."
/etc/openvpn/client-configs/make_config.sh "client1"

# Create port forwarding instructions
echo "Creating port forwarding instructions..."
cat > /etc/openvpn/PORT_FORWARDING_INSTRUCTIONS.txt << EOF
=== PORT FORWARDING INSTRUCTIONS ===

Your OpenVPN server is behind NAT and requires port forwarding to work properly.

1. LOGIN TO YOUR ROUTER:
   - Open your web browser and go to your router's admin interface
   - Usually http://192.168.1.1 or http://192.168.0.1
   - Login with your router credentials

2. FIND PORT FORWARDING SETTINGS:
   - Look for "Port Forwarding", "Virtual Server", or "NAT"
   - This is usually under "Advanced Settings" or "Security"

3. ADD PORT FORWARDING RULE:
   - Protocol: UDP
   - External Port: 1194
   - Internal Port: 1194
   - Internal IP: $(hostname -I | awk '{print $1}')
   - Description: OpenVPN

4. SAVE AND TEST:
   - Save the configuration
   - Test connectivity from outside your network

5. VERIFY:
   - Run: /etc/openvpn/manage-vpn.sh public-ip
   - Ensure the public IP matches your router's WAN IP

IMPORTANT: Keep your router's admin interface secure and use strong passwords.

=== PUBLIC IP ROUTING ===

This server is configured to route specific public IP ranges through the VPN.
Current configured public IP ranges:
- 203.0.113.0/24 (Example range 1)
- 198.51.100.0/24 (Example range 2)
- 192.0.2.0/24 (Example range 3)

To add more public IP ranges:
/etc/openvpn/manage-vpn.sh add-public-route IP_RANGE

=== TROUBLESHOOTING ===

If clients cannot connect:
1. Verify port forwarding is configured correctly
2. Check if your ISP blocks UDP port 1194
3. Try changing the port in server.conf and client configs
4. Ensure your router's firewall allows the traffic

=== ALTERNATIVE PORTS ===

If port 1194 is blocked, you can use:
- UDP 443 (HTTPS port, often open)
- UDP 53 (DNS port, often open)
- UDP 80 (HTTP port, often open)

To change ports:
1. Edit /etc/openvpn/server/server.conf (change port 1194)
2. Regenerate client configs: /etc/openvpn/manage-vpn.sh add-client CLIENT_NAME
3. Update port forwarding rule in router
EOF

echo
echo "=== OpenVPN Server Setup Complete (NAT Traversal + Public IP Access) ==="
echo
echo "Configuration Summary:"
echo "- Server: Behind NAT via Internet"
echo "- VPN Network: 10.8.0.0/24"
echo "- Local Network: 10.0.0.0/16"
echo "- Client Network: Behind NAT via Internet"
echo "- VPN Port: UDP 1194"
echo "- Public IP: $PUBLIC_IP"
echo "- Public IP Routing: Enabled"
echo
echo "IMPORTANT: PORT FORWARDING REQUIRED!"
echo "See: /etc/openvpn/PORT_FORWARDING_INSTRUCTIONS.txt"
echo
echo "Important Files:"
echo "- Server Config: /etc/openvpn/server/server.conf"
echo "- CA Certificate: /etc/openvpn/server/ca.crt"
echo "- Client Configs: /etc/openvpn/client-configs/files/"
echo "- Port Forwarding: /etc/openvpn/PORT_FORWARDING_INSTRUCTIONS.txt"
echo
echo "Management Commands:"
echo "  /etc/openvpn/manage-vpn.sh status           - Check server status"
echo "  /etc/openvpn/manage-vpn.sh add-client NAME  - Add new client"
echo "  /etc/openvpn/manage-vpn.sh public-ip        - Show public IP"
echo "  /etc/openvpn/manage-vpn.sh add-public-route IP_RANGE - Add public IP route"
echo "  /etc/openvpn/manage-vpn.sh list-public-routes - List public IP routes"
echo
echo "Initial client configuration created:"
echo "  /etc/openvpn/client-configs/files/client1.ovpn"
echo
echo "Next Steps:"
echo "1. Configure port forwarding in your router (UDP 1194)"
echo "2. Customize public IP ranges as needed"
echo "3. Copy client1.ovpn to your client device"
echo "4. Install OpenVPN client on your device"
echo "5. Import the .ovpn file and connect"
echo "6. Test split tunneling - only configured traffic goes through VPN" 