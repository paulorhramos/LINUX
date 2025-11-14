#!/bin/bash

# =============================================================================
# Sistema de Backup para Rocky Linux 10
# =============================================================================
# Descrição: Sistema completo de backup com compressão e verificação
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

# Configurações padrão
BACKUP_BASE_DIR="/var/backups"
CONFIG_FILE="/etc/backup-system.conf"
LOG_FILE="/var/log/backup-system.log"
LOCK_FILE="/var/run/backup-system.lock"

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

# Criar arquivo de configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuração do Sistema de Backup

# Diretórios base
BACKUP_DIR="/var/backups"
INCREMENTAL_DIR="/var/backups/incremental"
MYSQL_BACKUP_DIR="/var/backups/mysql"
POSTGRES_BACKUP_DIR="/var/backups/postgres"

# Configurações gerais
RETENTION_DAYS=30
COMPRESSION_LEVEL=6
EMAIL_NOTIFICATION=""
VERIFY_BACKUP=true
DELETE_OLD_BACKUPS=true

# Backup de sistema
BACKUP_SYSTEM_DIRS="/etc /home /var/www /opt /usr/local"
EXCLUDE_PATTERNS="*.tmp,*.cache,*.log,*.swap,*/tmp/*,*/cache/*"

# Backup de banco de dados
BACKUP_MYSQL=true
MYSQL_USER="backup"
MYSQL_PASSWORD=""
MYSQL_DATABASES="all"

BACKUP_POSTGRES=true
POSTGRES_USER="postgres"
POSTGRES_DATABASES="all"

# Configurações de rede
REMOTE_BACKUP=false
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""
RSYNC_OPTIONS="-avz --delete"

# Notificações
SLACK_WEBHOOK=""
DISCORD_WEBHOOK=""
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
        print_warning "Configure as opções em $CONFIG_FILE antes de usar"
    fi
    
    source "$CONFIG_FILE"
}

# Verificar se outro backup está rodando
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_error "Outro processo de backup está rodando (PID: $pid)"
            exit 1
        else
            print_warning "Lock file órfão encontrado, removendo..."
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # Criar lock file
    echo $$ > "$LOCK_FILE"
}

# Remover lock file
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}

# Setup de sinais
trap cleanup EXIT INT TERM

# Verificar espaço em disco
check_disk_space() {
    local backup_dir="$1"
    local required_space="$2"  # em MB
    
    local available_space=$(df "$backup_dir" | awk 'NR==2 {print int($4/1024)}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_error "Espaço insuficiente! Disponível: ${available_space}MB, Necessário: ${required_space}MB"
        return 1
    fi
    
    print_success "Espaço disponível: ${available_space}MB"
    return 0
}

# Estimar tamanho do backup
estimate_backup_size() {
    local dirs="$1"
    print_info "Estimando tamanho do backup..."
    
    local total_size=0
    for dir in $dirs; do
        if [ -d "$dir" ]; then
            local dir_size=$(du -sm "$dir" 2>/dev/null | awk '{print $1}')
            total_size=$((total_size + dir_size))
        fi
    done
    
    # Considerar compressão (aprox. 60% do tamanho original)
    local compressed_size=$((total_size * 60 / 100))
    echo "$compressed_size"
}

# Criar estrutura de diretórios
create_directories() {
    mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly,system,databases,incremental}
    mkdir -p "$MYSQL_BACKUP_DIR"
    mkdir -p "$POSTGRES_BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    print_success "Estrutura de diretórios criada"
}

# Backup do sistema
backup_system() {
    local backup_type="${1:-daily}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="system_${backup_type}_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_type/$backup_name.tar.gz"
    
    print_header "🗂️ Iniciando backup do sistema ($backup_type)"
    log_action "Iniciando backup do sistema: $backup_name"
    
    # Estimar espaço necessário
    local estimated_size=$(estimate_backup_size "$BACKUP_SYSTEM_DIRS")
    if ! check_disk_space "$BACKUP_DIR" "$((estimated_size + 500))"; then
        return 1
    fi
    
    # Criar arquivo de exclusões
    local exclude_file="/tmp/backup_exclude_$$"
    echo "$EXCLUDE_PATTERNS" | tr ',' '\n' > "$exclude_file"
    
    # Adicionar exclusões específicas
    cat >> "$exclude_file" << 'EOF'
/proc/*
/sys/*
/dev/*
/tmp/*
/var/tmp/*
/var/cache/*
/var/log/*
/run/*
/mnt/*
/media/*
/lost+found
*.sock
EOF

    print_info "Criando arquivo de backup: $backup_path"
    
    # Executar backup
    if tar -czf "$backup_path" \
        --exclude-from="$exclude_file" \
        --warning=no-file-ignored \
        --one-file-system \
        $BACKUP_SYSTEM_DIRS 2>/dev/null; then
        
        local backup_size=$(du -h "$backup_path" | cut -f1)
        print_success "Backup criado: $backup_path ($backup_size)"
        log_action "Backup sistema concluído: $backup_path ($backup_size)"
        
        # Verificar integridade se habilitado
        if [ "$VERIFY_BACKUP" = "true" ]; then
            verify_backup "$backup_path"
        fi
        
        # Limpar arquivo temporário
        rm -f "$exclude_file"
        
        return 0
    else
        print_error "Falha ao criar backup do sistema"
        rm -f "$exclude_file"
        return 1
    fi
}

# Backup incremental
backup_incremental() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local snapshot_file="$INCREMENTAL_DIR/snapshot.snar"
    local backup_name="incremental_${timestamp}"
    local backup_path="$INCREMENTAL_DIR/$backup_name.tar.gz"
    
    print_header "📈 Iniciando backup incremental"
    log_action "Iniciando backup incremental: $backup_name"
    
    mkdir -p "$INCREMENTAL_DIR"
    
    # Se não existe snapshot, é o primeiro backup (completo)
    if [ ! -f "$snapshot_file" ]; then
        print_info "Primeiro backup incremental (completo)"
    else
        print_info "Backup incremental baseado no snapshot anterior"
    fi
    
    if tar -czf "$backup_path" \
        --listed-incremental="$snapshot_file" \
        --warning=no-file-ignored \
        $BACKUP_SYSTEM_DIRS 2>/dev/null; then
        
        local backup_size=$(du -h "$backup_path" | cut -f1)
        print_success "Backup incremental criado: $backup_path ($backup_size)"
        log_action "Backup incremental concluído: $backup_path ($backup_size)"
        return 0
    else
        print_error "Falha ao criar backup incremental"
        return 1
    fi
}

# Backup MySQL
backup_mysql() {
    if [ "$BACKUP_MYSQL" != "true" ]; then
        return 0
    fi
    
    print_header "🗄️ Iniciando backup MySQL"
    
    if ! command -v mysqldump &> /dev/null; then
        print_warning "MySQL não instalado, pulando backup"
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Configurar autenticação
    local auth_opts=""
    if [ -n "$MYSQL_USER" ]; then
        auth_opts="-u$MYSQL_USER"
        if [ -n "$MYSQL_PASSWORD" ]; then
            auth_opts="$auth_opts -p$MYSQL_PASSWORD"
        fi
    fi
    
    if [ "$MYSQL_DATABASES" = "all" ]; then
        # Backup de todas as databases
        local backup_file="$MYSQL_BACKUP_DIR/mysql_all_${timestamp}.sql.gz"
        print_info "Fazendo backup de todas as databases MySQL..."
        
        if mysqldump $auth_opts --all-databases --single-transaction --routines --triggers | gzip > "$backup_file"; then
            local backup_size=$(du -h "$backup_file" | cut -f1)
            print_success "Backup MySQL criado: $backup_file ($backup_size)"
            log_action "Backup MySQL concluído: $backup_file ($backup_size)"
        else
            print_error "Falha no backup MySQL"
            return 1
        fi
    else
        # Backup de databases específicas
        for db in $MYSQL_DATABASES; do
            local backup_file="$MYSQL_BACKUP_DIR/mysql_${db}_${timestamp}.sql.gz"
            print_info "Fazendo backup da database: $db"
            
            if mysqldump $auth_opts "$db" --single-transaction --routines --triggers | gzip > "$backup_file"; then
                local backup_size=$(du -h "$backup_file" | cut -f1)
                print_success "Backup $db criado: $backup_file ($backup_size)"
            else
                print_error "Falha no backup da database $db"
            fi
        done
    fi
}

# Backup PostgreSQL
backup_postgres() {
    if [ "$BACKUP_POSTGRES" != "true" ]; then
        return 0
    fi
    
    print_header "🐘 Iniciando backup PostgreSQL"
    
    if ! command -v pg_dump &> /dev/null; then
        print_warning "PostgreSQL não instalado, pulando backup"
        return 0
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ "$POSTGRES_DATABASES" = "all" ]; then
        # Backup global
        local backup_file="$POSTGRES_BACKUP_DIR/postgres_all_${timestamp}.sql.gz"
        print_info "Fazendo backup global PostgreSQL..."
        
        if sudo -u "$POSTGRES_USER" pg_dumpall | gzip > "$backup_file"; then
            local backup_size=$(du -h "$backup_file" | cut -f1)
            print_success "Backup PostgreSQL criado: $backup_file ($backup_size)"
            log_action "Backup PostgreSQL concluído: $backup_file ($backup_size)"
        else
            print_error "Falha no backup PostgreSQL"
            return 1
        fi
    else
        # Backup de databases específicas
        for db in $POSTGRES_DATABASES; do
            local backup_file="$POSTGRES_BACKUP_DIR/postgres_${db}_${timestamp}.sql.gz"
            print_info "Fazendo backup da database: $db"
            
            if sudo -u "$POSTGRES_USER" pg_dump "$db" | gzip > "$backup_file"; then
                local backup_size=$(du -h "$backup_file" | cut -f1)
                print_success "Backup $db criado: $backup_file ($backup_size)"
            else
                print_error "Falha no backup da database $db"
            fi
        done
    fi
}

# Verificar integridade do backup
verify_backup() {
    local backup_file="$1"
    print_info "Verificando integridade do backup..."
    
    if [[ "$backup_file" == *.gz ]]; then
        if gzip -t "$backup_file" 2>/dev/null; then
            print_success "Backup íntegro"
            return 0
        else
            print_error "Backup corrompido!"
            return 1
        fi
    elif [[ "$backup_file" == *.tar ]]; then
        if tar -tf "$backup_file" > /dev/null 2>&1; then
            print_success "Backup íntegro"
            return 0
        else
            print_error "Backup corrompido!"
            return 1
        fi
    fi
}

# Sync remoto
remote_sync() {
    if [ "$REMOTE_BACKUP" != "true" ]; then
        return 0
    fi
    
    print_header "☁️ Sincronizando com servidor remoto"
    
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ]; then
        print_error "Configuração remota incompleta"
        return 1
    fi
    
    print_info "Sincronizando com $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"
    
    if rsync $RSYNC_OPTIONS "$BACKUP_DIR/" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"; then
        print_success "Sincronização remota concluída"
        log_action "Backup sincronizado remotamente"
        return 0
    else
        print_error "Falha na sincronização remota"
        return 1
    fi
}

# Limpeza de backups antigos
cleanup_old_backups() {
    if [ "$DELETE_OLD_BACKUPS" != "true" ]; then
        return 0
    fi
    
    print_header "🧹 Limpando backups antigos"
    
    local deleted_count=0
    
    # Limpar backups por tipo
    for backup_type in daily weekly monthly; do
        print_info "Limpando backups $backup_type com mais de $RETENTION_DAYS dias..."
        
        while IFS= read -r -d '' file; do
            rm -f "$file"
            deleted_count=$((deleted_count + 1))
        done < <(find "$BACKUP_DIR/$backup_type" -name "*.tar.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    done
    
    # Limpar backups de bancos
    for db_dir in "$MYSQL_BACKUP_DIR" "$POSTGRES_BACKUP_DIR"; do
        while IFS= read -r -d '' file; do
            rm -f "$file"
            deleted_count=$((deleted_count + 1))
        done < <(find "$db_dir" -name "*.sql.gz" -mtime +$RETENTION_DAYS -print0 2>/dev/null)
    done
    
    # Limpar backups incrementais (manter apenas 7 dias)
    while IFS= read -r -d '' file; do
        rm -f "$file"
        deleted_count=$((deleted_count + 1))
    done < <(find "$INCREMENTAL_DIR" -name "*.tar.gz" -mtime +7 -print0 2>/dev/null)
    
    if [ $deleted_count -gt 0 ]; then
        print_success "$deleted_count backups antigos removidos"
        log_action "$deleted_count backups antigos removidos"
    else
        print_info "Nenhum backup antigo para remover"
    fi
}

# Enviar notificações
send_notification() {
    local status="$1"
    local message="$2"
    
    # Email
    if [ -n "$EMAIL_NOTIFICATION" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup Status: $status" "$EMAIL_NOTIFICATION"
    fi
    
    # Slack
    if [ -n "$SLACK_WEBHOOK" ]; then
        local payload="{\"text\":\"🔄 Backup $status\\n$message\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK" &>/dev/null
    fi
    
    # Discord
    if [ -n "$DISCORD_WEBHOOK" ]; then
        local payload="{\"content\":\"🔄 **Backup $status**\\n$message\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$DISCORD_WEBHOOK" &>/dev/null
    fi
}

# Listar backups
list_backups() {
    print_header "📋 Backups Disponíveis"
    echo
    
    for backup_type in daily weekly monthly incremental; do
        local backup_dir="$BACKUP_DIR/$backup_type"
        if [ "$backup_type" = "incremental" ]; then
            backup_dir="$INCREMENTAL_DIR"
        fi
        
        if [ -d "$backup_dir" ] && [ "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
            print_info "Backups $backup_type:"
            ls -lh "$backup_dir"/*.tar.gz 2>/dev/null | awk '{print "  " $9 " - " $5 " - " $6 " " $7 " " $8}'
            echo
        fi
    done
    
    # Listar backups de bancos
    for db_type in mysql postgres; do
        local db_dir="${db_type^^}_BACKUP_DIR"
        db_dir="${!db_dir}"
        
        if [ -d "$db_dir" ] && [ "$(ls -A "$db_dir" 2>/dev/null)" ]; then
            print_info "Backups $db_type:"
            ls -lh "$db_dir"/*.sql.gz 2>/dev/null | awk '{print "  " $9 " - " $5 " - " $6 " " $7 " " $8}'
            echo
        fi
    done
}

# Restaurar backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        print_error "Arquivo de backup não encontrado: $backup_file"
        return 1
    fi
    
    print_header "♻️ Restaurando backup"
    print_warning "Esta operação pode sobrescrever arquivos existentes!"
    
    read -p "Tem certeza que deseja continuar? (s/N): " confirm
    if [[ ! $confirm =~ ^[SsYy]$ ]]; then
        print_info "Operação cancelada"
        return 1
    fi
    
    print_info "Verificando integridade do backup..."
    if ! verify_backup "$backup_file"; then
        return 1
    fi
    
    print_info "Restaurando: $backup_file"
    
    if [[ "$backup_file" == *.tar.gz ]]; then
        if tar -xzf "$backup_file" -C / 2>/dev/null; then
            print_success "Backup restaurado com sucesso"
            log_action "Backup restaurado: $backup_file"
            return 0
        else
            print_error "Falha ao restaurar backup"
            return 1
        fi
    else
        print_error "Formato de backup não suportado"
        return 1
    fi
}

# Estatísticas
show_statistics() {
    print_header "📊 Estatísticas de Backup"
    echo
    
    # Espaço total usado
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    print_info "Espaço total usado: $total_size"
    
    # Contadores por tipo
    for backup_type in daily weekly monthly incremental; do
        local backup_dir="$BACKUP_DIR/$backup_type"
        if [ "$backup_type" = "incremental" ]; then
            backup_dir="$INCREMENTAL_DIR"
        fi
        
        if [ -d "$backup_dir" ]; then
            local count=$(ls -1 "$backup_dir"/*.tar.gz 2>/dev/null | wc -l)
            local size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
            echo "  • $backup_type: $count backups ($size)"
        fi
    done
    
    echo
    
    # Último backup
    print_info "Últimos backups:"
    if [ -f "$LOG_FILE" ]; then
        grep "concluído:" "$LOG_FILE" | tail -5 | while read line; do
            echo "  • $line"
        done
    fi
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    Sistema de Backup                          ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 💾 Backup completo do sistema                             ║"
    echo "║  2. 📈 Backup incremental                                     ║"
    echo "║  3. 🗄️ Backup de bancos de dados                              ║"
    echo "║  4. 🔄 Backup completo (sistema + bancos)                    ║"
    echo "║  5. 📋 Listar backups                                        ║"
    echo "║  6. ♻️ Restaurar backup                                       ║"
    echo "║  7. 🧹 Limpeza de backups antigos                            ║"
    echo "║  8. ☁️ Sincronização remota                                   ║"
    echo "║  9. 📊 Estatísticas                                          ║"
    echo "║  10. ⚙️ Configurações                                         ║"
    echo "║  0. ❌ Sair                                                    ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_backup() {
    print_header "⚙️ Configurações de Backup"
    echo
    
    print_info "Arquivo de configuração: $CONFIG_FILE"
    print_info "Diretório de backup: $BACKUP_DIR"
    print_info "Retenção: $RETENTION_DAYS dias"
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
    create_config
    create_directories
    check_lock
    
    case "${1:-}" in
        "system")
            backup_system daily && send_notification "SUCCESS" "Backup do sistema concluído"
            ;;
        "incremental")
            backup_incremental && send_notification "SUCCESS" "Backup incremental concluído"
            ;;
        "databases")
            backup_mysql && backup_postgres && send_notification "SUCCESS" "Backup de bancos concluído"
            ;;
        "full")
            backup_system daily && backup_mysql && backup_postgres && cleanup_old_backups
            send_notification "SUCCESS" "Backup completo concluído"
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "list")
            list_backups
            ;;
        *)
            # Modo interativo
            while true; do
                show_menu
                read -p "Escolha uma opção (0-10): " choice
                
                case $choice in
                    1)
                        backup_system daily
                        ;;
                    2)
                        backup_incremental
                        ;;
                    3)
                        backup_mysql && backup_postgres
                        ;;
                    4)
                        backup_system daily && backup_mysql && backup_postgres
                        ;;
                    5)
                        list_backups
                        ;;
                    6)
                        list_backups
                        echo
                        read -p "Digite o caminho completo do backup a restaurar: " backup_path
                        if [ -n "$backup_path" ]; then
                            restore_backup "$backup_path"
                        fi
                        ;;
                    7)
                        cleanup_old_backups
                        ;;
                    8)
                        remote_sync
                        ;;
                    9)
                        show_statistics
                        ;;
                    10)
                        configure_backup
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