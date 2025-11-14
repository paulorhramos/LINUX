#!/bin/bash

# =============================================================================
# Sistema de Otimização de Performance para Rocky Linux 10
# =============================================================================
# Descrição: Otimizações completas de sistema e performance
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
CONFIG_FILE="/etc/performance-tuning.conf"
LOG_FILE="/var/log/performance-tuning.log"
BACKUP_DIR="/var/backups/performance-$(date +%Y%m%d_%H%M%S)"

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

# Detectar hardware
detect_hardware() {
    # Memória
    TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
    
    # CPU
    CPU_CORES=$(nproc)
    CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    
    # Storage
    STORAGE_TYPE="unknown"
    if lsblk -d -o name,rota | grep -q "0$"; then
        STORAGE_TYPE="ssd"
    else
        STORAGE_TYPE="hdd"
    fi
    
    # Virtualização
    VIRTUALIZATION=$(systemd-detect-virt 2>/dev/null || echo "none")
    
    print_info "Sistema detectado:"
    echo "  • RAM: ${TOTAL_RAM}MB"
    echo "  • CPU: $CPU_MODEL ($CPU_CORES cores)"
    echo "  • Storage: $STORAGE_TYPE"
    echo "  • Virtualização: $VIRTUALIZATION"
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações de Performance Tuning

# Configurações de memória
ENABLE_SWAPPINESS_TUNING=true
SWAPPINESS_VALUE=10
ENABLE_TRANSPARENT_HUGEPAGES=false
ENABLE_ZRAM=false

# Configurações de CPU
ENABLE_CPU_GOVERNOR=true
CPU_GOVERNOR="performance"
ENABLE_TURBO_BOOST=true
ENABLE_CPU_MITIGATIONS=false

# Configurações de I/O
ENABLE_IO_SCHEDULER=true
SSD_SCHEDULER="mq-deadline"
HDD_SCHEDULER="bfq"
ENABLE_READAHEAD=true
READAHEAD_VALUE=4096

# Configurações de rede
ENABLE_NETWORK_TUNING=true
TCP_WINDOW_SCALING=true
TCP_CONGESTION_CONTROL="bbr"
NETWORK_BUFFER_SIZE=16777216

# Configurações de kernel
ENABLE_KERNEL_TUNING=true
DIRTY_RATIO=15
DIRTY_BACKGROUND_RATIO=5
VFS_CACHE_PRESSURE=50

# Configurações de banco de dados
ENABLE_DATABASE_TUNING=true
MYSQL_TUNING=true
POSTGRES_TUNING=true

# Configurações específicas
WORKLOAD_TYPE="general"  # general, web, database, desktop
ENABLE_MONITORING=true
ENABLE_AUTOMATIC_TUNING=false
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Backup de configurações
create_backup() {
    print_info "Criando backup de configurações..."
    mkdir -p "$BACKUP_DIR"
    
    local files_to_backup=(
        "/etc/sysctl.conf"
        "/etc/systemd/system.conf"
        "/etc/security/limits.conf"
        "/etc/fstab"
        "/sys/block/*/queue/scheduler"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ]; then
            cp -r "$file" "$BACKUP_DIR/" 2>/dev/null
        fi
    done
    
    # Salvar configurações atuais
    sysctl -a > "$BACKUP_DIR/current-sysctl.conf" 2>/dev/null
    
    print_success "Backup criado em: $BACKUP_DIR"
    log_action "Backup de configurações criado"
}

# Otimizações de memória
optimize_memory() {
    print_header "💾 Otimizando Memória"
    
    if [ "$ENABLE_SWAPPINESS_TUNING" = "true" ]; then
        print_info "Configurando swappiness para $SWAPPINESS_VALUE"
        echo "vm.swappiness = $SWAPPINESS_VALUE" >> /etc/sysctl.conf
        sysctl vm.swappiness="$SWAPPINESS_VALUE"
    fi
    
    # Transparent Huge Pages
    if [ "$ENABLE_TRANSPARENT_HUGEPAGES" = "true" ]; then
        echo "vm.transparent_hugepage_enabled = 1" >> /etc/sysctl.conf
        print_info "Transparent Huge Pages habilitadas"
    else
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo "vm.transparent_hugepage_enabled = 0" >> /etc/sysctl.conf
        print_info "Transparent Huge Pages desabilitadas"
    fi
    
    # Configurações gerais de memória baseadas na RAM total
    cat >> /etc/sysctl.conf << EOF

# Otimizações de memória
vm.dirty_ratio = $DIRTY_RATIO
vm.dirty_background_ratio = $DIRTY_BACKGROUND_RATIO
vm.vfs_cache_pressure = $VFS_CACHE_PRESSURE
vm.min_free_kbytes = $((TOTAL_RAM * 1024 / 20))
vm.overcommit_memory = 1
vm.overcommit_ratio = 50

EOF
    
    # Configurar ZRAM se habilitado
    if [ "$ENABLE_ZRAM" = "true" ] && [ "$TOTAL_RAM" -lt 8192 ]; then
        setup_zram
    fi
    
    print_success "Otimizações de memória aplicadas"
    log_action "Otimizações de memória configuradas"
}

# Configurar ZRAM
setup_zram() {
    print_info "Configurando ZRAM..."
    
    # Instalar zram-generator se não estiver presente
    if ! command -v zramctl &> /dev/null; then
        dnf install -y util-linux
    fi
    
    # Criar configuração do ZRAM
    cat > /etc/systemd/zram-generator.conf << EOF
[zram0]
zram-fraction = 0.5
max-zram-size = 4096
compression-algorithm = lz4
EOF
    
    systemctl daemon-reload
    systemctl enable systemd-zram-setup@zram0.service
    
    print_success "ZRAM configurado"
}

# Otimizações de CPU
optimize_cpu() {
    print_header "⚡ Otimizando CPU"
    
    if [ "$ENABLE_CPU_GOVERNOR" = "true" ]; then
        print_info "Configurando governor para $CPU_GOVERNOR"
        
        # Instalar cpupower se necessário
        if ! command -v cpupower &> /dev/null; then
            dnf install -y kernel-tools
        fi
        
        # Configurar governor
        echo "$CPU_GOVERNOR" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || true
        
        # Criar serviço para persistir configuração
        cat > /etc/systemd/system/cpu-performance.service << EOF
[Unit]
Description=Set CPU Governor to $CPU_GOVERNOR
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo $CPU_GOVERNOR > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl enable cpu-performance.service
    fi
    
    # Turbo boost
    if [ "$ENABLE_TURBO_BOOST" = "true" ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        print_info "Turbo boost habilitado"
    fi
    
    # Mitigações de CPU (desabilitar para performance máxima)
    if [ "$ENABLE_CPU_MITIGATIONS" = "false" ]; then
        if ! grep -q "mitigations=off" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="mitigations=off /' /etc/default/grub
            grub2-mkconfig -o /boot/grub2/grub.cfg
            print_warning "Mitigações de CPU desabilitadas. Reinicialização necessária."
        fi
    fi
    
    print_success "Otimizações de CPU aplicadas"
    log_action "CPU otimizada para performance"
}

# Otimizações de I/O
optimize_io() {
    print_header "💽 Otimizando I/O"
    
    if [ "$ENABLE_IO_SCHEDULER" = "true" ]; then
        print_info "Configurando I/O scheduler..."
        
        # Detectar discos e aplicar scheduler apropriado
        for disk in $(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$|^nvme'); do
            local scheduler
            if [ "$STORAGE_TYPE" = "ssd" ]; then
                scheduler="$SSD_SCHEDULER"
            else
                scheduler="$HDD_SCHEDULER"
            fi
            
            echo "$scheduler" > "/sys/block/$disk/queue/scheduler" 2>/dev/null
            print_info "Scheduler $scheduler aplicado ao disco $disk"
        done
        
        # Persistir configuração
        cat > /etc/udev/rules.d/60-io-scheduler.rules << EOF
# Configuração automática de I/O scheduler
KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="$SSD_SCHEDULER"
KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="$HDD_SCHEDULER"
KERNEL=="nvme*", ATTR{queue/scheduler}="$SSD_SCHEDULER"
EOF
    fi
    
    # Readahead
    if [ "$ENABLE_READAHEAD" = "true" ]; then
        print_info "Configurando readahead para $READAHEAD_VALUE"
        for disk in $(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$'); do
            echo "$READAHEAD_VALUE" > "/sys/block/$disk/queue/read_ahead_kb" 2>/dev/null
        done
    fi
    
    # Configurações gerais de I/O
    cat >> /etc/sysctl.conf << EOF

# Otimizações de I/O
vm.dirty_expire_centisecs = 500
vm.dirty_writeback_centisecs = 100
kernel.sched_min_granularity_ns = 10000000
kernel.sched_wakeup_granularity_ns = 15000000

EOF
    
    print_success "Otimizações de I/O aplicadas"
    log_action "I/O otimizado para o tipo de storage: $STORAGE_TYPE"
}

# Otimizações de rede
optimize_network() {
    if [ "$ENABLE_NETWORK_TUNING" != "true" ]; then
        return 0
    fi
    
    print_header "🌐 Otimizando Rede"
    
    cat >> /etc/sysctl.conf << EOF

# Otimizações de rede
net.core.rmem_default = $NETWORK_BUFFER_SIZE
net.core.rmem_max = $NETWORK_BUFFER_SIZE
net.core.wmem_default = $NETWORK_BUFFER_SIZE
net.core.wmem_max = $NETWORK_BUFFER_SIZE
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600

# TCP optimizations
net.ipv4.tcp_rmem = 4096 $NETWORK_BUFFER_SIZE $NETWORK_BUFFER_SIZE
net.ipv4.tcp_wmem = 4096 65536 $NETWORK_BUFFER_SIZE
net.ipv4.tcp_congestion_control = $TCP_CONGESTION_CONTROL
net.ipv4.tcp_window_scaling = $([ "$TCP_WINDOW_SCALING" = "true" ] && echo 1 || echo 0)
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_adv_win_scale = 2

# Buffer sizes
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

EOF
    
    # Configurar BBR se disponível
    if modprobe tcp_bbr 2>/dev/null; then
        echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
        print_info "TCP BBR habilitado"
    fi
    
    print_success "Otimizações de rede aplicadas"
    log_action "Rede otimizada com TCP $TCP_CONGESTION_CONTROL"
}

# Otimizações específicas por workload
optimize_workload() {
    print_header "🎯 Otimizações para Workload: $WORKLOAD_TYPE"
    
    case "$WORKLOAD_TYPE" in
        "web")
            optimize_web_server
            ;;
        "database")
            optimize_database
            ;;
        "desktop")
            optimize_desktop
            ;;
        "general")
            optimize_general
            ;;
        *)
            print_warning "Tipo de workload desconhecido: $WORKLOAD_TYPE"
            ;;
    esac
}

# Otimizações para servidor web
optimize_web_server() {
    print_info "Aplicando otimizações para servidor web..."
    
    cat >> /etc/sysctl.conf << 'EOF'

# Otimizações para servidor web
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
EOF

    # Aumentar limites de file descriptors
    cat >> /etc/security/limits.conf << 'EOF'

# Limites para servidor web
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

    print_success "Otimizações para servidor web aplicadas"
}

# Otimizações para banco de dados
optimize_database() {
    print_info "Aplicando otimizações para banco de dados..."
    
    cat >> /etc/sysctl.conf << EOF

# Otimizações para banco de dados
kernel.shmmax = $((TOTAL_RAM * 1024 * 1024 * 3 / 4))
kernel.shmall = $((TOTAL_RAM * 1024 / 4))
kernel.shmmni = 4096
vm.swappiness = 1
vm.dirty_ratio = 3
vm.dirty_background_ratio = 1
EOF

    # Configurar transparent huge pages
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    
    print_success "Otimizações para banco de dados aplicadas"
}

# Otimizações para desktop
optimize_desktop() {
    print_info "Aplicando otimizações para desktop..."
    
    cat >> /etc/sysctl.conf << 'EOF'

# Otimizações para desktop
vm.swappiness = 10
vm.vfs_cache_pressure = 50
kernel.sched_autogroup_enabled = 1
kernel.sched_migration_cost_ns = 5000000
EOF

    print_success "Otimizações para desktop aplicadas"
}

# Otimizações gerais
optimize_general() {
    print_info "Aplicando otimizações gerais..."
    
    cat >> /etc/sysctl.conf << 'EOF'

# Otimizações gerais
kernel.pid_max = 4194304
fs.file-max = 1000000
fs.nr_open = 1000000
kernel.threads-max = 4194304
EOF

    print_success "Otimizações gerais aplicadas"
}

# Instalar ferramentas de monitoramento
setup_monitoring() {
    if [ "$ENABLE_MONITORING" != "true" ]; then
        return 0
    fi
    
    print_header "📊 Configurando Monitoramento"
    
    # Instalar htop, iotop, nethogs
    dnf install -y htop iotop nethogs sysstat
    
    # Habilitar coleta de estatísticas
    systemctl enable --now sysstat
    
    # Criar script de monitoramento personalizado
    cat > /usr/local/bin/system-monitor << 'EOF'
#!/bin/bash

# Monitoramento contínuo do sistema
echo "=== System Performance Monitor ==="
echo "Timestamp: $(date)"
echo

# CPU
echo "CPU Usage:"
grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4+$5)} END {print usage "%"}'
echo

# Memory
echo "Memory Usage:"
free -h
echo

# Disk I/O
echo "Disk I/O:"
iostat -x 1 1 | grep -E '^(Device|[sv]d[a-z]|nvme)'
echo

# Network
echo "Network Traffic:"
ss -tuln | grep LISTEN | wc -l | awk '{print "Listening ports: " $1}'
echo

# Top processes by CPU
echo "Top CPU processes:"
ps aux --sort=-%cpu | head -5
echo

# Top processes by Memory
echo "Top Memory processes:"
ps aux --sort=-%mem | head -5
EOF

    chmod +x /usr/local/bin/system-monitor
    
    print_success "Ferramentas de monitoramento instaladas"
    log_action "Monitoramento configurado"
}

