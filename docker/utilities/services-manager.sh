#!/bin/bash

# =============================================================================
# Services Stack Manager para Rocky Linux 10
# =============================================================================
# Descrição: Script para gerenciar múltiplos stacks de serviços Docker
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

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_DIR/services"

# Stacks disponíveis
declare -A STACKS=(
    ["dev"]="docker-compose.yml"
    ["lemp"]="services/docker-compose.lemp.yml"
    ["jenkins"]="services/docker-compose.jenkins.yml"
    ["gitea"]="services/docker-compose.gitea.yml"
    ["sonarqube"]="services/docker-compose.sonarqube.yml"
    ["nexus"]="services/docker-compose.nexus.yml"
    ["portainer"]="services/docker-compose.portainer.yml"
    ["elk"]="services/docker-compose.elk.yml"
    ["monitoring"]="services/docker-compose.monitoring.yml"
)

declare -A STACK_NAMES=(
    ["dev"]="🚀 Desenvolvimento (Full Stack)"
    ["lemp"]="🐘 LEMP (Linux, Nginx, MySQL, PHP)"
    ["jenkins"]="🔧 Jenkins CI/CD Pipeline"
    ["gitea"]="📦 Gitea Git Server"
    ["sonarqube"]="🔍 SonarQube Code Quality"
    ["nexus"]="📚 Nexus Repository Manager"
    ["portainer"]="🐳 Portainer Docker Management"
    ["elk"]="📊 ELK Stack (Logs & Search)"
    ["monitoring"]="📈 Monitoring (Grafana + Prometheus)"
)

declare -A STACK_PORTS=(
    ["dev"]="3000 5432 3306 6379 27017 80 8080 8081 9000"
    ["lemp"]="8082 3306"
    ["jenkins"]="8080 9000 8081 3000 5433 2222 6380"
    ["gitea"]="3000 5434 6381 2222"
    ["sonarqube"]="9000 5435"
    ["nexus"]="8081 8082 8083 8084"
    ["portainer"]="9000 9443"
    ["elk"]="5601 9200 5044"
    ["monitoring"]="3001 9090 9100 8080 9093"
)

# Verificar se está no diretório correto
check_environment() {
    if [ ! -d "$SERVICES_DIR" ]; then
        print_error "Diretório services/ não encontrado!"
        print_info "Execute este script a partir do diretório docker/"
        exit 1
    fi
}

# Menu principal
show_main_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                   Services Stack Manager                      ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 📋 Listar todos os stacks                                  ║"
    echo "║  2. 🚀 Iniciar stack específico                               ║"
    echo "║  3. 🛑 Parar stack específico                                 ║"
    echo "║  4. 📊 Status de todos os stacks                              ║"
    echo "║  5. 🔧 Gerenciar stack específico                             ║"
    echo "║  6. 🧹 Limpeza geral                                          ║"
    echo "║  7. 🌐 URLs de todos os serviços                              ║"
    echo "║  8. 💾 Backup de configurações                                ║"
    echo "║  9. 🔄 Atualizar todas as imagens                            ║"
    echo "║  10. ⚙️ Configurações do sistema                              ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Listar stacks
list_stacks() {
    print_header "📋 Stacks Disponíveis:"
    echo
    
    local i=1
    for stack in "${!STACKS[@]}"; do
        local compose_file="${STACKS[$stack]}"
        local stack_name="${STACK_NAMES[$stack]}"
        local ports="${STACK_PORTS[$stack]}"
        
        echo "$i. $stack_name"
        echo "   Arquivo: $compose_file"
        echo "   Portas: $ports"
        
        # Verificar se está rodando
        cd "$PROJECT_DIR"
        if docker-compose -f "$compose_file" ps -q 2>/dev/null | grep -q .; then
            print_success "   Status: 🟢 RODANDO"
        else
            echo "   Status: 🔴 PARADO"
        fi
        echo
        ((i++))
    done
}

