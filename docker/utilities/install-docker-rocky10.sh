#!/bin/bash

# =============================================================================
# Docker Installer para Rocky Linux 10
# =============================================================================
# Descrição: Script automatizado para instalar Docker no Rocky Linux 10
# Autor: Paulo Ramos
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
LOG_FILE="/var/log/docker_install_rocky.log"
DOCKER_COMPOSE_VERSION="v2.23.3"

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
        echo "Use: sudo $0"
        exit 1
    fi
}

check_distro() {
    if ! grep -q "Rocky Linux" /etc/os-release 2>/dev/null; then
        print_warning "Este script foi otimizado para Rocky Linux 10"
        print_warning "Pode funcionar em outras distribuições RHEL-based"
        echo
        read -p "Deseja continuar? (s/N): " choice
        if [[ ! "$choice" =~ ^[SsYy]$ ]]; then
            print_error "Instalação cancelada."
            exit 1
        fi
    fi
}

check_existing_docker() {
    if command -v docker &> /dev/null; then
        print_warning "Docker já está instalado!"
        docker --version
        echo
        read -p "Deseja reinstalar? (s/N): " choice
        if [[ ! "$choice" =~ ^[SsYy]$ ]]; then
            print_success "Instalação cancelada. Docker já disponível."
            exit 0
        fi
        return 1
    fi
    return 0
}

# =============================================================================
# FUNÇÕES DE INSTALAÇÃO
# =============================================================================

remove_old_docker() {
    print_step "Removendo versões antigas do Docker..."
    
    dnf remove -y \
        docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-engine \
        podman \
        runc &>/dev/null
    
    print_success "Versões antigas removidas!"
    log_action "Versões antigas do Docker removidas"
}

update_system() {
    print_step "Atualizando sistema..."
    dnf update -y > /dev/null 2>&1
    print_success "Sistema atualizado!"
    log_action "Sistema atualizado"
}

install_dependencies() {
    print_step "Instalando dependências..."
    
    dnf install -y \
        dnf-plugins-core \
        device-mapper-persistent-data \
        lvm2 \
        curl \
        wget \
        git \
        unzip > /dev/null 2>&1
    
    print_success "Dependências instaladas!"
    log_action "Dependências instaladas"
}

add_docker_repository() {
    print_step "Adicionando repositório oficial do Docker..."
    
    # Adicionar repositório Docker
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    
    # Importar chave GPG
    rpm --import https://download.docker.com/linux/rhel/gpg
    
    print_success "Repositório Docker adicionado!"
    log_action "Repositório Docker configurado"
}

install_docker() {
    print_step "Instalando Docker CE..."
    
    dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Docker CE instalado com sucesso!"
        log_action "Docker CE instalado"
    else
        print_error "Falha na instalação do Docker CE"
        exit 1
    fi
}

install_docker_compose() {
    print_step "Instalando Docker Compose..."
    
    # Baixar Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    # Dar permissão de execução
    chmod +x /usr/local/bin/docker-compose
    
    # Criar link simbólico
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_success "Docker Compose instalado!"
    log_action "Docker Compose instalado"
}

configure_docker_service() {
    print_step "Configurando serviço Docker..."
    
    # Habilitar e iniciar Docker
    systemctl enable docker
    systemctl start docker
    
    # Verificar se está rodando
    if systemctl is-active --quiet docker; then
        print_success "Serviço Docker configurado e iniciado!"
    else
        print_error "Falha ao iniciar serviço Docker"
        exit 1
    fi
    
    log_action "Serviço Docker configurado"
}

configure_user_access() {
    print_step "Configurando acesso do usuário..."
    
    # Verificar se existe usuário não-root
    if [[ -n "$SUDO_USER" ]]; then
        # Adicionar usuário ao grupo docker
        usermod -aG docker "$SUDO_USER"
        print_success "Usuário $SUDO_USER adicionado ao grupo docker"
        print_warning "Faça logout e login novamente para aplicar as permissões"
        log_action "Usuário $SUDO_USER adicionado ao grupo docker"
    else
        print_warning "Execute como sudo para configurar permissões de usuário"
    fi
}

configure_docker_daemon() {
    print_step "Configurando daemon Docker..."
    
    # Criar diretório de configuração
    mkdir -p /etc/docker
    
    # Criar arquivo de configuração otimizada
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
EOF

    print_success "Configurações do daemon aplicadas!"
    log_action "Daemon Docker configurado"
}

configure_firewall() {
    print_step "Configurando firewall..."
    
    if systemctl is-active --quiet firewalld; then
        # Adicionar Docker ao firewall
        firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null
        firewall-cmd --permanent --zone=trusted --add-masquerade
        firewall-cmd --reload
        
        print_success "Firewall configurado para Docker!"
        log_action "Firewall configurado"
    else
        print_warning "Firewalld não está ativo"
    fi
}

restart_docker_service() {
    print_step "Reiniciando serviço Docker..."
    
    systemctl daemon-reload
    systemctl restart docker
    
    if systemctl is-active --quiet docker; then
        print_success "Docker reiniciado com sucesso!"
    else
        print_error "Falha ao reiniciar Docker"
        exit 1
    fi
}

test_docker_installation() {
    print_step "Testando instalação..."
    
    # Testar Docker
    if docker run --rm hello-world > /dev/null 2>&1; then
        print_success "Docker funcionando corretamente!"
    else
        print_warning "Teste do Docker falhou - verifique as permissões"
    fi
    
    # Testar Docker Compose
    if docker-compose --version > /dev/null 2>&1; then
        print_success "Docker Compose funcionando!"
    else
        print_warning "Docker Compose não está funcionando"
    fi
    
    log_action "Testes de instalação executados"
}

show_installation_info() {
    print_header "INSTALAÇÃO CONCLUÍDA"
    
    echo -e "${GREEN}✓ Docker CE instalado e configurado${NC}"
    echo -e "${GREEN}✓ Docker Compose instalado${NC}"
    echo -e "${GREEN}✓ Serviço Docker iniciado${NC}"
    echo -e "${GREEN}✓ Configurações otimizadas aplicadas${NC}"
    echo
    
    echo -e "${BLUE}Informações da instalação:${NC}"
    echo "  • Docker version: $(docker --version 2>/dev/null || echo 'N/A')"
    echo "  • Docker Compose version: $(docker-compose --version 2>/dev/null || echo 'N/A')"
    echo "  • Status do serviço: $(systemctl is-active docker)"
    echo
    
    echo -e "${YELLOW}Próximos passos:${NC}"
    if [[ -n "$SUDO_USER" ]]; then
        echo "  1. Faça logout e login novamente"
        echo "  2. Teste: docker run hello-world"
        echo "  3. Use sem sudo: docker ps"
    else
        echo "  1. Adicione seu usuário ao grupo docker:"
        echo "     sudo usermod -aG docker \$USER"
        echo "  2. Faça logout e login novamente"
        echo "  3. Teste: docker run hello-world"
    fi
    echo
    
    echo -e "${PURPLE}Comandos úteis:${NC}"
    echo "  • docker ps                    - Listar containers"
    echo "  • docker images                - Listar imagens"
    echo "  • docker-compose up -d         - Iniciar stack"
    echo "  • systemctl status docker      - Status do serviço"
    echo
    
    echo -e "${CYAN}Log da instalação: ${LOG_FILE}${NC}"
}

# =============================================================================
# MENU DE INSTALAÇÃO
# =============================================================================

show_install_menu() {
    clear
    print_header "DOCKER INSTALLER - ROCKY LINUX 10"
    
    echo -e "${YELLOW}Opções de instalação:${NC}"
    echo
    echo "1. 🚀 Instalação Completa (Recomendado)"
    echo "   • Remove versões antigas"
    echo "   • Instala Docker CE + Docker Compose"
    echo "   • Configura serviço e otimizações"
    echo "   • Configura permissões de usuário"
    echo
    echo "2. 🔧 Instalação Básica"
    echo "   • Apenas Docker CE"
    echo "   • Configuração mínima"
    echo
    echo "3. ⚙️ Apenas Docker Compose"
    echo "   • Instala Docker Compose (requer Docker já instalado)"
    echo
    echo "4. 🧪 Teste da instalação existente"
    echo "   • Verifica se Docker está funcionando"
    echo
    echo "0. ❌ Cancelar"
    echo
}

install_complete() {
    remove_old_docker
    update_system
    install_dependencies
    add_docker_repository
    install_docker
    install_docker_compose
    configure_docker_daemon
    configure_docker_service
    configure_user_access
    configure_firewall
    restart_docker_service
    test_docker_installation
    show_installation_info
}

install_basic() {
    remove_old_docker
    update_system
    install_dependencies
    add_docker_repository
    install_docker
    configure_docker_service
    configure_user_access
    test_docker_installation
    show_installation_info
}

install_compose_only() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado! Instale o Docker primeiro."
        exit 1
    fi
    
    install_docker_compose
    print_success "Docker Compose instalado!"
}

test_existing_installation() {
    print_header "TESTE DA INSTALAÇÃO EXISTENTE"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado!"
        return
    fi
    
    echo -e "${BLUE}Versões instaladas:${NC}"
    echo "  • $(docker --version)"
    [ -f /usr/local/bin/docker-compose ] && echo "  • $(docker-compose --version)"
    echo
    
    echo -e "${BLUE}Status do serviço:${NC}"
    systemctl status docker --no-pager -l
    echo
    
    echo -e "${BLUE}Teste funcional:${NC}"
    if docker run --rm hello-world; then
        print_success "Docker funcionando perfeitamente!"
    else
        print_error "Problemas detectados na instalação"
    fi
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    # Verificações iniciais
    check_root
    check_distro
    
    # Criar log
    touch "$LOG_FILE"
    log_action "Início da instalação Docker"
    
    # Verificar se Docker já existe
    if ! check_existing_docker; then
        show_install_menu
    else
        show_install_menu
    fi
    
    read -p "Escolha uma opção (0-4): " choice
    echo
    
    case $choice in
        1)
            print_info "Iniciando instalação completa..."
            install_complete
            ;;
        2)
            print_info "Iniciando instalação básica..."
            install_basic
            ;;
        3)
            print_info "Instalando apenas Docker Compose..."
            install_compose_only
            ;;
        4)
            test_existing_installation
            ;;
        0)
            print_success "Instalação cancelada."
            exit 0
            ;;
        *)
            print_error "Opção inválida!"
            exit 1
            ;;
    esac
    
    log_action "Instalação Docker finalizada"
}

# Verificar se o script está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi