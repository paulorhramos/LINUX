#!/bin/bash

# =============================================================================
# Configurador de VPN para Rocky Linux 10
# =============================================================================
# Descrição: Setup completo de VPN (OpenVPN, WireGuard e IPSec)
# Autor: Paulo Ramos
# Versão: 1.0
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurações
CONFIG_FILE="/etc/vpn-setup.conf"
LOG_FILE="/var/log/vpn-setup.log"
VPN_BASE_DIR="/etc/vpn"
CERTS_DIR="$VPN_BASE_DIR/certs"

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script deve ser executado como root!"
        exit 1
    fi
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações do VPN Setup

# Configurações do servidor
SERVER_EXTERNAL_IP=""
SERVER_INTERNAL_IP="10.8.0.1"
VPN_NETWORK="10.8.0.0/24"
VPN_PORT_OPENVPN=1194
VPN_PORT_WIREGUARD=51820

# Configurações de certificados
CERT_COUNTRY="US"
CERT_PROVINCE="State"
CERT_CITY="City"
CERT_ORG="Organization"
CERT_EMAIL="admin@example.com"
CERT_VALIDITY_DAYS=3650

# Configurações de DNS
VPN_DNS="8.8.8.8,8.8.4.4"
ENABLE_DNS_FILTERING=false
DNS_FILTERING_LISTS="https://someonewhocares.org/hosts/zero/hosts"

# Configurações de segurança
ENABLE_FIREWALL_INTEGRATION=true
ENABLE_FAIL2BAN=true
ENABLE_LOG_MONITORING=true
COMPRESSION_ENABLED=true

# Configurações do cliente
GENERATE_CLIENT_CONFIGS=true
CLIENT_CONFIG_DIR="/etc/vpn/clients"
DEFAULT_CLIENT_NAME="client1"

# Configurações avançadas
ENABLE_TRAFFIC_FORWARDING=true
ENABLE_NAT=true
CIPHER="AES-256-GCM"
AUTH="SHA256"
TLS_VERSION="1.2"

# WireGuard específico
WG_INTERFACE="wg0"
WG_PRIVATE_KEY_FILE="/etc/vpn/wireguard/server_private.key"
WG_PUBLIC_KEY_FILE="/etc/vpn/wireguard/server_public.key"

# Monitoramento
ENABLE_BANDWIDTH_MONITORING=true
ENABLE_CONNECTION_LOGGING=true
LOG_RETENTION_DAYS=30
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Detectar IP externo
detect_external_ip() {
    local external_ip=""
    
    # Tentar vários métodos para detectar IP externo
    external_ip=$(curl -s ifconfig.me 2>/dev/null)
    
    if [ -z "$external_ip" ]; then
        external_ip=$(curl -s ipinfo.io/ip 2>/dev/null)
    fi
    
    if [ -z "$external_ip" ]; then
        external_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
    fi
    
    if [ -z "$external_ip" ]; then
        # Fallback para IP local se não conseguir detectar externo
        external_ip=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
    fi
    
    echo "$external_ip"
}

# Setup inicial
initial_setup() {
    print_header "🔧 Setup Inicial"
    
    # Detectar IP externo se não configurado
    if [ -z "$SERVER_EXTERNAL_IP" ]; then
        print_info "Detectando IP externo..."
        local detected_ip=$(detect_external_ip)
        
        if [ -n "$detected_ip" ]; then
            print_success "IP externo detectado: $detected_ip"
            SERVER_EXTERNAL_IP="$detected_ip"
            # Atualizar arquivo de configuração
            sed -i "s/SERVER_EXTERNAL_IP=\"\"/SERVER_EXTERNAL_IP=\"$detected_ip\"/" "$CONFIG_FILE"
        else
            print_warning "Não foi possível detectar IP externo automaticamente"
            read -p "Digite o IP externo do servidor: " manual_ip
            SERVER_EXTERNAL_IP="$manual_ip"
        fi
    fi
    
    # Criar estrutura de diretórios
    mkdir -p "$VPN_BASE_DIR"/{openvpn,wireguard,ipsec,clients,logs,certs}
    mkdir -p "$CERTS_DIR"/{ca,server,clients}
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    print_success "Estrutura de diretórios criada"
    
    # Configurar IP forwarding
    if [ "$ENABLE_TRAFFIC_FORWARDING" = "true" ]; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
        sysctl -p
        print_success "IP forwarding habilitado"
    fi
    
    log_action "Initial VPN setup completed"
}

