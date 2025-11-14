#!/bin/bash

# =============================================================================
# Gerenciador de Scripts do Sistema Rocky Linux 10
# =============================================================================
# Descrição: Interface centralizada para execução e gerenciamento de scripts
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
WHITE='\033[1;37m'
NC='\033[0m'

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/etc/scripts-manager.conf"
LOG_FILE="/var/log/scripts-manager.log"
LOCK_FILE="/tmp/scripts-manager.lock"

# Diretórios de scripts
SYSTEM_SCRIPTS_DIR="$SCRIPT_DIR/system"
MONITORING_SCRIPTS_DIR="$SCRIPT_DIR/monitoring"
NETWORK_SCRIPTS_DIR="$SCRIPT_DIR/network"

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }
print_title() { echo -e "${WHITE}$1${NC}"; }

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este gerenciador deve ser executado como root!"
        exit 1
    fi
}

# Verificar lock
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            print_error "Outro gerenciador já está em execução (PID: $lock_pid)"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Remover lock
remove_lock() {
    rm -f "$LOCK_FILE"
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações do Scripts Manager

# Configurações de logging
LOG_LEVEL="INFO"
LOG_RETENTION_DAYS=30
ENABLE_DETAILED_LOGGING=true

# Configurações de execução
CONFIRM_DANGEROUS_OPERATIONS=true
AUTO_UPDATE_SCRIPTS=false
BACKUP_BEFORE_EXECUTION=true

# Configurações de notificação
ENABLE_EMAIL_NOTIFICATIONS=false
ADMIN_EMAIL="admin@example.com"
SMTP_SERVER="localhost"

# Configurações de agendamento
ENABLE_SCHEDULED_TASKS=true
HEALTH_CHECK_INTERVAL="*/30 * * * *"
BACKUP_SCHEDULE="0 2 * * *"
UPDATE_SCHEDULE="0 4 * * 0"

# Configurações de monitoramento
ENABLE_PERFORMANCE_MONITORING=true
RESOURCE_USAGE_THRESHOLD=80
DISK_USAGE_THRESHOLD=85
MEMORY_USAGE_THRESHOLD=90

# Scripts habilitados
ENABLE_SYSTEM_SCRIPTS=true
ENABLE_MONITORING_SCRIPTS=true
ENABLE_NETWORK_SCRIPTS=true

# Configurações de segurança
REQUIRE_SUDO_PASSWORD=false
ENABLE_AUDIT_LOG=true
SESSION_TIMEOUT=3600
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Verificar dependências
check_dependencies() {
    local missing_deps=()
    
    # Verificar scripts essenciais
    for script_dir in "$SYSTEM_SCRIPTS_DIR" "$MONITORING_SCRIPTS_DIR" "$NETWORK_SCRIPTS_DIR"; do
        if [ ! -d "$script_dir" ]; then
            missing_deps+=("Diretório não encontrado: $script_dir")
        fi
    done
    
    # Verificar comandos essenciais
    local required_commands=("systemctl" "journalctl" "iptables" "grep" "awk" "sed")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("Comando não encontrado: $cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dependências em falta:"
        for dep in "${missing_deps[@]}"; do
            echo "  • $dep"
        done
        return 1
    fi
    
    return 0
}

# Listar scripts disponíveis
list_scripts() {
    local category="$1"
    local script_dir=""
    
    case "$category" in
        "system") script_dir="$SYSTEM_SCRIPTS_DIR" ;;
        "monitoring") script_dir="$MONITORING_SCRIPTS_DIR" ;;
        "network") script_dir="$NETWORK_SCRIPTS_DIR" ;;
        *) 
            print_error "Categoria inválida: $category"
            return 1
            ;;
    esac
    
    if [ ! -d "$script_dir" ]; then
        print_warning "Diretório não encontrado: $script_dir"
        return 1
    fi
    
    local scripts=($(find "$script_dir" -name "*.sh" -type f -executable 2>/dev/null))
    
    if [ ${#scripts[@]} -eq 0 ]; then
        print_warning "Nenhum script encontrado em: $script_dir"
        return 1
    fi
    
    for script in "${scripts[@]}"; do
        local script_name=$(basename "$script" .sh)
        local script_desc=""
        
        # Tentar extrair descrição do script
        if [ -f "$script" ]; then
            script_desc=$(grep -m1 "^# Descrição:" "$script" 2>/dev/null | cut -d':' -f2- | xargs)
        fi
        
        echo "$script_name|${script_desc:-'Sem descrição disponível'}|$script"
    done
}

# Executar script
execute_script() {
    local script_path="$1"
    local script_args="${2:-}"
    
    if [ ! -f "$script_path" ]; then
        print_error "Script não encontrado: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        print_error "Script não é executável: $script_path"
        return 1
    fi
    
    local script_name=$(basename "$script_path")
    
    print_info "Executando script: $script_name"
    log_action "Executing script: $script_name with args: $script_args"
    
    # Backup se habilitado
    if [ "$BACKUP_BEFORE_EXECUTION" = "true" ]; then
        create_execution_backup "$script_name"
    fi
    
    # Executar script
    local start_time=$(date +%s)
    
    if [ -n "$script_args" ]; then
        bash "$script_path" $script_args
    else
        bash "$script_path"
    fi
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        print_success "Script executado com sucesso em ${duration}s"
        log_action "Script '$script_name' completed successfully in ${duration}s"
    else
        print_error "Script falhou com código: $exit_code (duração: ${duration}s)"
        log_action "Script '$script_name' failed with exit code $exit_code in ${duration}s"
    fi
    
    return $exit_code
}

# Backup de execução
create_execution_backup() {
    local script_name="$1"
    local backup_dir="/var/backups/scripts-manager"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    # Backup de configurações importantes
    local backup_file="$backup_dir/${script_name}_${timestamp}.tar.gz"
    
    tar -czf "$backup_file" \
        /etc/passwd /etc/group /etc/hosts \
        /etc/systemd/system/*.service \
        /etc/firewalld/ \
        /etc/sysctl.conf \
        2>/dev/null || true
    
    print_info "Backup criado: $backup_file"
}

# Menu de scripts do sistema
system_scripts_menu() {
    while true; do
        clear
        print_title "╔════════════════════════════════════════════════════════════════╗"
        print_title "║                      Scripts do Sistema                       ║"
        print_title "╚════════════════════════════════════════════════════════════════╝"
        echo
        
        local scripts_info=($(list_scripts "system"))
        
        if [ ${#scripts_info[@]} -eq 0 ]; then
            print_warning "Nenhum script de sistema disponível"
            read -p "Pressione Enter para voltar..."
            return
        fi
        
        local counter=1
        local script_paths=()
        
        for script_info in "${scripts_info[@]}"; do
            IFS='|' read -r script_name script_desc script_path <<< "$script_info"
            echo "  $counter. 📁 $script_name"
            echo "     $script_desc"
            script_paths+=("$script_path")
            counter=$((counter + 1))
            echo
        done
        
        echo "  0. ⬅️  Voltar ao menu principal"
        echo
        
        read -p "Escolha uma opção (0-$((counter-1))): " choice
        
        if [ "$choice" = "0" ]; then
            break
        elif [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
            local selected_script="${script_paths[$((choice-1))]}"
            echo
            execute_script "$selected_script"
            echo
            read -p "Pressione Enter para continuar..."
        else
            print_error "Opção inválida!"
            sleep 1
        fi
    done
}

# Menu de scripts de monitoramento
monitoring_scripts_menu() {
    while true; do
        clear
        print_title "╔════════════════════════════════════════════════════════════════╗"
        print_title "║                   Scripts de Monitoramento                    ║"
        print_title "╚════════════════════════════════════════════════════════════════╝"
        echo
        
        local scripts_info=($(list_scripts "monitoring"))
        
        if [ ${#scripts_info[@]} -eq 0 ]; then
            print_warning "Nenhum script de monitoramento disponível"
            read -p "Pressione Enter para voltar..."
            return
        fi
        
        local counter=1
        local script_paths=()
        
        for script_info in "${scripts_info[@]}"; do
            IFS='|' read -r script_name script_desc script_path <<< "$script_info"
            echo "  $counter. 📊 $script_name"
            echo "     $script_desc"
            script_paths+=("$script_path")
            counter=$((counter + 1))
            echo
        done
        
        echo "  0. ⬅️  Voltar ao menu principal"
        echo
        
        read -p "Escolha uma opção (0-$((counter-1))): " choice
        
        if [ "$choice" = "0" ]; then
            break
        elif [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
            local selected_script="${script_paths[$((choice-1))]}"
            echo
            execute_script "$selected_script"
            echo
            read -p "Pressione Enter para continuar..."
        else
            print_error "Opção inválida!"
            sleep 1
        fi
    done
}

# Menu de scripts de rede
network_scripts_menu() {
    while true; do
        clear
        print_title "╔════════════════════════════════════════════════════════════════╗"
        print_title "║                      Scripts de Rede                         ║"
        print_title "╚════════════════════════════════════════════════════════════════╝"
        echo
        
        local scripts_info=($(list_scripts "network"))
        
        if [ ${#scripts_info[@]} -eq 0 ]; then
            print_warning "Nenhum script de rede disponível"
            read -p "Pressione Enter para voltar..."
            return
        fi
        
        local counter=1
        local script_paths=()
        
        for script_info in "${scripts_info[@]}"; do
            IFS='|' read -r script_name script_desc script_path <<< "$script_info"
            echo "  $counter. 🌐 $script_name"
            echo "     $script_desc"
            script_paths+=("$script_path")
            counter=$((counter + 1))
            echo
        done
        
        echo "  0. ⬅️  Voltar ao menu principal"
        echo
        
        read -p "Escolha uma opção (0-$((counter-1))): " choice
        
        if [ "$choice" = "0" ]; then
            break
        elif [ "$choice" -ge 1 ] && [ "$choice" -lt "$counter" ]; then
            local selected_script="${script_paths[$((choice-1))]}"
            echo
            execute_script "$selected_script"
            echo
            read -p "Pressione Enter para continuar..."
        else
            print_error "Opção inválida!"
            sleep 1
        fi
    done
}

# Status do sistema
show_system_status() {
    clear
    print_title "╔════════════════════════════════════════════════════════════════╗"
    print_title "║                       Status do Sistema                       ║"
    print_title "╚════════════════════════════════════════════════════════════════╝"
    echo
    
    # Informações básicas do sistema
    print_header "📋 Informações do Sistema:"
    echo "  🖥️  Hostname: $(hostname)"
    echo "  🐧 OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
    echo "  🔧 Kernel: $(uname -r)"
    echo "  ⏰ Uptime: $(uptime -p)"
    echo "  👤 Usuário: $(whoami)"
    echo
    
    # Status de recursos
    print_header "📊 Uso de Recursos:"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "  🔥 CPU: ${cpu_usage}%"
    
    # Memória
    local mem_info=$(free | grep "Mem:")
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))
    echo "  🧠 Memória: $mem_percent% ($(numfmt --to=iec $((mem_used * 1024))) / $(numfmt --to=iec $((mem_total * 1024))))"
    
    # Disco
    echo "  💾 Disco:"
    df -h | grep -E '^/dev' | while read filesystem size used avail percent mount; do
        echo "     $mount: $percent ($used / $size)"
    done
    echo
    
    # Serviços importantes
    print_header "🔧 Status dos Serviços:"
    local services=("sshd" "firewalld" "chronyd" "NetworkManager")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "$service: Ativo"
        else
            print_error "$service: Inativo"
        fi
    done
    echo
    
    # Últimas execuções de scripts
    if [ -f "$LOG_FILE" ]; then
        print_header "📈 Últimas Execuções:"
        tail -5 "$LOG_FILE" | while read line; do
            echo "  📝 $line"
        done
    fi
}

# Configurações avançadas
advanced_settings() {
    while true; do
        clear
        print_title "╔════════════════════════════════════════════════════════════════╗"
        print_title "║                   Configurações Avançadas                     ║"
        print_title "╚════════════════════════════════════════════════════════════════╝"
        echo
        
        echo "  1. ⚙️  Editar configurações"
        echo "  2. 📅 Gerenciar agendamentos"
        echo "  3. 📧 Configurar notificações"
        echo "  4. 🗂️  Gerenciar logs"
        echo "  5. 🔐 Configurações de segurança"
        echo "  6. 🧹 Limpeza do sistema"
        echo "  7. 📋 Relatórios detalhados"
        echo "  0. ⬅️  Voltar"
        echo
        
        read -p "Escolha uma opção (0-7): " choice
        
        case $choice in
            1) edit_config ;;
            2) manage_schedules ;;
            3) configure_notifications ;;
            4) manage_logs ;;
            5) security_settings ;;
            6) system_cleanup ;;
            7) detailed_reports ;;
            0) break ;;
            *) print_error "Opção inválida!" && sleep 1 ;;
        esac
    done
}

# Editar configurações
edit_config() {
    print_header "⚙️ Editando Configurações"
    echo
    
    print_info "Arquivo de configuração: $CONFIG_FILE"
    ${EDITOR:-nano} "$CONFIG_FILE"
    
    # Recarregar configurações
    source "$CONFIG_FILE"
    print_success "Configurações recarregadas"
    
    read -p "Pressione Enter para continuar..."
}

# Gerenciar agendamentos
manage_schedules() {
    print_header "📅 Gerenciamento de Agendamentos"
    echo
    
    echo "Cron jobs atuais para scripts-manager:"
    crontab -l | grep "scripts-manager" || print_info "Nenhum agendamento configurado"
    echo
    
    echo "Deseja configurar agendamentos automáticos? (s/N): "
    read setup_cron
    
    if [[ $setup_cron =~ ^[SsYy]$ ]]; then
        # Backup diário
        echo "0 2 * * * $SCRIPT_DIR/system/backup-system.sh" >> /tmp/new_crontab
        
        # Health check a cada 30 minutos
        echo "*/30 * * * * $SCRIPT_DIR/monitoring/health-check.sh" >> /tmp/new_crontab
        
        # Update semanal
        echo "0 4 * * 0 $SCRIPT_DIR/system/update-system.sh" >> /tmp/new_crontab
        
        crontab /tmp/new_crontab
        rm /tmp/new_crontab
        
        print_success "Agendamentos configurados"
    fi
    
    read -p "Pressione Enter para continuar..."
}

# Configurar notificações
configure_notifications() {
    print_header "📧 Configuração de Notificações"
    echo
    
    if [ "$ENABLE_EMAIL_NOTIFICATIONS" = "true" ]; then
        print_success "Notificações por email habilitadas"
        echo "  📧 Email: $ADMIN_EMAIL"
        echo "  📬 SMTP: $SMTP_SERVER"
    else
        print_warning "Notificações por email desabilitadas"
    fi
    
    echo
    read -p "Deseja configurar notificações? (s/N): " config_notif
    
    if [[ $config_notif =~ ^[SsYy]$ ]]; then
        read -p "Email do administrador: " admin_email
        read -p "Servidor SMTP: " smtp_server
        
        # Atualizar configuração
        sed -i "s/ADMIN_EMAIL=.*/ADMIN_EMAIL=\"$admin_email\"/" "$CONFIG_FILE"
        sed -i "s/SMTP_SERVER=.*/SMTP_SERVER=\"$smtp_server\"/" "$CONFIG_FILE"
        sed -i "s/ENABLE_EMAIL_NOTIFICATIONS=.*/ENABLE_EMAIL_NOTIFICATIONS=true/" "$CONFIG_FILE"
        
        print_success "Notificações configuradas"
    fi
    
    read -p "Pressione Enter para continuar..."
}

# Gerenciar logs
manage_logs() {
    print_header "🗂️ Gerenciamento de Logs"
    echo
    
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" | cut -f1)
        local log_lines=$(wc -l < "$LOG_FILE")
        
        echo "  📊 Arquivo: $LOG_FILE"
        echo "  📏 Tamanho: $log_size"
        echo "  📄 Linhas: $log_lines"
        echo
        
        echo "Opções:"
        echo "  1. Visualizar logs recentes"
        echo "  2. Limpar logs antigos"
        echo "  3. Exportar logs"
        echo "  0. Voltar"
        echo
        
        read -p "Escolha uma opção: " log_choice
        
        case $log_choice in
            1)
                echo
                print_info "Últimas 50 linhas:"
                tail -50 "$LOG_FILE"
                ;;
            2)
                find "$(dirname "$LOG_FILE")" -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete
                print_success "Logs antigos removidos"
                ;;
            3)
                local export_file="/tmp/scripts-manager-logs-$(date +%Y%m%d).txt"
                cp "$LOG_FILE" "$export_file"
                print_success "Logs exportados para: $export_file"
                ;;
        esac
    else
        print_warning "Arquivo de log não encontrado"
    fi
    
    read -p "Pressione Enter para continuar..."
}

# Configurações de segurança
security_settings() {
    print_header "🔐 Configurações de Segurança"
    echo
    
    echo "Status atual:"
    echo "  🔒 Audit log: $([ "$ENABLE_AUDIT_LOG" = "true" ] && echo "Habilitado" || echo "Desabilitado")"
    echo "  🔑 Senha sudo: $([ "$REQUIRE_SUDO_PASSWORD" = "true" ] && echo "Obrigatória" || echo "Não obrigatória")"
    echo "  ⏱️  Timeout: ${SESSION_TIMEOUT}s"
    echo
    
    echo "Verificações de segurança:"
    
    # Verificar permissões dos scripts
    print_info "Verificando permissões dos scripts..."
    find "$SCRIPT_DIR" -name "*.sh" -not -perm 755 | while read script; do
        print_warning "Permissão incorreta: $script"
    done
    
    # Verificar propriedade
    print_info "Verificando propriedade dos arquivos..."
    find "$SCRIPT_DIR" -not -user root | while read file; do
        print_warning "Propriedade incorreta: $file"
    done
    
    read -p "Pressione Enter para continuar..."
}

# Limpeza do sistema
system_cleanup() {
    print_header "🧹 Limpeza do Sistema"
    echo
    
    print_info "Executando limpeza..."
    
    # Limpar logs antigos
    local cleaned=0
    
    # Logs do sistema
    if [ -d "/var/log" ]; then
        find /var/log -name "*.log" -mtime +30 -size +100M -exec truncate -s 0 {} \; 2>/dev/null
        cleaned=$((cleaned + 1))
    fi
    
    # Cache de pacotes
    if command -v dnf &> /dev/null; then
        dnf clean all &>/dev/null
        cleaned=$((cleaned + 1))
    fi
    
    # Arquivos temporários
    find /tmp -mtime +7 -delete 2>/dev/null || true
    cleaned=$((cleaned + 1))
    
    print_success "Limpeza concluída ($cleaned operações)"
    
    read -p "Pressione Enter para continuar..."
}

