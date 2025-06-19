#!/bin/bash

# OpenVPN Custom Client Profile Generator
# Connects to server via SSH and generates client configuration

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set default values if environment variables are not set
DEFAULT_SERVER_IP="${OPEN_VPN_SERVER_IP:-47.111.68.124}"
DEFAULT_SSH_USER="${OPEN_VPN_SSH_USER:-root}"
DEFAULT_CLIENT_NAME="${OPEN_VPN_DEFAULT_CLIENT:-client1}"

echo "=== OpenVPN Custom Client Profile Generator ==="
echo

# Get server details
echo "Enter server IP (or press Enter for $DEFAULT_SERVER_IP):"
read -r SERVER_IP
SERVER_IP=${SERVER_IP:-$DEFAULT_SERVER_IP}

echo "Enter SSH username (or press Enter for $DEFAULT_SSH_USER):"
read -r SSH_USER
SSH_USER=${SSH_USER:-$DEFAULT_SSH_USER}

echo "Enter client name (or press Enter for $DEFAULT_CLIENT_NAME):"
read -r CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-$DEFAULT_CLIENT_NAME}

echo
echo "Configuration:"
echo "Server: $SERVER_IP"
echo "User: $SSH_USER"
echo "Client: $CLIENT_NAME"
echo

# Check if SSH key is available
if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "ERROR: SSH private key not found in ~/.ssh/"
    echo "Please ensure your SSH key is properly configured."
    exit 1
fi

echo "1. Testing SSH connection..."
if ssh -o ConnectTimeout=10 -o BatchMode=yes $SSH_USER@$SERVER_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✓ SSH connection successful"
else
    echo "✗ SSH connection failed"
    echo "Please check your SSH key configuration and server accessibility."
    exit 1
fi

echo
echo "2. Checking OpenVPN setup on server..."
if ssh -o BatchMode=yes $SSH_USER@$SERVER_IP "test -f /etc/openvpn/client-configs/make_config.sh" 2>/dev/null; then
    echo "✓ OpenVPN client config script found"
else
    echo "✗ OpenVPN client config script not found"
    echo "Please ensure OpenVPN server is properly set up on the server."
    exit 1
fi

echo
echo "3. Generating client certificate and configuration..."
ssh -o BatchMode=yes $SSH_USER@$SERVER_IP "bash -c '
    # Check if client already exists
    if [ -f \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" ]; then
        echo \"Client configuration already exists, regenerating...\"
        # Remove existing certificate
        cd /etc/openvpn/easy-rsa
        rm -f \"pki/issued/$CLIENT_NAME.crt\"
        rm -f \"pki/private/$CLIENT_NAME.key\"
    fi
    
    # Generate new client configuration
    echo \"Generating new client configuration...\"
    chmod +x /etc/openvpn/client-configs/make_config.sh
    /etc/openvpn/client-configs/make_config.sh $CLIENT_NAME
    
    if [ -f \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" ]; then
        echo \"✓ Client configuration generated successfully\"
        echo \"File: /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\"
        
        # Show file info
        FILE_SIZE=\$(stat -c%s \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" 2>/dev/null || stat -f%z \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" 2>/dev/null)
        echo \"Size: \$FILE_SIZE bytes\"
        
        # Check if file contains certificates
        if grep -q \"<ca>\" \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" && \\
           grep -q \"<cert>\" \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\" && \\
           grep -q \"<key>\" \"/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn\"; then
            echo \"✓ Configuration contains certificates\"
        else
            echo \"✗ Configuration missing certificates\"
            exit 1
        fi
    else
        echo \"✗ Failed to generate client configuration\"
        exit 1
    fi
'"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to generate client configuration on server"
    exit 1
fi

echo
echo "4. Downloading client configuration..."
if scp -o BatchMode=yes $SSH_USER@$SERVER_IP:/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn ./$CLIENT_NAME.ovpn 2>/dev/null; then
    echo "✓ Client configuration downloaded successfully"
    echo "File: ./$CLIENT_NAME.ovpn"
    
    # Show file info
    FILE_SIZE=$(stat -c%s "./$CLIENT_NAME.ovpn" 2>/dev/null || stat -f%z "./$CLIENT_NAME.ovpn" 2>/dev/null)
    echo "Size: $FILE_SIZE bytes"
    
    # Show server info from config
    echo
    echo "5. Configuration details:"
    echo "Server IP: $(grep '^remote' ./$CLIENT_NAME.ovpn | awk '{print $2}')"
    echo "Server Port: $(grep '^remote' ./$CLIENT_NAME.ovpn | awk '{print $3}')"
    echo "Protocol: $(grep '^proto' ./$CLIENT_NAME.ovpn | awk '{print $2}')"
    
    # Show routed networks
    echo
    echo "Routed networks through VPN:"
    grep '^route' ./$CLIENT_NAME.ovpn | head -10
    
    echo
    echo "=== SUCCESS ==="
    echo "OpenVPN client profile generated successfully!"
    echo
    echo "Next steps:"
    echo "1. Copy $CLIENT_NAME.ovpn to your client device"
    echo "2. Import it into your OpenVPN client application"
    echo "3. Connect to the VPN"
    echo
    echo "Supported OpenVPN clients:"
    echo "- OpenVPN Connect (Windows, macOS, Linux)"
    echo "- OpenVPN for Android"
    echo "- OpenVPN for iOS"
    echo "- Tunnelblick (macOS)"
    echo "- Viscosity (macOS, Windows)"
    echo
    echo "Note: This configuration uses split tunneling - only specified"
    echo "networks will be routed through the VPN."
    
else
    echo "✗ Failed to download client configuration"
    exit 1
fi

echo
echo "Profile generation completed!" 