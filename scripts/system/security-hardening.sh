#!/bin/bash

# =============================================================================
# Sistema de Endurecimento de Segurança para Rocky Linux 10
# =============================================================================
# Descrição: Script completo para hardening e segurança do sistema
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
CONFIG_FILE="/etc/security-hardening.conf"
LOG_FILE="/var/log/security-hardening.log"
BACKUP_DIR="/var/backups/security-$(date +%Y%m%d_%H%M%S)"

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
# Configurações do Security Hardening

# Configurações SSH
SSH_PORT=2222
DISABLE_ROOT_SSH=true
SSH_PROTOCOL=2
MAX_AUTH_TRIES=3
CLIENT_ALIVE_INTERVAL=300

# Configurações de firewall
ENABLE_FIREWALL=true
DEFAULT_SSH_ALLOW=true
HTTP_PORTS="80,443"
CUSTOM_PORTS=""

# Configurações de usuário
PASSWORD_MIN_LENGTH=12
PASSWORD_MAX_AGE=90
LOGIN_TIMEOUT=60
MAX_LOGIN_RETRIES=3

# Configurações de kernel
DISABLE_UNCOMMON_PROTOCOLS=true
ENABLE_SYN_COOKIES=true
DISABLE_ICMP_REDIRECTS=true
ENABLE_RP_FILTER=true

# Configurações de auditoria
ENABLE_AUDITD=true
AUDIT_LOGS=/var/log/audit/audit.log
ROTATE_AUDIT_LOGS=true

# Configurações de sistema
DISABLE_UNNECESSARY_SERVICES=true
SECURE_SHARED_MEMORY=true
DISABLE_USB_STORAGE=false
REMOVE_UNUSED_PACKAGES=true

# Antivirus e malware
INSTALL_CLAMAV=true
INSTALL_RKHUNTER=true
INSTALL_CHKROOTKIT=true
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Backup de arquivos importantes
create_backup() {
    print_info "Criando backup de configurações..."
    mkdir -p "$BACKUP_DIR"
    
    # Arquivos importantes para backup
    local files_to_backup=(
        "/etc/ssh/sshd_config"
        "/etc/sudoers"
        "/etc/passwd"
        "/etc/shadow"
        "/etc/group"
        "/etc/fstab"
        "/etc/sysctl.conf"
        "/etc/security/limits.conf"
        "/etc/pam.d/"
        "/etc/login.defs"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ]; then
            cp -r "$file" "$BACKUP_DIR/" 2>/dev/null
        fi
    done
    
    print_success "Backup criado em: $BACKUP_DIR"
    log_action "Backup de configurações criado em $BACKUP_DIR"
}

# Hardening SSH
harden_ssh() {
    print_header "🔐 Configurando SSH"
    
    local ssh_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$ssh_config" ]; then
        print_error "Arquivo de configuração SSH não encontrado"
        return 1
    fi
    
    # Backup da configuração atual
    cp "$ssh_config" "${ssh_config}.backup.$(date +%Y%m%d)"
    
    print_info "Aplicando configurações de segurança SSH..."
    
    # Configurações SSH seguras
    cat > "${ssh_config}.new" << EOF
# SSH Hardened Configuration
Port $SSH_PORT
Protocol $SSH_PROTOCOL

# Autenticação
PermitRootLogin $([ "$DISABLE_ROOT_SSH" = "true" ] && echo "no" || echo "yes")
MaxAuthTries $MAX_AUTH_TRIES
PasswordAuthentication yes
PermitEmptyPasswords no
PubkeyAuthentication yes

# Configurações de sessão
ClientAliveInterval $CLIENT_ALIVE_INTERVAL
ClientAliveCountMax 3
MaxStartups 2

# Logging
LogLevel VERBOSE
SyslogFacility AUTH

# Configurações de rede
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no

# Usuários e grupos permitidos
# AllowUsers user1 user2
# DenyUsers root

# Banner
Banner /etc/ssh/banner

# Configurações de criptografia
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Configurações de tempo
LoginGraceTime 20
EOF

    mv "${ssh_config}.new" "$ssh_config"
    
    # Criar banner SSH
    cat > /etc/ssh/banner << 'EOF'
*******************************************************************
*                     ACESSO AUTORIZADO APENAS                  *
*                                                                *
*   Esta é uma área restrita. O acesso não autorizado           *
*   é proibido e será monitorado e registrado.                 *
*                                                                *
*   Todos os acessos são auditados conforme a legislação       *
*   aplicável.                                                   *
*                                                                *
*******************************************************************
EOF

    # Testar configuração
    if sshd -t; then
        print_success "Configuração SSH aplicada"
        systemctl reload sshd
        log_action "SSH hardening aplicado - porta $SSH_PORT"
    else
        print_error "Erro na configuração SSH, restaurando backup"
        cp "${ssh_config}.backup.$(date +%Y%m%d)" "$ssh_config"
        return 1
    fi
}

# Configurar firewall
configure_firewall() {
    if [ "$ENABLE_FIREWALL" != "true" ]; then
        return 0
    fi
    
    print_header "🔥 Configurando Firewall"
    
    # Instalar firewalld se não estiver instalado
    if ! command -v firewall-cmd &> /dev/null; then
        print_info "Instalando firewalld..."
        dnf install -y firewalld
    fi
    
    # Iniciar e habilitar firewall
    systemctl enable --now firewalld
    
    # Configurar zona padrão
    firewall-cmd --set-default-zone=public
    
    # Remover serviços desnecessários
    firewall-cmd --permanent --remove-service=dhcpv6-client
    firewall-cmd --permanent --remove-service=cockpit
    
    # SSH customizado
    if [ "$DEFAULT_SSH_ALLOW" = "true" ]; then
        firewall-cmd --permanent --add-port="$SSH_PORT/tcp"
        print_info "SSH permitido na porta $SSH_PORT"
    fi
    
    # Portas HTTP/HTTPS
    if [ -n "$HTTP_PORTS" ]; then
        IFS=',' read -ra PORTS <<< "$HTTP_PORTS"
        for port in "${PORTS[@]}"; do
            firewall-cmd --permanent --add-port="$port/tcp"
            print_info "Porta $port/tcp adicionada"
        done
    fi
    
    # Portas customizadas
    if [ -n "$CUSTOM_PORTS" ]; then
        IFS=',' read -ra PORTS <<< "$CUSTOM_PORTS"
        for port in "${PORTS[@]}"; do
            firewall-cmd --permanent --add-port="$port"
            print_info "Porta customizada $port adicionada"
        done
    fi
    
    # Aplicar configurações
    firewall-cmd --reload
    
    print_success "Firewall configurado"
    log_action "Firewall configurado com regras personalizadas"
}

# Hardening do kernel
kernel_hardening() {
    print_header "🔧 Hardening do Kernel"
    
    # Backup da configuração atual
    cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)
    
    cat >> /etc/sysctl.conf << 'EOF'

# =============================================================================
# Security Hardening - Kernel Parameters
# =============================================================================

# Proteção contra IP Spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desabilitar redirecionamentos ICMP
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Desabilitar source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Proteger contra SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 3

# Ignorar pings ICMP
net.ipv4.icmp_echo_ignore_all = 1

# Log de pacotes suspeitos
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Desabilitar IPv6 se não usado
# net.ipv6.conf.all.disable_ipv6 = 1

# Proteção de memória
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2

# Proteção contra buffer overflow
kernel.exec-shield = 1
kernel.randomize_va_space = 2

# Configurações de rede adicionais
net.ipv4.ip_forward = 0
net.ipv4.tcp_timestamps = 0

# Proteção contra ataques de fragmentação
net.ipv4.ipfrag_high_thresh = 512000
net.ipv4.ipfrag_low_thresh = 446464
EOF

    # Aplicar configurações
    sysctl -p
    
    print_success "Parâmetros do kernel aplicados"
    log_action "Kernel hardening aplicado"
}

# Configurar auditoria
setup_auditd() {
    if [ "$ENABLE_AUDITD" != "true" ]; then
        return 0
    fi
    
    print_header "📋 Configurando Auditoria"
    
    # Instalar auditd
    if ! command -v auditctl &> /dev/null; then
        dnf install -y audit
    fi
    
    # Configurar regras de auditoria
    cat > /etc/audit/rules.d/security.rules << 'EOF'
# Security Audit Rules

# Deletar todas as regras existentes
-D

# Definir buffer size
-b 8192

# Falhas de autenticação
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins

# Modificações no sistema de usuários
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Modificações em configurações
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/sysctl.conf -p wa -k sysctl

# Acessos de root
-a exit,always -F arch=b64 -F euid=0 -S execve -k rootcmd
-a exit,always -F arch=b32 -F euid=0 -S execve -k rootcmd

# Modificações no kernel
-w /etc/sysctl.d/ -p wa -k kernel
-w /etc/modprobe.d/ -p wa -k kernel

# Comandos privilegiados
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=500 -F auid!=4294967295 -k privileged

# Travamento da configuração (deve ser a última linha)
-e 2
EOF

    # Reiniciar serviço
    systemctl enable --now auditd
    
    print_success "Sistema de auditoria configurado"
    log_action "Auditd configurado com regras de segurança"
}

# Configurar PAM
configure_pam() {
    print_header "🔒 Configurando PAM"
    
    # Configurar limites de tentativas de login
    if ! grep -q "pam_faillock" /etc/pam.d/system-auth; then
        # Backup
        cp /etc/pam.d/system-auth /etc/pam.d/system-auth.backup.$(date +%Y%m%d)
        
        # Adicionar faillock ao início
        sed -i '2i auth        required      pam_faillock.so preauth silent audit deny='"$MAX_LOGIN_RETRIES"' unlock_time=900' /etc/pam.d/system-auth
        sed -i '/^auth.*pam_unix.so/a auth        [default=die] pam_faillock.so authfail audit deny='"$MAX_LOGIN_RETRIES"' unlock_time=900' /etc/pam.d/system-auth
        sed -i '/^account.*pam_unix.so/i account     required      pam_faillock.so' /etc/pam.d/system-auth
    fi
    
    # Configurar política de senhas
    cat > /etc/security/pwquality.conf << EOF
# Configuração de qualidade de senhas
minlen = $PASSWORD_MIN_LENGTH
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 3
maxrepeat = 2
maxsequence = 2
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcing = 1
EOF

    print_success "PAM configurado para segurança"
    log_action "PAM configurado com políticas de senha seguras"
}

# Desabilitar serviços desnecessários
disable_services() {
    if [ "$DISABLE_UNNECESSARY_SERVICES" != "true" ]; then
        return 0
    fi
    
    print_header "🚫 Desabilitando Serviços Desnecessários"
    
    local unnecessary_services=(
        "rpcbind"
        "nfs-server"
        "telnet"
        "rsh"
        "rlogin"
        "vsftpd"
        "httpd"
        "nginx"
        "dovecot"
        "squid"
        "snmpd"
        "cups"
        "avahi-daemon"
        "bluetooth"
    )
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl disable --now "$service" 2>/dev/null
            print_info "Serviço $service desabilitado"
        fi
    done
    
    print_success "Serviços desnecessários desabilitados"
    log_action "Serviços desnecessários desabilitados"
}

# Instalar e configurar antivírus
install_antivirus() {
    if [ "$INSTALL_CLAMAV" = "true" ]; then
        print_header "🦠 Instalando ClamAV"
        
        dnf install -y clamav clamd clamav-update
        
        # Atualizar definições
        freshclam
        
        # Configurar scan automático
        cat > /etc/systemd/system/clamav-scan.service << 'EOF'
[Unit]
Description=ClamAV Scan
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/clamscan -r --bell -i /home /var/www /opt
User=clam
EOF

        cat > /etc/systemd/system/clamav-scan.timer << 'EOF'
[Unit]
Description=Run ClamAV scan daily
Requires=clamav-scan.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

        systemctl enable clamav-scan.timer
        systemctl start clamav-scan.timer
        
        print_success "ClamAV instalado e configurado"
    fi
}

# Instalar rootkit hunters
install_rootkit_detection() {
    if [ "$INSTALL_RKHUNTER" = "true" ]; then
        print_header "🔍 Instalando RKHunter"
        
        dnf install -y rkhunter
        
        # Configurar database inicial
        rkhunter --update
        rkhunter --propupd
        
        # Agendar verificações
        echo "0 3 * * * root /usr/bin/rkhunter --check --skip-keypress --report-warnings-only" >> /etc/crontab
        
        print_success "RKHunter instalado"
    fi
    
    if [ "$INSTALL_CHKROOTKIT" = "true" ]; then
        print_header "🔍 Instalando Chkrootkit"
        
        dnf install -y chkrootkit
        
        # Agendar verificações
        echo "0 4 * * * root /usr/sbin/chkrootkit" >> /etc/crontab
        
        print_success "Chkrootkit instalado"
    fi
}

# Configurar limites do sistema
configure_limits() {
    print_header "⚡ Configurando Limites do Sistema"
    
    cat >> /etc/security/limits.conf << 'EOF'

# Security hardening limits
* hard core 0
* soft nproc 65536
* hard nproc 65536
* soft nofile 65536
* hard nofile 65536

# Root limits
root soft nproc unlimited
root hard nproc unlimited
EOF

    print_success "Limites do sistema configurados"
    log_action "Limites de sistema configurados para segurança"
}