# Relatórios detalhados
detailed_reports() {
    print_header "📋 Relatórios Detalhados"
    echo
    
    local report_file="/tmp/system-report-$(date +%Y%m%d_%H%M%S).txt"
    
    print_info "Gerando relatório detalhado..."
    
    {
        echo "RELATÓRIO DO SISTEMA - $(date)"
        echo "================================="
        echo
        
        echo "HARDWARE:"
        lscpu | head -10
        echo
        
        echo "MEMÓRIA:"
        free -h
        echo
        
        echo "DISCOS:"
        df -h
        echo
        
        echo "REDE:"
        ip addr show
        echo
        
        echo "SERVIÇOS ATIVOS:"
        systemctl list-units --state=active --type=service | head -20
        echo
        
        echo "LOGS RECENTES:"
        journalctl --since "1 hour ago" | tail -50
        
    } > "$report_file"
    
    print_success "Relatório salvo em: $report_file"
    
    read -p "Deseja visualizar o relatório? (s/N): " view_report
    if [[ $view_report =~ ^[SsYy]$ ]]; then
        less "$report_file"
    fi
    
    read -p "Pressione Enter para continuar..."
}

# Menu principal
show_main_menu() {
    clear
    print_title "╔════════════════════════════════════════════════════════════════╗"
    print_title "║                  Scripts Manager - Rocky Linux 10             ║"
    print_title "║                     Gerenciador de Scripts                     ║"
    print_title "╠════════════════════════════════════════════════════════════════╣"
    echo "║                                                                ║"
    echo "║  1. 📁 Scripts do Sistema                                      ║"
    echo "║  2. 📊 Scripts de Monitoramento                                ║"
    echo "║  3. 🌐 Scripts de Rede                                         ║"
    echo "║  4. 📈 Status do Sistema                                       ║"
    echo "║  5. ⚙️  Configurações Avançadas                                ║"
    echo "║  6. 📋 Logs e Relatórios                                       ║"
    echo "║  7. ℹ️  Ajuda                                                   ║"
    echo "║  0. ❌ Sair                                                     ║"
    echo "║                                                                ║"
    print_title "╚════════════════════════════════════════════════════════════════╝"
    echo
    
    # Mostrar status rápido
    local mem_usage=$(free | grep "Mem:" | awk '{printf "%.0f", $3/$2 * 100}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo "  💡 Status: CPU: $(uptime | awk '{print $NF}') | RAM: ${mem_usage}% | Disco: ${disk_usage}%"
    echo
}

# Ajuda
show_help() {
    clear
    print_title "╔════════════════════════════════════════════════════════════════╗"
    print_title "║                           Ajuda                               ║"
    print_title "╚════════════════════════════════════════════════════════════════╝"
    echo
    
    echo "📖 DESCRIÇÃO:"
    echo "   O Scripts Manager é uma interface centralizada para gerenciar"
    echo "   todos os scripts de administração do Rocky Linux 10."
    echo
    
    echo "📁 ESTRUTURA DE DIRETÓRIOS:"
    echo "   • $SYSTEM_SCRIPTS_DIR/     - Scripts do sistema"
    echo "   • $MONITORING_SCRIPTS_DIR/ - Scripts de monitoramento"
    echo "   • $NETWORK_SCRIPTS_DIR/    - Scripts de rede"
    echo
    
    echo "⚙️ CONFIGURAÇÃO:"
    echo "   • Arquivo: $CONFIG_FILE"
    echo "   • Logs: $LOG_FILE"
    echo "   • Lock: $LOCK_FILE"
    echo
    
    echo "🚀 USO POR LINHA DE COMANDO:"
    echo "   • $0                    - Menu interativo"
    echo "   • $0 status             - Status do sistema"
    echo "   • $0 list system        - Listar scripts do sistema"
    echo "   • $0 run <script>       - Executar script específico"
    echo "   • $0 cleanup            - Limpeza do sistema"
    echo
    
    echo "🔧 MANUTENÇÃO:"
    echo "   • Logs são rotacionados automaticamente"
    echo "   • Backups são criados antes de execuções importantes"
    echo "   • Configurações podem ser editadas pelo menu"
    echo
    
    read -p "Pressione Enter para continuar..."
}

# Função principal
main() {
    # Configurações iniciais
    check_root
    check_lock
    trap remove_lock EXIT
    
    create_config
    
    # Criar diretórios necessários
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Verificar dependências
    if ! check_dependencies; then
        print_error "Falha na verificação de dependências!"
        exit 1
    fi
    
    log_action "Scripts Manager started by $(whoami)"
    
    # Verificar argumentos da linha de comando
    case "${1:-}" in
        "status")
            show_system_status
            read -p "Pressione Enter para continuar..."
            ;;
        "list")
            case "${2:-}" in
                "system"|"monitoring"|"network")
                    list_scripts "$2" | while IFS='|' read name desc path; do
                        echo "$name - $desc"
                    done
                    ;;
                *)
                    print_error "Categoria inválida. Use: system, monitoring, network"
                    exit 1
                    ;;
            esac
            ;;
        "run")
            if [ -n "${2:-}" ]; then
                # Procurar script em todos os diretórios
                local script_found=""
                for dir in "$SYSTEM_SCRIPTS_DIR" "$MONITORING_SCRIPTS_DIR" "$NETWORK_SCRIPTS_DIR"; do
                    local script_path="$dir/$2.sh"
                    if [ -f "$script_path" ]; then
                        script_found="$script_path"
                        break
                    fi
                done
                
                if [ -n "$script_found" ]; then
                    execute_script "$script_found" "${3:-}"
                else
                    print_error "Script não encontrado: $2"
                    exit 1
                fi
            else
                print_error "Nome do script não especificado"
                exit 1
            fi
            ;;
        "cleanup")
            system_cleanup
            ;;
        *)
            # Menu interativo
            while true; do
                show_main_menu
                read -p "Escolha uma opção (0-7): " choice
                
                case $choice in
                    1) system_scripts_menu ;;
                    2) monitoring_scripts_menu ;;
                    3) network_scripts_menu ;;
                    4) 
                        show_system_status
                        read -p "Pressione Enter para continuar..."
                        ;;
                    5) advanced_settings ;;
                    6)
                        manage_logs
                        ;;
                    7) show_help ;;
                    0)
                        print_success "Até logo!"
                        log_action "Scripts Manager terminated by user"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        sleep 1
                        ;;
                esac
            done
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi