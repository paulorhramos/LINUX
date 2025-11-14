#!/bin/bash

# =============================================================================
# Sistema de Atualizações para Rocky Linux 10
# =============================================================================
# Descrição: Gerencia atualizações do sistema de forma segura e inteligente
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
LOG_FILE="/var/log/system-update.log"
BACKUP_DIR="/var/backups/pre-update"
UPDATE_CONFIG="/etc/system-update.conf"

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

# Criar arquivo de configuração se não existir
create_config() {
    if [ ! -f "$UPDATE_CONFIG" ]; then
        cat > "$UPDATE_CONFIG" << 'EOF'
# Configurações do sistema de atualizações
AUTO_REBOOT=false
BACKUP_BEFORE_UPDATE=true
UPDATE_KERNEL=true
UPDATE_SECURITY_ONLY=false
EXCLUDE_PACKAGES=""
NOTIFICATION_EMAIL=""
KEEP_KERNEL_VERSIONS=3
EOF
        print_info "Arquivo de configuração criado em: $UPDATE_CONFIG"
    fi
    source "$UPDATE_CONFIG"
}

# Verificar conectividade
check_connectivity() {
    print_info "Verificando conectividade..."
    
    if ping -c 3 8.8.8.8 &> /dev/null; then
        print_success "Conectividade OK"
        return 0
    else
        print_error "Sem conectividade com a internet!"
        return 1
    fi
}

# Backup do sistema crítico
backup_critical_files() {
    if [ "$BACKUP_BEFORE_UPDATE" = "true" ]; then
        print_info "Fazendo backup de arquivos críticos..."
        
        mkdir -p "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
        local backup_path="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
        
        # Backup de configurações críticas
        cp -r /etc/fstab "$backup_path/" 2>/dev/null
        cp -r /boot/grub2/grub.cfg "$backup_path/" 2>/dev/null
        cp -r /etc/dnf/dnf.conf "$backup_path/" 2>/dev/null
        
        # Lista de pacotes instalados
        dnf list installed > "$backup_path/installed-packages.txt"
        
        print_success "Backup criado em: $backup_path"
        log_action "Backup criado em $backup_path"
    fi
}

# Verificar espaço em disco
check_disk_space() {
    print_info "Verificando espaço em disco..."
    
    local root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    local boot_usage=$(df /boot | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    
    if [ "$root_usage" -gt 90 ]; then
        print_error "Espaço insuficiente na partição raiz (${root_usage}% usado)"
        return 1
    fi
    
    if [ "$boot_usage" -gt 80 ]; then
        print_warning "Pouco espaço na partição /boot (${boot_usage}% usado)"
        print_info "Removendo kernels antigos..."
        clean_old_kernels
    fi
    
    print_success "Espaço em disco suficiente"
    return 0
}

# Limpar kernels antigos
clean_old_kernels() {
    local current_kernel=$(uname -r)
    local installed_kernels=$(dnf list installed kernel-core | grep kernel-core | wc -l)
    
    if [ "$installed_kernels" -gt "$KEEP_KERNEL_VERSIONS" ]; then
        print_info "Removendo kernels antigos..."
        dnf remove --oldinstallonly --setopt installonly_limit="$KEEP_KERNEL_VERSIONS" kernel-core -y
        print_success "Kernels antigos removidos"
    fi
}

# Verificar repositórios
check_repositories() {
    print_info "Verificando repositórios..."
    
    if dnf repolist enabled &> /dev/null; then
        print_success "Repositórios OK"
        return 0
    else
        print_error "Problemas com repositórios!"
        print_info "Tentando reparar..."
        dnf clean all
        dnf makecache
        return $?
    fi
}

# Atualizar metadados
update_metadata() {
    print_info "Atualizando metadados dos repositórios..."
    dnf clean expire-cache
    dnf makecache
    print_success "Metadados atualizados"
}

# Verificar atualizações disponíveis
check_updates() {
    print_info "Verificando atualizações disponíveis..."
    
    local updates_count=$(dnf check-update --quiet | wc -l)
    
    if [ "$updates_count" -eq 0 ]; then
        print_success "Sistema já está atualizado!"
        return 1
    else
        print_info "$updates_count atualizações disponíveis"
        
        # Mostrar atualizações de segurança
        local security_updates=$(dnf updateinfo list sec | wc -l)
        if [ "$security_updates" -gt 0 ]; then
            print_warning "$security_updates atualizações de segurança disponíveis!"
        fi
        
        return 0
    fi
}

# Listar atualizações
list_updates() {
    print_header "=== ATUALIZAÇÕES DISPONÍVEIS ==="
    
    print_info "Atualizações de segurança:"
    dnf updateinfo list sec --color=always
    echo
    
    print_info "Todas as atualizações:"
    dnf check-update --color=always
}

# Aplicar atualizações de segurança apenas
security_updates() {
    print_info "Aplicando apenas atualizações de segurança..."
    dnf update --security -y
    log_action "Atualizações de segurança aplicadas"
}

# Aplicar todas as atualizações
full_update() {
    print_info "Aplicando todas as atualizações disponíveis..."
    
    local exclude_opts=""
    if [ -n "$EXCLUDE_PACKAGES" ]; then
        exclude_opts="--exclude=$EXCLUDE_PACKAGES"
    fi
    
    if [ "$UPDATE_KERNEL" = "false" ]; then
        exclude_opts="$exclude_opts --exclude=kernel*"
    fi
    
    dnf update $exclude_opts -y
    log_action "Atualização completa do sistema aplicada"
}

# Verificar se é necessário reiniciar
check_reboot_needed() {
    if [ -f /var/run/reboot-required ] || needs-restarting -r &> /dev/null; then
        print_warning "Reinicialização necessária!"
        
        if [ "$AUTO_REBOOT" = "true" ]; then
            print_info "Reinicialização automática habilitada. Reiniciando em 60 segundos..."
            print_warning "Pressione Ctrl+C para cancelar"
            sleep 60
            reboot
        else
            print_info "Execute 'sudo reboot' para aplicar as atualizações"
        fi
        return 0
    else
        print_success "Reinicialização não necessária"
        return 1
    fi
}

# Verificar serviços que precisam reiniciar
check_services_restart() {
    print_info "Verificando serviços que precisam reiniciar..."
    
    if command -v needs-restarting &> /dev/null; then
        local services_restart=$(needs-restarting -s)
        
        if [ -n "$services_restart" ]; then
            print_warning "Serviços que precisam reiniciar:"
            echo "$services_restart"
            
            read -p "Deseja reiniciar os serviços agora? (s/N): " restart_services
            if [[ $restart_services =~ ^[SsYy]$ ]]; then
                echo "$services_restart" | while read service; do
                    if systemctl is-active --quiet "$service"; then
                        print_info "Reiniciando $service..."
                        systemctl restart "$service"
                    fi
                done
            fi
        else
            print_success "Nenhum serviço precisa reiniciar"
        fi
    fi
}

# Enviar notificação por email
send_notification() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$NOTIFICATION_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$NOTIFICATION_EMAIL"
        print_info "Notificação enviada para $NOTIFICATION_EMAIL"
    fi
}

# Limpeza pós-atualização
post_update_cleanup() {
    print_info "Executando limpeza pós-atualização..."
    
    # Limpar cache de pacotes
    dnf clean packages
    
    # Remover dependências órfãs
    dnf autoremove -y
    
    # Atualizar cache de fontes
    if command -v fc-cache &> /dev/null; then
        fc-cache -f
    fi
    
    # Atualizar database do locate
    if command -v updatedb &> /dev/null; then
        updatedb &
    fi
    
    print_success "Limpeza pós-atualização concluída"
}

# Menu interativo
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                 Sistema de Atualizações                       ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔍 Verificar atualizações disponíveis                     ║"
    echo "║  2. 📋 Listar todas as atualizações                           ║"
    echo "║  3. 🛡️ Aplicar apenas atualizações de segurança               ║"
    echo "║  4. 🚀 Aplicar todas as atualizações                          ║"
    echo "║  5. 🧹 Limpeza do sistema                                     ║"
    echo "║  6. 🔄 Verificar serviços para reiniciar                     ║"
    echo "║  7. ⚙️ Configurações                                          ║"
    echo "║  8. 📊 Relatório do sistema                                   ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Relatório do sistema
system_report() {
    print_header "📊 Relatório do Sistema"
    echo
    
    print_info "Sistema:"
    echo "  • Distribuição: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  • Kernel: $(uname -r)"
    echo "  • Uptime: $(uptime -p)"
    echo
    
    print_info "Atualizações:"
    local updates=$(dnf check-update --quiet 2>/dev/null | wc -l)
    local security=$(dnf updateinfo list sec 2>/dev/null | wc -l)
    echo "  • Disponíveis: $updates"
    echo "  • Segurança: $security"
    echo
    
    print_info "Espaço em disco:"
    df -h / /boot 2>/dev/null | grep -v Filesystem
    echo
    
    print_info "Última atualização:"
    if [ -f "$LOG_FILE" ]; then
        tail -1 "$LOG_FILE" 2>/dev/null || echo "  • Nenhuma atualização registrada"
    else
        echo "  • Nenhuma atualização registrada"
    fi
}

# Configurações
configure_updates() {
    print_header "⚙️ Configurações"
    echo
    
    echo "Configurações atuais:"
    echo "  • Auto-reboot: $AUTO_REBOOT"
    echo "  • Backup antes de atualizar: $BACKUP_BEFORE_UPDATE"
    echo "  • Atualizar kernel: $UPDATE_KERNEL"
    echo "  • Apenas segurança: $UPDATE_SECURITY_ONLY"
    echo
    
    read -p "Deseja editar as configurações? (s/N): " edit_config
    if [[ $edit_config =~ ^[SsYy]$ ]]; then
        ${EDITOR:-nano} "$UPDATE_CONFIG"
        source "$UPDATE_CONFIG"
        print_success "Configurações atualizadas!"
    fi
}

# Função principal
main() {
    check_root
    create_config
    
    # Criar diretórios necessários
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    
    # Se argumentos foram passados, executa modo não-interativo
    case "${1:-}" in
        "check")
            check_connectivity && check_repositories && check_updates
            ;;
        "security")
            backup_critical_files && security_updates && post_update_cleanup
            ;;
        "full")
            backup_critical_files && full_update && post_update_cleanup && check_reboot_needed
            ;;
        "clean")
            post_update_cleanup && clean_old_kernels
            ;;
        *)
            # Modo interativo
            while true; do
                show_menu
                read -p "Escolha uma opção (0-8): " choice
                
                case $choice in
                    1)
                        check_connectivity && check_repositories && update_metadata && check_updates
                        ;;
                    2)
                        list_updates
                        ;;
                    3)
                        if check_connectivity && check_disk_space; then
                            backup_critical_files && security_updates && post_update_cleanup
                            check_services_restart
                        fi
                        ;;
                    4)
                        if check_connectivity && check_disk_space; then
                            backup_critical_files && full_update && post_update_cleanup
                            check_services_restart && check_reboot_needed
                        fi
                        ;;
                    5)
                        post_update_cleanup && clean_old_kernels
                        ;;
                    6)
                        check_services_restart
                        ;;
                    7)
                        configure_updates
                        ;;
                    8)
                        system_report
                        ;;
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

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi