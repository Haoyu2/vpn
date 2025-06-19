#!/bin/bash

# Environment Setup Script for OpenVPN Profile Generator

echo "=== OpenVPN Environment Setup ==="
echo

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠ .env file already exists!"
    echo "Current contents:"
    cat .env
    echo
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

echo "Please provide your OpenVPN server details:"
echo

# Get server IP
read -p "Enter your OpenVPN server IP [47.111.68.124]: " SERVER_IP
SERVER_IP=${SERVER_IP:-47.111.68.124}

# Get SSH user
read -p "Enter SSH username [root]: " SSH_USER
SSH_USER=${SSH_USER:-root}

# Get default client name
read -p "Enter default client name [client1]: " CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-client1}

# Create .env file
cat > .env << EOF
# OpenVPN Server Configuration
OPEN_VPN_SERVER_IP=$SERVER_IP
OPEN_VPN_SSH_USER=$SSH_USER
OPEN_VPN_DEFAULT_CLIENT=$CLIENT_NAME
EOF

echo
echo "✅ .env file created successfully!"
echo
echo "Configuration:"
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "Default Client: $CLIENT_NAME"
echo
echo "You can now run:"
echo "  ./generate-client-profile.sh    # Generate profile with default settings"
echo "  ./generate-custom-profile.sh    # Generate profile with custom settings"
echo
echo "To modify these settings later, edit the .env file or run this script again." 