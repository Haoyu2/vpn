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
echo "Generating client certificate for: $CLIENT_NAME"
./easyrsa build-client-full $CLIENT_NAME nopass

# Check if certificate generation was successful
if [ ! -f "pki/issued/$CLIENT_NAME.crt" ] || [ ! -f "pki/private/$CLIENT_NAME.key" ]; then
    echo "ERROR: Failed to generate client certificate for $CLIENT_NAME"
    echo "Please check if Easy-RSA is properly initialized and try again."
    exit 1
fi

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