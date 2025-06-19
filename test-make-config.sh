#!/bin/bash

# Test script for make_config.sh functionality

CLIENT_NAME="testclient"
PUBLIC_IP_RANGES="203.0.113.0/24"

echo "Testing make_config.sh with:"
echo "CLIENT_NAME: $CLIENT_NAME"
echo "PUBLIC_IP_RANGES: $PUBLIC_IP_RANGES"

# Test the certificate file paths
echo "Testing certificate file paths:"
echo "CA cert: pki/ca.crt"
echo "Client cert: pki/issued/$CLIENT_NAME.crt"
echo "Client key: pki/private/$CLIENT_NAME.key"
echo "TLS auth: /etc/openvpn/ta.key"

# Test if files exist (this would fail in the actual script)
echo "Checking if files exist:"
[ -f "pki/ca.crt" ] && echo "CA cert exists" || echo "CA cert missing"
[ -f "pki/issued/$CLIENT_NAME.crt" ] && echo "Client cert exists" || echo "Client cert missing"
[ -f "pki/private/$CLIENT_NAME.key" ] && echo "Client key exists" || echo "Client key missing"
[ -f "/etc/openvpn/ta.key" ] && echo "TLS auth exists" || echo "TLS auth missing"

echo "Test completed." 