# Aplicar todas as configurações
apply_configurations() {
    print_info "Aplicando configurações do kernel..."
    
    # Aplicar sysctl
    sysctl -p
    
    # Recarregar systemd
    systemctl daemon-reload
    
    # Aplicar limites
    if command -v systemctl &> /dev/null; then
        systemctl restart systemd-logind 2>/dev/null || true
    fi
    
    print_success "Configurações aplicadas"
    log_action "Todas as configurações de performance aplicadas"
}

# Benchmark básico
run_benchmark() {
    print_header "🏃 Executando Benchmark Básico"
    
    # CPU benchmark
    print_info "Testando performance da CPU..."
    if command -v sysbench &> /dev/null; then
        sysbench --test=cpu --cpu-max-prime=20000 run | grep "total time:"
    else
        # Benchmark simples com dd
        dd if=/dev/zero of=/tmp/benchmark bs=1M count=1024 2>&1 | grep copied
        rm -f /tmp/benchmark
    fi
    
    # Memory benchmark
    print_info "Testando latência da memória..."
    if command -v sysbench &> /dev/null; then
        sysbench --test=memory run | grep "total time:"
    fi
    
    # Disk I/O benchmark
    print_info "Testando I/O do disco..."
    sync && echo 3 > /proc/sys/vm/drop_caches
    dd if=/dev/zero of=/tmp/iobench bs=1M count=1024 conv=fdatasync 2>&1 | grep copied
    rm -f /tmp/iobench
    
    print_success "Benchmark concluído"
}

# Verificar melhorias
check_improvements() {
    print_header "📈 Verificando Melhorias"
    echo
    
    # Verificar configurações aplicadas
    print_info "Configurações aplicadas:"
    echo "  • Swappiness: $(cat /proc/sys/vm/swappiness)"
    echo "  • Dirty ratio: $(cat /proc/sys/vm/dirty_ratio)"
    echo "  • TCP congestion: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
    
    # Verificar schedulers
    print_info "I/O Schedulers:"
    for disk in $(lsblk -d -o name -n | grep -E '^[sv]d[a-z]$'); do
        local scheduler=$(cat /sys/block/$disk/queue/scheduler | grep -o '\[.*\]' | tr -d '[]')
        echo "  • $disk: $scheduler"
    done
    
    # Status da memória
    print_info "Status da memória:"
    free -h | grep -E "(Mem|Swap)"
    
    # Load average
    print_info "Load average:"
    uptime | awk -F'load average:' '{print $2}'
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                Performance Tuning                             ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🚀 Otimização completa                                    ║"
    echo "║  2. 💾 Otimizar memória                                       ║"
    echo "║  3. ⚡ Otimizar CPU                                           ║"
    echo "║  4. 💽 Otimizar I/O                                          ║"
    echo "║  5. 🌐 Otimizar rede                                         ║"
    echo "║  6. 🎯 Otimizar por workload                                 ║"
    echo "║  7. 📊 Configurar monitoramento                              ║"
    echo "║  8. 🏃 Executar benchmark                                    ║"
    echo "║  9. 📈 Verificar melhorias                                   ║"
    echo "║  10. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_performance() {
    print_header "⚙️ Configurações de Performance"
    echo
    
    print_info "Configurações atuais:"
    echo "  • Workload: $WORKLOAD_TYPE"
    echo "  • CPU Governor: $CPU_GOVERNOR"
    echo "  • Swappiness: $SWAPPINESS_VALUE"
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
    detect_hardware
    create_config
    
    case "${1:-}" in
        "full")
            create_backup
            optimize_memory && optimize_cpu && optimize_io && optimize_network
            optimize_workload && setup_monitoring && apply_configurations
            ;;
        "memory")
            create_backup && optimize_memory && apply_configurations
            ;;
        "cpu")
            create_backup && optimize_cpu && apply_configurations
            ;;
        "io")
            create_backup && optimize_io && apply_configurations
            ;;
        "network")
            optimize_network && apply_configurations
            ;;
        "benchmark")
            run_benchmark
            ;;
        "check")
            check_improvements
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-10): " choice
                
                case $choice in
                    1)
                        create_backup
                        optimize_memory && optimize_cpu && optimize_io && optimize_network
                        optimize_workload && setup_monitoring && apply_configurations
                        print_success "Otimização completa aplicada!"
                        ;;
                    2) create_backup && optimize_memory && apply_configurations ;;
                    3) create_backup && optimize_cpu && apply_configurations ;;
                    4) create_backup && optimize_io && apply_configurations ;;
                    5) optimize_network && apply_configurations ;;
                    6) optimize_workload && apply_configurations ;;
                    7) setup_monitoring ;;
                    8) run_benchmark ;;
                    9) check_improvements ;;
                    10) configure_performance ;;
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