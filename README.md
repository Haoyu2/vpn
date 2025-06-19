# VPN Automation Scripts

This repository contains comprehensive automation scripts for setting up VPN servers and clients using both **StrongSwan** (IPsec) and **OpenVPN** solutions. The scripts support NAT traversal, split tunneling, and public IP routing capabilities.

## 🚀 Quick Start

### StrongSwan (IPsec) Setup
```bash
# Server (Alpine Linux)
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-strongswan-server.sh
chmod +x setup-strongswan-server.sh
sudo ./setup-strongswan-server.sh

# Client (Alpine Linux)
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-strongswan-client.sh
chmod +x setup-strongswan-client.sh
sudo ./setup-strongswan-client.sh
```

### OpenVPN Setup
```bash
# Server (Ubuntu)
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-openvpn-server.sh
chmod +x setup-openvpn-server.sh
sudo ./setup-openvpn-server.sh

# Client (Ubuntu)
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-openvpn-client.sh
chmod +x setup-openvpn-client.sh
sudo ./setup-openvpn-client.sh
```

## 📋 Features

### StrongSwan (IPsec)
- ✅ Certificate-based authentication
- ✅ Pre-shared key (PSK) authentication
- ✅ EAP authentication support
- ✅ Modern `swanctl.conf` configuration
- ✅ NAT traversal support
- ✅ Split tunneling
- ✅ Alpine Linux optimized

### OpenVPN
- ✅ NAT traversal for both server and clients
- ✅ Split tunneling with public IP routing
- ✅ Certificate-based authentication
- ✅ Automatic port forwarding detection
- ✅ Connection stability for NAT environments
- ✅ Comprehensive management scripts
- ✅ Ubuntu optimized

## 🏗️ Architecture

```
Internet
    │
    ├── Server Router (NAT)
    │   └── VPN Server (10.0.0.2)
    │       ├── StrongSwan (IPsec)
    │       └── OpenVPN
    │           └── VPN Network (10.8.0.0/24)
    │               └── Routes to: 10.0.0.0/16 + Public IP ranges
    │
    └── Client Router (NAT)
        └── VPN Client
            ├── StrongSwan Client
            └── OpenVPN Client
                └── Routes through VPN: 10.0.0.0/16 + Public IP ranges
                └── Direct internet: All other traffic
```

## 📁 Repository Structure

```
vpn/
├── setup-strongswan-server.sh      # StrongSwan server setup (Alpine)
├── setup-strongswan-client.sh      # StrongSwan client setup (Alpine)
├── setup-openvpn-server.sh         # OpenVPN server setup (Ubuntu)
├── setup-openvpn-client.sh         # OpenVPN client setup (Ubuntu)
├── validate-strongswan-config.sh   # StrongSwan config validation
├── README.md                       # This file
├── README-OpenVPN.md              # OpenVPN detailed guide
└── .gitignore                     # Git ignore rules
```

## 🔧 Network Configuration

### Target Networks
- **Local Network**: 10.0.0.0/16
- **Client Network**: 192.168.0.0/16
- **VPN Network**: 10.8.0.0/24 (OpenVPN)
- **Public IP Routing**: Configurable ranges

### Ports
- **StrongSwan**: UDP 500 (IKE), UDP 4500 (NAT-T)
- **OpenVPN**: UDP 1194 (default), alternatives: 443, 53, 80

## 🛡️ Security Features

### Authentication Methods
- **Certificate-based**: TLS certificates for identity verification
- **Pre-shared Keys**: Simple PSK authentication
- **EAP**: Extensible Authentication Protocol
- **TLS Auth**: Additional HMAC key protection

### Encryption
- **StrongSwan**: AES-256, SHA-256, MODP-2048
- **OpenVPN**: AES-256-CBC, SHA-256, TLS 1.2+

### Network Security
- Split tunneling prevents unnecessary traffic exposure
- Firewall rules restrict access
- NAT isolation for VPN clients
- Secure certificate management

## 📖 Documentation

### StrongSwan
- [StrongSwan Server Setup](README.md#strongswan-setup)
- [StrongSwan Client Setup](README.md#strongswan-client)
- [Configuration Management](README.md#strongswan-management)

### OpenVPN
- [OpenVPN Detailed Guide](README-OpenVPN.md)
- [NAT Traversal Setup](README-OpenVPN.md#nat-traversal)
- [Public IP Routing](README-OpenVPN.md#public-ip-routing)
- [Split Tunneling](README-OpenVPN.md#split-tunneling)

## 🚦 Management Commands

### StrongSwan
```bash
# Server management
swanctl --list-conns
swanctl --list-sas
swanctl --reload

# Client management
swanctl --initiate --child vpn-tunnel
swanctl --terminate --child vpn-tunnel
```

### OpenVPN
```bash
# Server management
/etc/openvpn/manage-vpn.sh status
/etc/openvpn/manage-vpn.sh add-client CLIENT_NAME
/etc/openvpn/manage-vpn.sh add-public-route IP_RANGE

# Client management
/etc/openvpn/client/connect-CLIENT_NAME.sh start
/etc/openvpn/client/connect-CLIENT_NAME.sh status
/etc/openvpn/client/connect-CLIENT_NAME.sh test-connection
```

## 🔍 Troubleshooting

### Common Issues
1. **Port Forwarding**: Ensure UDP ports are forwarded in router
2. **Certificate Issues**: Verify certificate validity and permissions
3. **NAT Traversal**: Check public IP detection and NAT-T settings
4. **Split Tunneling**: Verify route configuration and iptables rules

### Diagnostic Tools
```bash
# StrongSwan
validate-strongswan-config.sh
swanctl --list-conns
swanctl --list-sas

# OpenVPN
/etc/openvpn/client/troubleshoot.sh
/etc/openvpn/client/connect-CLIENT_NAME.sh test-connection
journalctl -u openvpn@server -f
```

## 📊 Comparison

| Feature | StrongSwan | OpenVPN |
|---------|------------|---------|
| **Protocol** | IPsec/IKEv2 | OpenVPN |
| **NAT Traversal** | Excellent | Excellent |
| **Setup Complexity** | Advanced | Simple |
| **Split Tunneling** | Advanced | Easy |
| **Client Support** | Good | Excellent |
| **Performance** | Excellent | Good |
| **Security** | Excellent | Very Good |
| **Mobile Support** | Good | Excellent |
| **Configuration** | Multiple files | Single .ovpn file |

## 🔄 Version History

### v2.0.0 (Current)
- Added OpenVPN support with NAT traversal
- Enhanced StrongSwan with EAP authentication
- Added public IP routing capabilities
- Improved management scripts
- Comprehensive documentation

### v1.0.0
- Initial StrongSwan implementation
- Basic certificate and PSK authentication
- Alpine Linux support

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

These scripts are provided as-is for educational and testing purposes. Ensure compliance with your organization's security policies before deployment in production environments. Always test thoroughly in a safe environment before using in production.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting sections in the documentation
2. Review log files for error messages
3. Test with basic configurations first
4. Verify network connectivity and firewall rules
5. Check certificate validity and permissions

## 🔗 Links

- [StrongSwan Documentation](https://www.strongswan.org/documentation.html)
- [OpenVPN Documentation](https://openvpn.net/community-resources/)
- [IPsec Protocol](https://tools.ietf.org/html/rfc4301)
- [IKEv2 Protocol](https://tools.ietf.org/html/rfc7296) 