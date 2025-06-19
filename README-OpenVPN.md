# OpenVPN Setup Guide (NAT Traversal + Public IP Access)

This guide provides comprehensive setup instructions for OpenVPN with NAT traversal support and public IP routing capabilities. The setup allows clients behind NAT to connect to a server behind NAT, with split tunneling that routes specific public IP ranges through the VPN.

## Overview

- **Server**: Behind NAT via Internet
- **Client**: Behind NAT via Internet  
- **Target Network**: 10.0.0.0/16
- **VPN Network**: 10.8.0.0/24
- **Public IP Routing**: Configurable public IP ranges
- **Split Tunneling**: Only specific traffic goes through VPN

## Features

- ✅ NAT traversal support for both server and clients
- ✅ Split tunneling with public IP routing
- ✅ Certificate-based authentication
- ✅ Automatic port forwarding detection
- ✅ Connection stability for NAT environments
- ✅ Comprehensive management scripts
- ✅ Troubleshooting tools
- ✅ Public IP range management

## Architecture

```
Internet
    │
    ├── Server Router (NAT)
    │   └── OpenVPN Server (10.0.0.2)
    │       └── VPN Network (10.8.0.0/24)
    │           └── Routes to: 10.0.0.0/16 + Public IP ranges
    │
    └── Client Router (NAT)
        └── OpenVPN Client
            └── Routes through VPN: 10.0.0.0/16 + Public IP ranges
            └── Direct internet: All other traffic
```

## Quick Start

### 1. Server Setup

```bash
# Download and run server setup
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-openvpn-server.sh
chmod +x setup-openvpn-server.sh
sudo ./setup-openvpn-server.sh
```

### 2. Port Forwarding

Configure your router to forward UDP port 1194 to the server:
- Protocol: UDP
- External Port: 1194
- Internal Port: 1194
- Internal IP: [Your server's local IP]

### 3. Client Setup

```bash
# Download and run client setup
wget https://raw.githubusercontent.com/Haoyu2/vpn/main/setup-openvpn-client.sh
chmod +x setup-openvpn-client.sh
sudo ./setup-openvpn-client.sh
```

### 4. Add Certificates

Copy certificates from server to client configuration files.

### 5. Connect

```bash
/etc/openvpn/client/connect-CLIENT_NAME.sh start
```

## Detailed Setup

### Server Configuration

The server setup script (`setup-openvpn-server.sh`) performs the following:

1. **Package Installation**
   - OpenVPN server
   - Easy-RSA for certificate management
   - iptables-persistent for firewall rules

2. **Certificate Generation**
   - CA certificate and private key
   - Server certificate and private key
   - Diffie-Hellman parameters
   - TLS auth key

3. **Server Configuration**
   - NAT traversal settings
   - Split tunneling with public IP routing
   - Security settings (AES-256, SHA256)
   - Connection stability options

4. **Firewall Configuration**
   - Allow UDP port 1194
   - Forward traffic between VPN and local networks
   - Forward traffic to configured public IP ranges
   - NAT rules for VPN clients

5. **Management Tools**
   - Client configuration generator
   - Public IP route management
   - Status monitoring
   - Troubleshooting scripts

### Client Configuration

The client setup script (`setup-openvpn-client.sh`) performs the following:

1. **Package Installation**
   - OpenVPN client
   - resolvconf for DNS management

2. **Client Configuration**
   - NAT traversal settings
   - Split tunneling with public IP routing
   - Connection stability options
   - Certificate placeholders

3. **Systemd Service**
   - Automatic startup
   - Service management
   - Logging integration

4. **Management Tools**
   - Connection scripts
   - Status monitoring
   - Public IP route management
   - Troubleshooting tools

## Public IP Routing

### Default Configuration

The setup includes example public IP ranges that are routed through the VPN:

- `203.0.113.0/24` (Example range 1)
- `198.51.100.0/24` (Example range 2)  
- `192.0.2.0/24` (Example range 3)

### Adding Custom Public IP Ranges

#### On Server

```bash
# Add new public IP range
/etc/openvpn/manage-vpn.sh add-public-route 203.0.114.0/24

# List configured routes
/etc/openvpn/manage-vpn.sh list-public-routes

# Restart server to apply changes
/etc/openvpn/manage-vpn.sh restart
```

#### On Client

```bash
# Add new public IP range
/etc/openvpn/client/connect-CLIENT_NAME.sh add-public-route 203.0.114.0/24

# List configured routes
/etc/openvpn/client/connect-CLIENT_NAME.sh list-public-routes

# Restart client to apply changes
/etc/openvpn/client/connect-CLIENT_NAME.sh restart
```

### Creating Clients with Custom Routes

```bash
# Server: Create client with custom public IP ranges
/etc/openvpn/manage-vpn.sh add-client client1 "203.0.113.0/24 198.51.100.0/24"

# Client: Setup with custom public IP ranges
sudo ./setup-openvpn-client.sh
# Enter server IP and custom ranges when prompted
```

## Management Commands

### Server Management

```bash
# Check server status
/etc/openvpn/manage-vpn.sh status

# Add new client
/etc/openvpn/manage-vpn.sh add-client CLIENT_NAME [PUBLIC_IP_RANGES]

# List clients
/etc/openvpn/manage-vpn.sh list-clients

# Show public IP
/etc/openvpn/manage-vpn.sh public-ip

# Add public IP route
/etc/openvpn/manage-vpn.sh add-public-route IP_RANGE

# List public IP routes
/etc/openvpn/manage-vpn.sh list-public-routes

# Restart server
/etc/openvpn/manage-vpn.sh restart
```

### Client Management

```bash
# Start VPN
/etc/openvpn/client/connect-CLIENT_NAME.sh start

# Stop VPN
/etc/openvpn/client/connect-CLIENT_NAME.sh stop

# Check status
/etc/openvpn/client/connect-CLIENT_NAME.sh status

# Test connection
/etc/openvpn/client/connect-CLIENT_NAME.sh test-connection

# View logs
/etc/openvpn/client/connect-CLIENT_NAME.sh logs

# Add public IP route
/etc/openvpn/client/connect-CLIENT_NAME.sh add-public-route IP_RANGE

# List public IP routes
/etc/openvpn/client/connect-CLIENT_NAME.sh list-public-routes

# Restart client
/etc/openvpn/client/connect-CLIENT_NAME.sh restart
```

### General Management

```bash
# Server: List all management commands
/etc/openvpn/manage-vpn.sh

# Client: List all management commands
/etc/openvpn/client/manage-vpn.sh

# Client: Run troubleshooting
/etc/openvpn/client/troubleshoot.sh
```

## Configuration Files

### Server Files

- `/etc/openvpn/server/server.conf` - Main server configuration
- `/etc/openvpn/server/ca.crt` - CA certificate
- `/etc/openvpn/server/server.crt` - Server certificate
- `/etc/openvpn/server/server.key` - Server private key
- `/etc/openvpn/server/dh.pem` - Diffie-Hellman parameters
- `/etc/openvpn/server/ta.key` - TLS auth key
- `/etc/openvpn/client-configs/files/` - Client configurations
- `/etc/openvpn/manage-vpn.sh` - Management script
- `/etc/openvpn/PORT_FORWARDING_INSTRUCTIONS.txt` - Port forwarding guide

### Client Files

- `/etc/openvpn/client/CLIENT_NAME.conf` - Client configuration
- `/etc/openvpn/client/connect-CLIENT_NAME.sh` - Connection script
- `/etc/openvpn/client/manage-vpn.sh` - Management script
- `/etc/openvpn/client/troubleshoot.sh` - Troubleshooting script
- `/etc/openvpn/client/SETUP_INSTRUCTIONS.txt` - Setup instructions

## Split Tunneling

The configuration uses split tunneling to route only specific traffic through the VPN:

### Traffic Through VPN
- Local networks: `10.0.0.0/16`, `192.168.0.0/16`
- Configured public IP ranges (default: `203.0.113.0/24`, `198.51.100.0/24`, `192.0.2.0/24`)

### Traffic Direct (Not Through VPN)
- All other internet traffic
- DNS queries (except for VPN networks)
- Local network traffic

### Benefits
- Better performance for general internet access
- Reduced VPN server load
- Maintained security for target networks
- Flexible routing based on requirements

## NAT Traversal

### Server NAT Traversal
- Automatic public IP detection
- NAT traversal-specific OpenVPN options
- Port forwarding instructions
- Connection stability settings

### Client NAT Traversal
- NAT traversal-specific client options
- Connection retry and timeout settings
- Persistent connection handling
- Troubleshooting for NAT issues

### Port Forwarding Requirements
- UDP port 1194 must be forwarded to server
- Alternative ports available (443, 53, 80)
- Router configuration instructions provided

## Security Features

### Authentication
- Certificate-based authentication
- TLS auth key for additional security
- Strong encryption (AES-256-CBC)
- SHA256 message authentication

### Network Security
- Split tunneling prevents unnecessary traffic exposure
- Firewall rules restrict access
- NAT isolation for VPN clients
- Secure certificate management

### Best Practices
- Regular certificate rotation
- Strong private key protection
- Monitoring of connection logs
- Regular security updates

## Troubleshooting

### Common Issues

#### Connection Problems
```bash
# Check server status
/etc/openvpn/manage-vpn.sh status

# Check client status
/etc/openvpn/client/connect-CLIENT_NAME.sh status

# View server logs
journalctl -u openvpn@server -f

# View client logs
journalctl -u openvpn-client@CLIENT_NAME -f

# Run troubleshooting
/etc/openvpn/client/troubleshoot.sh
```

#### Port Forwarding Issues
1. Verify UDP port 1194 is forwarded
2. Check router firewall settings
3. Test with alternative ports
4. Verify server public IP

#### Certificate Issues
1. Ensure certificates are properly embedded
2. Check certificate validity dates
3. Verify CA certificate matches
4. Check file permissions

#### Split Tunneling Issues
1. Verify route configuration
2. Check iptables rules
3. Test connectivity to target networks
4. Verify public IP ranges are correct

### Testing Connectivity

```bash
# Test VPN connection
/etc/openvpn/client/connect-CLIENT_NAME.sh test-connection

# Test specific networks
ping 10.0.0.1
ping 203.0.113.1

# Test split tunneling
curl https://www.google.com  # Should be direct
curl https://10.0.0.1       # Should go through VPN
```

### Log Analysis

```bash
# Server logs
tail -f /var/log/openvpn.log

# Client logs
journalctl -u openvpn-client@CLIENT_NAME -f

# System logs
journalctl -f | grep openvpn
```

## Performance Tuning

### Server Optimization
- Worker thread configuration
- Connection limits
- Memory usage optimization
- Network buffer settings

### Client Optimization
- Connection retry settings
- Timeout configurations
- Buffer size optimization
- DNS resolution settings

### Network Optimization
- MTU size adjustment
- Compression settings
- Protocol optimization
- Route optimization

## Monitoring

### Server Monitoring
```bash
# Active connections
/etc/openvpn/manage-vpn.sh status

# Connection logs
tail -f /var/log/openvpn.log

# System resources
htop
```

### Client Monitoring
```bash
# Connection status
/etc/openvpn/client/connect-CLIENT_NAME.sh status

# Performance metrics
/etc/openvpn/client/connect-CLIENT_NAME.sh test-connection

# System resources
htop
```

## Backup and Recovery

### Server Backup
```bash
# Backup certificates and keys
tar -czf openvpn-server-backup.tar.gz /etc/openvpn/server/

# Backup configurations
tar -czf openvpn-config-backup.tar.gz /etc/openvpn/client-configs/
```

### Client Backup
```bash
# Backup client configuration
cp /etc/openvpn/client/CLIENT_NAME.conf /backup/

# Backup certificates
tar -czf openvpn-client-backup.tar.gz /etc/openvpn/client/
```

## Advanced Configuration

### Custom Ports
Edit server and client configurations to use different ports:
```bash
# Server: Change port in /etc/openvpn/server/server.conf
port 443

# Client: Change port in client configuration
remote SERVER_IP 443
```

### Custom Encryption
Modify encryption settings in configurations:
```bash
# Server and client: Change cipher
cipher AES-256-GCM
auth SHA512
```

### Custom Routes
Add additional network routes:
```bash
# Server: Add to server.conf
push "route 172.16.0.0 255.255.0.0"

# Client: Add to client config
route 172.16.0.0 255.255.0.0
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review log files
3. Test with basic configurations
4. Verify network connectivity
5. Check certificate validity

## License

This setup is provided as-is for educational and testing purposes. Ensure compliance with your organization's security policies before deployment in production environments. 