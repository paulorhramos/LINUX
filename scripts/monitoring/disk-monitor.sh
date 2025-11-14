#!/bin/bash

# =============================================================================
# Monitor de Disco para Rocky Linux 10
# =============================================================================
# Descrição: Monitoramento completo de discos, I/O e sistemas de arquivos
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
CONFIG_FILE="/etc/disk-monitor.conf"
LOG_FILE="/var/log/disk-monitor.log"
ALERT_FILE="/var/log/disk-alerts.log"

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: $1" | tee -a "$ALERT_FILE"
    log_action "ALERT: $1"
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações do Disk Monitor

# Limites de alerta (%)
DISK_USAGE_WARNING=80
DISK_USAGE_CRITICAL=90
INODE_USAGE_WARNING=80
INODE_USAGE_CRITICAL=90

# Limites de I/O
IO_WAIT_WARNING=20
IO_UTIL_WARNING=80
IO_UTIL_CRITICAL=95

# Monitoramento de SMART
ENABLE_SMART_MONITORING=true
SMART_CHECK_INTERVAL=3600

# Monitoramento de temperatura
CHECK_DISK_TEMPERATURE=true
TEMP_WARNING=45
TEMP_CRITICAL=55

# Configurações de alerta
ALERT_EMAIL=""
ALERT_WEBHOOK=""
ENABLE_SOUND_ALERT=false

# Configurações de log
LOG_RETENTION_DAYS=30
ENABLE_IOSTAT_LOGGING=true
IOSTAT_INTERVAL=60

# Diretórios para monitorar
MONITOR_PATHS="/,/home,/var,/tmp,/opt"

# Configurações de performance
ENABLE_READAHEAD_OPTIMIZATION=true
ENABLE_IO_SCHEDULER_OPTIMIZATION=true
SSD_SCHEDULER="mq-deadline"
HDD_SCHEDULER="bfq"
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Detectar tipo de disco
detect_disk_type() {
    local device="$1"
    local disk_name=$(echo "$device" | sed 's|/dev/||')
    
    # Verificar se é SSD através do rotational
    if [ -f "/sys/block/$disk_name/queue/rotational" ]; then
        local rotational=$(cat "/sys/block/$disk_name/queue/rotational")
        if [ "$rotational" = "0" ]; then
            echo "SSD"
        else
            echo "HDD"
        fi
    else
        # Fallback para NVMe
        if [[ "$device" =~ nvme ]]; then
            echo "NVMe"
        else
            echo "Unknown"
        fi
    fi
}

# Monitor de uso de disco
monitor_disk_usage() {
    print_header "💽 Monitorando Uso de Disco"
    
    local alerts_triggered=0
    
    # Verificar cada path configurado
    IFS=',' read -ra PATHS <<< "$MONITOR_PATHS"
    for path in "${PATHS[@]}"; do
        if [ -d "$path" ]; then
            local usage_info=$(df -h "$path" | tail -1)
            local usage_percent=$(echo "$usage_info" | awk '{print $5}' | sed 's/%//')
            local available=$(echo "$usage_info" | awk '{print $4}')
            local filesystem=$(echo "$usage_info" | awk '{print $1}')
            
            echo "📁 $path:"
            echo "  • Filesystem: $filesystem"
            echo "  • Uso: ${usage_percent}%"
            echo "  • Disponível: $available"
            
            # Verificar limites
            if [ "$usage_percent" -ge "$DISK_USAGE_CRITICAL" ]; then
                print_error "CRÍTICO: $path está com ${usage_percent}% de uso!"
                log_alert "Disco crítico em $path: ${usage_percent}%"
                alerts_triggered=$((alerts_triggered + 1))
            elif [ "$usage_percent" -ge "$DISK_USAGE_WARNING" ]; then
                print_warning "ALERTA: $path está com ${usage_percent}% de uso"
                log_alert "Alerta de disco em $path: ${usage_percent}%"
                alerts_triggered=$((alerts_triggered + 1))
            else
                print_success "$path - uso normal (${usage_percent}%)"
            fi
            
            # Verificar inodes
            local inode_info=$(df -i "$path" | tail -1)
            local inode_usage=$(echo "$inode_info" | awk '{print $5}' | sed 's/%//')
            
            echo "  • Inodes: ${inode_usage}% utilizados"
            
            if [ "$inode_usage" -ge "$INODE_USAGE_CRITICAL" ]; then
                print_error "CRÍTICO: Inodes em $path: ${inode_usage}%"
                log_alert "Inodes críticos em $path: ${inode_usage}%"
                alerts_triggered=$((alerts_triggered + 1))
            elif [ "$inode_usage" -ge "$INODE_USAGE_WARNING" ]; then
                print_warning "ALERTA: Inodes em $path: ${inode_usage}%"
            fi
            
            echo
        fi
    done
    
    return $alerts_triggered
}

# Monitor de I/O
monitor_io() {
    print_header "📊 Monitorando I/O de Disco"
    
    if ! command -v iostat &> /dev/null; then
        print_warning "iostat não encontrado. Instalando sysstat..."
        dnf install -y sysstat
    fi
    
    local alerts_triggered=0
    
    # Obter estatísticas de I/O
    local io_stats=$(iostat -x 1 2 | grep -E '^[sv]d[a-z]|^nvme')
    
    echo "$io_stats" | while read line; do
        if [ -n "$line" ]; then
            local device=$(echo "$line" | awk '{print $1}')
            local util=$(echo "$line" | awk '{print $NF}')
            local await=$(echo "$line" | awk '{print $(NF-1)}')
            local read_rate=$(echo "$line" | awk '{print $4}')
            local write_rate=$(echo "$line" | awk '{print $5}')
            
            # Remover decimais para comparação
            local util_int=${util%.*}
            local await_int=${await%.*}
            
            echo "💾 /dev/$device:"
            echo "  • Utilização: ${util}%"
            echo "  • Await: ${await}ms"
            echo "  • Read: ${read_rate} KB/s"
            echo "  • Write: ${write_rate} KB/s"
            
            # Verificar tipo de disco
            local disk_type=$(detect_disk_type "/dev/$device")
            echo "  • Tipo: $disk_type"
            
            # Verificar limites
            if [ "$util_int" -ge "$IO_UTIL_CRITICAL" ]; then
                print_error "CRÍTICO: I/O utilization em $device: ${util}%"
                log_alert "I/O crítico em $device: ${util}%"
            elif [ "$util_int" -ge "$IO_UTIL_WARNING" ]; then
                print_warning "ALERTA: I/O utilization em $device: ${util}%"
            fi
            
            if [ "$await_int" -ge "$IO_WAIT_WARNING" ]; then
                print_warning "ALERTA: I/O wait alto em $device: ${await}ms"
            fi
            
            echo
        fi
    done
}

# Monitor SMART
monitor_smart() {
    if [ "$ENABLE_SMART_MONITORING" != "true" ]; then
        return 0
    fi
    
    print_header "🔍 Monitorando SMART"
    
    if ! command -v smartctl &> /dev/null; then
        print_warning "smartctl não encontrado. Instalando smartmontools..."
        dnf install -y smartmontools
    fi
    
    # Listar todos os discos
    local disks=$(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$|^nvme')
    
    echo "$disks" | while read disk; do
        if [ -n "$disk" ]; then
            local device="/dev/$disk"
            
            echo "🔍 Verificando SMART para $device:"
            
            # Verificar se SMART está habilitado
            if smartctl -i "$device" | grep -q "SMART support is: Enabled"; then
                # Obter status geral
                local smart_status=$(smartctl -H "$device" | grep "SMART overall-health" | awk '{print $NF}')
                
                if [ "$smart_status" = "PASSED" ]; then
                    print_success "SMART OK para $device"
                else
                    print_error "SMART FALHOU para $device!"
                    log_alert "SMART failure detectado em $device"
                fi
                
                # Verificar atributos críticos
                local reallocated=$(smartctl -A "$device" | grep "Reallocated_Sector_Ct" | awk '{print $10}')
                local pending=$(smartctl -A "$device" | grep "Current_Pending_Sector" | awk '{print $10}')
                local uncorrectable=$(smartctl -A "$device" | grep "Offline_Uncorrectable" | awk '{print $10}')
                
                echo "  • Sectores realocados: ${reallocated:-N/A}"
                echo "  • Sectores pendentes: ${pending:-N/A}"
                echo "  • Erros não corrigíveis: ${uncorrectable:-N/A}"
                
                # Verificar temperatura se disponível
                if [ "$CHECK_DISK_TEMPERATURE" = "true" ]; then
                    local temp=$(smartctl -A "$device" | grep -E "Temperature_Celsius|Airflow_Temperature_Cel" | awk '{print $10}' | head -1)
                    if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                        echo "  • Temperatura: ${temp}°C"
                        
                        if [ "$temp" -ge "$TEMP_CRITICAL" ]; then
                            print_error "CRÍTICO: Temperatura alta em $device: ${temp}°C"
                            log_alert "Temperatura crítica em $device: ${temp}°C"
                        elif [ "$temp" -ge "$TEMP_WARNING" ]; then
                            print_warning "ALERTA: Temperatura em $device: ${temp}°C"
                        fi
                    fi
                fi
                
            else
                print_warning "SMART não suportado ou não habilitado em $device"
            fi
            
            echo
        fi
    done
}

# Análise de fragmentação
analyze_fragmentation() {
    print_header "🧩 Analisando Fragmentação"
    
    local ext_filesystems=$(mount | grep -E "ext[234]" | awk '{print $3}')
    
    if [ -n "$ext_filesystems" ]; then
        echo "$ext_filesystems" | while read mountpoint; do
            local device=$(mount | grep "$mountpoint" | awk '{print $1}')
            echo "📁 Analisando fragmentação em $mountpoint ($device):"
            
            # Usar e2fsck para verificar fragmentação
            local fs_info=$(tune2fs -l "$device" 2>/dev/null)
            if [ $? -eq 0 ]; then
                local free_blocks=$(echo "$fs_info" | grep "Free blocks" | awk '{print $3}')
                local total_blocks=$(echo "$fs_info" | grep "Block count" | awk '{print $3}')
                
                if [ -n "$free_blocks" ] && [ -n "$total_blocks" ]; then
                    local free_percent=$((free_blocks * 100 / total_blocks))
                    echo "  • Blocos livres: ${free_percent}%"
                    
                    if [ "$free_percent" -lt 10 ]; then
                        print_warning "Fragmentação pode estar alta (${free_percent}% livres)"
                    else
                        print_success "Fragmentação normal"
                    fi
                fi
            fi
            echo
        done
    else
        print_info "Nenhum filesystem ext2/3/4 encontrado"
    fi
}

# Otimizações automáticas
auto_optimize() {
    print_header "⚡ Aplicando Otimizações Automáticas"
    
    if [ "$ENABLE_IO_SCHEDULER_OPTIMIZATION" = "true" ]; then
        print_info "Otimizando I/O schedulers..."
        
        local disks=$(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$|^nvme')
        
        echo "$disks" | while read disk; do
            if [ -n "$disk" ]; then
                local device="/dev/$disk"
                local disk_type=$(detect_disk_type "$device")
                local current_scheduler=$(cat "/sys/block/$disk/queue/scheduler" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]')
                
                local optimal_scheduler
                case "$disk_type" in
                    "SSD"|"NVMe")
                        optimal_scheduler="$SSD_SCHEDULER"
                        ;;
                    "HDD")
                        optimal_scheduler="$HDD_SCHEDULER"
                        ;;
                    *)
                        optimal_scheduler="$SSD_SCHEDULER"  # Default para SSD
                        ;;
                esac
                
                if [ "$current_scheduler" != "$optimal_scheduler" ]; then
                    echo "$optimal_scheduler" > "/sys/block/$disk/queue/scheduler" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        print_success "Scheduler $optimal_scheduler aplicado em $disk ($disk_type)"
                        log_action "I/O scheduler otimizado: $disk -> $optimal_scheduler"
                    fi
                else
                    print_info "$disk já está usando o scheduler otimizado ($current_scheduler)"
                fi
            fi
        done
    fi
    
    if [ "$ENABLE_READAHEAD_OPTIMIZATION" = "true" ]; then
        print_info "Otimizando readahead..."
        
        local disks=$(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$')
        
        echo "$disks" | while read disk; do
            if [ -n "$disk" ]; then
                local disk_type=$(detect_disk_type "/dev/$disk")
                local current_readahead=$(cat "/sys/block/$disk/queue/read_ahead_kb" 2>/dev/null)
                
                local optimal_readahead
                case "$disk_type" in
                    "SSD"|"NVMe")
                        optimal_readahead=128  # Menor para SSDs
                        ;;
                    "HDD")
                        optimal_readahead=4096  # Maior para HDDs
                        ;;
                    *)
                        optimal_readahead=1024  # Default
                        ;;
                esac
                
                if [ "$current_readahead" != "$optimal_readahead" ]; then
                    echo "$optimal_readahead" > "/sys/block/$disk/queue/read_ahead_kb" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        print_success "Readahead otimizado para $disk: ${optimal_readahead}KB"
                        log_action "Readahead otimizado: $disk -> ${optimal_readahead}KB"
                    fi
                fi
            fi
        done
    fi
}