# Instalar dependências
install_dependencies() {
    print_header "📦 Instalando Dependências"
    
    local packages=("epel-release")
    
    # Verificar qual VPN será configurada
    if command -v openvpn &> /dev/null; then
        print_success "OpenVPN já está instalado"
    else
        packages+=("openvpn" "easy-rsa")
    fi
    
    if command -v wg &> /dev/null; then
        print_success "WireGuard já está instalado"
    else
        packages+=("wireguard-tools")
    fi
    
    # Instalar pacotes necessários
    print_info "Instalando pacotes: ${packages[*]}"
    dnf install -y "${packages[@]}"
    
    # Instalar certificados adicionais
    dnf install -y openssl
    
    print_success "Dependências instaladas"
}

# Setup OpenVPN
setup_openvpn() {
    print_header "🔐 Configurando OpenVPN"
    
    local openvpn_dir="$VPN_BASE_DIR/openvpn"
    local easy_rsa_dir="$openvpn_dir/easy-rsa"
    
    # Copiar easy-rsa
    if [ -d "/usr/share/easy-rsa" ]; then
        cp -r /usr/share/easy-rsa "$openvpn_dir/"
    else
        print_error "Easy-RSA não encontrado"
        return 1
    fi
    
    cd "$easy_rsa_dir"
    
    # Configurar vars
    cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY    "$CERT_COUNTRY"
set_var EASYRSA_REQ_PROVINCE   "$CERT_PROVINCE"
set_var EASYRSA_REQ_CITY       "$CERT_CITY"
set_var EASYRSA_REQ_ORG        "$CERT_ORG"
set_var EASYRSA_REQ_EMAIL      "$CERT_EMAIL"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_DIGEST         sha256
set_var EASYRSA_CERT_EXPIRE    $CERT_VALIDITY_DAYS
EOF

    # Inicializar PKI
    print_info "Inicializando PKI..."
    ./easyrsa init-pki
    
    # Criar CA
    print_info "Criando Autoridade Certificadora..."
    echo -e "\n" | ./easyrsa build-ca nopass
    
    # Criar certificado do servidor
    print_info "Criando certificado do servidor..."
    echo -e "\n\n\n" | ./easyrsa build-server-full server nopass
    
    # Gerar parâmetros DH
    print_info "Gerando parâmetros Diffie-Hellman..."
    ./easyrsa gen-dh
    
    # Gerar chave TLS-AUTH
    openvpn --genkey secret pki/ta.key
    
    # Copiar certificados para diretório OpenVPN
    cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem pki/ta.key /etc/openvpn/server/
    
    # Criar configuração do servidor
    cat > /etc/openvpn/server/server.conf << EOF
port $VPN_PORT_OPENVPN
proto udp
dev tun

# Certificados e chaves
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0

# Rede VPN
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Configurações de roteamento
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $(echo $VPN_DNS | cut -d',' -f1)"
push "dhcp-option DNS $(echo $VPN_DNS | cut -d',' -f2)"

# Configurações de segurança
cipher $CIPHER
auth $AUTH
tls-version-min $TLS_VERSION
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Configurações de performance
$([ "$COMPRESSION_ENABLED" = "true" ] && echo "compress lz4-v2")
$([ "$COMPRESSION_ENABLED" = "true" ] && echo "push \"compress lz4-v2\"")

# Configurações de cliente
client-to-client
keepalive 10 120
user nobody
group nobody
persist-key
persist-tun

# Logging
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
mute 20

# Configurações de conexão
max-clients 100
duplicate-cn
EOF

    # Configurar NAT e firewall
    if [ "$ENABLE_NAT" = "true" ]; then
        setup_openvpn_firewall
    fi
    
    # Habilitar e iniciar serviço
    systemctl enable --now openvpn-server@server
    
    print_success "OpenVPN configurado e iniciado"
    log_action "OpenVPN server configured"
}

# Setup WireGuard
setup_wireguard() {
    print_header "⚡ Configurando WireGuard"
    
    local wg_dir="$VPN_BASE_DIR/wireguard"
    
    cd "$wg_dir"
    
    # Gerar chaves do servidor
    print_info "Gerando chaves do servidor..."
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key
    
    local server_private_key=$(cat server_private.key)
    local server_public_key=$(cat server_public.key)
    
    # Criar configuração do servidor
    cat > /etc/wireguard/$WG_INTERFACE.conf << EOF
[Interface]
PrivateKey = $server_private_key
Address = $SERVER_INTERNAL_IP/24
ListenPort = $VPN_PORT_WIREGUARD
SaveConfig = true

# Configurações de rede
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

    # Configurar firewall para WireGuard
    if [ "$ENABLE_FIREWALL_INTEGRATION" = "true" ]; then
        setup_wireguard_firewall
    fi
    
    # Habilitar e iniciar serviço
    systemctl enable --now wg-quick@$WG_INTERFACE
    
    print_success "WireGuard configurado e iniciado"
    print_info "Chave pública do servidor: $server_public_key"
    
    log_action "WireGuard server configured"
}

# Configurar firewall para OpenVPN
setup_openvpn_firewall() {
    print_info "Configurando firewall para OpenVPN..."
    
    if command -v firewall-cmd &> /dev/null; then
        # Permitir porta OpenVPN
        firewall-cmd --permanent --add-port=$VPN_PORT_OPENVPN/udp
        
        # Permitir serviço OpenVPN
        firewall-cmd --permanent --add-service=openvpn
        
        # Configurar masquerading
        firewall-cmd --permanent --add-masquerade
        
        # Adicionar rich rule para VPN
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='10.8.0.0/24' accept"
        
        firewall-cmd --reload
        print_success "Firewall configurado para OpenVPN"
    else
        # Configurar iptables diretamente
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
        iptables -A FORWARD -i tun0 -j ACCEPT
        iptables -A FORWARD -o tun0 -j ACCEPT
    fi
}

# Configurar firewall para WireGuard
setup_wireguard_firewall() {
    print_info "Configurando firewall para WireGuard..."
    
    if command -v firewall-cmd &> /dev/null; then
        # Permitir porta WireGuard
        firewall-cmd --permanent --add-port=$VPN_PORT_WIREGUARD/udp
        
        # Configurar masquerading
        firewall-cmd --permanent --add-masquerade
        
        # Adicionar rich rule para WireGuard
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='10.8.0.0/24' accept"
        
        firewall-cmd --reload
        print_success "Firewall configurado para WireGuard"
    fi
}

# Gerar configuração de cliente OpenVPN
generate_openvpn_client() {
    local client_name="${1:-$DEFAULT_CLIENT_NAME}"
    print_header "👤 Gerando Cliente OpenVPN: $client_name"
    
    local easy_rsa_dir="$VPN_BASE_DIR/openvpn/easy-rsa"
    local client_dir="$CLIENT_CONFIG_DIR/$client_name"
    
    mkdir -p "$client_dir"
    cd "$easy_rsa_dir"
    
    # Gerar certificado do cliente
    print_info "Gerando certificado para $client_name..."
    echo -e "\n\n\n" | ./easyrsa build-client-full "$client_name" nopass
    
    # Criar arquivo de configuração do cliente
    cat > "$client_dir/$client_name.ovpn" << EOF
client
dev tun
proto udp
remote $SERVER_EXTERNAL_IP $VPN_PORT_OPENVPN
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher $CIPHER
auth $AUTH
key-direction 1
verb 3

<ca>
$(cat pki/ca.crt)
</ca>

<cert>
$(cat pki/issued/$client_name.crt)
</cert>

<key>
$(cat pki/private/$client_name.key)
</key>

<tls-auth>
$(cat pki/ta.key)
</tls-auth>
EOF

    print_success "Configuração do cliente salva em: $client_dir/$client_name.ovpn"
    log_action "OpenVPN client '$client_name' generated"
}

# Gerar configuração de cliente WireGuard
generate_wireguard_client() {
    local client_name="${1:-$DEFAULT_CLIENT_NAME}"
    local client_ip="${2:-10.8.0.2}"
    
    print_header "👤 Gerando Cliente WireGuard: $client_name"
    
    local wg_dir="$VPN_BASE_DIR/wireguard"
    local client_dir="$CLIENT_CONFIG_DIR/$client_name"
    
    mkdir -p "$client_dir"
    cd "$wg_dir"
    
    # Gerar chaves do cliente
    wg genkey | tee "$client_dir/${client_name}_private.key" | wg pubkey > "$client_dir/${client_name}_public.key"
    chmod 600 "$client_dir/${client_name}_private.key"
    
    local client_private_key=$(cat "$client_dir/${client_name}_private.key")
    local client_public_key=$(cat "$client_dir/${client_name}_public.key")
    local server_public_key=$(cat server_public.key)
    
    # Criar configuração do cliente
    cat > "$client_dir/$client_name.conf" << EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/32
DNS = $(echo $VPN_DNS | tr ',' ' ')

[Peer]
PublicKey = $server_public_key
Endpoint = $SERVER_EXTERNAL_IP:$VPN_PORT_WIREGUARD
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # Adicionar peer ao servidor
    wg set $WG_INTERFACE peer "$client_public_key" allowed-ips "$client_ip/32"
    
    # Salvar configuração
    wg-quick save $WG_INTERFACE
    
    print_success "Configuração do cliente salva em: $client_dir/$client_name.conf"
    print_info "Chave pública do cliente: $client_public_key"
    
    log_action "WireGuard client '$client_name' generated"
}

# Status da VPN
show_vpn_status() {
    print_header "📊 Status da VPN"
    
    # OpenVPN
    if systemctl is-active --quiet openvpn-server@server; then
        print_success "OpenVPN: Ativo"
        
        local openvpn_clients=$(grep "CLIENT_LIST" /var/log/openvpn/openvpn-status.log 2>/dev/null | wc -l)
        echo "  📱 Clientes conectados: $openvpn_clients"
        
        if [ "$openvpn_clients" -gt 0 ]; then
            echo "  👥 Lista de clientes:"
            grep "CLIENT_LIST" /var/log/openvpn/openvpn-status.log 2>/dev/null | while IFS=',' read -r tag name real_ip virtual_ip bytes_rx bytes_tx connected_since; do
                echo "    $name: $virtual_ip (desde $connected_since)"
            done
        fi
    else
        print_error "OpenVPN: Inativo"
    fi
    
    echo
    
    # WireGuard
    if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
        print_success "WireGuard: Ativo"
        
        echo "  🔧 Interface: $WG_INTERFACE"
        echo "  📱 Peers configurados:"
        wg show $WG_INTERFACE | grep -A4 "peer:" | while read line; do
            echo "    $line"
        done
    else
        print_error "WireGuard: Inativo"
    fi
    
    echo
    
    # Estatísticas de tráfego
    if [ "$ENABLE_BANDWIDTH_MONITORING" = "true" ]; then
        print_info "Estatísticas de tráfego:"
        
        # OpenVPN
        if [ -f /var/log/openvpn/openvpn-status.log ]; then
            local total_rx=$(awk -F',' '/CLIENT_LIST/ {sum+=$5} END {print sum+0}' /var/log/openvpn/openvpn-status.log 2>/dev/null)
            local total_tx=$(awk -F',' '/CLIENT_LIST/ {sum+=$6} END {print sum+0}' /var/log/openvpn/openvpn-status.log 2>/dev/null)
            
            echo "  📥 OpenVPN RX: $(numfmt --to=iec $total_rx 2>/dev/null || echo $total_rx) bytes"
            echo "  📤 OpenVPN TX: $(numfmt --to=iec $total_tx 2>/dev/null || echo $total_tx) bytes"
        fi
        
        # WireGuard
        if systemctl is-active --quiet wg-quick@$WG_INTERFACE; then
            wg show $WG_INTERFACE transfer | while read peer rx tx; do
                echo "  📊 WireGuard peer: RX=$(numfmt --to=iec $rx 2>/dev/null || echo $rx), TX=$(numfmt --to=iec $tx 2>/dev/null || echo $tx)"
            done
        fi
    fi
}

# Monitor de logs
monitor_logs() {
    print_header "📋 Monitor de Logs VPN"
    
    echo "Monitorando logs em tempo real (Ctrl+C para parar)..."
    echo
    
    # Monitorar logs do OpenVPN e WireGuard
    tail -f /var/log/openvpn/openvpn.log /var/log/messages 2>/dev/null | while read line; do
        if [[ "$line" =~ "openvpn" ]] || [[ "$line" =~ "wireguard" ]]; then
            local timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
            echo "$(date '+%H:%M:%S') VPN: $line"
        fi
    done
}

# Troubleshooting
troubleshoot_vpn() {
    print_header "🔧 Troubleshooting VPN"
    
    echo "Escolha o tipo de problema:"
    echo "1. Cliente não consegue conectar"
    echo "2. Conecta mas não há internet"
    echo "3. Velocidade lenta"
    echo "4. Desconexões frequentes"
    echo "5. Verificação geral"
    echo "0. Voltar"
    echo
    
    read -p "Escolha uma opção: " trouble_choice
    
    case $trouble_choice in
        1)
            print_info "Diagnosticando problemas de conexão..."
            
            # Verificar se serviços estão rodando
            if systemctl is-active --quiet openvpn-server@server; then
                print_success "OpenVPN está rodando"
            else
                print_error "OpenVPN não está rodando"
                print_info "Tente: systemctl start openvpn-server@server"
            fi
            
            # Verificar firewall
            if firewall-cmd --list-ports | grep -q "$VPN_PORT_OPENVPN"; then
                print_success "Porta OpenVPN liberada no firewall"
            else
                print_error "Porta OpenVPN não está liberada"
                print_info "Execute: firewall-cmd --permanent --add-port=$VPN_PORT_OPENVPN/udp"
            fi
            
            # Verificar certificados
            if [ -f /etc/openvpn/server/server.crt ]; then
                local cert_expiry=$(openssl x509 -in /etc/openvpn/server/server.crt -noout -enddate | cut -d'=' -f2)
                print_info "Certificado expira em: $cert_expiry"
            fi
            ;;
            
        2)
            print_info "Verificando configuração de roteamento..."
            
            # Verificar IP forwarding
            local ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
            if [ "$ip_forward" = "1" ]; then
                print_success "IP forwarding está habilitado"
            else
                print_error "IP forwarding não está habilitado"
                print_info "Execute: echo 1 > /proc/sys/net/ipv4/ip_forward"
            fi
            
            # Verificar NAT
            if iptables -t nat -L POSTROUTING | grep -q "MASQUERADE"; then
                print_success "NAT configurado"
            else
                print_warning "NAT pode não estar configurado"
            fi
            ;;
            
        3)
            print_info "Analisando performance..."
            
            # Verificar compressão
            if grep -q "compress" /etc/openvpn/server/server.conf; then
                print_success "Compressão habilitada"
            else
                print_info "Compressão não habilitada (pode melhorar velocidade)"
            fi
            
            # Verificar cifra
            local cipher=$(grep "cipher" /etc/openvpn/server/server.conf | awk '{print $2}')
            echo "  🔐 Cifra atual: $cipher"
            ;;
            
        4)
            print_info "Verificando estabilidade da conexão..."
            
            # Verificar logs para desconexões
            local disconnects=$(grep -c "SIGTERM\|restart" /var/log/openvpn/openvpn.log 2>/dev/null)
            echo "  📊 Reinicializações detectadas: $disconnects"
            
            # Verificar keepalive
            if grep -q "keepalive" /etc/openvpn/server/server.conf; then
                print_success "Keepalive configurado"
            else
                print_warning "Keepalive não configurado"
            fi
            ;;
            
        5)
            print_info "Executando verificação geral..."
            show_vpn_status
            ;;
    esac
}

# Backup de configurações
backup_vpn_config() {
    print_header "💾 Backup das Configurações VPN"
    
    local backup_dir="/var/backups/vpn-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup OpenVPN
    if [ -d /etc/openvpn ]; then
        cp -r /etc/openvpn "$backup_dir/"
        print_success "Configurações OpenVPN copiadas"
    fi
    
    # Backup WireGuard
    if [ -d /etc/wireguard ]; then
        cp -r /etc/wireguard "$backup_dir/"
        print_success "Configurações WireGuard copiadas"
    fi
    
    # Backup certificados
    if [ -d "$VPN_BASE_DIR" ]; then
        cp -r "$VPN_BASE_DIR" "$backup_dir/"
        print_success "Certificados e chaves copiados"
    fi
    
    # Criar tarball comprimido
    cd /var/backups
    tar -czf "vpn-backup-$(date +%Y%m%d_%H%M%S).tar.gz" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    print_success "Backup criado: /var/backups/vpn-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    log_action "VPN configuration backup created"
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    VPN Setup Manager                          ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔧 Setup inicial                                          ║"
    echo "║  2. 📦 Instalar dependências                                  ║"
    echo "║  3. 🔐 Configurar OpenVPN                                     ║"
    echo "║  4. ⚡ Configurar WireGuard                                   ║"
    echo "║  5. 👤 Gerar cliente OpenVPN                                  ║"
    echo "║  6. 👤 Gerar cliente WireGuard                                ║"
    echo "║  7. 📊 Status da VPN                                          ║"
    echo "║  8. 📋 Monitor de logs                                        ║"
    echo "║  9. 🔧 Troubleshooting                                        ║"
    echo "║  10. 💾 Backup configurações                                  ║"
    echo "║  11. ⚙️ Configurações                                         ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_vpn() {
    print_header "⚙️ Configurações VPN"
    echo
    
    print_info "Configurações atuais:"
    echo "  • IP externo: $SERVER_EXTERNAL_IP"
    echo "  • Rede VPN: $VPN_NETWORK"
    echo "  • Porta OpenVPN: $VPN_PORT_OPENVPN"
    echo "  • Porta WireGuard: $VPN_PORT_WIREGUARD"
    echo
    
    read -p "Deseja editar as configurações? (s/N): " edit_config
    if [[ $edit_config =~ ^[SsYy]$ ]]; then
        ${EDITOR:-nano} "$CONFIG_FILE"
        source "$CONFIG_FILE"
        print_success "Configurações recarregadas"
    fi
}

# Função principal
main() {
    check_root
    create_config
    
    # Criar diretórios necessários
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$VPN_BASE_DIR"
    mkdir -p "$CLIENT_CONFIG_DIR"
    
    case "${1:-}" in
        "setup")
            initial_setup
            ;;
        "install")
            install_dependencies
            ;;
        "openvpn")
            setup_openvpn
            ;;
        "wireguard")
            setup_wireguard
            ;;
        "client-openvpn")
            generate_openvpn_client "${2:-$DEFAULT_CLIENT_NAME}"
            ;;
        "client-wireguard")
            generate_wireguard_client "${2:-$DEFAULT_CLIENT_NAME}" "${3:-10.8.0.2}"
            ;;
        "status")
            show_vpn_status
            ;;
        "backup")
            backup_vpn_config
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-11): " choice
                
                case $choice in
                    1) initial_setup ;;
                    2) install_dependencies ;;
                    3) setup_openvpn ;;
                    4) setup_wireguard ;;
                    5)
                        read -p "Nome do cliente OpenVPN: " client_name
                        generate_openvpn_client "${client_name:-$DEFAULT_CLIENT_NAME}"
                        ;;
                    6)
                        read -p "Nome do cliente WireGuard: " client_name
                        read -p "IP do cliente (ex: 10.8.0.3): " client_ip
                        generate_wireguard_client "${client_name:-$DEFAULT_CLIENT_NAME}" "${client_ip:-10.8.0.2}"
                        ;;
                    7) show_vpn_status ;;
                    8) monitor_logs ;;
                    9) troubleshoot_vpn ;;
                    10) backup_vpn_config ;;
                    11) configure_vpn ;;
                    0)
                        print_success "Até logo!"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        ;;
                esac
                
                if [ "$choice" != "8" ]; then
                    echo
                    read -p "Pressione Enter para continuar..."
                fi
            done
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi