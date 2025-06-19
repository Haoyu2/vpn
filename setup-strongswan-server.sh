#!/bin/sh

# StrongSwan VPN Server Setup Script for Alpine Linux
# Server: 10.0.0.2/16 (behind NAT)
# Client Network: 192.168.0.0/16
# Target Network: 10.0.0.0/16

set -e

echo "=== StrongSwan VPN Server Setup for Alpine Linux ==="
echo "Server IP: 10.0.0.2"
echo "Client Network: 192.168.0.0/16"
echo "Target Network: 10.0.0.0/16"
echo

# Update package repository
echo "Updating package repository..."
apk update

# Install StrongSwan and related packages
# echo "Installing StrongSwan and dependencies..."
# apk add strongswan strongswan-openrc iptables ip6tables strongswan-eap

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Create StrongSwan configuration directory if it doesn't exist
mkdir -p /etc/ipsec.d/{cacerts,certs,private}

# Generate CA certificate and private key
echo "Generating CA certificate and private key..."
cd /etc/ipsec.d

# Generate CA private key
openssl genrsa -out private/ca-key.pem 4096

# Generate CA certificate
openssl req -new -x509 -days 3650 -key private/ca-key.pem -out cacerts/ca-cert.pem -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=VPN-CA"

# Generate server private key
openssl genrsa -out private/server-key.pem 4096

# Generate server certificate request
openssl req -new -key private/server-key.pem -out server-req.pem -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=10.0.0.2"

# Sign server certificate with CA
openssl x509 -req -days 3650 -in server-req.pem -CA cacerts/ca-cert.pem -CAkey private/ca-key.pem -CAcreateserial -out certs/server-cert.pem

# Clean up certificate request
rm server-req.pem

# Set proper permissions
chmod 600 private/*
chmod 644 cacerts/* certs/*

# Create swanctl.conf configuration
echo "Creating modern StrongSwan configuration (swanctl)..."
mkdir -p /etc/swanctl/{conf.d,x509,x509ca,private,rsa}

# Copy certificates to swanctl directories
cp /etc/ipsec.d/cacerts/ca-cert.pem /etc/swanctl/x509ca/
cp /etc/ipsec.d/certs/server-cert.pem /etc/swanctl/x509/
cp /etc/ipsec.d/private/server-key.pem /etc/swanctl/private/

cat > /etc/swanctl/swanctl.conf << 'EOF'
# /etc/swanctl/swanctl.conf - Modern StrongSwan configuration

connections {
    # Certificate-based VPN tunnel
    vpn-tunnel {
        version = 2
        local_addrs = 10.0.0.2
        remote_addrs = %any
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = "CN=10.0.0.2"
        }
        
        remote {
            auth = pubkey
            id = %any
        }
        
        children {
            vpn-tunnel {
                local_ts = 10.0.0.0/16
                remote_ts = 192.168.0.0/16
                
                # ESP settings
                esp_proposals = aes256-sha2_256
                
                # Rekeying
                rekey_time = 1h
                life_time = 1h30m
                
                # DPD
                dpd_action = clear
                
                # Mode
                mode = tunnel
                
                # Auto start
                start_action = trap
                close_action = trap
            }
        }
        
        # IKE settings
        proposals = aes256-sha2_256-modp2048
        
        # Rekeying
        rekey_time = 24h
        over_time = 3h
        
        # DPD
        dpd_delay = 300s
        dpd_timeout = 1h
        
        # Fragmentation
        fragmentation = yes
        
        # Unique IDs
        unique = no
        
        # MOBIKE
        mobike = yes
    }
    
    # PSK-based VPN tunnel (simpler setup)
    psk-tunnel {
        version = 2
        local_addrs = 10.0.0.2
        remote_addrs = %any
        
        local {
            auth = psk
            id = 10.0.0.2
        }
        
        remote {
            auth = psk
            id = %any
        }
        
        children {
            psk-tunnel {
                local_ts = 10.0.0.0/16
                remote_ts = 192.168.0.0/16
                
                # ESP settings
                esp_proposals = aes256-sha2_256
                
                # Rekeying
                rekey_time = 1h
                life_time = 1h30m
                
                # DPD
                dpd_action = clear
                
                # Mode
                mode = tunnel
                
                # Auto start
                start_action = trap
                close_action = trap
            }
        }
        
        # IKE settings
        proposals = aes256-sha2_256-modp2048
        
        # Rekeying
        rekey_time = 24h
        over_time = 3h
        
        # DPD
        dpd_delay = 300s
        dpd_timeout = 1h
        
        # Fragmentation
        fragmentation = yes
        
        # Unique IDs
        unique = no
        
        # MOBIKE
        mobike = yes
    }
    
    # EAP-based VPN tunnel (user authentication)
    eap-tunnel {
        version = 2
        local_addrs = 10.0.0.2
        remote_addrs = %any
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = "CN=10.0.0.2"
        }
        
        remote {
            auth = eap-mschapv2
            id = %any
            eap_id = %any
        }
        
        children {
            eap-tunnel {
                local_ts = 10.0.0.0/16
                remote_ts = 192.168.0.0/16
                
                # ESP settings
                esp_proposals = aes256-sha2_256
                
                # Rekeying
                rekey_time = 1h
                life_time = 1h30m
                
                # DPD
                dpd_action = clear
                
                # Mode
                mode = tunnel
                
                # Auto start
                start_action = trap
                close_action = trap
                
                # IP assignment
                # Uncomment to assign IPs from pool
                # ipcomp = no
            }
        }
        
        # IKE settings
        proposals = aes256-sha2_256-modp2048
        
        # Rekeying
        rekey_time = 24h
        over_time = 3h
        
        # DPD
        dpd_delay = 300s
        dpd_timeout = 1h
        
        # Fragmentation
        fragmentation = yes
        
        # Unique IDs
        unique = no
        
        # MOBIKE
        mobike = yes
        
        # EAP settings
        send_certreq = no
    }
}

# Secrets for PSK authentication
secrets {
    ike-psk {
        id = 10.0.0.2
        secret = "ChangeThisToAStrongRandomKey123!"
    }
    
    ike-any {
        id = %any
        secret = "ChangeThisToAStrongRandomKey123!"
    }
    
    # EAP user credentials
    eap-user1 {
        id = "alice"
        secret = "SecurePassword123!"
    }
    
    eap-user2 {
        id = "bob"
        secret = "AnotherSecurePass456!"
    }
    
    eap-user3 {
        id = "charlie"
        secret = "YetAnotherPass789!"
    }
}

# Pools for dynamic IP assignment (if needed)
pools {
    # IP pool for EAP clients
    eap-pool {
        addrs = 192.168.200.1-192.168.200.100
        dns = 8.8.8.8, 8.8.4.4
        split_include = 10.0.0.0/16
    }
    
    # Uncomment if you want additional IP pools
    # client-pool {
    #     addrs = 192.168.100.1-192.168.100.100
    #     dns = 8.8.8.8, 8.8.4.4
    # }
}
EOF

# Set proper permissions
chmod 600 /etc/swanctl/swanctl.conf
chmod 600 /etc/swanctl/private/*
chmod 644 /etc/swanctl/x509/* /etc/swanctl/x509ca/*

# Create legacy ipsec.conf for compatibility (empty but required)
cat > /etc/ipsec.conf << 'EOF'
# /etc/ipsec.conf - Legacy configuration file (empty - using swanctl.conf)
config setup
EOF

# Create empty ipsec.secrets for compatibility
cat > /etc/ipsec.secrets << 'EOF'
# /etc/ipsec.secrets - Legacy secrets file (empty - using swanctl.conf)
EOF

# Set proper permissions for legacy files
chmod 600 /etc/ipsec.secrets

# Create strongswan.conf configuration
echo "Creating StrongSwan daemon configuration..."
cat > /etc/strongswan.conf << 'EOF'
# /etc/strongswan.conf - strongSwan configuration file

charon {
    # Number of worker threads in charon
    threads = 16
    
    # Enable NAT traversal and ports
    port_nat_t = 4500
    
    # Send and accept IKE fragmentation
    fragment_size = 1280
    
    # Logging configuration
    filelog {
        charon {
            path = /var/log/charon.log
            time_format = %b %e %T
            default = 1
            append = no
            flush_line = yes
        }
        stderr {
            ike = 1
            knl = 1
        }
    }
    
    # IKE daemon options
    ikesa_table_size = 8
    ikesa_table_segments = 1
    
    # Enable multiple authentication rounds
    multiple_authentication = no
    
    # Close IKE_SA if setup of CHILD_SA failed
    close_ike_on_child_failure = yes
    
    # Use MOBIKE if peer supports it
    mobility = yes
    
    # Install routes into main table
    install_routes = yes
    
    # Install virtual IP addresses
    install_virtual_ip = yes
    
    # Dead peer detection
    dpd_delay = 30s
    
    # Keep alive
    keep_alive = 20s
}

# Include additional configuration files
include strongswan.d/*.conf
EOF

# Create strongswan.d directory structure
mkdir -p /etc/strongswan.d/charon

# Create basic charon plugin configuration
cat > /etc/strongswan.d/charon/logging.conf << 'EOF'
# Basic logging configuration for charon plugins
# Main logging is configured in strongswan.conf
EOF

# Set proper permissions
chmod 644 /etc/strongswan.conf
chmod 644 /etc/strongswan.d/charon/logging.conf

# Configure iptables rules for NAT and forwarding
echo "Configuring iptables rules..."

# Save current iptables rules
iptables-save > /etc/iptables-backup.rules

# Allow VPN traffic
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT

# Allow forwarding between VPN and local network
iptables -A FORWARD -s 192.168.0.0/16 -d 10.0.0.0/16 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/16 -d 192.168.0.0/16 -j ACCEPT

# NAT rules for VPN clients to access local network
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -d 10.0.0.0/16 -j MASQUERADE

# Save iptables rules
/etc/init.d/iptables save

# Enable and start services
echo "Enabling and starting services..."
rc-update add iptables default
rc-update add strongswan default

# Start StrongSwan
rc-service strongswan start

# Load swanctl configuration
echo "Loading swanctl configuration..."
swanctl --load-all

echo
echo "=== StrongSwan VPN Server Setup Complete ==="
echo
echo "Configuration Summary:"
echo "- Server IP: 10.0.0.2"
echo "- Local Network: 10.0.0.0/16"
echo "- Client Network: 192.168.0.0/16"
echo "- VPN Ports: UDP 500, 4500"
echo
echo "Important Files:"
echo "- Configuration: /etc/ipsec.conf"
echo "- Secrets: /etc/ipsec.secrets"
echo "- CA Certificate: /etc/ipsec.d/cacerts/ca-cert.pem"
echo "- Server Certificate: /etc/ipsec.d/certs/server-cert.pem"
echo
echo "Next Steps:"
echo "1. Copy the CA certificate to your client VMs"
echo "2. Configure your VM clients to connect to 10.0.0.2"
echo "3. Update the PSK in /etc/ipsec.secrets to a strong random key"
echo "4. Test the connection from a VM in 192.168.0.0/16"
echo
echo "To check status: ipsec status"
echo "To reload config: ipsec reload"
echo "To restart: rc-service strongswan restart" 