#!/bin/bash

# StrongSwan VPN Client Setup Script
# For VMs in 192.168.0.0/16 network
# Connecting to server at 10.0.0.2

set -e

VPN_SERVER="10.0.0.2"
PSK_KEY="ChangeThisToAStrongRandomKey123!"  # Must match server PSK

echo "=== StrongSwan VPN Client Setup ==="
echo "Server: $VPN_SERVER"
echo "Client Network: 192.168.0.0/16"
echo "Target Network: 10.0.0.0/16"
echo

# Detect OS and install StrongSwan
if [ -f /etc/alpine-release ]; then
    echo "Detected Alpine Linux"
    apk update
    apk add strongswan strongswan-openrc iptables strongswan-eap
    SERVICE_CMD="rc-service"
    UPDATE_CMD="rc-update add"
elif [ -f /etc/debian_version ]; then
    echo "Detected Debian/Ubuntu"
    apt-get update
    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins
    SERVICE_CMD="systemctl"
    UPDATE_CMD="systemctl enable"
elif [ -f /etc/redhat-release ]; then
    echo "Detected RHEL/CentOS"
    yum install -y epel-release
    yum install -y strongswan
    SERVICE_CMD="systemctl"
    UPDATE_CMD="systemctl enable"
else
    echo "Unsupported OS. Please install StrongSwan manually."
    exit 1
fi

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Create client certificate directory
mkdir -p /etc/ipsec.d/{cacerts,certs,private}

# Generate client private key
echo "Generating client certificate..."
cd /etc/ipsec.d

# Get client IP for certificate
CLIENT_IP=$(ip route get 8.8.8.8 | awk '/src/{print $7}' | head -1)
echo "Client IP: $CLIENT_IP"

# Generate client private key
openssl genrsa -out private/client-key.pem 4096

# Generate client certificate request
openssl req -new -key private/client-key.pem -out client-req.pem -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$CLIENT_IP"

echo "NOTE: You need to copy the CA certificate from the server to /etc/ipsec.d/cacerts/ca-cert.pem"
echo "And get your client certificate signed by the server's CA"

