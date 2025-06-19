#!/bin/bash

# StrongSwan Configuration Validation Script

echo "=== StrongSwan Configuration Validation ==="

# Check if strongswan.conf exists
if [ ! -f /etc/strongswan.conf ]; then
    echo "ERROR: /etc/strongswan.conf not found!"
    exit 1
fi

echo "Found /etc/strongswan.conf"

# Test the configuration syntax
echo "Testing strongswan.conf syntax..."
if strongswan --help-config >/dev/null 2>&1; then
    echo "✓ strongswan.conf syntax is valid"
else
    echo "✗ strongswan.conf has syntax errors"
    echo "Running syntax check with details:"
    strongswan --help-config
    exit 1
fi

# Check if swanctl.conf exists
if [ -f /etc/swanctl/swanctl.conf ]; then
    echo "Found /etc/swanctl/swanctl.conf"
    
    # Test swanctl configuration loading
    echo "Testing swanctl.conf syntax..."
    if swanctl --load-conns --raw >/dev/null 2>&1; then
        echo "✓ swanctl.conf syntax is valid"
    else
        echo "✗ swanctl.conf has syntax errors"
        echo "Running syntax check with details:"
        swanctl --load-conns --raw
        exit 1
    fi
else
    echo "No swanctl.conf found (using legacy ipsec.conf)"
fi

# Check if StrongSwan is running
if pgrep -f charon >/dev/null; then
    echo "✓ StrongSwan charon daemon is running"
    
    # Show current status
    echo
    echo "Current VPN Status:"
    swanctl --list-conns 2>/dev/null || ipsec status
else
    echo "! StrongSwan charon daemon is not running"
fi

echo
echo "=== Configuration Validation Complete ===" 