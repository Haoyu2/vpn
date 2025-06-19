#!/bin/bash

# Example Usage Script for China VPN Generator
# This script demonstrates how to use the generate-china-vpn.sh script

echo "=== China VPN Configuration Generator - Example Usage ==="
echo

echo "1. Basic usage (interactive mode):"
echo "   ./generate-china-vpn.sh"
echo "   # This will prompt for server IP and client name"
echo

echo "2. Specify server IP only:"
echo "   ./generate-china-vpn.sh 203.0.113.1"
echo "   # This will prompt for client name"
echo

echo "3. Specify both server IP and client name:"
echo "   ./generate-china-vpn.sh 203.0.113.1 my-computer"
echo "   # This will generate: my-computer-china-vpn.ovpn"
echo

echo "4. Example with your actual server IP:"
echo "   ./generate-china-vpn.sh YOUR_SERVER_PUBLIC_IP $(hostname)"
echo

echo "=== What the script does ==="
echo "1. Reads China service IP ranges from china-service-ips.txt"
echo "2. Prompts for server public IP (or auto-detects)"
echo "3. Prompts for client name (or uses hostname)"
echo "4. Generates OpenVPN configuration with split tunneling"
echo "5. Creates setup instructions"
echo "6. Only routes mainland China services through VPN"
echo

echo "=== Generated Files ==="
echo "- CLIENT_NAME-china-vpn.ovpn (OpenVPN configuration)"
echo "- CLIENT_NAME-china-vpn-setup-instructions.txt (Setup guide)"
echo

echo "=== China Services Included ==="
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

echo "=== Next Steps ==="
echo "1. Run: ./generate-china-vpn.sh"
echo "2. Get certificates from your OpenVPN server"
echo "3. Add certificates to the generated .ovpn file"
echo "4. Import into OpenVPN client and connect"
echo

echo "=== Requirements ==="
echo "- china-service-ips.txt file (included)"
echo "- OpenVPN server running and accessible"
echo "- Server certificates (ca.crt, client.crt, client.key, ta.key)"
echo "- OpenVPN client software" 