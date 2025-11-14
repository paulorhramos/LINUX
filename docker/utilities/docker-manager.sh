#!/bin/bash

# =============================================================================
# Docker Utilities Script para Rocky Linux
# =============================================================================
# Descrição: Scripts utilitários para gerenciamento Docker
# Autor: Paulo Ramos
# Versão: 1.0
# =============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Verificar se Docker está instalado
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado!"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker não está rodando ou você não tem permissões!"
        print_info "Execute: sudo systemctl start docker"
        print_info "Ou adicione seu usuário ao grupo docker: sudo usermod -aG docker \$USER"
        exit 1
    fi
}

# Menu principal
show_menu() {
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    Docker Utilities Menu                      ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🚀 Iniciar stack de desenvolvimento completo              ║"
    echo "║  2. 🛑 Parar todos os containers                              ║"
    echo "║  3. 🧹 Limpeza completa (containers, images, volumes)         ║"
    echo "║  4. 📊 Status dos containers                                  ║"
    echo "║  5. 📋 Logs dos containers                                    ║"
    echo "║  6. 🔧 Rebuild de containers                                  ║"
    echo "║  7. 💾 Backup dos volumes                                     ║"
    echo "║  8. 📦 Gerenciar images                                       ║"
    echo "║  9. 🌐 Informações de rede                                    ║"
    echo "║  10. ⚙️ Configurações do sistema                              ║"
    echo "║  0. ❌ Sair                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
}

# Iniciar stack de desenvolvimento
start_dev_stack() {
    print_info "Iniciando stack de desenvolvimento..."
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d
        print_success "Stack iniciado!"
        print_info "Serviços disponíveis:"
        echo "  • Aplicação web: http://localhost:3000"
        echo "  • Adminer (DB): http://localhost:8080"
        echo "  • phpMyAdmin: http://localhost:8081"
        echo "  • Portainer: http://localhost:9000"
    else
        print_error "Arquivo docker-compose.yml não encontrado!"
    fi
}

# Parar todos os containers
stop_all_containers() {
    print_info "Parando todos os containers..."
    docker stop $(docker ps -q) 2>/dev/null
    print_success "Containers parados!"
}

# Limpeza completa
cleanup_all() {
    print_warning "Esta ação irá remover TODOS os containers, images e volumes!"
    read -p "Tem certeza? (s/N): " confirm
    
    if [[ $confirm =~ ^[SsYy]$ ]]; then
        print_info "Iniciando limpeza completa..."
        
        # Parar containers
        docker stop $(docker ps -q) 2>/dev/null
        
        # Remover containers
        docker rm $(docker ps -aq) 2>/dev/null
        
        # Remover images
        docker rmi $(docker images -q) 2>/dev/null
        
        # Remover volumes
        docker volume prune -f
        
        # Remover networks
        docker network prune -f
        
        # Limpeza do sistema
        docker system prune -a -f
        
        print_success "Limpeza completa realizada!"
    fi
}

# Status dos containers
show_container_status() {
    print_info "Status dos containers:"
    echo
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    print_info "Uso de recursos:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Logs dos containers
show_container_logs() {
    containers=$(docker ps --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        print_error "Nenhum container rodando!"
        return
    fi
    
    echo "Containers disponíveis:"
    echo "$containers" | nl
    echo
    
    read -p "Digite o número do container: " choice
    container=$(echo "$containers" | sed -n "${choice}p")
    
    if [ -n "$container" ]; then
        print_info "Logs do container: $container"
        docker logs -f --tail=50 "$container"
    fi
}

# Rebuild containers
rebuild_containers() {
    print_info "Fazendo rebuild dos containers..."
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        print_success "Rebuild concluído!"
    else
        print_error "docker-compose.yml não encontrado!"
    fi
}

# Backup dos volumes
backup_volumes() {
    print_info "Criando backup dos volumes..."
    
    backup_dir="./backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    volumes=$(docker volume ls -q)
    
    for volume in $volumes; do
        print_info "Backup do volume: $volume"
        docker run --rm -v "$volume":/data -v "$(pwd)/$backup_dir":/backup alpine tar czf "/backup/${volume}.tar.gz" -C /data .
    done
    
    print_success "Backup salvo em: $backup_dir"
}

# Gerenciar images
manage_images() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                        Gerenciar Images                         ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  1. Listar images                                                ║"
    echo "║  2. Remover images não utilizadas                                ║"
    echo "║  3. Remover image específica                                     ║"
    echo "║  4. Pull de nova image                                           ║"
    echo "║  0. Voltar                                                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    
    read -p "Escolha: " choice
    
    case $choice in
        1)
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
            ;;
        2)
            docker image prune -a -f
            print_success "Images não utilizadas removidas!"
            ;;
        3)
            docker images --format "{{.Repository}}:{{.Tag}}" | nl
            read -p "Digite o número da image: " img_choice
            image=$(docker images --format "{{.Repository}}:{{.Tag}}" | sed -n "${img_choice}p")
            if [ -n "$image" ]; then
                docker rmi "$image"
                print_success "Image $image removida!"
            fi
            ;;
        4)
            read -p "Digite o nome da image: " image_name
            docker pull "$image_name"
            ;;
    esac
}

# Informações de rede
network_info() {
    print_info "Redes Docker:"
    docker network ls
    echo
    
    print_info "Containers por rede:"
    for network in $(docker network ls --format "{{.Name}}"); do
        echo "=== $network ==="
        docker network inspect "$network" | grep -A 3 "Containers"
        echo
    done
}

# Configurações do sistema
system_config() {
    print_info "Configurações do Docker:"
    echo
    
    echo "Versão do Docker:"
    docker version --format "{{.Server.Version}}"
    echo
    
    echo "Informações do sistema:"
    docker system df
    echo
    
    echo "Configurações de runtime:"
    docker info | grep -E "(Runtime|Storage Driver|Logging Driver)"
}

# Função principal
main() {
    check_docker
    
    while true; do
        show_menu
        read -p "Escolha uma opção (0-10): " choice
        
        case $choice in
            1) start_dev_stack ;;
            2) stop_all_containers ;;
            3) cleanup_all ;;
            4) show_container_status ;;
            5) show_container_logs ;;
            6) rebuild_containers ;;
            7) backup_volumes ;;
            8) manage_images ;;
            9) network_info ;;
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