# Limpeza de disco
disk_cleanup() {
    print_header "🧹 Limpeza de Disco"
    
    local cleaned_size=0
    
    # Cache do sistema
    print_info "Limpando caches do sistema..."
    sync
    echo 3 > /proc/sys/vm/drop_caches
    print_success "Cache do kernel limpo"
    
    # Logs antigos
    print_info "Limpando logs antigos..."
    local log_size_before=$(du -sm /var/log 2>/dev/null | awk '{print $1}')
    
    # Limpar journald logs antigos
    journalctl --vacuum-time=7d &>/dev/null
    
    # Limpar logs de rotação
    find /var/log -name "*.old" -delete 2>/dev/null
    find /var/log -name "*.gz" -mtime +7 -delete 2>/dev/null
    
    local log_size_after=$(du -sm /var/log 2>/dev/null | awk '{print $1}')
    local log_cleaned=$((log_size_before - log_size_after))
    
    if [ "$log_cleaned" -gt 0 ]; then
        print_success "Logs limpos: ${log_cleaned}MB"
        cleaned_size=$((cleaned_size + log_cleaned))
    fi
    
    # Cache de pacotes
    print_info "Limpando cache de pacotes..."
    local cache_size_before=$(du -sm /var/cache/dnf 2>/dev/null | awk '{print $1}')
    dnf clean all &>/dev/null
    local cache_size_after=$(du -sm /var/cache/dnf 2>/dev/null | awk '{print $1}')
    local cache_cleaned=$((cache_size_before - cache_size_after))
    
    if [ "$cache_cleaned" -gt 0 ]; then
        print_success "Cache de pacotes limpo: ${cache_cleaned}MB"
        cleaned_size=$((cleaned_size + cache_cleaned))
    fi
    
    # Arquivos temporários
    print_info "Limpando arquivos temporários..."
    local temp_files=$(find /tmp -type f -mtime +1 2>/dev/null | wc -l)
    find /tmp -type f -mtime +1 -delete 2>/dev/null
    
    if [ "$temp_files" -gt 0 ]; then
        print_success "$temp_files arquivos temporários removidos"
    fi
    
    # Core dumps
    local core_dumps=$(find /var/lib/systemd/coredump -name "*.xz" 2>/dev/null | wc -l)
    if [ "$core_dumps" -gt 0 ]; then
        find /var/lib/systemd/coredump -name "*.xz" -delete 2>/dev/null
        print_success "$core_dumps core dumps removidos"
    fi
    
    print_success "Limpeza concluída! Total liberado: ${cleaned_size}MB"
    log_action "Disk cleanup: ${cleaned_size}MB liberados"
}

# Análise de arquivos grandes
find_large_files() {
    print_header "🔍 Procurando Arquivos Grandes"
    
    local size_limit="${1:-100M}"
    
    print_info "Procurando arquivos maiores que $size_limit..."
    echo
    
    # Procurar arquivos grandes (excluindo /proc, /sys, /dev)
    find / -type f -size "+$size_limit" \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        -not -path "/dev/*" \
        -not -path "/run/*" \
        -exec ls -lh {} \; 2>/dev/null | \
        head -20 | \
        while read line; do
            local size=$(echo "$line" | awk '{print $5}')
            local file=$(echo "$line" | awk '{print $NF}')
            echo "📄 $file: $size"
        done
}

# Relatório completo
generate_disk_report() {
    print_header "📊 Relatório de Disco"
    
    local report_file="/var/log/disk-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Relatório de Disco - $(date)"
        echo "=========================================="
        echo
        
        echo "=== USO DE DISCO ==="
        df -h
        echo
        
        echo "=== INODES ==="
        df -i
        echo
        
        echo "=== I/O STATISTICS ==="
        iostat -x 1 1 2>/dev/null | grep -v "^$"
        echo
        
        echo "=== DISCOS DETECTADOS ==="
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
        echo
        
        echo "=== TOP 10 DIRETÓRIOS POR TAMANHO ==="
        du -sh /* 2>/dev/null | sort -hr | head -10
        echo
        
        if [ "$ENABLE_SMART_MONITORING" = "true" ]; then
            echo "=== STATUS SMART ==="
            local disks=$(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$|^nvme')
            echo "$disks" | while read disk; do
                if [ -n "$disk" ]; then
                    echo "--- $disk ---"
                    smartctl -H "/dev/$disk" 2>/dev/null | grep "SMART overall-health"
                    echo
                fi
            done
        fi
        
    } > "$report_file"
    
    print_success "Relatório salvo em: $report_file"
    
    # Mostrar resumo
    echo
    print_info "Resumo do sistema:"
    df -h / | tail -1 | awk '{print "  • Disco raiz: " $5 " usado, " $4 " disponível"}'
    free -h | grep Mem | awk '{print "  • Memória: " $3 " usado, " $7 " disponível"}'
    uptime | awk '{print "  • Load average:" $10 $11 $12}'
}

# Enviar alertas
send_alert() {
    local message="$1"
    
    # Email
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Disk Alert - $(hostname)" "$ALERT_EMAIL"
    fi
    
    # Webhook
    if [ -n "$ALERT_WEBHOOK" ]; then
        local payload="{\"text\":\"🚨 **Disk Alert**\\n$message\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$ALERT_WEBHOOK" &>/dev/null
    fi
    
    # Som de alerta
    if [ "$ENABLE_SOUND_ALERT" = "true" ] && command -v beep &> /dev/null; then
        beep -f 1000 -l 500 &
    fi
}

# Monitor contínuo
continuous_monitor() {
    local interval="${1:-300}"  # 5 minutos padrão
    
    print_header "🔄 Iniciando Monitor Contínuo (${interval}s)"
    
    while true; do
        clear
        echo "=== DISK MONITOR - $(date) ==="
        echo
        
        # Executar verificações
        monitor_disk_usage
        local alerts=$?
        
        monitor_io
        
        if [ "$ENABLE_SMART_MONITORING" = "true" ]; then
            monitor_smart
        fi
        
        # Enviar alertas se necessário
        if [ "$alerts" -gt 0 ]; then
            send_alert "Disk monitoring detectou $alerts problemas em $(hostname)"
        fi
        
        echo "Próxima verificação em ${interval} segundos..."
        echo "Pressione Ctrl+C para parar"
        
        sleep "$interval"
    done
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    Disk Monitor                               ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 💽 Monitor uso de disco                                   ║"
    echo "║  2. 📊 Monitor I/O                                           ║"
    echo "║  3. 🔍 Verificar SMART                                       ║"
    echo "║  4. 🧩 Analisar fragmentação                                 ║"
    echo "║  5. ⚡ Otimizações automáticas                               ║"
    echo "║  6. 🧹 Limpeza de disco                                      ║"
    echo "║  7. 🔍 Encontrar arquivos grandes                            ║"
    echo "║  8. 📊 Gerar relatório completo                              ║"
    echo "║  9. 🔄 Monitor contínuo                                      ║"
    echo "║  10. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_disk_monitor() {
    print_header "⚙️ Configurações do Disk Monitor"
    echo
    
    print_info "Configurações atuais:"
    echo "  • Alerta de uso: ${DISK_USAGE_WARNING}%/${DISK_USAGE_CRITICAL}%"
    echo "  • Monitoramento SMART: $ENABLE_SMART_MONITORING"
    echo "  • Verificar temperatura: $CHECK_DISK_TEMPERATURE"
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
    create_config
    
    case "${1:-}" in
        "usage")
            monitor_disk_usage
            ;;
        "io")
            monitor_io
            ;;
        "smart")
            monitor_smart
            ;;
        "cleanup")
            disk_cleanup
            ;;
        "optimize")
            auto_optimize
            ;;
        "report")
            generate_disk_report
            ;;
        "monitor")
            continuous_monitor "${2:-300}"
            ;;
        "large")
            find_large_files "${2:-100M}"
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-10): " choice
                
                case $choice in
                    1) monitor_disk_usage ;;
                    2) monitor_io ;;
                    3) monitor_smart ;;
                    4) analyze_fragmentation ;;
                    5) auto_optimize ;;
                    6) disk_cleanup ;;
                    7)
                        read -p "Tamanho mínimo dos arquivos (ex: 100M): " size
                        find_large_files "${size:-100M}"
                        ;;
                    8) generate_disk_report ;;
                    9)
                        read -p "Intervalo em segundos (padrão 300): " interval
                        continuous_monitor "${interval:-300}"
                        ;;
                    10) configure_disk_monitor ;;
                    0)
                        print_success "Até logo!"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        ;;
                esac
                
                if [ "$choice" != "9" ]; then
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