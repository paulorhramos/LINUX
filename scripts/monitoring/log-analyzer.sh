#!/bin/bash

# =============================================================================
# Analisador de Logs para Rocky Linux 10
# =============================================================================
# Descrição: Sistema completo de análise e monitoramento de logs
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
CONFIG_FILE="/etc/log-analyzer.conf"
LOG_FILE="/var/log/log-analyzer.log"
REPORT_DIR="/var/log/log-analysis"

# Funções auxiliares
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_header() { echo -e "${CYAN}$1${NC}"; }

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Criar configuração
create_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configurações do Log Analyzer

# Logs para monitorar
SYSTEM_LOGS="/var/log/messages,/var/log/secure,/var/log/cron"
SERVICE_LOGS="/var/log/httpd/error_log,/var/log/nginx/error.log,/var/log/mysql/error.log"
CUSTOM_LOGS=""

# Configurações de análise
ANALYSIS_PERIOD="24h"
ERROR_THRESHOLD=10
WARNING_THRESHOLD=5
CRITICAL_PATTERNS="CRITICAL,FATAL,PANIC,ERROR,FAILED"
WARNING_PATTERNS="WARNING,WARN,TIMEOUT,SLOW"
SECURITY_PATTERNS="authentication failure,invalid user,connection refused,break-in attempt"

# Configurações de relatório
GENERATE_REPORTS=true
REPORT_FORMAT="html"
KEEP_REPORTS_DAYS=30

# Configurações de alertas
ALERT_EMAIL=""
ALERT_WEBHOOK=""
ENABLE_REAL_TIME_ALERTS=true

# Configurações de performance
MAX_LOG_SIZE_MB=500
ENABLE_LOG_ROTATION_CHECK=true
COMPRESS_OLD_REPORTS=true

# Filtros personalizados
EXCLUDE_PATTERNS="systemd,NetworkManager"
INCLUDE_ONLY=""
IGNORE_IPS="127.0.0.1,::1"

# Configurações avançadas
ENABLE_TREND_ANALYSIS=true
ENABLE_ANOMALY_DETECTION=true
BASELINE_DAYS=7
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Preparar ambiente
setup_environment() {
    mkdir -p "$REPORT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Verificar dependências
    local missing_deps=()
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v awk &> /dev/null; then
        missing_deps+=("gawk")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_info "Instalando dependências: ${missing_deps[*]}"
        dnf install -y "${missing_deps[@]}"
    fi
}