# Selecionar stack
select_stack() {
    echo "Stacks disponíveis:"
    local i=1
    local stack_array=()
    
    for stack in "${!STACKS[@]}"; do
        echo "$i. ${STACK_NAMES[$stack]} ($stack)"
        stack_array+=("$stack")
        ((i++))
    done
    
    echo "0. Voltar"
    echo
    read -p "Escolha o stack: " choice
    
    if [ "$choice" = "0" ]; then
        return 1
    elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#stack_array[@]}" ]; then
        selected_stack="${stack_array[$((choice-1))]}"
        return 0
    else
        print_error "Opção inválida!"
        return 1
    fi
}

# Iniciar stack
start_stack() {
    if select_stack; then
        local compose_file="${STACKS[$selected_stack]}"
        local stack_name="${STACK_NAMES[$selected_stack]}"
        
        print_info "Iniciando $stack_name..."
        cd "$PROJECT_DIR"
        
        docker-compose -f "$compose_file" up -d
        
        if [ $? -eq 0 ]; then
            print_success "$stack_name iniciado com sucesso!"
            echo
            show_stack_urls "$selected_stack"
        else
            print_error "Erro ao iniciar $stack_name!"
        fi
    fi
}

# Parar stack
stop_stack() {
    if select_stack; then
        local compose_file="${STACKS[$selected_stack]}"
        local stack_name="${STACK_NAMES[$selected_stack]}"
        
        print_info "Parando $stack_name..."
        cd "$PROJECT_DIR"
        
        docker-compose -f "$compose_file" down
        
        if [ $? -eq 0 ]; then
            print_success "$stack_name parado com sucesso!"
        else
            print_error "Erro ao parar $stack_name!"
        fi
    fi
}

# Status de todos os stacks
show_all_status() {
    print_header "📊 Status de Todos os Stacks:"
    echo
    
    cd "$PROJECT_DIR"
    
    for stack in "${!STACKS[@]}"; do
        local compose_file="${STACKS[$stack]}"
        local stack_name="${STACK_NAMES[$stack]}"
        
        echo "═══ $stack_name ═══"
        
        if docker-compose -f "$compose_file" ps -q 2>/dev/null | grep -q .; then
            docker-compose -f "$compose_file" ps
        else
            echo "🔴 Stack parado"
        fi
        echo
    done
    
    print_info "Uso geral de recursos:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Gerenciar stack específico
manage_specific_stack() {
    if select_stack; then
        local compose_file="${STACKS[$selected_stack]}"
        local stack_name="${STACK_NAMES[$selected_stack]}"
        
        while true; do
            clear
            print_header "🔧 Gerenciar: $stack_name"
            echo
            echo "1. 🚀 Iniciar"
            echo "2. 🛑 Parar"
            echo "3. 🔄 Reiniciar"
            echo "4. 📋 Logs"
            echo "5. 📊 Status"
            echo "6. 🔧 Rebuild"
            echo "7. 🧹 Limpeza"
            echo "8. 🌐 URLs"
            echo "0. ⬅️ Voltar"
            echo
            
            read -p "Escolha: " action
            
            cd "$PROJECT_DIR"
            
            case $action in
                1)
                    docker-compose -f "$compose_file" up -d
                    ;;
                2)
                    docker-compose -f "$compose_file" down
                    ;;
                3)
                    docker-compose -f "$compose_file" restart
                    ;;
                4)
                    docker-compose -f "$compose_file" logs -f
                    ;;
                5)
                    docker-compose -f "$compose_file" ps
                    ;;
                6)
                    docker-compose -f "$compose_file" down
                    docker-compose -f "$compose_file" build --no-cache
                    docker-compose -f "$compose_file" up -d
                    ;;
                7)
                    print_warning "Isso removerá todos os volumes e dados!"
                    read -p "Confirmar? (s/N): " confirm
                    if [[ $confirm =~ ^[SsYy]$ ]]; then
                        docker-compose -f "$compose_file" down -v
                    fi
                    ;;
                8)
                    show_stack_urls "$selected_stack"
                    ;;
                0)
                    break
                    ;;
                *)
                    print_error "Opção inválida!"
                    ;;
            esac
            
            echo
            read -p "Pressione Enter para continuar..."
        done
    fi
}

# Mostrar URLs do stack
show_stack_urls() {
    local stack="$1"
    local ports="${STACK_PORTS[$stack]}"
    
    print_header "🌐 URLs para ${STACK_NAMES[$stack]}:"
    echo
    
    case "$stack" in
        "dev")
            echo "Aplicação:          http://localhost:3000"
            echo "Adminer:            http://localhost:8080"
            echo "phpMyAdmin:         http://localhost:8081"
            echo "Portainer:          http://localhost:9000"
            ;;
        "lemp")
            echo "Aplicação PHP:      http://localhost:8082"
            ;;
        "jenkins")
            echo "Jenkins:            http://localhost:8080 (admin/admin123)"
            echo "SonarQube:          http://localhost:9000 (admin/admin)"
            echo "Nexus:              http://localhost:8081 (admin/admin123)"
            echo "Gitea:              http://localhost:3000"
            ;;
        "gitea")
            echo "Gitea:              http://localhost:3000"
            echo "SSH:                ssh://localhost:2222"
            ;;
        "sonarqube")
            echo "SonarQube:          http://localhost:9000 (admin/admin)"
            ;;
        "nexus")
            echo "Nexus:              http://localhost:8081"
            echo "Docker Registry:    localhost:8082"
            ;;
        "portainer")
            echo "Portainer:          http://localhost:9000"
            ;;
        "elk")
            echo "Kibana:             http://localhost:5601"
            echo "Elasticsearch:      http://localhost:9200"
            ;;
        "monitoring")
            echo "Grafana:            http://localhost:3001 (admin/admin123)"
            echo "Prometheus:         http://localhost:9090"
            echo "AlertManager:       http://localhost:9093"
            ;;
    esac
}

# Mostrar todas as URLs
show_all_urls() {
    print_header "🌐 URLs de Todos os Serviços:"
    echo
    
    for stack in "${!STACKS[@]}"; do
        show_stack_urls "$stack"
        echo
    done
}

# Limpeza geral
general_cleanup() {
    print_warning "ATENÇÃO: Isso irá parar todos os containers e limpar recursos!"
    read -p "Continuar? (s/N): " confirm
    
    if [[ $confirm =~ ^[SsYy]$ ]]; then
        print_info "Parando todos os stacks..."
        
        cd "$PROJECT_DIR"
        for stack in "${!STACKS[@]}"; do
            local compose_file="${STACKS[$stack]}"
            docker-compose -f "$compose_file" down 2>/dev/null
        done
        
        print_info "Limpando recursos não utilizados..."
        docker system prune -a -f
        docker volume prune -f
        docker network prune -f
        
        print_success "Limpeza geral concluída!"
    fi
}

# Backup configurações
backup_configurations() {
    local backup_dir="./backups/services-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_info "Criando backup das configurações..."
    
    # Copiar arquivos de configuração
    cp -r "$PROJECT_DIR"/*.yml "$backup_dir/" 2>/dev/null
    cp -r "$SERVICES_DIR" "$backup_dir/" 2>/dev/null
    
    print_success "Backup salvo em: $backup_dir"
}

# Atualizar imagens
update_all_images() {
    print_info "Atualizando todas as imagens Docker..."
    
    cd "$PROJECT_DIR"
    for stack in "${!STACKS[@]}"; do
        local compose_file="${STACKS[$stack]}"
        docker-compose -f "$compose_file" pull
    done
    
    print_success "Todas as imagens atualizadas!"
    print_warning "Reinicie os stacks para usar as versões atualizadas."
}

# Configurações do sistema
system_config() {
    print_header "⚙️ Configurações do Sistema Docker:"
    echo
    
    echo "📊 Informações gerais:"
    docker system df
    echo
    
    echo "🐳 Versão do Docker:"
    docker version --format "{{.Server.Version}}"
    echo
    
    echo "📋 Containers ativos:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    echo "🌐 Redes Docker:"
    docker network ls
}

# Função principal
main() {
    check_environment
    
    while true; do
        show_main_menu
        read -p "Escolha uma opção (0-10): " choice
        
        case $choice in
            1) list_stacks ;;
            2) start_stack ;;
            3) stop_stack ;;
            4) show_all_status ;;
            5) manage_specific_stack ;;
            6) general_cleanup ;;
            7) show_all_urls ;;
            8) backup_configurations ;;
            9) update_all_images ;;
            10) system_config ;;
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