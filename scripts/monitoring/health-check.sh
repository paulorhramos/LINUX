#!/bin/bash

# =============================================================================
# Sistema de Health Check para Rocky Linux 10
# =============================================================================
# Descrição: Monitoramento completo da saúde do sistema
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
CONFIG_FILE="/etc/health-check.conf"
LOG_FILE="/var/log/health-check.log"
REPORT_FILE="/var/log/health-report-$(date +%Y%m%d_%H%M%S).txt"

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações do Health Check

# Limites de alerta
CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=95
MEMORY_WARNING_THRESHOLD=80
MEMORY_CRITICAL_THRESHOLD=90
DISK_WARNING_THRESHOLD=80
DISK_CRITICAL_THRESHOLD=90
LOAD_WARNING_THRESHOLD=4
LOAD_CRITICAL_THRESHOLD=8

# Configurações de rede
NETWORK_CHECK_HOSTS="8.8.8.8,1.1.1.1"
NETWORK_TIMEOUT=5
PORT_CHECK_ENABLED=true
CRITICAL_PORTS="22,80,443"

# Configurações de serviços
CRITICAL_SERVICES="sshd,systemd-resolved,firewalld"
OPTIONAL_SERVICES="httpd,nginx,mysql,postgresql"

# Configurações de temperatura
TEMP_WARNING_THRESHOLD=70
TEMP_CRITICAL_THRESHOLD=80
CHECK_TEMPERATURE=true

# Notificações
EMAIL_NOTIFICATIONS=false
EMAIL_ADDRESS=""
SLACK_WEBHOOK=""
DISCORD_WEBHOOK=""
SEND_CRITICAL_ONLY=true

# Configurações de log
LOG_RETENTION_DAYS=30
ENABLE_DETAILED_LOGGING=true
GENERATE_REPORTS=true
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Verificar CPU
check_cpu() {
    print_header "⚡ Verificando CPU"
    
    # Usage atual
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    cpu_usage=${cpu_usage%.*}  # Remover decimais
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    load_avg=${load_avg%.*}
    
    # Número de cores
    local cpu_cores=$(nproc)
    
    # Temperatura (se disponível)
    local temp="N/A"
    if [ "$CHECK_TEMPERATURE" = "true" ] && command -v sensors &> /dev/null; then
        temp=$(sensors 2>/dev/null | grep -E '(Core|Package).*°C' | head -1 | awk '{print $3}' | sed 's/[+°C]//g')
        if [ -z "$temp" ]; then
            temp="N/A"
        fi
    fi
    
    echo "  • Usage: ${cpu_usage}%"
    echo "  • Load Average: $load_avg (Cores: $cpu_cores)"
    echo "  • Temperature: ${temp}°C"
    
    # Avaliar status
    local cpu_status="OK"
    if [ "$cpu_usage" -gt "$CPU_CRITICAL_THRESHOLD" ]; then
        cpu_status="CRITICAL"
        print_error "CPU usage crítico: ${cpu_usage}%"
    elif [ "$cpu_usage" -gt "$CPU_WARNING_THRESHOLD" ]; then
        cpu_status="WARNING"
        print_warning "CPU usage alto: ${cpu_usage}%"
    else
        print_success "CPU usage normal: ${cpu_usage}%"
    fi
    
    # Verificar load
    if [ "$load_avg" -gt "$LOAD_CRITICAL_THRESHOLD" ]; then
        print_error "Load average crítico: $load_avg"
        cpu_status="CRITICAL"
    elif [ "$load_avg" -gt "$LOAD_WARNING_THRESHOLD" ]; then
        print_warning "Load average alto: $load_avg"
        [ "$cpu_status" = "OK" ] && cpu_status="WARNING"
    fi
    
    # Verificar temperatura
    if [ "$temp" != "N/A" ] && [ "$temp" -gt "$TEMP_CRITICAL_THRESHOLD" ]; then
        print_error "Temperatura crítica: ${temp}°C"
        cpu_status="CRITICAL"
    elif [ "$temp" != "N/A" ] && [ "$temp" -gt "$TEMP_WARNING_THRESHOLD" ]; then
        print_warning "Temperatura alta: ${temp}°C"
        [ "$cpu_status" = "OK" ] && cpu_status="WARNING"
    fi
    
    log_action "CPU Check: Usage=${cpu_usage}%, Load=${load_avg}, Temp=${temp}°C, Status=${cpu_status}"
    echo "CPU_STATUS=$cpu_status" >> /tmp/health-status.tmp
}

# Verificar memória
check_memory() {
    print_header "💾 Verificando Memória"
    
    local mem_info=$(free | awk 'NR==2')
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    local available=$(echo $mem_info | awk '{print $7}')
    local mem_usage=$((used * 100 / total))
    
    # Swap
    local swap_info=$(free | awk 'NR==3')
    local swap_total=$(echo $swap_info | awk '{print $2}')
    local swap_used=$(echo $swap_info | awk '{print $3}')
    local swap_usage=0
    
    if [ "$swap_total" -gt 0 ]; then
        swap_usage=$((swap_used * 100 / swap_total))
    fi
    
    echo "  • Memory Usage: ${mem_usage}% ($(($used/1024))MB/$(($total/1024))MB)"
    echo "  • Available: $(($available/1024))MB"
    echo "  • Swap Usage: ${swap_usage}% ($(($swap_used/1024))MB/$(($swap_total/1024))MB)"
    
    # Avaliar status
    local mem_status="OK"
    if [ "$mem_usage" -gt "$MEMORY_CRITICAL_THRESHOLD" ]; then
        mem_status="CRITICAL"
        print_error "Uso de memória crítico: ${mem_usage}%"
    elif [ "$mem_usage" -gt "$MEMORY_WARNING_THRESHOLD" ]; then
        mem_status="WARNING"
        print_warning "Uso de memória alto: ${mem_usage}%"
    else
        print_success "Uso de memória normal: ${mem_usage}%"
    fi
    
    # Verificar swap excessivo
    if [ "$swap_usage" -gt 50 ]; then
        print_warning "Uso de swap alto: ${swap_usage}%"
        [ "$mem_status" = "OK" ] && mem_status="WARNING"
    fi
    
    # Top processos por memória
    echo "  • Top processos por memória:"
    ps aux --sort=-%mem | head -5 | tail -4 | awk '{print "    " $11 ": " $4"%"}'
    
    log_action "Memory Check: Usage=${mem_usage}%, Swap=${swap_usage}%, Status=${mem_status}"
    echo "MEMORY_STATUS=$mem_status" >> /tmp/health-status.tmp
}

# Verificar discos
check_disk() {
    print_header "💽 Verificando Discos"
    
    local disk_status="OK"
    
    # Verificar uso dos filesystems
    while IFS= read -r line; do
        local filesystem=$(echo "$line" | awk '{print $1}')
        local usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        
        echo "  • $mountpoint: ${usage}% ($filesystem)"
        
        if [ "$usage" -gt "$DISK_CRITICAL_THRESHOLD" ]; then
            disk_status="CRITICAL"
            print_error "Disco crítico em $mountpoint: ${usage}%"
        elif [ "$usage" -gt "$DISK_WARNING_THRESHOLD" ]; then
            [ "$disk_status" = "OK" ] && disk_status="WARNING"
            print_warning "Disco com pouco espaço em $mountpoint: ${usage}%"
        fi
    done < <(df -h | grep -E '^/dev/' | grep -v '/boot/efi')
    
    # Verificar inodes
    echo "  • Verificando inodes:"
    while IFS= read -r line; do
        local filesystem=$(echo "$line" | awk '{print $1}')
        local inode_usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        local mountpoint=$(echo "$line" | awk '{print $6}')
        
        if [ "$inode_usage" -gt 90 ]; then
            print_error "Inodes críticos em $mountpoint: ${inode_usage}%"
            disk_status="CRITICAL"
        elif [ "$inode_usage" -gt 80 ]; then
            print_warning "Inodes altos em $mountpoint: ${inode_usage}%"
            [ "$disk_status" = "OK" ] && disk_status="WARNING"
        fi
    done < <(df -i | grep -E '^/dev/' | grep -v '/boot/efi')
    
    # Verificar I/O
    if command -v iostat &> /dev/null; then
        echo "  • I/O Stats:"
        iostat -x 1 1 | grep -E '^[sv]d[a-z]|^nvme' | while read line; do
            local device=$(echo "$line" | awk '{print $1}')
            local util=$(echo "$line" | awk '{print $NF}')
            echo "    $device: ${util}% utilization"
            
            if (( $(echo "$util > 90" | bc -l) )); then
                print_warning "High I/O utilization on $device: ${util}%"
            fi
        done
    fi
    
    if [ "$disk_status" = "OK" ]; then
        print_success "Espaço em disco adequado"
    fi
    
    log_action "Disk Check: Status=${disk_status}"
    echo "DISK_STATUS=$disk_status" >> /tmp/health-status.tmp
}

# Verificar rede
check_network() {
    print_header "🌐 Verificando Rede"
    
    local network_status="OK"
    
    # Testar conectividade
    IFS=',' read -ra HOSTS <<< "$NETWORK_CHECK_HOSTS"
    for host in "${HOSTS[@]}"; do
        if ping -c 1 -W "$NETWORK_TIMEOUT" "$host" &> /dev/null; then
            print_success "Conectividade OK para $host"
        else
            print_error "Falha na conectividade para $host"
            network_status="CRITICAL"
        fi
    done
    
    # Verificar interfaces de rede
    echo "  • Interfaces de rede:"
    ip link show | grep -E '^[0-9]' | while read line; do
        local interface=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
        local status=$(echo "$line" | grep -o 'state [A-Z]*' | awk '{print $2}')
        echo "    $interface: $status"
        
        if [ "$interface" != "lo" ] && [ "$status" != "UP" ]; then
            print_warning "Interface $interface está $status"
        fi
    done
    
    # Verificar portas críticas
    if [ "$PORT_CHECK_ENABLED" = "true" ]; then
        echo "  • Verificando portas críticas:"
        IFS=',' read -ra PORTS <<< "$CRITICAL_PORTS"
        for port in "${PORTS[@]}"; do
            if ss -tlnp | grep ":$port " &> /dev/null; then
                print_success "Porta $port está em uso"
            else
                print_warning "Porta $port não está em uso"
            fi
        done
    fi
    
    # Estatísticas de rede
    echo "  • Estatísticas de rede:"
    local rx_errors=$(cat /sys/class/net/*/statistics/rx_errors | awk '{sum += $1} END {print sum}')
    local tx_errors=$(cat /sys/class/net/*/statistics/tx_errors | awk '{sum += $1} END {print sum}')
    echo "    RX Errors: $rx_errors"
    echo "    TX Errors: $tx_errors"
    
    if [ "$rx_errors" -gt 1000 ] || [ "$tx_errors" -gt 1000 ]; then
        print_warning "Alto número de erros de rede"
        [ "$network_status" = "OK" ] && network_status="WARNING"
    fi
    
    log_action "Network Check: Status=${network_status}, RX_Errors=${rx_errors}, TX_Errors=${tx_errors}"
    echo "NETWORK_STATUS=$network_status" >> /tmp/health-status.tmp
}

# Verificar serviços
check_services() {
    print_header "🔧 Verificando Serviços"
    
    local services_status="OK"
    
    # Serviços críticos
    echo "  • Serviços críticos:"
    IFS=',' read -ra SERVICES <<< "$CRITICAL_SERVICES"
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "$service está ativo"
        else
            print_error "$service não está ativo"
            services_status="CRITICAL"
        fi
    done
    
    # Serviços opcionais
    echo "  • Serviços opcionais:"
    IFS=',' read -ra SERVICES <<< "$OPTIONAL_SERVICES"
    for service in "${SERVICES[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            if systemctl is-active --quiet "$service"; then
                print_success "$service está ativo"
            else
                print_warning "$service está habilitado mas não ativo"
            fi
        fi
    done
    
    # Serviços falhados
    local failed_services=$(systemctl --failed --no-legend | wc -l)
    if [ "$failed_services" -gt 0 ]; then
        print_error "$failed_services serviços falharam"
        services_status="WARNING"
        systemctl --failed --no-legend | head -5 | awk '{print "    " $1}'
    else
        print_success "Nenhum serviço falhado"
    fi
    
    log_action "Services Check: Status=${services_status}, Failed=${failed_services}"
    echo "SERVICES_STATUS=$services_status" >> /tmp/health-status.tmp
}

# Verificar logs
check_logs() {
    print_header "📋 Verificando Logs"
    
    local logs_status="OK"
    
    # Verificar erros críticos nos últimos 24h
    local critical_errors=$(journalctl --since "24 hours ago" --priority=0..2 --no-pager | wc -l)
    local warnings=$(journalctl --since "24 hours ago" --priority=3..4 --no-pager | wc -l)
    
    echo "  • Erros críticos (24h): $critical_errors"
    echo "  • Warnings (24h): $warnings"
    
    if [ "$critical_errors" -gt 10 ]; then
        print_error "Muitos erros críticos nos logs"
        logs_status="CRITICAL"
    elif [ "$critical_errors" -gt 0 ]; then
        print_warning "$critical_errors erros críticos encontrados"
        [ "$logs_status" = "OK" ] && logs_status="WARNING"
    fi
    
    # Mostrar últimos erros críticos
    if [ "$critical_errors" -gt 0 ]; then
        echo "  • Últimos erros críticos:"
        journalctl --since "24 hours ago" --priority=0..2 --no-pager | tail -5 | while read line; do
            echo "    $(echo "$line" | cut -c1-100)..."
        done
    fi
    
    # Verificar tamanho dos logs
    local log_size=$(du -sm /var/log | awk '{print $1}')
    echo "  • Tamanho total dos logs: ${log_size}MB"
    
    if [ "$log_size" -gt 5000 ]; then
        print_warning "Logs ocupando muito espaço: ${log_size}MB"
        [ "$logs_status" = "OK" ] && logs_status="WARNING"
    fi
    
    log_action "Logs Check: Status=${logs_status}, Critical=${critical_errors}, Warnings=${warnings}, Size=${log_size}MB"
    echo "LOGS_STATUS=$logs_status" >> /tmp/health-status.tmp
}

# Verificar segurança
check_security() {
    print_header "🔒 Verificando Segurança"
    
    local security_status="OK"
    
    # Verificar últimos logins
    echo "  • Últimos logins:"
    last -n 5 | grep -v "reboot\|shutdown" | head -3 | while read line; do
        echo "    $line"
    done
    
    # Verificar tentativas de login falharam
    local failed_logins=$(lastb 2>/dev/null | grep -v "wtmp\|reboot" | wc -l)
    echo "  • Tentativas de login falharam: $failed_logins"
    
    if [ "$failed_logins" -gt 10 ]; then
        print_warning "Muitas tentativas de login falharam"
        [ "$security_status" = "OK" ] && security_status="WARNING"
    fi
    
    # Verificar processos suspeitos
    local suspicious_procs=$(ps aux | grep -E "(nc|netcat|nmap|tcpdump)" | grep -v grep | wc -l)
    if [ "$suspicious_procs" -gt 0 ]; then
        print_warning "$suspicious_procs processos de rede suspeitos detectados"
        [ "$security_status" = "OK" ] && security_status="WARNING"
    fi
    
    # Verificar conexões de rede
    local connections=$(ss -tn | grep ESTAB | wc -l)
    echo "  • Conexões estabelecidas: $connections"
    
    # Verificar fail2ban se instalado
    if command -v fail2ban-client &> /dev/null && systemctl is-active --quiet fail2ban; then
        local banned_ips=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list" | awk -F: '{print $2}' | wc -w)
        echo "  • IPs banidos pelo fail2ban: $banned_ips"
    fi
    
    log_action "Security Check: Status=${security_status}, Failed_logins=${failed_logins}, Connections=${connections}"
    echo "SECURITY_STATUS=$security_status" >> /tmp/health-status.tmp
}

# Verificar atualizações
check_updates() {
    print_header "📦 Verificando Atualizações"
    
    local updates_status="OK"
    
    # Verificar atualizações disponíveis
    local updates=$(dnf check-update --quiet 2>/dev/null | wc -l)
    local security_updates=$(dnf updateinfo list sec 2>/dev/null | wc -l)
    
    echo "  • Atualizações disponíveis: $updates"
    echo "  • Atualizações de segurança: $security_updates"
    
    if [ "$security_updates" -gt 0 ]; then
        print_error "$security_updates atualizações de segurança disponíveis"
        updates_status="CRITICAL"
    elif [ "$updates" -gt 20 ]; then
        print_warning "Muitas atualizações disponíveis: $updates"
        updates_status="WARNING"
    elif [ "$updates" -gt 0 ]; then
        print_info "$updates atualizações disponíveis"
    else
        print_success "Sistema atualizado"
    fi
    
    # Verificar última atualização
    local last_update=$(rpm -qa --last | head -1 | awk '{print $3, $4, $5}')
    echo "  • Última atualização: $last_update"
    
    log_action "Updates Check: Status=${updates_status}, Available=${updates}, Security=${security_updates}"
    echo "UPDATES_STATUS=$updates_status" >> /tmp/health-status.tmp
}

# Gerar relatório
generate_report() {
    print_header "📊 Gerando Relatório"
    
    # Ler status dos checks
    local overall_status="OK"
    if [ -f /tmp/health-status.tmp ]; then
        source /tmp/health-status.tmp
        
        # Determinar status geral
        for status in $CPU_STATUS $MEMORY_STATUS $DISK_STATUS $NETWORK_STATUS $SERVICES_STATUS $LOGS_STATUS $SECURITY_STATUS $UPDATES_STATUS; do
            if [ "$status" = "CRITICAL" ]; then
                overall_status="CRITICAL"
                break
            elif [ "$status" = "WARNING" ] && [ "$overall_status" = "OK" ]; then
                overall_status="WARNING"
            fi
        done
        
        rm -f /tmp/health-status.tmp
    fi
    
    # Criar relatório
    if [ "$GENERATE_REPORTS" = "true" ]; then
        cat > "$REPORT_FILE" << EOF
Health Check Report - $(date '+%Y-%m-%d %H:%M:%S')
================================================================

Overall Status: $overall_status

System Information:
- Hostname: $(hostname)
- OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- Kernel: $(uname -r)
- Uptime: $(uptime -p)

Component Status:
- CPU: ${CPU_STATUS:-UNKNOWN}
- Memory: ${MEMORY_STATUS:-UNKNOWN}
- Disk: ${DISK_STATUS:-UNKNOWN}
- Network: ${NETWORK_STATUS:-UNKNOWN}
- Services: ${SERVICES_STATUS:-UNKNOWN}
- Logs: ${LOGS_STATUS:-UNKNOWN}
- Security: ${SECURITY_STATUS:-UNKNOWN}
- Updates: ${UPDATES_STATUS:-UNKNOWN}

Detailed Information:
$(cat "$LOG_FILE" | tail -20)

================================================================
EOF
        
        print_success "Relatório salvo em: $REPORT_FILE"
    fi
    
    # Enviar notificações se necessário
    if [ "$overall_status" != "OK" ] || [ "$SEND_CRITICAL_ONLY" != "true" ]; then
        send_notifications "$overall_status"
    fi
    
    # Mostrar resumo
    echo
    case "$overall_status" in
        "OK")
            print_success "Sistema está saudável! ✓"
            ;;
        "WARNING")
            print_warning "Sistema tem alguns problemas que precisam atenção !"
            ;;
        "CRITICAL")
            print_error "Sistema tem problemas críticos que precisam correção imediata !!"
            ;;
    esac
}

# Enviar notificações
send_notifications() {
    local status="$1"
    local message="Sistema $status - Health Check em $(hostname) - $(date)"
    
    # Email
    if [ "$EMAIL_NOTIFICATIONS" = "true" ] && [ -n "$EMAIL_ADDRESS" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Health Check: $status" "$EMAIL_ADDRESS"
    fi
    
    # Slack
    if [ -n "$SLACK_WEBHOOK" ]; then
        local emoji="✅"
        [ "$status" = "WARNING" ] && emoji="⚠️"
        [ "$status" = "CRITICAL" ] && emoji="🚨"
        
        local payload="{\"text\":\"$emoji $message\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK" &>/dev/null
    fi
    
    # Discord
    if [ -n "$DISCORD_WEBHOOK" ]; then
        local payload="{\"content\":\"**$message**\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$DISCORD_WEBHOOK" &>/dev/null
    fi
}

# Executar check completo
run_full_check() {
    echo > /tmp/health-status.tmp
    
    check_cpu
    check_memory
    check_disk
    check_network
    check_services
    check_logs
    check_security
    check_updates
    
    generate_report
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    Health Check                               ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🏥 Check completo do sistema                              ║"
    echo "║  2. ⚡ Verificar CPU                                          ║"
    echo "║  3. 💾 Verificar memória                                     ║"
    echo "║  4. 💽 Verificar discos                                      ║"
    echo "║  5. 🌐 Verificar rede                                        ║"
    echo "║  6. 🔧 Verificar serviços                                    ║"
    echo "║  7. 📋 Verificar logs                                        ║"
    echo "║  8. 🔒 Verificar segurança                                   ║"
    echo "║  9. 📦 Verificar atualizações                                ║"
    echo "║  10. 📊 Visualizar último relatório                          ║"
    echo "║  11. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_health() {
    print_header "⚙️ Configurações do Health Check"
    echo
    
    print_info "Limites atuais:"
    echo "  • CPU Warning/Critical: ${CPU_WARNING_THRESHOLD}%/${CPU_CRITICAL_THRESHOLD}%"
    echo "  • Memory Warning/Critical: ${MEMORY_WARNING_THRESHOLD}%/${MEMORY_CRITICAL_THRESHOLD}%"
    echo "  • Disk Warning/Critical: ${DISK_WARNING_THRESHOLD}%/${DISK_CRITICAL_THRESHOLD}%"
    echo
    
    read -p "Deseja editar as configurações? (s/N): " edit_config
    if [[ $edit_config =~ ^[SsYy]$ ]]; then
        ${EDITOR:-nano} "$CONFIG_FILE"
        source "$CONFIG_FILE"
        print_success "Configurações recarregadas"
    fi
}

# Visualizar último relatório
view_last_report() {
    local last_report=$(ls -t /var/log/health-report-*.txt 2>/dev/null | head -1)
    
    if [ -n "$last_report" ]; then
        print_header "📊 Último Relatório: $last_report"
        echo
        cat "$last_report"
    else
        print_info "Nenhum relatório encontrado"
    fi
}

# Função principal
main() {
    create_config
    
    case "${1:-}" in
        "full")
            run_full_check
            ;;
        "cpu")
            echo > /tmp/health-status.tmp && check_cpu
            ;;
        "memory")
            echo > /tmp/health-status.tmp && check_memory
            ;;
        "disk")
            echo > /tmp/health-status.tmp && check_disk
            ;;
        "network")
            echo > /tmp/health-status.tmp && check_network
            ;;
        "services")
            echo > /tmp/health-status.tmp && check_services
            ;;
        "logs")
            echo > /tmp/health-status.tmp && check_logs
            ;;
        "security")
            echo > /tmp/health-status.tmp && check_security
            ;;
        "updates")
            echo > /tmp/health-status.tmp && check_updates
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-11): " choice
                
                case $choice in
                    1) run_full_check ;;
                    2) echo > /tmp/health-status.tmp && check_cpu ;;
                    3) echo > /tmp/health-status.tmp && check_memory ;;
                    4) echo > /tmp/health-status.tmp && check_disk ;;
                    5) echo > /tmp/health-status.tmp && check_network ;;
                    6) echo > /tmp/health-status.tmp && check_services ;;
                    7) echo > /tmp/health-status.tmp && check_logs ;;
                    8) echo > /tmp/health-status.tmp && check_security ;;
                    9) echo > /tmp/health-status.tmp && check_updates ;;
                    10) view_last_report ;;
                    11) configure_health ;;
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