# Set proper permissions
chmod 600 private/*
chmod 644 cacerts/* certs/* 2>/dev/null || true

# Create swanctl.conf for client
echo "Creating modern client StrongSwan configuration (swanctl)..."
mkdir -p /etc/swanctl/{conf.d,x509,x509ca,private,rsa}

cat > /etc/swanctl/swanctl.conf << EOF
# /etc/swanctl/swanctl.conf - Modern StrongSwan client configuration

connections {
    # PSK-based connection to server
    to-server-psk {
        version = 2
        local_addrs = $CLIENT_IP
        remote_addrs = $VPN_SERVER
        
        local {
            auth = psk
            id = $CLIENT_IP
        }
        
        remote {
            auth = psk
            id = $VPN_SERVER
        }
        
        children {
            to-server-psk {
                local_ts = 192.168.0.0/16
                remote_ts = 10.0.0.0/16
                
                # ESP settings
                esp_proposals = aes256-sha2_256
                
                # Rekeying
                rekey_time = 1h
                life_time = 1h30m
                
                # DPD
                dpd_action = restart
                
                # Mode
                mode = tunnel
                
                # Auto start
                start_action = none
                close_action = none
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
        
        # Retries
        keyingtries = 0
    }
    
    # EAP-based connection to server (user authentication)
    to-server-eap {
        version = 2
        local_addrs = $CLIENT_IP
        remote_addrs = $VPN_SERVER
        
        local {
            auth = eap-mschapv2
            id = "alice"  # Change this to your username
            eap_id = "alice"
        }
        
        remote {
            auth = pubkey
            id = "CN=$VPN_SERVER"
        }
        
        children {
            to-server-eap {
                local_ts = 0.0.0.0/0
                remote_ts = 10.0.0.0/16
                
                # ESP settings
                esp_proposals = aes256-sha2_256
                
                # Rekeying
                rekey_time = 1h
                life_time = 1h30m
                
                # DPD
                dpd_action = restart
                
                # Mode
                mode = tunnel
                
                # Auto start
                start_action = start
                close_action = start
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
        
        # Retries
        keyingtries = 0
    }
}

# Secrets for PSK authentication
secrets {
    ike-client {
        id = $CLIENT_IP
        secret = "$PSK_KEY"
    }
    
    ike-server {
        id = $VPN_SERVER
        secret = "$PSK_KEY"
    }
    
    # EAP user credentials
    eap-alice {
        id = "alice"
        secret = "SecurePassword123!"
    }
    
    eap-bob {
        id = "bob"
        secret = "AnotherSecurePass456!"
    }
    
    eap-charlie {
        id = "charlie"
        secret = "YetAnotherPass789!"
    }
}
EOF

# Set proper permissions
chmod 600 /etc/swanctl/swanctl.conf

# Create legacy ipsec.conf for compatibility (empty but required)
cat > /etc/ipsec.conf << EOF
# /etc/ipsec.conf - Legacy configuration file (empty - using swanctl.conf)
config setup
EOF

# Create empty ipsec.secrets for compatibility
cat > /etc/ipsec.secrets << EOF
# /etc/ipsec.secrets - Legacy secrets file (empty - using swanctl.conf)
EOF

# Set proper permissions for legacy files
chmod 600 /etc/ipsec.secrets

# Create strongswan.conf configuration for client
echo "Creating StrongSwan daemon configuration..."
cat > /etc/strongswan.conf << 'EOF'
# /etc/strongswan.conf - strongSwan configuration file

charon {
    # Number of worker threads in charon
    threads = 8
    
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
    ikesa_table_size = 4
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
    
    # Retry connection if it fails
    retry_attempts = 3
    
    # Keep alive interval
    keep_alive = 20s
    
    # Dead peer detection
    dpd_delay = 30s
}

# Include additional configuration files
include strongswan.d/*.conf
EOF

# Create strongswan.d directory structure
mkdir -p /etc/strongswan.d/charon

# Create basic charon plugin configuration for client
cat > /etc/strongswan.d/charon/logging.conf << 'EOF'
# Basic logging configuration for charon plugins
# Main logging is configured in strongswan.conf
EOF

# Set proper permissions
chmod 644 /etc/strongswan.conf
chmod 644 /etc/strongswan.d/charon/logging.conf

# Configure iptables rules for client
echo "Configuring client iptables rules..."

# Allow VPN traffic
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT

# Allow traffic to/from VPN tunnel
iptables -A FORWARD -s 192.168.0.0/16 -d 10.0.0.0/16 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/16 -d 192.168.0.0/16 -j ACCEPT

# Save iptables rules (method varies by OS)
if [ -f /etc/alpine-release ]; then
    /etc/init.d/iptables save
elif [ -f /etc/debian_version ]; then
    iptables-save > /etc/iptables/rules.v4
elif [ -f /etc/redhat-release ]; then
    iptables-save > /etc/sysconfig/iptables
fi

# Enable and start services
echo "Enabling and starting services..."
if [ -f /etc/alpine-release ]; then
    rc-update add iptables default
    rc-update add strongswan default
    rc-service strongswan start
else
    systemctl enable strongswan
    systemctl start strongswan
fi

# Load swanctl configuration
echo "Loading swanctl configuration..."
swanctl --load-all

echo
echo "=== StrongSwan VPN Client Setup Complete ==="
echo
echo "Configuration Summary:"
echo "- Client IP: $CLIENT_IP"
echo "- Server IP: $VPN_SERVER"
echo "- Local Network: 192.168.0.0/16"
echo "- Remote Network: 10.0.0.0/16"
echo
echo "Important: Make sure the PSK matches the server configuration!"
echo
echo "To test the connection:"
echo "  ipsec status"
echo "  ping 10.0.0.1  # Test connectivity to target network"
echo
echo "To restart VPN:"
if [ -f /etc/alpine-release ]; then
    echo "  rc-service strongswan restart"
else
    echo "  systemctl restart strongswan"
fi 