# Proteger diretórios importantes
protect_directories() {
    print_header "📁 Protegendo Diretórios"
    
    # Tornar /tmp noexec
    if [ "$SECURE_SHARED_MEMORY" = "true" ]; then
        if ! grep -q "tmpfs.*noexec" /etc/fstab; then
            echo "tmpfs /tmp tmpfs defaults,rw,nosuid,nodev,noexec,relatime 0 0" >> /etc/fstab
            print_info "/tmp configurado como noexec"
        fi
        
        if ! grep -q "tmpfs.*shm.*noexec" /etc/fstab; then
            echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
            print_info "/dev/shm protegido"
        fi
    fi
    
    # Proteger arquivos importantes
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 644 /etc/passwd
    chmod 644 /etc/group
    
    print_success "Diretórios e arquivos protegidos"
    log_action "Permissões de diretórios endurecidas"
}

# Configurar fail2ban
install_fail2ban() {
    print_header "🚨 Configurando Fail2Ban"
    
    # Instalar fail2ban
    if ! command -v fail2ban-client &> /dev/null; then
        dnf install -y fail2ban
    fi
    
    # Configuração personalizada
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = $MAX_LOGIN_RETRIES
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/secure
maxretry = $MAX_LOGIN_RETRIES

[nginx-http-auth]
enabled = false

[nginx-limit-req]
enabled = false
EOF

    systemctl enable --now fail2ban
    
    print_success "Fail2Ban configurado"
    log_action "Fail2Ban configurado para proteção contra ataques"
}

# Verificação de segurança
security_check() {
    print_header "🔍 Verificação de Segurança"
    echo
    
    # Verificar SSH
    print_info "SSH Status:"
    if systemctl is-active --quiet sshd; then
        local ssh_port=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
        print_success "SSH ativo na porta $ssh_port"
    else
        print_error "SSH não está ativo"
    fi
    
    # Verificar firewall
    print_info "Firewall Status:"
    if systemctl is-active --quiet firewalld; then
        print_success "Firewall ativo"
        firewall-cmd --list-all | grep -E "(services|ports)" | head -5
    else
        print_warning "Firewall não está ativo"
    fi
    
    # Verificar fail2ban
    print_info "Fail2Ban Status:"
    if systemctl is-active --quiet fail2ban; then
        print_success "Fail2Ban ativo"
        fail2ban-client status 2>/dev/null | grep "Jail list"
    else
        print_warning "Fail2Ban não está ativo"
    fi
    
    # Verificar auditd
    print_info "Auditd Status:"
    if systemctl is-active --quiet auditd; then
        print_success "Auditd ativo"
    else
        print_warning "Auditd não está ativo"
    fi
    
    echo
    print_info "Últimas tentativas de login falharam:"
    lastb | head -5 2>/dev/null || echo "Nenhuma falha de login registrada"
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                 Security Hardening                            ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔐 Hardening completo do sistema                          ║"
    echo "║  2. 🔑 Configurar SSH                                         ║"
    echo "║  3. 🔥 Configurar Firewall                                    ║"
    echo "║  4. 🔧 Hardening do Kernel                                    ║"
    echo "║  5. 📋 Configurar Auditoria                                   ║"
    echo "║  6. 🔒 Configurar PAM                                         ║"
    echo "║  7. 🚫 Desabilitar serviços                                   ║"
    echo "║  8. 🦠 Instalar Antivírus                                     ║"
    echo "║  9. 🚨 Configurar Fail2Ban                                    ║"
    echo "║  10. 🔍 Verificação de segurança                              ║"
    echo "║  11. ⚙️ Configurações                                         ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_security() {
    print_header "⚙️ Configurações de Segurança"
    echo
    
    print_info "Arquivo de configuração: $CONFIG_FILE"
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
    
    case "${1:-}" in
        "full")
            create_backup
            harden_ssh && configure_firewall && kernel_hardening && setup_auditd
            configure_pam && disable_services && install_fail2ban && configure_limits
            protect_directories && security_check
            ;;
        "ssh")
            create_backup && harden_ssh
            ;;
        "firewall")
            configure_firewall
            ;;
        "kernel")
            create_backup && kernel_hardening
            ;;
        "audit")
            setup_auditd
            ;;
        "check")
            security_check
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-11): " choice
                
                case $choice in
                    1)
                        create_backup
                        harden_ssh && configure_firewall && kernel_hardening && setup_auditd
                        configure_pam && disable_services && install_fail2ban && configure_limits
                        protect_directories
                        print_success "Hardening completo aplicado!"
                        ;;
                    2) create_backup && harden_ssh ;;
                    3) configure_firewall ;;
                    4) create_backup && kernel_hardening ;;
                    5) setup_auditd ;;
                    6) create_backup && configure_pam ;;
                    7) disable_services ;;
                    8) install_antivirus && install_rootkit_detection ;;
                    9) install_fail2ban ;;
                    10) security_check ;;
                    11) configure_security ;;
                    0)
                        print_success "Até logo!"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        ;;
                esac
                
                echo
                read -p "Pressione Enter para continuar..."
            done
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi