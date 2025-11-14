#!/bin/bash

# =============================================================================
# Jenkins Stack Manager para Rocky Linux 10
# =============================================================================
# Descrição: Script para gerenciar o stack Jenkins CI/CD
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

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

# Arquivo compose
COMPOSE_FILE="services/docker-compose.jenkins.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Verificar se está no diretório correto
check_environment() {
    if [ ! -f "$PROJECT_DIR/$COMPOSE_FILE" ]; then
        print_error "Arquivo $COMPOSE_FILE não encontrado!"
        print_info "Execute este script a partir do diretório docker/"
        exit 1
    fi
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    Jenkins Stack Manager                      ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🚀 Iniciar stack completo                                  ║"
    echo "║  2. 🛑 Parar stack                                            ║"
    echo "║  3. 📊 Status dos serviços                                    ║"
    echo "║  4. 📋 Logs dos serviços                                      ║"
    echo "║  5. 🔧 Rebuild containers                                     ║"
    echo "║  6. 🧹 Limpeza completa                                       ║"
    echo "║  7. 🌐 URLs dos serviços                                      ║"
    echo "║  8. 👥 Iniciar com agents                                     ║"
    echo "║  9. 💾 Backup configurações                                   ║"
    echo "║  10. 🔐 Reset senha admin                                     ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Iniciar stack completo
start_stack() {
    print_info "Iniciando Jenkins CI/CD Stack..."
    cd "$PROJECT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    if [ $? -eq 0 ]; then
        print_success "Stack iniciado com sucesso!"
        echo
        show_urls
        echo
        print_warning "Jenkins pode levar alguns minutos para inicializar completamente."
        print_info "Aguarde e acesse http://localhost:8080"
        print_info "Usuário: admin | Senha: admin123"
    else
        print_error "Erro ao iniciar o stack!"
    fi
}

# Parar stack
stop_stack() {
    print_info "Parando Jenkins Stack..."
    cd "$PROJECT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" down
    
    if [ $? -eq 0 ]; then
        print_success "Stack parado com sucesso!"
    else
        print_error "Erro ao parar o stack!"
    fi
}

# Status dos serviços
show_status() {
    print_info "Status dos serviços Jenkins:"
    cd "$PROJECT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    print_info "Uso de recursos:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Logs dos serviços
show_logs() {
    services=("jenkins" "sonarqube" "nexus" "gitea" "postgres" "docker-dind" "nginx" "redis")
    
    echo "Serviços disponíveis:"
    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[$i]}"
    done
    echo "0. Todos os serviços"
    echo
    
    read -p "Escolha o serviço: " choice
    
    cd "$PROJECT_DIR"
    
    if [ "$choice" = "0" ]; then
        docker-compose -f "$COMPOSE_FILE" logs -f
    elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#services[@]}" ]; then
        service="${services[$((choice-1))]}"
        docker-compose -f "$COMPOSE_FILE" logs -f "$service"
    else
        print_error "Opção inválida!"
    fi
}

# Rebuild containers
rebuild_stack() {
    print_warning "Isso irá parar e recriar todos os containers."
    read -p "Continuar? (s/N): " confirm
    
    if [[ $confirm =~ ^[SsYy]$ ]]; then
        print_info "Fazendo rebuild do stack..."
        cd "$PROJECT_DIR"
        
        docker-compose -f "$COMPOSE_FILE" down
        docker-compose -f "$COMPOSE_FILE" build --no-cache
        docker-compose -f "$COMPOSE_FILE" up -d
        
        print_success "Rebuild concluído!"
    fi
}

# Limpeza completa
cleanup_stack() {
    print_warning "ATENÇÃO: Isso irá remover TODOS os dados dos serviços!"
    print_warning "Volumes, configurações e dados serão perdidos permanentemente."
    echo
    read -p "Tem CERTEZA? Digite 'CONFIRMAR' para continuar: " confirm
    
    if [ "$confirm" = "CONFIRMAR" ]; then
        print_info "Executando limpeza completa..."
        cd "$PROJECT_DIR"
        
        docker-compose -f "$COMPOSE_FILE" down -v
        docker-compose -f "$COMPOSE_FILE" down --rmi all
        
        print_success "Limpeza completa realizada!"
    else
        print_info "Operação cancelada."
    fi
}

# Mostrar URLs dos serviços
show_urls() {
    print_header "🌐 URLs dos Serviços:"
    echo
    echo "Jenkins CI/CD:      http://localhost:8080"
    echo "                   (admin / admin123)"
    echo
    echo "SonarQube:         http://localhost:9000"
    echo "                   (admin / admin)"
    echo
    echo "Nexus Repository:  http://localhost:8081"
    echo "                   (admin / admin123)"
    echo
    echo "Gitea Git Server:  http://localhost:3000"
    echo "                   SSH: localhost:2222"
    echo
    echo "PostgreSQL:        localhost:5433"
    echo "                   (sonarqube / sonarqube123)"
    echo
    echo "Redis:             localhost:6380"
    echo
    print_header "🔗 Proxy URLs (se Nginx estiver configurado):"
    echo "Jenkins:           http://jenkins.local"
    echo "SonarQube:         http://sonarqube.local"
    echo "Nexus:             http://nexus.local"
    echo "Gitea:             http://gitea.local"
}

# Iniciar com agents
start_with_agents() {
    print_info "Iniciando stack com Jenkins agents..."
    cd "$PROJECT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" --profile agents up -d
    
    if [ $? -eq 0 ]; then
        print_success "Stack com agents iniciado!"
        show_urls
    else
        print_error "Erro ao iniciar stack com agents!"
    fi
}

# Backup configurações
backup_configs() {
    backup_dir="./backups/jenkins-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_info "Criando backup das configurações..."
    
    # Backup Jenkins
    docker-compose -f "$COMPOSE_FILE" exec -T jenkins tar czf - /var/jenkins_home > "$backup_dir/jenkins-home.tar.gz"
    
    # Backup PostgreSQL
    docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U sonarqube sonarqube > "$backup_dir/sonarqube-db.sql"
    
    # Backup Nexus
    docker-compose -f "$COMPOSE_FILE" exec -T nexus tar czf - /nexus-data > "$backup_dir/nexus-data.tar.gz"
    
    # Backup Gitea
    docker-compose -f "$COMPOSE_FILE" exec -T gitea tar czf - /data > "$backup_dir/gitea-data.tar.gz"
    
    print_success "Backup salvo em: $backup_dir"
}

# Reset senha admin Jenkins
reset_admin_password() {
    print_info "Resetando senha do admin Jenkins..."
    
    docker-compose -f "$COMPOSE_FILE" exec jenkins bash -c "
        echo 'jenkins.model.Jenkins.getInstance().getSecurityRealm().createAccount(\"admin\", \"admin123\")' | \
        java -jar /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/ groovy =
    "
    
    print_success "Senha resetada para: admin123"
}

# Função principal
main() {
    check_environment
    
    while true; do
        show_menu
        read -p "Escolha uma opção (0-10): " choice
        
        case $choice in
            1) start_stack ;;
            2) stop_stack ;;
            3) show_status ;;
            4) show_logs ;;
            5) rebuild_stack ;;
            6) cleanup_stack ;;
            7) show_urls ;;
            8) start_with_agents ;;
            9) backup_configs ;;
            10) reset_admin_password ;;
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
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi