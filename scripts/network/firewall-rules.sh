#!/bin/bash

# =============================================================================
# Gerenciador de Regras de Firewall para Rocky Linux 10
# =============================================================================
# Descrição: Sistema completo de gerenciamento de firewall com firewalld
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
CONFIG_FILE="/etc/firewall-rules.conf"
LOG_FILE="/var/log/firewall-rules.log"
BACKUP_DIR="/var/backups/firewall"

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
# Configurações do Firewall Manager

# Configurações básicas
DEFAULT_ZONE="public"
ENABLE_LOGGING=true
LOG_DENIED_PACKETS=true
REJECT_ICMP=false

# Serviços permitidos por padrão
DEFAULT_SERVICES="ssh"
WEB_SERVICES="http,https"
DATABASE_SERVICES="mysql,postgresql"
EMAIL_SERVICES="smtp,pop3,imap"

# Portas customizadas
CUSTOM_TCP_PORTS=""
CUSTOM_UDP_PORTS=""

# Configurações de segurança
ENABLE_FAIL2BAN_INTEGRATION=true
BLOCK_COMMON_ATTACKS=true
ENABLE_PORT_KNOCKING=false
PORT_KNOCK_SEQUENCE="7000,8000,9000"

# Listas de IPs
WHITELIST_IPS=""
BLACKLIST_IPS=""
TRUSTED_NETWORKS="192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"

# Configurações avançadas
ENABLE_RICH_RULES=true
RATE_LIMITING=true
MAX_CONNECTIONS_PER_IP=20
ENABLE_GEO_BLOCKING=false
BLOCKED_COUNTRIES=""

# Backup e restore
AUTO_BACKUP=true
BACKUP_RETENTION_DAYS=30
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Verificar se firewalld está instalado
check_firewalld() {
    if ! command -v firewall-cmd &> /dev/null; then
        print_warning "Firewalld não está instalado. Instalando..."
        dnf install -y firewalld
        systemctl enable --now firewalld
    fi
    
    if ! systemctl is-active --quiet firewalld; then
        print_info "Iniciando firewalld..."
        systemctl start firewalld
    fi
}

# Backup das configurações atuais
backup_config() {
    if [ "$AUTO_BACKUP" = "true" ]; then
        local backup_timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="$BACKUP_DIR/firewall-backup-$backup_timestamp"
        
        mkdir -p "$backup_path"
        
        # Backup das configurações do firewalld
        cp -r /etc/firewalld/* "$backup_path/" 2>/dev/null
        
        # Salvar configuração atual em formato legível
        firewall-cmd --list-all > "$backup_path/current-config.txt"
        firewall-cmd --list-all-zones > "$backup_path/all-zones.txt"
        
        print_success "Backup criado em: $backup_path"
        log_action "Backup das configurações de firewall criado: $backup_path"
        
        # Limpar backups antigos
        find "$BACKUP_DIR" -name "firewall-backup-*" -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null
    fi
}

# Status do firewall
show_status() {
    print_header "🔥 Status do Firewall"
    
    # Status básico
    echo "🟢 Estado do firewalld:"
    if systemctl is-active --quiet firewalld; then
        print_success "Firewalld está ativo"
    else
        print_error "Firewalld não está ativo"
        return 1
    fi
    
    # Zona padrão
    local default_zone=$(firewall-cmd --get-default-zone)
    echo "  • Zona padrão: $default_zone"
    
    # Zonas ativas
    echo "  • Zonas ativas:"
    firewall-cmd --get-active-zones | while read zone_line; do
        if [[ "$zone_line" =~ ^[a-z] ]]; then
            echo "    - $zone_line"
        else
            echo "      $zone_line"
        fi
    done
    
    echo
    
    # Configuração da zona padrão
    print_info "Configuração da zona $default_zone:"
    firewall-cmd --zone="$default_zone" --list-all | while read line; do
        echo "  $line"
    done
    
    echo
    
    # Estatísticas
    print_info "Estatísticas:"
    local total_rules=$(firewall-cmd --list-all | grep -c "ports\|services\|rich rules")
    local active_services=$(firewall-cmd --list-services | wc -w)
    local active_ports=$(firewall-cmd --list-ports | wc -w)
    
    echo "  • Total de regras: $total_rules"
    echo "  • Serviços ativos: $active_services"
    echo "  • Portas abertas: $active_ports"
}

# Configurar serviços básicos
setup_basic_services() {
    print_header "⚙️ Configurando Serviços Básicos"
    
    backup_config
    
    # Remover serviços desnecessários
    local current_services=$(firewall-cmd --list-services)
    for service in $current_services; do
        if [[ ! "$DEFAULT_SERVICES" =~ $service ]]; then
            firewall-cmd --permanent --remove-service="$service"
            print_info "Serviço $service removido"
        fi
    done
    
    # Adicionar serviços padrão
    IFS=',' read -ra SERVICES <<< "$DEFAULT_SERVICES"
    for service in "${SERVICES[@]}"; do
        if firewall-cmd --permanent --add-service="$service"; then
            print_success "Serviço $service adicionado"
        else
            print_warning "Falha ao adicionar serviço $service"
        fi
    done
    
    # Aplicar configurações
    firewall-cmd --reload
    
    log_action "Serviços básicos configurados: $DEFAULT_SERVICES"
}

# Configurar serviços web
setup_web_services() {
    print_header "🌐 Configurando Serviços Web"
    
    read -p "Deseja configurar serviços web (HTTP/HTTPS)? (s/N): " confirm
    if [[ ! $confirm =~ ^[SsYy]$ ]]; then
        return 0
    fi
    
    backup_config
    
    IFS=',' read -ra SERVICES <<< "$WEB_SERVICES"
    for service in "${SERVICES[@]}"; do
        firewall-cmd --permanent --add-service="$service"
        print_success "Serviço web $service adicionado"
    done
    
    # Configurar rate limiting para HTTP
    if [ "$RATE_LIMITING" = "true" ]; then
        local rate_rule="rule family='ipv4' service name='http' accept limit value='$MAX_CONNECTIONS_PER_IP/m'"
        firewall-cmd --permanent --add-rich-rule="$rate_rule"
        print_info "Rate limiting configurado para HTTP"
    fi
    
    firewall-cmd --reload
    log_action "Serviços web configurados: $WEB_SERVICES"
}

# Configurar portas customizadas
setup_custom_ports() {
    print_header "🔧 Configurando Portas Customizadas"
    
    echo "Portas TCP atuais: $(firewall-cmd --list-ports | grep tcp || echo 'Nenhuma')"
    echo "Portas UDP atuais: $(firewall-cmd --list-ports | grep udp || echo 'Nenhuma')"
    echo
    
    read -p "Deseja adicionar portas TCP? (formato: 8080,9090 ou deixe vazio): " tcp_ports
    read -p "Deseja adicionar portas UDP? (formato: 1194,5353 ou deixe vazio): " udp_ports
    
    backup_config
    
    # Processar portas TCP
    if [ -n "$tcp_ports" ]; then
        IFS=',' read -ra PORTS <<< "$tcp_ports"
        for port in "${PORTS[@]}"; do
            if firewall-cmd --permanent --add-port="${port}/tcp"; then
                print_success "Porta TCP $port adicionada"
            else
                print_error "Falha ao adicionar porta TCP $port"
            fi
        done
    fi
    
    # Processar portas UDP
    if [ -n "$udp_ports" ]; then
        IFS=',' read -ra PORTS <<< "$udp_ports"
        for port in "${PORTS[@]}"; do
            if firewall-cmd --permanent --add-port="${port}/udp"; then
                print_success "Porta UDP $port adicionada"
            else
                print_error "Falha ao adicionar porta UDP $port"
            fi
        done
    fi
    
    firewall-cmd --reload
    log_action "Portas customizadas configuradas - TCP: $tcp_ports, UDP: $udp_ports"
}

# Gerenciar listas de IPs
manage_ip_lists() {
    print_header "📋 Gerenciando Listas de IPs"
    
    echo "1. Adicionar IP à whitelist"
    echo "2. Adicionar IP à blacklist"
    echo "3. Remover IP da whitelist"
    echo "4. Remover IP da blacklist"
    echo "5. Mostrar listas atuais"
    echo "0. Voltar"
    echo
    
    read -p "Escolha uma opção: " choice
    
    case $choice in
        1)
            read -p "Digite o IP ou rede para whitelist (ex: 192.168.1.100 ou 10.0.0.0/24): " ip
            if [ -n "$ip" ]; then
                backup_config
                firewall-cmd --permanent --add-source="$ip"
                firewall-cmd --reload
                print_success "IP $ip adicionado à whitelist"
                log_action "IP $ip adicionado à whitelist"
            fi
            ;;
        2)
            read -p "Digite o IP ou rede para blacklist: " ip
            if [ -n "$ip" ]; then
                backup_config
                firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' reject"
                firewall-cmd --reload
                print_success "IP $ip adicionado à blacklist"
                log_action "IP $ip adicionado à blacklist"
            fi
            ;;
        3)
            read -p "Digite o IP para remover da whitelist: " ip
            if [ -n "$ip" ]; then
                firewall-cmd --permanent --remove-source="$ip"
                firewall-cmd --reload
                print_success "IP $ip removido da whitelist"
            fi
            ;;
        4)
            read -p "Digite o IP para remover da blacklist: " ip
            if [ -n "$ip" ]; then
                firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' reject"
                firewall-cmd --reload
                print_success "IP $ip removido da blacklist"
            fi
            ;;
        5)
            echo
            print_info "Fontes permitidas (whitelist):"
            firewall-cmd --list-sources | tr ' ' '\n' | while read source; do
                [ -n "$source" ] && echo "  • $source"
            done
            
            echo
            print_info "Rich rules (inclui blacklist):"
            firewall-cmd --list-rich-rules | while read rule; do
                echo "  • $rule"
            done
            ;;
    esac
}

# Configurar proteções avançadas
setup_advanced_protection() {
    print_header "🛡️ Configurando Proteções Avançadas"
    
    if [ "$BLOCK_COMMON_ATTACKS" != "true" ]; then
        print_info "Proteções avançadas desabilitadas na configuração"
        return 0
    fi
    
    backup_config
    
    print_info "Configurando proteções contra ataques comuns..."
    
    # Bloquear ping flood
    firewall-cmd --permanent --add-rich-rule="rule protocol value='icmp' accept limit value='1/m'"
    print_success "Proteção contra ping flood configurada"
    
    # Limitar conexões SSH
    firewall-cmd --permanent --add-rich-rule="rule service name='ssh' accept limit value='3/m'"
    print_success "Limite de conexões SSH configurado"
    
    # Bloquear scans de porta comuns
    local common_scan_ports=(23 135 139 445 1433 1521 3389)
    for port in "${common_scan_ports[@]}"; do
        firewall-cmd --permanent --add-rich-rule="rule port port='$port' protocol='tcp' reject"
    done
    print_success "Bloqueio de portas de scan comum configurado"
    
    # Configurar logging
    if [ "$ENABLE_LOGGING" = "true" ]; then
        firewall-cmd --set-log-denied=all
        print_success "Logging de pacotes negados habilitado"
    fi
    
    firewall-cmd --reload
    log_action "Proteções avançadas configuradas"
}

# Port knocking
setup_port_knocking() {
    if [ "$ENABLE_PORT_KNOCKING" != "true" ]; then
        return 0
    fi
    
    print_header "🔑 Configurando Port Knocking"
    
    if ! command -v knockd &> /dev/null; then
        print_info "Instalando knock..."
        dnf install -y knock-server
    fi
    
    IFS=',' read -ra PORTS <<< "$PORT_KNOCK_SEQUENCE"
    
    cat > /etc/knockd.conf << EOF
[options]
    UseSyslog

[openSSH]
    sequence    = ${PORTS[0]},${PORTS[1]},${PORTS[2]}
    seq_timeout = 5
    command     = /bin/firewall-cmd --add-rich-rule="rule family='ipv4' source address='%IP%' service name='ssh' accept"
    tcpflags    = syn

[closeSSH]
    sequence    = ${PORTS[2]},${PORTS[1]},${PORTS[0]}
    seq_timeout = 5
    command     = /bin/firewall-cmd --remove-rich-rule="rule family='ipv4' source address='%IP%' service name='ssh' accept"
    tcpflags    = syn
EOF

    # Remover SSH padrão e iniciar knockd
    firewall-cmd --permanent --remove-service=ssh
    systemctl enable --now knockd
    
    print_success "Port knocking configurado"
    print_info "Sequência: ${PORTS[*]}"
    print_warning "ATENÇÃO: SSH agora requer port knocking!"
    
    log_action "Port knocking configurado com sequência: ${PORTS[*]}"
}

# Configurar zonas personalizadas
setup_custom_zones() {
    print_header "🎯 Configurando Zonas Personalizadas"
    
    # Zona DMZ
    read -p "Deseja criar uma zona DMZ? (s/N): " create_dmz
    if [[ $create_dmz =~ ^[SsYy]$ ]]; then
        firewall-cmd --permanent --new-zone=dmz 2>/dev/null || true
        firewall-cmd --permanent --zone=dmz --add-service=http
        firewall-cmd --permanent --zone=dmz --add-service=https
        firewall-cmd --permanent --zone=dmz --set-target=ACCEPT
        print_success "Zona DMZ configurada"
    fi
    
    # Zona para administração
    read -p "Deseja criar uma zona de administração? (s/N): " create_admin
    if [[ $create_admin =~ ^[SsYy]$ ]]; then
        firewall-cmd --permanent --new-zone=admin 2>/dev/null || true
        firewall-cmd --permanent --zone=admin --add-service=ssh
        firewall-cmd --permanent --zone=admin --add-service=cockpit
        firewall-cmd --permanent --zone=admin --set-target=ACCEPT
        
        read -p "Digite a rede de administração (ex: 192.168.1.0/24): " admin_network
        if [ -n "$admin_network" ]; then
            firewall-cmd --permanent --zone=admin --add-source="$admin_network"
        fi
        
        print_success "Zona de administração configurada"
    fi
    
    firewall-cmd --reload
}

# Monitorar conexões
monitor_connections() {
    print_header "👁️ Monitorando Conexões"
    
    echo "Pressione Ctrl+C para parar o monitoramento"
    echo
    
    while true; do
        clear
        print_info "=== Monitoramento de Conexões - $(date) ==="
        echo
        
        # Conexões ativas
        echo "🔗 Conexões TCP ativas:"
        ss -tn state established | head -10
        echo
        
        # Top IPs conectados
        echo "📊 Top IPs conectados:"
        ss -tn state established | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -5
        echo
        
        # Conexões por porta
        echo "🔌 Conexões por porta local:"
        ss -tn state established | awk '{print $4}' | cut -d':' -f2 | sort | uniq -c | sort -nr | head -5
        echo
        
        # Logs recentes do firewall
        echo "📋 Últimos logs do firewall:"
        journalctl -u firewalld --since "1 minute ago" --no-pager | tail -3
        
        sleep 5
    done
}

# Testar regras
test_rules() {
    print_header "🧪 Testando Regras do Firewall"
    
    echo "Escolha o tipo de teste:"
    echo "1. Testar conectividade de porta"
    echo "2. Testar regra específica"
    echo "3. Verificar logs de bloqueio"
    echo "4. Simular ataque"
    echo
    
    read -p "Escolha uma opção: " test_choice
    
    case $test_choice in
        1)
            read -p "Digite a porta para testar (ex: 80): " test_port
            read -p "Digite o IP de origem (deixe vazio para local): " test_ip
            
            if [ -z "$test_ip" ]; then
                test_ip="127.0.0.1"
            fi
            
            print_info "Testando conectividade $test_ip:$test_port..."
            
            if timeout 5 bash -c "echo >/dev/tcp/$test_ip/$test_port" 2>/dev/null; then
                print_success "Porta $test_port está acessível"
            else
                print_error "Porta $test_port não está acessível ou bloqueada"
            fi
            ;;
        2)
            read -p "Digite o IP para testar: " test_ip
            read -p "Digite a porta para testar: " test_port
            
            # Verificar se há regra para este IP/porta
            if firewall-cmd --query-rich-rule="rule family='ipv4' source address='$test_ip' port port='$test_port' protocol='tcp' accept"; then
                print_success "Regra específica permite $test_ip:$test_port"
            else
                print_info "Verificando regras gerais..."
                # Verificar outras regras
                firewall-cmd --list-all | grep -E "ports|services" | while read line; do
                    echo "  $line"
                done
            fi
            ;;
        3)
            print_info "Últimos bloqueios pelo firewall:"
            dmesg | grep -i "refused\|blocked\|denied" | tail -10 | while read line; do
                echo "  $(date -d "$(echo "$line" | awk '{print $1,$2,$3}')" '+%H:%M:%S'): $(echo "$line" | cut -d']' -f2-)"
            done
            ;;
        4)
            print_warning "Simulando tentativas de conexão suspeitas..."
            
            # Simular scan de portas
            for port in 21 23 135 139 445 1433 3389; do
                timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null
                if [ $? -eq 0 ]; then
                    print_warning "Porta $port está aberta (pode ser um risco)"
                fi
            done
            
            print_info "Verificando logs após simulação..."
            sleep 2
            journalctl -u firewalld --since "30 seconds ago" --no-pager | tail -5
            ;;
    esac
}

# Restaurar configurações
restore_config() {
    print_header "🔄 Restaurar Configurações"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Nenhum backup encontrado"
        return 1
    fi
    
    echo "Backups disponíveis:"
    ls -la "$BACKUP_DIR" | grep firewall-backup | awk '{print $9, $6, $7, $8}'
    echo
    
    read -p "Digite o nome do backup para restaurar (firewall-backup-YYYYMMDD_HHMMSS): " backup_name
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup não encontrado: $backup_path"
        return 1
    fi
    
    print_warning "Esta operação irá sobrescrever as configurações atuais!"
    read -p "Tem certeza? (s/N): " confirm
    
    if [[ $confirm =~ ^[SsYy]$ ]]; then
        # Criar backup da configuração atual antes de restaurar
        backup_config
        
        # Parar firewalld
        systemctl stop firewalld
        
        # Restaurar configurações
        cp -r "$backup_path"/* /etc/firewalld/ 2>/dev/null
        
        # Reiniciar firewalld
        systemctl start firewalld
        
        print_success "Configurações restauradas de $backup_name"
        log_action "Configurações restauradas de $backup_name"
    else
        print_info "Operação cancelada"
    fi
}

# Relatório de segurança
security_report() {
    print_header "📊 Relatório de Segurança do Firewall"
    
    local report_file="/var/log/firewall-security-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Firewall Security Report - $(date)"
        echo "=========================================="
        echo "Hostname: $(hostname)"
        echo "Default Zone: $(firewall-cmd --get-default-zone)"
        echo
        
        echo "=== ACTIVE CONFIGURATION ==="
        firewall-cmd --list-all
        echo
        
        echo "=== RICH RULES ==="
        firewall-cmd --list-rich-rules
        echo
        
        echo "=== RECENT DENIALS ==="
        journalctl -u firewalld --since "24 hours ago" | grep -i "denied\|refused\|blocked" | tail -10
        echo
        
        echo "=== CONNECTIONS SUMMARY ==="
        echo "Active TCP connections: $(ss -tn state established | wc -l)"
        echo "Listening ports: $(ss -tln | wc -l)"
        echo
        
        echo "=== TOP CONNECTING IPs ==="
        ss -tn state established | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -10
        echo
        
        echo "=== SECURITY RECOMMENDATIONS ==="
        # Verificações de segurança
        if firewall-cmd --list-services | grep -q "ssh"; then
            echo "- SSH is open (consider changing default port)"
        fi
        
        if [ "$(firewall-cmd --list-ports | wc -w)" -gt 10 ]; then
            echo "- Many custom ports open (review if all are necessary)"
        fi
        
        if [ "$(firewall-cmd --list-rich-rules | wc -l)" -eq 0 ]; then
            echo "- No advanced rules configured (consider rate limiting)"
        fi
        
    } > "$report_file"
    
    print_success "Relatório salvo em: $report_file"
    
    # Mostrar resumo
    echo
    print_info "Resumo de segurança:"
    echo "  • Zona padrão: $(firewall-cmd --get-default-zone)"
    echo "  • Serviços ativos: $(firewall-cmd --list-services | wc -w)"
    echo "  • Portas customizadas: $(firewall-cmd --list-ports | wc -w)"
    echo "  • Rich rules: $(firewall-cmd --list-rich-rules | wc -l)"
    echo "  • Conexões ativas: $(ss -tn state established | wc -l)"
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                   Firewall Rules Manager                      ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔥 Status do firewall                                     ║"
    echo "║  2. ⚙️ Configurar serviços básicos                            ║"
    echo "║  3. 🌐 Configurar serviços web                                ║"
    echo "║  4. 🔧 Configurar portas customizadas                        ║"
    echo "║  5. 📋 Gerenciar listas de IPs                               ║"
    echo "║  6. 🛡️ Proteções avançadas                                    ║"
    echo "║  7. 🎯 Configurar zonas personalizadas                       ║"
    echo "║  8. 👁️ Monitorar conexões                                    ║"
    echo "║  9. 🧪 Testar regras                                         ║"
    echo "║  10. 🔄 Restaurar configurações                               ║"
    echo "║  11. 📊 Relatório de segurança                               ║"
    echo "║  12. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_firewall() {
    print_header "⚙️ Configurações do Firewall Manager"
    echo
    
    print_info "Configurações atuais:"
    echo "  • Zona padrão: $DEFAULT_ZONE"
    echo "  • Logging: $ENABLE_LOGGING"
    echo "  • Backup automático: $AUTO_BACKUP"
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
    check_firewalld
    
    # Criar diretórios necessários
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "${1:-}" in
        "status")
            show_status
            ;;
        "basic")
            setup_basic_services
            ;;
        "web")
            setup_web_services
            ;;
        "advanced")
            setup_advanced_protection
            ;;
        "monitor")
            monitor_connections
            ;;
        "report")
            security_report
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-12): " choice
                
                case $choice in
                    1) show_status ;;
                    2) setup_basic_services ;;
                    3) setup_web_services ;;
                    4) setup_custom_ports ;;
                    5) manage_ip_lists ;;
                    6) setup_advanced_protection ;;
                    7) setup_custom_zones ;;
                    8) monitor_connections ;;
                    9) test_rules ;;
                    10) restore_config ;;
                    11) security_report ;;
                    12) configure_firewall ;;
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