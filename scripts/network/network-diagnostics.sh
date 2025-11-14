#!/bin/bash

# =============================================================================
# Diagnóstico de Rede para Rocky Linux 10
# =============================================================================
# Descrição: Ferramentas completas de diagnóstico e troubleshooting de rede
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
CONFIG_FILE="/etc/network-diagnostics.conf"
LOG_FILE="/var/log/network-diagnostics.log"
REPORT_DIR="/var/log/network-reports"

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
# Configurações do Network Diagnostics

# Hosts para teste de conectividade
TEST_HOSTS="8.8.8.8,1.1.1.1,google.com,cloudflare.com"
DNS_SERVERS="8.8.8.8,1.1.1.1,208.67.222.222"

# Configurações de timeout
PING_TIMEOUT=5
DNS_TIMEOUT=3
TCP_TIMEOUT=10

# Configurações de monitoramento
ENABLE_CONTINUOUS_MONITORING=false
MONITORING_INTERVAL=60
ALERT_THRESHOLDS_PACKET_LOSS=5
ALERT_THRESHOLDS_LATENCY=100

# Configurações de relatório
GENERATE_REPORTS=true
REPORT_FORMAT="text"
KEEP_REPORTS_DAYS=30

# Configurações de speedtest
ENABLE_SPEEDTEST=true
SPEEDTEST_SERVER=""
BANDWIDTH_THRESHOLD_DOWN=10
BANDWIDTH_THRESHOLD_UP=5

# Configurações avançadas
ENABLE_TRACEROUTE=true
MAX_HOPS=30
ENABLE_PORT_SCAN=false
COMMON_PORTS="22,80,443,993,995"

# Notificações
ALERT_EMAIL=""
ALERT_WEBHOOK=""
ENABLE_SOUND_ALERTS=false
EOF
        print_info "Arquivo de configuração criado: $CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
}

# Verificar dependências
check_dependencies() {
    local missing_deps=()
    
    # Ferramentas essenciais
    local tools=("ping" "dig" "nslookup" "ss" "ip" "route")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # Ferramentas opcionais
    if ! command -v traceroute &> /dev/null; then
        missing_deps+=("traceroute")
    fi
    
    if ! command -v nmap &> /dev/null && [ "$ENABLE_PORT_SCAN" = "true" ]; then
        missing_deps+=("nmap")
    fi
    
    if ! command -v speedtest-cli &> /dev/null && [ "$ENABLE_SPEEDTEST" = "true" ]; then
        missing_deps+=("python3-pip")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "Instalando dependências: ${missing_deps[*]}"
        dnf install -y "${missing_deps[@]}"
        
        # Instalar speedtest-cli via pip se necessário
        if [[ "${missing_deps[*]}" =~ "python3-pip" ]] && [ "$ENABLE_SPEEDTEST" = "true" ]; then
            pip3 install speedtest-cli
        fi
    fi
}

# Informações básicas da rede
show_network_info() {
    print_header "📡 Informações da Rede"
    
    # Interfaces de rede
    print_info "Interfaces de rede:"
    ip link show | grep -E '^[0-9]' | while read line; do
        local interface=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
        local status=$(echo "$line" | grep -o 'state [A-Z]*' | awk '{print $2}')
        local flags=$(echo "$line" | grep -o '<[^>]*>' | tr -d '<>')
        
        echo "  🔌 $interface: $status ($flags)"
    done
    
    echo
    
    # Endereços IP
    print_info "Endereços IP:"
    ip addr show | grep -E 'inet ' | while read line; do
        local ip=$(echo "$line" | awk '{print $2}')
        local interface=$(echo "$line" | awk '{print $NF}')
        echo "  🌐 $interface: $ip"
    done
    
    echo
    
    # Rotas
    print_info "Tabela de roteamento:"
    ip route show | head -5 | while read line; do
        echo "  🛣️ $line"
    done
    
    echo
    
    # DNS
    print_info "Configuração DNS:"
    if [ -f /etc/resolv.conf ]; then
        grep -E '^nameserver' /etc/resolv.conf | while read line; do
            echo "  🔍 $line"
        done
    fi
    
    # Gateway padrão
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        echo "  🚪 Gateway padrão: $gateway"
    fi
}

# Teste de conectividade
test_connectivity() {
    print_header "🔗 Testando Conectividade"
    
    local total_tests=0
    local successful_tests=0
    
    IFS=',' read -ra HOSTS <<< "$TEST_HOSTS"
    for host in "${HOSTS[@]}"; do
        total_tests=$((total_tests + 1))
        echo -n "📡 Testando $host... "
        
        if ping -c 1 -W "$PING_TIMEOUT" "$host" &> /dev/null; then
            successful_tests=$((successful_tests + 1))
            print_success "OK"
            
            # Medir latência
            local latency=$(ping -c 3 -W "$PING_TIMEOUT" "$host" 2>/dev/null | grep 'avg' | awk -F'/' '{print $5}' | awk '{print $1}')
            if [ -n "$latency" ]; then
                echo "     Latência: ${latency}ms"
                
                # Verificar se latência está alta
                if (( $(echo "$latency > $ALERT_THRESHOLDS_LATENCY" | bc -l) 2>/dev/null )); then
                    print_warning "Latência alta para $host: ${latency}ms"
                fi
            fi
        else
            print_error "FALHA"
            log_action "CONNECTIVITY FAILED: $host"
        fi
    done
    
    echo
    local success_rate=$((successful_tests * 100 / total_tests))
    print_info "Taxa de sucesso: $success_rate% ($successful_tests/$total_tests)"
    
    if [ "$success_rate" -lt 50 ]; then
        print_error "CRÍTICO: Baixa taxa de conectividade ($success_rate%)"
        return 1
    elif [ "$success_rate" -lt 100 ]; then
        print_warning "ALERTA: Alguns hosts inacessíveis ($success_rate%)"
        return 2
    else
        print_success "Conectividade excelente!"
        return 0
    fi
}

# Teste de DNS
test_dns() {
    print_header "🔍 Testando DNS"
    
    local dns_issues=0
    
    # Testar servidores DNS
    print_info "Testando servidores DNS:"
    IFS=',' read -ra SERVERS <<< "$DNS_SERVERS"
    for server in "${SERVERS[@]}"; do
        echo -n "  🔍 $server... "
        
        local start_time=$(date +%s%N)
        if timeout "$DNS_TIMEOUT" nslookup google.com "$server" &> /dev/null; then
            local end_time=$(date +%s%N)
            local response_time=$(( (end_time - start_time) / 1000000 ))
            print_success "OK (${response_time}ms)"
        else
            print_error "FALHA"
            dns_issues=$((dns_issues + 1))
        fi
    done
    
    echo
    
    # Testar resolução de nomes
    print_info "Testando resolução de nomes:"
    local test_domains=("google.com" "github.com" "cloudflare.com")
    
    for domain in "${test_domains[@]}"; do
        echo -n "  🌐 $domain... "
        
        if timeout "$DNS_TIMEOUT" dig +short "$domain" &> /dev/null; then
            local ip=$(dig +short "$domain" | head -1)
            print_success "OK ($ip)"
        else
            print_error "FALHA"
            dns_issues=$((dns_issues + 1))
        fi
    done
    
    # Teste reverso
    echo
    print_info "Testando DNS reverso:"
    local test_ip="8.8.8.8"
    echo -n "  🔄 $test_ip... "
    
    if timeout "$DNS_TIMEOUT" dig -x "$test_ip" +short &> /dev/null; then
        local hostname=$(dig -x "$test_ip" +short)
        print_success "OK ($hostname)"
    else
        print_error "FALHA"
        dns_issues=$((dns_issues + 1))
    fi
    
    echo
    
    if [ "$dns_issues" -eq 0 ]; then
        print_success "DNS funcionando perfeitamente!"
        return 0
    else
        print_warning "$dns_issues problemas de DNS detectados"
        return 1
    fi
}

# Análise de rota
analyze_routes() {
    print_header "🛣️ Análise de Rotas"
    
    # Gateway padrão
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    print_info "Gateway padrão: $gateway"
    
    if [ -n "$gateway" ]; then
        echo -n "  📡 Testando gateway... "
        if ping -c 1 -W "$PING_TIMEOUT" "$gateway" &> /dev/null; then
            print_success "OK"
        else
            print_error "Gateway inacessível!"
            return 1
        fi
    fi
    
    echo
    
    # Traceroute para hosts de teste
    if [ "$ENABLE_TRACEROUTE" = "true" ] && command -v traceroute &> /dev/null; then
        print_info "Análise de rota para google.com:"
        
        local traceroute_output=$(timeout 30 traceroute -m "$MAX_HOPS" google.com 2>/dev/null)
        echo "$traceroute_output" | head -10 | while read line; do
            if [[ "$line" =~ ^[[:space:]]*[0-9]+ ]]; then
                echo "  $line"
            fi
        done
        
        # Verificar se há timeouts excessivos
        local timeouts=$(echo "$traceroute_output" | grep -c "\*")
        if [ "$timeouts" -gt 3 ]; then
            print_warning "$timeouts hops com timeout detectados"
        fi
    fi
}

# Análise de portas
analyze_ports() {
    print_header "🔌 Análise de Portas"
    
    # Portas em listening
    print_info "Portas em listening:"
    ss -tlnp | grep LISTEN | head -10 | while read line; do
        local port=$(echo "$line" | awk '{print $4}' | awk -F':' '{print $NF}')
        local process=$(echo "$line" | awk '{print $6}' | cut -d'"' -f2 2>/dev/null)
        echo "  🔌 Porta $port: ${process:-N/A}"
    done
    
    echo
    
    # Conexões ativas
    print_info "Conexões ativas:"
    local active_connections=$(ss -tn state established | wc -l)
    echo "  🔗 Total de conexões: $active_connections"
    
    # Top IPs conectados
    if [ "$active_connections" -gt 0 ]; then
        echo "  📊 Top IPs conectados:"
        ss -tn state established | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -5 | while read count ip; do
            echo "    $ip: $count conexões"
        done
    fi
    
    echo
    
    # Teste de portas comuns (se habilitado)
    if [ "$ENABLE_PORT_SCAN" = "true" ] && command -v nmap &> /dev/null; then
        print_info "Testando portas comuns no localhost:"
        
        IFS=',' read -ra PORTS <<< "$COMMON_PORTS"
        for port in "${PORTS[@]}"; do
            echo -n "  🔌 Porta $port... "
            
            if timeout "$TCP_TIMEOUT" bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
                print_success "ABERTA"
            else
                print_info "FECHADA"
            fi
        done
    fi
}

# Análise de interface
analyze_interfaces() {
    print_header "🖧 Análise de Interfaces"
    
    # Estatísticas de interfaces
    ip -s link show | while read -r line; do
        if [[ "$line" =~ ^[0-9]+: ]]; then
            local interface=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
            local status=$(echo "$line" | grep -o 'state [A-Z]*' | awk '{print $2}')
            
            echo "🖧 Interface $interface ($status):"
            
            # Ler próximas linhas para estatísticas
            read -r stats_line1
            read -r stats_line2
            
            if [[ "$stats_line1" =~ RX.*bytes ]]; then
                local rx_packets=$(echo "$stats_line1" | awk '{print $2}')
                local rx_bytes=$(echo "$stats_line1" | awk '{print $5}')
                echo "  📥 RX: $rx_packets pacotes, $rx_bytes bytes"
            fi
            
            if [[ "$stats_line2" =~ TX.*bytes ]]; then
                local tx_packets=$(echo "$stats_line2" | awk '{print $2}')
                local tx_bytes=$(echo "$stats_line2" | awk '{print $5}')
                echo "  📤 TX: $tx_packets pacotes, $tx_bytes bytes"
            fi
            
            # Verificar erros
            local rx_errors=$(echo "$stats_line1" | awk '{print $3}')
            local tx_errors=$(echo "$stats_line2" | awk '{print $3}')
            
            if [ "$rx_errors" -gt 0 ] || [ "$tx_errors" -gt 0 ]; then
                print_warning "Erros detectados - RX: $rx_errors, TX: $tx_errors"
            fi
            
            echo
        fi
    done
}

# Teste de velocidade
speedtest() {
    if [ "$ENABLE_SPEEDTEST" != "true" ]; then
        print_info "Speedtest desabilitado na configuração"
        return 0
    fi
    
    print_header "🚀 Teste de Velocidade"
    
    if ! command -v speedtest-cli &> /dev/null; then
        print_warning "speedtest-cli não encontrado. Tentando instalar..."
        pip3 install speedtest-cli 2>/dev/null
        
        if ! command -v speedtest-cli &> /dev/null; then
            print_error "Falha ao instalar speedtest-cli"
            return 1
        fi
    fi
    
    print_info "Executando teste de velocidade..."
    print_warning "Isso pode demorar alguns minutos..."
    
    local speedtest_output
    if [ -n "$SPEEDTEST_SERVER" ]; then
        speedtest_output=$(speedtest-cli --server "$SPEEDTEST_SERVER" --simple 2>/dev/null)
    else
        speedtest_output=$(speedtest-cli --simple 2>/dev/null)
    fi
    
    if [ $? -eq 0 ]; then
        echo "$speedtest_output" | while read line; do
            if [[ "$line" =~ Ping ]]; then
                local ping=$(echo "$line" | awk '{print $2}')
                echo "  🏓 Ping: ${ping} ms"
            elif [[ "$line" =~ Download ]]; then
                local download=$(echo "$line" | awk '{print $2}')
                echo "  📥 Download: ${download} Mbit/s"
                
                # Verificar se está abaixo do limite
                local download_num=${download%.*}
                if [ "$download_num" -lt "$BANDWIDTH_THRESHOLD_DOWN" ]; then
                    print_warning "Velocidade de download baixa: ${download} Mbit/s"
                fi
            elif [[ "$line" =~ Upload ]]; then
                local upload=$(echo "$line" | awk '{print $2}')
                echo "  📤 Upload: ${upload} Mbit/s"
                
                # Verificar se está abaixo do limite
                local upload_num=${upload%.*}
                if [ "$upload_num" -lt "$BANDWIDTH_THRESHOLD_UP" ]; then
                    print_warning "Velocidade de upload baixa: ${upload} Mbit/s"
                fi
            fi
        done
        
        print_success "Teste de velocidade concluído"
        log_action "Speedtest completed: $speedtest_output"
    else
        print_error "Falha no teste de velocidade"
        return 1
    fi
}

# Diagnóstico completo
full_diagnosis() {
    print_header "🏥 Diagnóstico Completo da Rede"
    
    local issues_found=0
    
    echo "🔍 Executando diagnóstico completo..."
    echo
    
    # Executar todos os testes
    show_network_info
    echo
    
    if ! test_connectivity; then
        issues_found=$((issues_found + 1))
    fi
    echo
    
    if ! test_dns; then
        issues_found=$((issues_found + 1))
    fi
    echo
    
    analyze_routes
    echo
    
    analyze_ports
    echo
    
    analyze_interfaces
    echo
    
    speedtest
    echo
    
    # Resumo
    print_header "📋 Resumo do Diagnóstico"
    
    if [ "$issues_found" -eq 0 ]; then
        print_success "✅ Rede funcionando perfeitamente!"
        print_info "Todos os testes passaram com sucesso"
    elif [ "$issues_found" -eq 1 ]; then
        print_warning "⚠️ 1 problema detectado na rede"
        print_info "Verifique os detalhes acima"
    else
        print_error "❌ $issues_found problemas detectados na rede"
        print_info "Correção necessária - verifique os detalhes acima"
    fi
    
    log_action "Full network diagnosis completed: $issues_found issues found"
    
    return "$issues_found"
}

# Monitor contínuo
continuous_monitor() {
    print_header "📺 Monitor Contínuo de Rede"
    
    local interval="${1:-$MONITORING_INTERVAL}"
    
    print_info "Monitoramento iniciado (intervalo: ${interval}s)"
    print_info "Pressione Ctrl+C para parar"
    echo
    
    while true; do
        clear
        echo "=== Network Monitor - $(date) ==="
        echo
        
        # Teste rápido de conectividade
        local connectivity_ok=true
        IFS=',' read -ra HOSTS <<< "$TEST_HOSTS"
        for host in "${HOSTS[@]}" ; do
            if ! ping -c 1 -W 2 "$host" &> /dev/null; then
                connectivity_ok=false
                break
            fi
        done
        
        if [ "$connectivity_ok" = true ]; then
            print_success "Conectividade: OK"
        else
            print_error "Conectividade: PROBLEMA"
        fi
        
        # Estatísticas rápidas
        local active_connections=$(ss -tn state established | wc -l)
        local listening_ports=$(ss -tln | grep LISTEN | wc -l)
        
        echo "📊 Conexões ativas: $active_connections"
        echo "🔌 Portas listening: $listening_ports"
        
        # Mostrar top conexões
        echo
        echo "📈 Top conexões por IP:"
        ss -tn state established | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -nr | head -3 | while read count ip; do
            echo "  $ip: $count"
        done
        
        echo
        echo "Próxima verificação em ${interval} segundos..."
        
        sleep "$interval"
    done
}

# Resolver problemas comuns
troubleshoot() {
    print_header "🔧 Solucionador de Problemas"
    
    echo "Escolha o problema para diagnosticar:"
    echo "1. Sem conectividade com a internet"
    echo "2. DNS não funciona"
    echo "3. Velocidade lenta"
    echo "4. Conexões intermitentes"
    echo "5. Porta específica não acessível"
    echo "0. Voltar"
    echo
    
    read -p "Escolha uma opção: " trouble_choice
    
    case $trouble_choice in
        1)
            print_info "Diagnosticando conectividade..."
            
            # Testar gateway
            local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
            if [ -n "$gateway" ]; then
                if ping -c 1 -W 3 "$gateway" &> /dev/null; then
                    print_success "Gateway acessível: $gateway"
                    
                    # Testar DNS
                    if nslookup google.com &> /dev/null; then
                        print_success "DNS funcionando"
                        print_info "Problema pode ser com sites específicos"
                    else
                        print_error "Problema no DNS"
                        print_info "Soluções:"
                        print_info "- Verificar /etc/resolv.conf"
                        print_info "- Testar DNS público: echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
                    fi
                else
                    print_error "Gateway não acessível"
                    print_info "Soluções:"
                    print_info "- Verificar cabo de rede"
                    print_info "- Reiniciar interface: ip link set <interface> down && ip link set <interface> up"
                    print_info "- Verificar configuração de rede"
                fi
            else
                print_error "Nenhum gateway configurado"
                print_info "Configure um gateway padrão"
            fi
            ;;
            
        2)
            print_info "Diagnosticando DNS..."
            
            # Verificar arquivo resolv.conf
            if [ -f /etc/resolv.conf ]; then
                local dns_count=$(grep -c "^nameserver" /etc/resolv.conf)
                if [ "$dns_count" -eq 0 ]; then
                    print_error "Nenhum servidor DNS configurado"
                    print_info "Adicione: echo 'nameserver 8.8.8.8' >> /etc/resolv.conf"
                else
                    print_success "$dns_count servidores DNS configurados"
                    
                    # Testar cada servidor
                    grep "^nameserver" /etc/resolv.conf | while read line; do
                        local dns_server=$(echo "$line" | awk '{print $2}')
                        if timeout 3 nslookup google.com "$dns_server" &> /dev/null; then
                            print_success "DNS $dns_server funcionando"
                        else
                            print_error "DNS $dns_server com problema"
                        fi
                    done
                fi
            else
                print_error "/etc/resolv.conf não encontrado"
            fi
            ;;
            
        3)
            print_info "Diagnosticando velocidade..."
            
            # Verificar interfaces
            print_info "Verificando interfaces por erros..."
            ip -s link show | grep -A3 -B1 "errors" | while read line; do
                if [[ "$line" =~ errors.*dropped ]]; then
                    echo "  $line"
                fi
            done
            
            print_info "Execute um speedtest para medição precisa"
            ;;
            
        4)
            print_info "Diagnosticando conexões intermitentes..."
            
            print_info "Executando ping contínuo (Ctrl+C para parar)..."
            ping -i 1 8.8.8.8 | while read line; do
                if [[ "$line" =~ "time=" ]]; then
                    echo "$line"
                elif [[ "$line" =~ "no answer" ]] || [[ "$line" =~ "timeout" ]]; then
                    print_error "$line"
                fi
            done
            ;;
            
        5)
            read -p "Digite a porta para testar: " test_port
            read -p "Digite o host (localhost se local): " test_host
            
            if [ -z "$test_host" ]; then
                test_host="localhost"
            fi
            
            print_info "Testando conectividade para $test_host:$test_port"
            
            if timeout 5 bash -c "echo >/dev/tcp/$test_host/$test_port" 2>/dev/null; then
                print_success "Porta $test_port acessível em $test_host"
            else
                print_error "Porta $test_port não acessível"
                print_info "Verificações:"
                print_info "- Serviço rodando: ss -tlnp | grep :$test_port"
                print_info "- Firewall: firewall-cmd --list-ports"
                print_info "- SELinux: getsebool -a | grep http"
            fi
            ;;
    esac
}

# Gerar relatório
generate_report() {
    print_header "📊 Gerando Relatório de Rede"
    
    local report_file="$REPORT_DIR/network-report-$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$REPORT_DIR"
    
    {
        echo "=========================================="
        echo "Network Diagnostic Report - $(date)"
        echo "=========================================="
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo
        
        echo "=== NETWORK INTERFACES ==="
        ip addr show
        echo
        
        echo "=== ROUTING TABLE ==="
        ip route show
        echo
        
        echo "=== DNS CONFIGURATION ==="
        cat /etc/resolv.conf 2>/dev/null || echo "resolv.conf not found"
        echo
        
        echo "=== ACTIVE CONNECTIONS ==="
        ss -tuln | head -20
        echo
        
        echo "=== CONNECTIVITY TEST ==="
        # Teste rápido de conectividade
        for host in google.com cloudflare.com; do
            if ping -c 1 -W 3 "$host" &> /dev/null; then
                echo "$host: OK"
            else
                echo "$host: FAILED"
            fi
        done
        echo
        
        echo "=== NETWORK STATISTICS ==="
        cat /proc/net/dev
        echo
        
    } > "$report_file"
    
    print_success "Relatório salvo em: $report_file"
    
    # Limpar relatórios antigos
    find "$REPORT_DIR" -name "network-report-*.txt" -mtime +$KEEP_REPORTS_DAYS -delete 2>/dev/null
}

# Menu principal
show_menu() {
    clear
    print_header "╔════════════════════════════════════════════════════════════════╗"
    print_header "║                Network Diagnostics                            ║"
    print_header "║                    Rocky Linux 10                             ║"
    print_header "╠════════════════════════════════════════════════════════════════╣"
    echo "║  1. 📡 Informações da rede                                   ║"
    echo "║  2. 🔗 Testar conectividade                                  ║"
    echo "║  3. 🔍 Testar DNS                                            ║"
    echo "║  4. 🛣️ Análise de rotas                                      ║"
    echo "║  5. 🔌 Análise de portas                                     ║"
    echo "║  6. 🖧 Análise de interfaces                                 ║"
    echo "║  7. 🚀 Teste de velocidade                                   ║"
    echo "║  8. 🏥 Diagnóstico completo                                  ║"
    echo "║  9. 📺 Monitor contínuo                                      ║"
    echo "║  10. 🔧 Solucionador de problemas                            ║"
    echo "║  11. 📊 Gerar relatório                                      ║"
    echo "║  12. ⚙️ Configurações                                        ║"
    echo "║  0. ❌ Sair                                                   ║"
    print_header "╚════════════════════════════════════════════════════════════════╝"
}

# Configurações
configure_diagnostics() {
    print_header "⚙️ Configurações do Network Diagnostics"
    echo
    
    print_info "Configurações atuais:"
    echo "  • Hosts de teste: $TEST_HOSTS"
    echo "  • Timeout de ping: ${PING_TIMEOUT}s"
    echo "  • Speedtest: $ENABLE_SPEEDTEST"
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
    check_dependencies
    
    # Criar diretórios necessários
    mkdir -p "$REPORT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "${1:-}" in
        "info")
            show_network_info
            ;;
        "connectivity")
            test_connectivity
            ;;
        "dns")
            test_dns
            ;;
        "routes")
            analyze_routes
            ;;
        "ports")
            analyze_ports
            ;;
        "interfaces")
            analyze_interfaces
            ;;
        "speedtest")
            speedtest
            ;;
        "full")
            full_diagnosis
            ;;
        "monitor")
            continuous_monitor "${2:-60}"
            ;;
        "report")
            generate_report
            ;;
        *)
            while true; do
                show_menu
                read -p "Escolha uma opção (0-12): " choice
                
                case $choice in
                    1) show_network_info ;;
                    2) test_connectivity ;;
                    3) test_dns ;;
                    4) analyze_routes ;;
                    5) analyze_ports ;;
                    6) analyze_interfaces ;;
                    7) speedtest ;;
                    8) full_diagnosis ;;
                    9)
                        read -p "Intervalo de monitoramento em segundos (padrão: 60): " interval
                        continuous_monitor "${interval:-60}"
                        ;;
                    10) troubleshoot ;;
                    11) generate_report ;;
                    12) configure_diagnostics ;;
                    0)
                        print_success "Até logo!"
                        exit 0
                        ;;
                    *)
                        print_error "Opção inválida!"
                        ;;
                esac
                
                if [ "$choice" != "9" ]; then
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