# Verificar tamanho dos logs
check_log_sizes() {
    print_header "📏 Verificando Tamanho dos Logs"
    
    local total_size=0
    local large_logs=()
    
    # Verificar logs do sistema
    IFS=',' read -ra LOGS <<< "$SYSTEM_LOGS"
    for log_file in "${LOGS[@]}"; do
        if [ -f "$log_file" ]; then
            local size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1)
            total_size=$((total_size + size_mb))
            
            echo "📄 $log_file: ${size_mb}MB"
            
            if [ "$size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
                large_logs+=("$log_file")
                print_warning "Log muito grande: $log_file (${size_mb}MB)"
            fi
        fi
    done
    
    # Verificar logs de serviços
    IFS=',' read -ra LOGS <<< "$SERVICE_LOGS"
    for log_file in "${LOGS[@]}"; do
        if [ -f "$log_file" ]; then
            local size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1)
            total_size=$((total_size + size_mb))
            
            echo "📄 $log_file: ${size_mb}MB"
            
            if [ "$size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
                large_logs+=("$log_file")
                print_warning "Log muito grande: $log_file (${size_mb}MB)"
            fi
        fi
    done
    
    echo
    print_info "Tamanho total dos logs: ${total_size}MB"
    
    if [ ${#large_logs[@]} -gt 0 ]; then
        print_warning "${#large_logs[@]} logs excedem o limite de ${MAX_LOG_SIZE_MB}MB"
        return 1
    else
        print_success "Todos os logs estão dentro do limite de tamanho"
        return 0
    fi
}

# Analisar erros
analyze_errors() {
    print_header "🔍 Analisando Erros"
    
    local time_filter=""
    case "$ANALYSIS_PERIOD" in
        "1h") time_filter="--since '1 hour ago'" ;;
        "6h") time_filter="--since '6 hours ago'" ;;
        "12h") time_filter="--since '12 hours ago'" ;;
        "24h") time_filter="--since '24 hours ago'" ;;
        "7d") time_filter="--since '7 days ago'" ;;
        *) time_filter="--since '24 hours ago'" ;;
    esac
    
    echo "🕒 Período de análise: $ANALYSIS_PERIOD"
    echo
    
    # Analisar journald
    print_info "Analisando journald..."
    
    local critical_count=$(eval "journalctl $time_filter --priority=0..2 --no-pager" | wc -l)
    local error_count=$(eval "journalctl $time_filter --priority=3 --no-pager" | wc -l)
    local warning_count=$(eval "journalctl $time_filter --priority=4 --no-pager" | wc -l)
    
    echo "  • Erros críticos: $critical_count"
    echo "  • Erros: $error_count"
    echo "  • Warnings: $warning_count"
    
    if [ "$critical_count" -gt 0 ]; then
        print_error "$critical_count mensagens críticas encontradas"
        echo "  📋 Últimas mensagens críticas:"
        eval "journalctl $time_filter --priority=0..2 --no-pager" | tail -5 | while read line; do
            echo "    $(echo "$line" | cut -c1-120)..."
        done
    fi
    
    if [ "$error_count" -gt "$ERROR_THRESHOLD" ]; then
        print_warning "Muitos erros detectados: $error_count (limite: $ERROR_THRESHOLD)"
    fi
    
    echo
    
    # Analisar logs específicos
    print_info "Analisando logs específicos..."
    
    IFS=',' read -ra PATTERNS <<< "$CRITICAL_PATTERNS"
    for pattern in "${PATTERNS[@]}"; do
        local matches=$(grep -i "$pattern" /var/log/messages 2>/dev/null | wc -l)
        if [ "$matches" -gt 0 ]; then
            echo "  • Pattern '$pattern': $matches ocorrências"
            if [ "$matches" -gt 5 ]; then
                print_warning "Muitas ocorrências de '$pattern'"
            fi
        fi
    done
}

# Analisar segurança
analyze_security() {
    print_header "🔒 Analisando Logs de Segurança"
    
    local security_events=0
    
    # Verificar tentativas de login falharam
    local failed_logins=$(grep -i "authentication failure" /var/log/secure 2>/dev/null | wc -l)
    local invalid_users=$(grep -i "invalid user" /var/log/secure 2>/dev/null | wc -l)
    local connection_refused=$(grep -i "connection refused" /var/log/secure 2>/dev/null | wc -l)
    
    echo "🚨 Eventos de segurança:"
    echo "  • Falhas de autenticação: $failed_logins"
    echo "  • Usuários inválidos: $invalid_users"
    echo "  • Conexões recusadas: $connection_refused"
    
    security_events=$((failed_logins + invalid_users + connection_refused))
    
    if [ "$failed_logins" -gt 10 ]; then
        print_warning "Muitas falhas de autenticação detectadas"
        echo "  📋 IPs mais frequentes:"
        grep -i "authentication failure" /var/log/secure 2>/dev/null | \
        awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -5 | \
        while read count ip; do
            echo "    $ip: $count tentativas"
        done
    fi
    
    if [ "$invalid_users" -gt 5 ]; then
        print_warning "Tentativas de acesso com usuários inválidos"
        echo "  📋 Usuários mais tentados:"
        grep -i "invalid user" /var/log/secure 2>/dev/null | \
        awk '{print $8}' | sort | uniq -c | sort -nr | head -5 | \
        while read count user; do
            echo "    $user: $count tentativas"
        done
    fi
    
    # Verificar sudo
    local sudo_events=$(grep -i "sudo:" /var/log/secure 2>/dev/null | wc -l)
    echo "  • Eventos sudo: $sudo_events"
    
    # Verificar SELinux denials
    if command -v getenforce &> /dev/null && [ "$(getenforce)" != "Disabled" ]; then
        local selinux_denials=$(grep -i "avc.*denied" /var/log/audit/audit.log 2>/dev/null | wc -l)
        echo "  • SELinux denials: $selinux_denials"
        
        if [ "$selinux_denials" -gt 0 ]; then
            print_warning "$selinux_denials denials SELinux encontrados"
        fi
    fi
    
    echo
    
    if [ "$security_events" -gt 20 ]; then
        print_error "Alto número de eventos de segurança: $security_events"
        log_action "SECURITY ALERT: $security_events eventos de segurança detectados"
        return 1
    elif [ "$security_events" -gt 5 ]; then
        print_warning "Eventos de segurança detectados: $security_events"
        return 2
    else
        print_success "Nível normal de eventos de segurança"
        return 0
    fi
}

# Analisar performance
analyze_performance() {
    print_header "⚡ Analisando Performance"
    
    # OOM kills
    local oom_kills=$(dmesg | grep -i "killed process" | wc -l)
    echo "💾 Out of Memory:"
    echo "  • OOM kills: $oom_kills"
    
    if [ "$oom_kills" -gt 0 ]; then
        print_warning "$oom_kills processos mortos por OOM"
        echo "  📋 Últimos processos mortos:"
        dmesg | grep -i "killed process" | tail -3 | while read line; do
            echo "    $(echo "$line" | awk '{print $5, $6, $7, $8}')"
        done
    fi
    
    # Slow queries (se MySQL estiver instalado)
    if [ -f "/var/log/mysql/slow.log" ] || [ -f "/var/log/mysqld-slow.log" ]; then
        local slow_queries=$(grep -c "Query_time" /var/log/mysql/slow.log /var/log/mysqld-slow.log 2>/dev/null)
        echo "🗄️ MySQL:"
        echo "  • Slow queries: $slow_queries"
        
        if [ "$slow_queries" -gt 10 ]; then
            print_warning "Muitas queries lentas detectadas"
        fi
    fi
    
    # High load
    local high_load_events=$(grep -i "load average" /var/log/messages 2>/dev/null | grep -E "[0-9]{2}\." | wc -l)
    echo "📊 Sistema:"
    echo "  • Eventos de alta carga: $high_load_events"
    
    # Disk I/O errors
    local io_errors=$(dmesg | grep -i "i/o error\|ata.*error" | wc -l)
    echo "💽 I/O:"
    echo "  • Erros de I/O: $io_errors"
    
    if [ "$io_errors" -gt 0 ]; then
        print_error "$io_errors erros de I/O detectados"
    fi
}

# Analisar serviços
analyze_services() {
    print_header "🔧 Analisando Serviços"
    
    # Serviços que falharam
    local failed_services=$(systemctl --failed --no-legend | wc -l)
    echo "⚙️ Status dos serviços:"
    echo "  • Serviços falhados: $failed_services"
    
    if [ "$failed_services" -gt 0 ]; then
        print_error "$failed_services serviços falharam"
        echo "  📋 Serviços falhados:"
        systemctl --failed --no-legend | head -5 | while read line; do
            echo "    $(echo "$line" | awk '{print $1}')"
        done
    else
        print_success "Todos os serviços estão funcionando"
    fi
    
    # Restarts de serviços
    local service_restarts=$(journalctl --since "24 hours ago" --no-pager | grep -i "started\|stopped" | wc -l)
    echo "  • Restarts recentes: $service_restarts"
    
    # Verificar logs específicos de serviços
    local services=("httpd" "nginx" "mysql" "postgresql" "docker")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            local service_errors=$(journalctl -u "$service" --since "24 hours ago" --priority=3 --no-pager | wc -l)
            echo "  • $service errors: $service_errors"
            
            if [ "$service_errors" -gt 5 ]; then
                print_warning "Muitos erros no serviço $service"
            fi
        fi
    done
}

# Análise de tendências
analyze_trends() {
    if [ "$ENABLE_TREND_ANALYSIS" != "true" ]; then
        return 0
    fi
    
    print_header "📈 Análise de Tendências"
    
    local report_file="$REPORT_DIR/trends-$(date +%Y%m%d).txt"
    
    # Coletar dados dos últimos dias
    for days in 1 2 3 7; do
        local errors=$(journalctl --since "${days} days ago" --until "$((days-1)) days ago" --priority=3 --no-pager | wc -l)
        local warnings=$(journalctl --since "${days} days ago" --until "$((days-1)) days ago" --priority=4 --no-pager | wc -l)
        
        echo "📅 $days dia(s) atrás: $errors erros, $warnings warnings"
    done
    
    # Análise por hora do dia
    echo
    print_info "Distribuição de erros por hora:"
    journalctl --since "24 hours ago" --priority=3 --no-pager | \
    awk '{print $3}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -5 | \
    while read count hour; do
        echo "  • ${hour}h: $count erros"
    done
}

# Detectar anomalias
detect_anomalies() {
    if [ "$ENABLE_ANOMALY_DETECTION" != "true" ]; then
        return 0
    fi
    
    print_header "🎯 Detectando Anomalias"
    
    # Calcular baseline dos últimos dias
    local baseline_errors=$(journalctl --since "${BASELINE_DAYS} days ago" --priority=3 --no-pager | wc -l)
    local daily_baseline=$((baseline_errors / BASELINE_DAYS))
    
    # Erros de hoje
    local today_errors=$(journalctl --since "today" --priority=3 --no-pager | wc -l)
    
    echo "📊 Comparação com baseline:"
    echo "  • Baseline diário: $daily_baseline erros"
    echo "  • Hoje: $today_errors erros"
    
    # Detectar se está muito acima do normal
    local threshold=$((daily_baseline * 3))
    if [ "$today_errors" -gt "$threshold" ]; then
        print_error "ANOMALIA: Erros hoje ($today_errors) excedem 3x o baseline ($daily_baseline)"
        log_action "ANOMALY DETECTED: $today_errors errors vs baseline $daily_baseline"
        return 1
    elif [ "$today_errors" -gt "$((daily_baseline * 2))" ]; then
        print_warning "Erros elevados: $today_errors vs baseline $daily_baseline"
        return 2
    else
        print_success "Nível de erros dentro do esperado"
        return 0
    fi
}

# Gerar relatório HTML
generate_html_report() {
    local report_file="$REPORT_DIR/log-analysis-$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Log Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #3498db; background: #f8f9fa; }
        .error { border-left-color: #e74c3c; background: #fdf2f2; }
        .warning { border-left-color: #f39c12; background: #fef9e7; }
        .success { border-left-color: #27ae60; background: #f0f8f0; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #34495e; color: white; }
        .chart { width: 100%; height: 300px; background: #ecf0f1; margin: 10px 0; }
    </style>
</head>
<body>
EOF

    echo "<div class='header'>" >> "$report_file"
    echo "<h1>🔍 Log Analysis Report</h1>" >> "$report_file"
    echo "<p>Generated: $(date)</p>" >> "$report_file"
    echo "<p>Hostname: $(hostname)</p>" >> "$report_file"
    echo "<p>Period: $ANALYSIS_PERIOD</p>" >> "$report_file"
    echo "</div>" >> "$report_file"
    
    # Adicionar seções do relatório
    {
        echo "<div class='section'>"
        echo "<h2>📊 Summary</h2>"
        echo "<table>"
        echo "<tr><th>Metric</th><th>Count</th><th>Status</th></tr>"
        
        local critical_count=$(journalctl --since "24 hours ago" --priority=0..2 --no-pager | wc -l)
        local error_count=$(journalctl --since "24 hours ago" --priority=3 --no-pager | wc -l)
        local warning_count=$(journalctl --since "24 hours ago" --priority=4 --no-pager | wc -l)
        
        echo "<tr><td>Critical Events</td><td>$critical_count</td><td>$([ $critical_count -eq 0 ] && echo "✅ OK" || echo "❌ CRITICAL")</td></tr>"
        echo "<tr><td>Errors</td><td>$error_count</td><td>$([ $error_count -lt $ERROR_THRESHOLD ] && echo "✅ OK" || echo "⚠️ HIGH")</td></tr>"
        echo "<tr><td>Warnings</td><td>$warning_count</td><td>$([ $warning_count -lt $WARNING_THRESHOLD ] && echo "✅ OK" || echo "⚠️ HIGH")</td></tr>"
        
        echo "</table>"
        echo "</div>"
    } >> "$report_file"
    
    echo "</body></html>" >> "$report_file"
    
    print_success "Relatório HTML gerado: $report_file"
}

# Gerar relatório texto
generate_text_report() {
    local report_file="$REPORT_DIR/log-analysis-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Log Analysis Report - $(date)"
        echo "=========================================="
        echo "Hostname: $(hostname)"
        echo "Period: $ANALYSIS_PERIOD"
        echo
        
        echo "=== SUMMARY ==="
        local critical_count=$(journalctl --since "24 hours ago" --priority=0..2 --no-pager | wc -l)
        local error_count=$(journalctl --since "24 hours ago" --priority=3 --no-pager | wc -l)
        local warning_count=$(journalctl --since "24 hours ago" --priority=4 --no-pager | wc -l)
        
        echo "Critical Events: $critical_count"
        echo "Errors: $error_count"
        echo "Warnings: $warning_count"
        echo
        
        echo "=== SECURITY EVENTS ==="
        local failed_logins=$(grep -i "authentication failure" /var/log/secure 2>/dev/null | wc -l)
        local invalid_users=$(grep -i "invalid user" /var/log/secure 2>/dev/null | wc -l)
        
        echo "Failed Logins: $failed_logins"
        echo "Invalid Users: $invalid_users"
        echo
        
        echo "=== SERVICE STATUS ==="
        local failed_services=$(systemctl --failed --no-legend | wc -l)
        echo "Failed Services: $failed_services"
        
        if [ "$failed_services" -gt 0 ]; then
            echo "Failed service list:"
            systemctl --failed --no-legend | awk '{print "  " $1}'
        fi
        echo
        
        echo "=== TOP ERRORS ==="
        journalctl --since "24 hours ago" --priority=3 --no-pager | \
        awk '{for(i=5;i<=NF;i++) printf $i" "; print ""}' | \
        sort | uniq -c | sort -nr | head -10
        echo
        
    } > "$report_file"
    
    print_success "Relatório texto gerado: $report_file"
}

# Monitor em tempo real
real_time_monitor() {
    print_header "🔴 Monitor em Tempo Real"
    
    print_info "Monitorando logs em tempo real (Ctrl+C para parar)..."
    echo
    
    # Monitorar journald em tempo real
    journalctl -f --priority=0..4 | while read line; do
        local timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
        local level=""
        
        # Determinar nível baseado em keywords
        if echo "$line" | grep -qiE "critical|fatal|panic"; then
            level="${RED}[CRITICAL]${NC}"
        elif echo "$line" | grep -qiE "error|failed"; then
            level="${RED}[ERROR]${NC}"
        elif echo "$line" | grep -qiE "warning|warn"; then
            level="${YELLOW}[WARNING]${NC}"
        else
            level="${BLUE}[INFO]${NC}"
        fi
        
        echo -e "$level $timestamp: $(echo "$line" | cut -c50-150)..."
        
        # Enviar alerta se crítico
        if echo "$line" | grep -qiE "critical|fatal|panic" && [ "$ENABLE_REAL_TIME_ALERTS" = "true" ]; then
            send_alert "CRITICAL LOG EVENT: $line"
        fi
    done
}

# Enviar alertas
send_alert() {
    local message="$1"
    
    # Email
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Log Alert - $(hostname)" "$ALERT_EMAIL"
    fi
    
    # Webhook
    if [ -n "$ALERT_WEBHOOK" ]; then
        local payload="{\"text\":\"🚨 **Log Alert**\\n$message\"}"
        curl -X POST -H 'Content-type: application/json' --data "$payload" "$ALERT_WEBHOOK" &>/dev/null
    fi
    
    log_action "ALERT SENT: $message"
}

# Limpeza de logs antigos
cleanup_old_logs() {
    print_header "🧹 Limpeza de Logs Antigos"
    
    # Limpar relatórios antigos
    local old_reports=$(find "$REPORT_DIR" -name "*.txt" -o -name "*.html" -mtime +$KEEP_REPORTS_DAYS 2>/dev/null | wc -l)
    
    if [ "$old_reports" -gt 0 ]; then
        find "$REPORT_DIR" -name "*.txt" -o -name "*.html" -mtime +$KEEP_REPORTS_DAYS -delete 2>/dev/null
        print_success "$old_reports relatórios antigos removidos"
    fi
    
    # Comprimir relatórios antigos se habilitado
    if [ "$COMPRESS_OLD_REPORTS" = "true" ]; then
        find "$REPORT_DIR" -name "*.txt" -o -name "*.html" -mtime +1 ! -name "*.gz" -exec gzip {} \; 2>/dev/null
        print_info "Relatórios antigos comprimidos"
    fi
    
    # Limpar journald logs antigos
    local journal_size_before=$(journalctl --disk-usage | awk '{print $3}' | sed 's/G//')
    journalctl --vacuum-time=7d &>/dev/null
    local journal_size_after=$(journalctl --disk-usage | awk '{print $3}' | sed 's/G//')
    
    print_info "Journal: ${journal_size_before} -> ${journal_size_after} (GB)"
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                    Log Analyzer                               ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 🔍 Analisar erros                                        ║"
    echo "║  2. 🔒 Analisar segurança                                    ║"
    echo "║  3. ⚡ Analisar performance                                   ║"
    echo "║  4. 🔧 Analisar serviços                                     ║"
    echo "║  5. 📈 Análise de tendências                                 ║"
    echo "║  6. 🎯 Detectar anomalias                                    ║"
    echo "║  7. 📊 Gerar relatório completo                              ║"
    echo "║  8. 🔴 Monitor em tempo real                                 ║"
    echo "║  9. 📏 Verificar tamanho dos logs                           ║"
    echo "║  10. 🧹 Limpeza de logs                                      ║"
    echo "║  11. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_analyzer() {
    print_header "⚙️ Configurações do Log Analyzer"
    echo
    
    print_info "Configurações atuais:"
    echo "  • Período de análise: $ANALYSIS_PERIOD"
    echo "  • Limite de erros: $ERROR_THRESHOLD"
    echo "  • Formato de relatório: $REPORT_FORMAT"
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
    setup_environment
    
    case "${1:-}" in
        "errors")
            analyze_errors
            ;;
        "security")
            analyze_security
            ;;
        "performance")
            analyze_performance
            ;;
        "services")
            analyze_services
            ;;
        "trends")
            analyze_trends
            ;;
        "anomalies")
            detect_anomalies
            ;;
        "report")
            analyze_errors && analyze_security && analyze_performance && analyze_services
            if [ "$REPORT_FORMAT" = "html" ]; then
                generate_html_report
            else
                generate_text_report
            fi
            ;;
        "monitor")
            real_time_monitor
            ;;
        "cleanup")
            cleanup_old_logs
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-11): " choice
                
                case $choice in
                    1) analyze_errors ;;
                    2) analyze_security ;;
                    3) analyze_performance ;;
                    4) analyze_services ;;
                    5) analyze_trends ;;
                    6) detect_anomalies ;;
                    7)
                        analyze_errors && analyze_security && analyze_performance && analyze_services
                        if [ "$REPORT_FORMAT" = "html" ]; then
                            generate_html_report
                        else
                            generate_text_report
                        fi
                        ;;
                    8) real_time_monitor ;;
                    9) check_log_sizes ;;
                    10) cleanup_old_logs ;;
                    11) configure_analyzer ;;
                    0)
                        print_success "Até logo!"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        ;;
                esac
                
                if [ "$choice" != "8" ]; then
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