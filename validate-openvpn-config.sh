#!/bin/bash

# OpenVPN Configuration Validation Script

echo "=== OpenVPN Configuration Validation ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Check if OpenVPN is installed
echo "1. Checking OpenVPN installation..."
if command -v openvpn >/dev/null 2>&1; then
    echo "✓ OpenVPN is installed"
    openvpn --version | head -1
else
    echo "✗ OpenVPN is not installed"
fi
echo

# Check if Easy-RSA is available
echo "2. Checking Easy-RSA..."
if [ -d "/etc/openvpn/easy-rsa" ]; then
    echo "✓ Easy-RSA directory exists"
    if [ -f "/etc/openvpn/easy-rsa/easyrsa" ]; then
        echo "✓ Easy-RSA script exists"
    else
        echo "✗ Easy-RSA script missing"
    fi
else
    echo "✗ Easy-RSA directory missing"
fi
echo

# Check PKI structure
echo "3. Checking PKI structure..."
if [ -d "/etc/openvpn/easy-rsa/pki" ]; then
    echo "✓ PKI directory exists"
    
    # Check CA certificate
    if [ -f "/etc/openvpn/easy-rsa/pki/ca.crt" ]; then
        echo "✓ CA certificate exists"
    else
        echo "✗ CA certificate missing"
    fi
    
    # Check issued certificates directory
    if [ -d "/etc/openvpn/easy-rsa/pki/issued" ]; then
        echo "✓ Issued certificates directory exists"
        echo "  Found certificates:"
        ls -1 /etc/openvpn/easy-rsa/pki/issued/*.crt 2>/dev/null | wc -l | tr -d ' '
        echo " certificates"
    else
        echo "✗ Issued certificates directory missing"
    fi
    
    # Check private keys directory
    if [ -d "/etc/openvpn/easy-rsa/pki/private" ]; then
        echo "✓ Private keys directory exists"
        echo "  Found keys:"
        ls -1 /etc/openvpn/easy-rsa/pki/private/*.key 2>/dev/null | wc -l | tr -d ' '
        echo " keys"
    else
        echo "✗ Private keys directory missing"
    fi
else
    echo "✗ PKI directory missing"
fi
echo

# Check server configuration
echo "4. Checking server configuration..."
if [ -f "/etc/openvpn/server/server.conf" ]; then
    echo "✓ Server configuration exists"
    
    # Check important settings
    echo "  Server settings:"
    grep -E "^(port|proto|dev|server|ca|cert|key|tls-auth)" /etc/openvpn/server/server.conf | head -10
else
    echo "✗ Server configuration missing"
fi
echo

# Check TLS auth key
echo "5. Checking TLS auth key..."
if [ -f "/etc/openvpn/ta.key" ]; then
    echo "✓ TLS auth key exists"
else
    echo "✗ TLS auth key missing"
fi
echo

# Check client configs directory
echo "6. Checking client configurations..."
if [ -d "/etc/openvpn/client-configs" ]; then
    echo "✓ Client configs directory exists"
    
    if [ -f "/etc/openvpn/client-configs/make_config.sh" ]; then
        echo "✓ make_config.sh script exists"
        
        # Test make_config.sh syntax
        if bash -n /etc/openvpn/client-configs/make_config.sh 2>/dev/null; then
            echo "✓ make_config.sh syntax is valid"
        else
            echo "✗ make_config.sh has syntax errors"
        fi
    else
        echo "✗ make_config.sh script missing"
    fi
    
    if [ -d "/etc/openvpn/client-configs/files" ]; then
        echo "✓ Client files directory exists"
        echo "  Found client configs:"
        ls -1 /etc/openvpn/client-configs/files/*.ovpn 2>/dev/null | wc -l | tr -d ' '
        echo " configs"
    else
        echo "✗ Client files directory missing"
    fi
else
    echo "✗ Client configs directory missing"
fi
echo

# Check OpenVPN service
echo "7. Checking OpenVPN service..."
if systemctl is-active openvpn@server >/dev/null 2>&1; then
    echo "✓ OpenVPN service is running"
elif systemctl is-enabled openvpn@server >/dev/null 2>&1; then
    echo "⚠ OpenVPN service is enabled but not running"
else
    echo "✗ OpenVPN service is not enabled"
fi
echo

# Check iptables rules
echo "8. Checking iptables rules..."
if iptables -L INPUT -n | grep -q "1194"; then
    echo "✓ OpenVPN port 1194 is allowed in INPUT"
else
    echo "✗ OpenVPN port 1194 not found in INPUT rules"
fi

if iptables -L FORWARD -n | grep -q "10.8.0.0/24"; then
    echo "✓ VPN forwarding rules exist"
else
    echo "✗ VPN forwarding rules missing"
fi
echo

# Check public IP detection
echo "9. Checking public IP detection..."
PUBLIC_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://icanhazip.com 2>/dev/null || echo "Could not detect")
echo "  Detected public IP: $PUBLIC_IP"
echo

echo "=== Validation Complete ==="
echo
echo "If you see any ✗ marks above, those issues need to be resolved."
echo "Common fixes:"
echo "1. Run the OpenVPN server setup script as root"
echo "2. Ensure Easy-RSA is properly initialized"
echo "3. Check that all required packages are installed"
echo "4. Verify network connectivity for public IP detection" 