#!/bin/bash

# =============================================================================
# Rocky Linux 10 Post-Installation Script
# =============================================================================
# Descrição: Script automatizado para configurar Rocky Linux 10 após instalação
# Autor: Sistema automatizado
# Data: $(date +"%d/%m/%Y")
# Versão: 1.0
# =============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/rocky_post_install.log"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

print_header() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}=================================================${NC}"
}

print_step() {
    echo -e "${BLUE}[PASSO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script deve ser executado como root!"
        exit 1
    fi
}

check_distro() {
    if ! grep -q "Rocky Linux" /etc/os-release; then
        print_error "Este script é específico para Rocky Linux!"
        exit 1
    fi
}

# =============================================================================
# FUNÇÕES DE CONFIGURAÇÃO
# =============================================================================

update_system() {
    print_step "Atualizando sistema..."
    dnf update -y && \
    print_success "Sistema atualizado com sucesso!" || \
    print_error "Falha na atualização do sistema"
    log_action "Sistema atualizado"
}

configure_repositories() {
    print_step "Configurando repositórios adicionais..."
    
    # EPEL Repository
    dnf install -y epel-release
    
    # PowerTools/CRB Repository
    dnf config-manager --set-enabled crb
    
    # RPM Fusion
    dnf install -y --nogpgcheck \
        https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm \
        https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
    
    # Google Chrome Repository
    cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    
    print_success "Repositórios configurados!"
    log_action "Repositórios adicionais configurados"
}

install_development_tools() {
    print_step "Instalando ferramentas de desenvolvimento..."
    
    local dev_packages=(
        "git"
        "vim"
        "nano"
        "curl"
        "wget"
        "htop"
        "tree"
        "unzip"
        "tar"
        "gcc"
        "make"
        "cmake"
        "python3"
        "python3-pip"
        "nodejs"
        "npm"
        "docker"
        "docker-compose"
        "code"
        "neofetch"
        "zsh"
        "tmux"
        "screen"
    )
    
    for package in "${dev_packages[@]}"; do
        if dnf install -y "$package" &>/dev/null; then
            print_success "Instalado: $package"
        else
            print_warning "Falha ao instalar: $package"
        fi
    done
    
    log_action "Ferramentas de desenvolvimento instaladas"
}

install_multimedia_tools() {
    print_step "Instalando ferramentas multimídia..."
    
    local multimedia_packages=(
        "vlc"
        "ffmpeg"
        "gimp"
        "audacity"
        "brasero"
        "cheese"
        "rhythmbox"
    )
    
    for package in "${multimedia_packages[@]}"; do
        if dnf install -y "$package" &>/dev/null; then
            print_success "Instalado: $package"
        else
            print_warning "Falha ao instalar: $package"
        fi
    done
    
    log_action "Ferramentas multimídia instaladas"
}

install_system_utilities() {
    print_step "Instalando utilitários do sistema..."
    
    local system_packages=(
        "firewalld"
        "fail2ban"
        "rsync"
        "gparted"
        "baobab"
        "dconf-editor"
        "gnome-tweaks"
        "flatpak"
        "snapd"
        "timeshift"
        "rpmconf"
        "dnf-automatic"
    )
    
    for package in "${system_packages[@]}"; do
        if dnf install -y "$package" &>/dev/null; then
            print_success "Instalado: $package"
        else
            print_warning "Falha ao instalar: $package"
        fi
    done
    
    log_action "Utilitários do sistema instalados"
}

configure_firewall() {
    print_step "Configurando firewall..."
    
    systemctl enable firewalld
    systemctl start firewalld
    
    # Configurações básicas do firewall
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    
    print_success "Firewall configurado!"
    log_action "Firewall configurado"
}

configure_docker() {
    print_step "Configurando Docker..."
    
    systemctl enable docker
    systemctl start docker
    
    # Adicionar usuário atual ao grupo docker
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        print_success "Usuário $SUDO_USER adicionado ao grupo docker"
    fi
    
    log_action "Docker configurado"
}

configure_flatpak() {
    print_step "Configurando Flatpak..."
    
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    print_success "Flatpak configurado com Flathub!"
    log_action "Flatpak configurado"
}

configure_automatic_updates() {
    print_step "Configurando atualizações automáticas..."
    
    # Configurar dnf-automatic
    sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
    systemctl enable dnf-automatic.timer
    systemctl start dnf-automatic.timer
    
    print_success "Atualizações automáticas configuradas!"
    log_action "Atualizações automáticas configuradas"
}

optimize_system() {
    print_step "Otimizando sistema..."
    
    # Melhorar performance do DNF
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
    echo "keepcache=True" >> /etc/dnf/dnf.conf
    
    # Configurar swappiness
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    
    # Melhorar cache de inodes
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    
    print_success "Sistema otimizado!"
    log_action "Sistema otimizado"
}

cleanup_system() {
    print_step "Limpando sistema..."
    
    # Limpar cache do DNF
    dnf clean all
    
    # Remover pacotes órfãos
    dnf autoremove -y
    
    # Limpar logs antigos
    journalctl --vacuum-time=7d
    
    print_success "Sistema limpo!"
    log_action "Sistema limpo"
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    print_header "ROCKY LINUX 10 POST-INSTALL SCRIPT"
    
    # Verificações iniciais
    check_root
    check_distro
    
    # Criar arquivo de log
    touch "$LOG_FILE"
    log_action "Início da execução do script"
    
    print_step "Iniciando configuração pós-instalação..."
    
    # Menu de opções
    echo -e "\n${YELLOW}Selecione as opções desejadas:${NC}"
    echo "1. Atualização completa do sistema"
    echo "2. Configurar repositórios adicionais"
    echo "3. Instalar ferramentas de desenvolvimento"
    echo "4. Instalar ferramentas multimídia"
    echo "5. Instalar utilitários do sistema"
    echo "6. Configurar firewall"
    echo "7. Configurar Docker"
    echo "8. Configurar Flatpak"
    echo "9. Configurar atualizações automáticas"
    echo "10. Otimizar sistema"
    echo "11. Limpeza do sistema"
    echo "0. Executar tudo automaticamente"
    echo
    
    read -p "Digite sua escolha (0-11): " choice
    
    case $choice in
        0)
            update_system
            configure_repositories
            install_development_tools
            install_multimedia_tools
            install_system_utilities
            configure_firewall
            configure_docker
            configure_flatpak
            configure_automatic_updates
            optimize_system
            cleanup_system
            ;;
        1) update_system ;;
        2) configure_repositories ;;
        3) install_development_tools ;;
        4) install_multimedia_tools ;;
        5) install_system_utilities ;;
        6) configure_firewall ;;
        7) configure_docker ;;
        8) configure_flatpak ;;
        9) configure_automatic_updates ;;
        10) optimize_system ;;
        11) cleanup_system ;;
        *)
            print_error "Opção inválida!"
            exit 1
            ;;
    esac
    
    print_header "CONFIGURAÇÃO CONCLUÍDA!"
    print_success "Script executado com sucesso!"
    print_warning "Recomenda-se reiniciar o sistema para aplicar todas as mudanças."
    
    log_action "Script finalizado com sucesso"
}

# Verificar se o script está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi