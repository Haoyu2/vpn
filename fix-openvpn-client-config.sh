#!/bin/bash

# Fix OpenVPN Client Configuration Generation
# This script fixes issues with client certificate generation

echo "=== OpenVPN Client Configuration Fix ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "/etc/openvpn" ]; then
    echo "ERROR: OpenVPN directory not found. Please run the OpenVPN server setup first."
    exit 1
fi

echo "1. Checking Easy-RSA setup..."
cd /etc/openvpn/easy-rsa

# Check if PKI is initialized
if [ ! -f "pki/ca.crt" ]; then
    echo "ERROR: CA certificate not found. Easy-RSA PKI is not properly initialized."
    echo "Please run the OpenVPN server setup script first."
    exit 1
fi

echo "✓ CA certificate found"

# Check if make_config.sh exists
if [ ! -f "/etc/openvpn/client-configs/make_config.sh" ]; then
    echo "ERROR: make_config.sh not found. Please run the OpenVPN server setup script first."
    exit 1
fi

echo "✓ make_config.sh found"

# Create client configs directory if it doesn't exist
mkdir -p /etc/openvpn/client-configs/files

echo "2. Testing client certificate generation..."

# Test with a simple client name
TEST_CLIENT="testclient"

# Remove existing test certificate if it exists
if [ -f "pki/issued/$TEST_CLIENT.crt" ]; then
    echo "Removing existing test certificate..."
    rm -f "pki/issued/$TEST_CLIENT.crt"
    rm -f "pki/private/$TEST_CLIENT.key"
fi

# Generate test certificate
echo "Generating test certificate for: $TEST_CLIENT"
./easyrsa build-client-full $TEST_CLIENT nopass

# Check if generation was successful
if [ ! -f "pki/issued/$TEST_CLIENT.crt" ] || [ ! -f "pki/private/$TEST_CLIENT.key" ]; then
    echo "ERROR: Failed to generate test certificate"
    echo "This indicates an issue with Easy-RSA setup"
    exit 1
fi

echo "✓ Test certificate generated successfully"

# Test the make_config.sh script
echo "3. Testing make_config.sh script..."
if /etc/openvpn/client-configs/make_config.sh $TEST_CLIENT; then
    echo "✓ make_config.sh executed successfully"
    
    # Check if client config was created
    if [ -f "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn" ]; then
        echo "✓ Client configuration file created"
        echo "  File: /etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn"
        
        # Show file size
        FILE_SIZE=$(stat -c%s "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn" 2>/dev/null || stat -f%z "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn" 2>/dev/null)
        echo "  Size: $FILE_SIZE bytes"
        
        # Check if file contains certificates
        if grep -q "<ca>" "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn" && \
           grep -q "<cert>" "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn" && \
           grep -q "<key>" "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn"; then
            echo "✓ Client configuration contains certificates"
        else
            echo "✗ Client configuration missing certificates"
        fi
    else
        echo "✗ Client configuration file not created"
    fi
else
    echo "✗ make_config.sh failed"
    exit 1
fi

echo
echo "4. Creating a real client configuration..."
echo "Enter client name (or press Enter for 'client1'):"
read -r CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-client1}

# Remove existing certificate if it exists
if [ -f "pki/issued/$CLIENT_NAME.crt" ]; then
    echo "Removing existing certificate for $CLIENT_NAME..."
    rm -f "pki/issued/$CLIENT_NAME.crt"
    rm -f "pki/private/$CLIENT_NAME.key"
fi

# Generate certificate
echo "Generating certificate for: $CLIENT_NAME"
./easyrsa build-client-full $CLIENT_NAME nopass

# Create client config
echo "Creating client configuration..."
/etc/openvpn/client-configs/make_config.sh $CLIENT_NAME

if [ -f "/etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn" ]; then
    echo
    echo "=== SUCCESS ==="
    echo "Client configuration created successfully!"
    echo "File: /etc/openvpn/client-configs/files/$CLIENT_NAME.ovpn"
    echo
    echo "Next steps:"
    echo "1. Copy the .ovpn file to your client device"
    echo "2. Import it into your OpenVPN client"
    echo "3. Connect to the VPN"
    echo
    echo "To create additional clients, run:"
    echo "  /etc/openvpn/manage-vpn.sh add-client CLIENT_NAME"
else
    echo "ERROR: Failed to create client configuration"
    exit 1
fi

# Clean up test certificate
echo "Cleaning up test certificate..."
rm -f "pki/issued/$TEST_CLIENT.crt"
rm -f "pki/private/$TEST_CLIENT.key"
rm -f "/etc/openvpn/client-configs/files/$TEST_CLIENT.ovpn"

echo "Fix completed successfully!" 