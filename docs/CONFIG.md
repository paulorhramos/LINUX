# 📖 Guia de Configuração - Scripts Rocky Linux 10

## 📋 Visão Geral das Configurações

Todos os scripts utilizam arquivos de configuração centralizados localizados em `/etc/`. Cada script pode funcionar com configurações padrão ou ser personalizado através de seus respectivos arquivos.

## 🎛️ Configuração Principal - scripts-manager.conf

### Localização
```
/etc/scripts-manager.conf
```

### Parâmetros Principais
```bash
# Configurações de logging
LOG_LEVEL="INFO"                    # DEBUG, INFO, WARN, ERROR
LOG_RETENTION_DAYS=30               # Dias para manter logs
ENABLE_DETAILED_LOGGING=true        # Logs detalhados

# Configurações de execução
CONFIRM_DANGEROUS_OPERATIONS=true   # Confirmar operações perigosas
AUTO_UPDATE_SCRIPTS=false          # Update automático dos scripts
BACKUP_BEFORE_EXECUTION=true       # Backup antes de execuções

# Configurações de notificação
ENABLE_EMAIL_NOTIFICATIONS=false   # Habilitar emails
ADMIN_EMAIL="admin@example.com"     # Email do administrador
SMTP_SERVER="localhost"             # Servidor SMTP

# Agendamentos
ENABLE_SCHEDULED_TASKS=true         # Habilitar agendamentos
HEALTH_CHECK_INTERVAL="*/30 * * * *" # A cada 30 minutos
BACKUP_SCHEDULE="0 2 * * *"         # Diário às 2:00
UPDATE_SCHEDULE="0 4 * * 0"         # Domingos às 4:00

# Monitoramento
ENABLE_PERFORMANCE_MONITORING=true # Monitorar performance
RESOURCE_USAGE_THRESHOLD=80        # Threshold de recursos (%)
DISK_USAGE_THRESHOLD=85            # Threshold de disco (%)
MEMORY_USAGE_THRESHOLD=90          # Threshold de memória (%)

# Segurança
REQUIRE_SUDO_PASSWORD=false        # Exigir senha sudo
ENABLE_AUDIT_LOG=true              # Log de auditoria
SESSION_TIMEOUT=3600               # Timeout da sessão (segundos)
```

## 🔧 Configurações por Script

### 1. Update System - update-system.conf

```bash
# Configurações de atualização
AUTO_REBOOT=false                   # Reiniciar automaticamente
REBOOT_TIME="03:00"                # Horário para reiniciar
CHECK_INTERVAL=24                   # Intervalo de verificação (horas)

# Backup antes de update
BACKUP_BEFORE_UPDATE=true          # Fazer backup antes
BACKUP_RETENTION=7                 # Dias para manter backups

# Repositórios
ENABLE_EPEL=true                   # Habilitar repositório EPEL
ENABLE_RPMFUSION=false             # Habilitar RPM Fusion
ENABLE_TESTING_REPOS=false         # Repositórios de teste

# Exclusões
EXCLUDE_PACKAGES=""                # Pacotes para excluir
EXCLUDE_KERNELS=false              # Excluir kernels
ONLY_SECURITY_UPDATES=false        # Apenas updates de segurança

# Logs e notificações
LOG_DETAILED_UPDATES=true          # Log detalhado
NOTIFY_ON_ERRORS=true              # Notificar erros
NOTIFY_ON_SUCCESS=false            # Notificar sucessos
```

**Exemplo de personalização:**
```bash
# Para servidores de produção
AUTO_REBOOT=false
BACKUP_BEFORE_UPDATE=true
ONLY_SECURITY_UPDATES=true
EXCLUDE_KERNELS=true

# Para servidores de desenvolvimento
AUTO_REBOOT=true
REBOOT_TIME="02:00"
ENABLE_TESTING_REPOS=true
```

### 2. Backup System - backup-system.conf

```bash
# Diretórios para backup
BACKUP_DIRS="/home /etc /opt /var/www"
EXCLUDE_DIRS="/tmp /var/tmp /proc /sys /dev"
INCLUDE_DATABASES=true
INCLUDE_SYSTEM_CONFIG=true

# Configurações de destino
BACKUP_DESTINATION="/var/backups"
REMOTE_BACKUP_ENABLED=false
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH=""

# Configurações de retenção
DAILY_RETENTION=7                  # Dias para backups diários
WEEKLY_RETENTION=4                 # Semanas para backups semanais
MONTHLY_RETENTION=6                # Meses para backups mensais

# Compressão e criptografia
COMPRESSION_LEVEL=6                # Nível de compressão (1-9)
ENABLE_ENCRYPTION=false           # Habilitar criptografia
ENCRYPTION_KEY_FILE=""            # Arquivo da chave de criptografia

# Verificação de integridade
VERIFY_BACKUPS=true               # Verificar integridade
CHECKSUM_ALGORITHM="sha256"       # Algoritmo de checksum

# Cloud backup
ENABLE_CLOUD_BACKUP=false         # Backup para nuvem
CLOUD_PROVIDER=""                 # aws, gcp, azure
CLOUD_BUCKET=""                   # Nome do bucket/container
```

**Exemplo de configuração para diferentes cenários:**

**Servidor Web:**
```bash
BACKUP_DIRS="/home /etc /opt /var/www /var/log/apache2"
INCLUDE_DATABASES=true
DAILY_RETENTION=14
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="aws"
```

**Servidor de Banco de Dados:**
```bash
BACKUP_DIRS="/home /etc /opt /var/lib/mysql"
INCLUDE_DATABASES=true
ENABLE_ENCRYPTION=true
VERIFY_BACKUPS=true
REMOTE_BACKUP_ENABLED=true
```

### 3. Security Hardening - security-hardening.conf

```bash
# Configurações SSH
SSH_PORT=22                        # Porta SSH
SSH_ROOT_LOGIN=false              # Login root via SSH
SSH_PASSWORD_AUTH=false           # Autenticação por senha
SSH_MAX_AUTH_TRIES=3              # Tentativas máximas
SSH_KEY_ALGORITHMS="rsa,ecdsa,ed25519"

# Firewall
ENABLE_FIREWALL=true              # Habilitar firewall
DEFAULT_POLICY="DROP"             # Política padrão
ALLOW_SSH=true                    # Permitir SSH
ALLOW_HTTP=false                  # Permitir HTTP
ALLOW_HTTPS=false                 # Permitir HTTPS

# Fail2Ban
ENABLE_FAIL2BAN=true              # Habilitar Fail2Ban
FAIL2BAN_BANTIME=3600             # Tempo de banimento (segundos)
FAIL2BAN_MAXRETRY=3               # Tentativas máximas
FAIL2BAN_FINDTIME=600             # Janela de tempo (segundos)

# SELinux
SELINUX_MODE="enforcing"          # enforcing, permissive, disabled
SELINUX_TYPE="targeted"           # targeted, strict, mls

# Auditoria
ENABLE_AUDITD=true                # Habilitar auditd
AUDIT_RULES_FILE="/etc/audit/rules.d/custom.rules"
AUDIT_LOG_RETENTION=90            # Dias para manter logs

# Políticas de senha
PASSWORD_MIN_LENGTH=12            # Tamanho mínimo
PASSWORD_COMPLEXITY=true          # Exigir complexidade
PASSWORD_HISTORY=5                # Histórico de senhas
PASSWORD_MAX_AGE=90               # Idade máxima (dias)

# Configurações do kernel
KERNEL_HARDENING=true             # Hardening do kernel
DISABLE_IPV6=false               # Desabilitar IPv6
DISABLE_UNUSED_PROTOCOLS=true     # Desabilitar protocolos não usados
```

### 4. Performance Tuning - performance-tuning.conf

```bash
# Configurações de CPU
CPU_GOVERNOR="performance"         # performance, powersave, ondemand
CPU_SCALING_MAX_FREQ=""           # Frequência máxima (deixe vazio para auto)
ENABLE_CPU_ISOLATION=false        # Isolamento de CPU
ISOLATED_CPUS=""                  # CPUs para isolar (ex: 2-7)

# Configurações de memória
SWAPPINESS=10                     # Tendência de swap (0-100)
DIRTY_RATIO=15                    # Percentual de RAM para dirty pages
DIRTY_BACKGROUND_RATIO=5          # Percentual para background flush
ENABLE_HUGE_PAGES=false          # Habilitar huge pages
HUGE_PAGES_SIZE=2048              # Tamanho das huge pages (KB)

# Configurações de I/O
IO_SCHEDULER="mq-deadline"        # none, kyber, bfq, mq-deadline
READ_AHEAD_KB=128                 # Read-ahead (KB)
QUEUE_DEPTH=32                    # Profundidade da fila

# Configurações de rede
TCP_CONGESTION_CONTROL="bbr"      # bbr, cubic, reno
TCP_WINDOW_SCALING=true           # Habilitar window scaling
NET_CORE_RMEM_MAX=134217728      # Buffer máximo de recepção
NET_CORE_WMEM_MAX=134217728      # Buffer máximo de envio

# Configurações de sistema
ENABLE_IRQBALANCE=true           # Balanceamento de IRQ
DISABLE_TRANSPARENT_HUGEPAGES=true # Desabilitar THP
ENABLE_NUMA_BALANCING=false      # Balanceamento NUMA
```

### 5. Health Check - health-check.conf

```bash
# Thresholds de recursos
CPU_WARNING_THRESHOLD=70          # Aviso de CPU (%)
CPU_CRITICAL_THRESHOLD=90         # Crítico de CPU (%)
MEMORY_WARNING_THRESHOLD=80       # Aviso de memória (%)
MEMORY_CRITICAL_THRESHOLD=95      # Crítico de memória (%)
DISK_WARNING_THRESHOLD=80         # Aviso de disco (%)
DISK_CRITICAL_THRESHOLD=95        # Crítico de disco (%)

# Monitoramento de serviços
MONITOR_SERVICES="sshd firewalld chronyd NetworkManager"
SERVICE_RESTART_ATTEMPTS=3        # Tentativas de reiniciar
SERVICE_RESTART_DELAY=30          # Delay entre tentativas (segundos)

# Monitoramento de rede
CHECK_INTERNET_CONNECTIVITY=true  # Verificar conectividade
PING_TARGETS="8.8.8.8 1.1.1.1"  # Targets para ping
PING_TIMEOUT=5                    # Timeout do ping (segundos)
CHECK_DNS_RESOLUTION=true         # Verificar resolução DNS
DNS_TEST_DOMAINS="google.com cloudflare.com"

# Monitoramento de processos
MONITOR_PROCESSES=""              # Processos para monitorar
MAX_PROCESS_CPU=80               # CPU máxima por processo (%)
MAX_PROCESS_MEMORY=80            # Memória máxima por processo (%)

# Configurações de relatório
GENERATE_REPORT=true             # Gerar relatório
REPORT_FORMAT="text"             # text, html, json
SAVE_HISTORICAL_DATA=true        # Salvar dados históricos
HISTORICAL_DATA_RETENTION=30     # Dias para manter dados
```

### 6. Disk Monitor - disk-monitor.conf

```bash
# Monitoramento SMART
ENABLE_SMART_MONITORING=true      # Habilitar monitoramento SMART
SMART_SCAN_SCHEDULE="daily"       # daily, weekly, monthly
SMART_ERROR_THRESHOLD=5           # Errors máximos antes de alerta

# Monitoramento de espaço
DISK_USAGE_WARNING=80            # Aviso de uso (%)
DISK_USAGE_CRITICAL=95           # Crítico de uso (%)
INODE_USAGE_WARNING=80           # Aviso de inodes (%)
INODE_USAGE_CRITICAL=95          # Crítico de inodes (%)

# Monitoramento de I/O
MONITOR_IO_STATS=true            # Monitorar estatísticas I/O
IO_UTIL_WARNING=80               # Aviso de utilização I/O (%)
IO_UTIL_CRITICAL=95              # Crítico de utilização I/O (%)
IO_WAIT_WARNING=20               # Aviso de I/O wait (%)

# Limpeza automática
ENABLE_AUTO_CLEANUP=false        # Habilitar limpeza automática
CLEANUP_TEMP_FILES=true          # Limpar arquivos temporários
CLEANUP_LOG_FILES=true           # Limpar logs antigos
CLEANUP_CACHE_FILES=true         # Limpar cache
MAX_LOG_SIZE_MB=100              # Tamanho máximo de log (MB)

# Configurações de relatório
GENERATE_DISK_REPORT=true        # Gerar relatório de disco
INCLUDE_FILESYSTEM_INFO=true     # Incluir info do filesystem
INCLUDE_MOUNT_INFO=true          # Incluir info de montagem
```

### 7. Firewall Rules - firewall-rules.conf

```bash
# Configurações gerais
FIREWALL_BACKEND="firewalld"      # firewalld, iptables
DEFAULT_ZONE="public"             # Zona padrão
ENABLE_LOGGING=true               # Habilitar logging
LOG_DENIED_PACKETS=true           # Log de pacotes negados

# Portas e serviços padrão
ALLOW_SSH=true                    # Permitir SSH
SSH_PORT=22                       # Porta SSH
ALLOW_HTTP=false                  # Permitir HTTP
ALLOW_HTTPS=false                 # Permitir HTTPS
ALLOW_PING=true                   # Permitir ping

# Regras personalizadas
CUSTOM_TCP_PORTS=""               # Portas TCP customizadas (ex: 8080,9000)
CUSTOM_UDP_PORTS=""               # Portas UDP customizadas
TRUSTED_NETWORKS=""               # Redes confiáveis (ex: 192.168.1.0/24)
BLOCKED_COUNTRIES=""              # Países para bloquear (ex: CN,RU)

# Proteção DDoS
ENABLE_DDOS_PROTECTION=true       # Habilitar proteção DDoS
CONN_LIMIT_PER_IP=50              # Conexões por IP
RATE_LIMIT_SSH=3                  # Taxa limite SSH (por minuto)
ENABLE_PORT_SCAN_DETECTION=true   # Detectar port scan

# Backup e restore
BACKUP_RULES_ON_CHANGE=true       # Backup ao alterar regras
RULES_BACKUP_DIR="/var/backups/firewall"
RULES_BACKUP_RETENTION=30         # Dias para manter backups
```

### 8. VPN Setup - vpn-setup.conf

```bash
# Configurações do servidor
SERVER_EXTERNAL_IP=""             # IP externo (auto-detectado se vazio)
SERVER_INTERNAL_IP="10.8.0.1"    # IP interno do servidor VPN
VPN_NETWORK="10.8.0.0/24"         # Rede VPN
VPN_PORT_OPENVPN=1194             # Porta OpenVPN
VPN_PORT_WIREGUARD=51820          # Porta WireGuard

# Certificados
CERT_COUNTRY="US"                 # País
CERT_PROVINCE="State"             # Estado
CERT_CITY="City"                  # Cidade
CERT_ORG="Organization"           # Organização
CERT_EMAIL="admin@example.com"    # Email
CERT_VALIDITY_DAYS=3650           # Validade (dias)

# DNS
VPN_DNS="8.8.8.8,8.8.4.4"       # Servidores DNS
ENABLE_DNS_FILTERING=false        # Filtrar DNS
DNS_FILTERING_LISTS=""            # Listas de filtros

# Configurações de segurança
ENABLE_FIREWALL_INTEGRATION=true  # Integração com firewall
ENABLE_FAIL2BAN=true              # Habilitar Fail2Ban para VPN
ENABLE_LOG_MONITORING=true        # Monitorar logs
COMPRESSION_ENABLED=true          # Habilitar compressão

# Cliente
GENERATE_CLIENT_CONFIGS=true      # Gerar configs de cliente
CLIENT_CONFIG_DIR="/etc/vpn/clients"
DEFAULT_CLIENT_NAME="client1"     # Nome padrão do cliente

# Avançado
ENABLE_TRAFFIC_FORWARDING=true    # Encaminhar tráfego
ENABLE_NAT=true                   # Habilitar NAT
CIPHER="AES-256-GCM"              # Algoritmo de criptografia
AUTH="SHA256"                     # Algoritmo de autenticação
TLS_VERSION="1.2"                 # Versão mínima TLS
```

## 🔄 Recarregando Configurações

### Método 1: Via Scripts Manager
```bash
sudo ./scripts-manager.sh
# Menu -> Configurações Avançadas -> Editar configurações
```

### Método 2: Edição Manual
```bash
# Editar arquivo de configuração
sudo nano /etc/script-name.conf

# Recarregar via script
sudo ./scripts/categoria/script-name.sh reload
```

### Método 3: Reinicialização Completa
```bash
# Parar todos os serviços relacionados
sudo systemctl stop scripts-monitor 2>/dev/null || true

# Recarregar configurações
source /etc/scripts-manager.conf

# Reiniciar serviços
sudo ./scripts-manager.sh restart-services
```

## 📝 Templates de Configuração

### Template para Servidor Web
```bash
# /etc/template-webserver.conf
BACKUP_DIRS="/home /etc /opt /var/www /var/log/httpd"
FIREWALL_ALLOW_HTTP=true
FIREWALL_ALLOW_HTTPS=true
MONITOR_SERVICES="sshd firewalld chronyd NetworkManager httpd"
PERFORMANCE_PROFILE="web"
```

### Template para Servidor de Banco
```bash
# /etc/template-database.conf
BACKUP_DIRS="/home /etc /opt /var/lib/mysql"
INCLUDE_DATABASES=true
ENABLE_ENCRYPTION=true
PERFORMANCE_PROFILE="database"
MEMORY_SWAPPINESS=1
```

### Template para Servidor de Desenvolvimento
```bash
# /etc/template-development.conf
AUTO_REBOOT=true
ENABLE_TESTING_REPOS=true
BACKUP_RETENTION=3
PERFORMANCE_PROFILE="development"
ENABLE_DEBUG_LOGGING=true
```

## 🔧 Configurações Dinâmicas

### Configuração por Variáveis de Ambiente
```bash
# Sobrescrever configurações via environment
export SCRIPTS_LOG_LEVEL="DEBUG"
export SCRIPTS_BACKUP_ENABLED="false"

# Executar script com configurações personalizadas
sudo -E ./scripts-manager.sh
```

### Configuração por Argumentos
```bash
# Passar configurações via linha de comando
sudo ./scripts/system/backup-system.sh --config-file=/etc/backup-custom.conf
sudo ./scripts/monitoring/health-check.sh --cpu-threshold=85 --memory-threshold=90
```

## 🔒 Segurança das Configurações

### Permissões Recomendadas
```bash
# Arquivos de configuração
sudo chmod 644 /etc/scripts-*.conf
sudo chown root:root /etc/scripts-*.conf

# Arquivos sensíveis (com senhas/chaves)
sudo chmod 600 /etc/scripts-sensitive.conf
sudo chown root:root /etc/scripts-sensitive.conf
```

### Criptografia de Configurações Sensíveis
```bash
# Criptografar arquivo sensível
sudo gpg --symmetric --cipher-algo AES256 /etc/vpn-setup.conf

# Descriptografar para usar
sudo gpg --decrypt /etc/vpn-setup.conf.gpg > /tmp/vpn-setup.conf
```

## 📊 Validação de Configurações

### Script de Validação
```bash
#!/bin/bash
# validate-config.sh

# Validar configuração do scripts-manager
if ! source /etc/scripts-manager.conf 2>/dev/null; then
    echo "ERRO: Arquivo de configuração inválido"
    exit 1
fi

# Validar thresholds
if [ "$RESOURCE_USAGE_THRESHOLD" -gt 100 ]; then
    echo "AVISO: Threshold de recursos > 100%"
fi

# Validar diretórios
if [ ! -d "$BACKUP_DESTINATION" ]; then
    echo "ERRO: Diretório de backup não existe: $BACKUP_DESTINATION"
fi

echo "Configuração válida!"
```

## 🚨 Configurações de Emergência

### Modo Seguro
```bash
# Configuração mínima para modo de emergência
ENABLE_ALL_MONITORING=false
BACKUP_BEFORE_EXECUTION=false
CONFIRM_DANGEROUS_OPERATIONS=true
LOG_LEVEL="ERROR"
DISABLE_NETWORK_OPERATIONS=true
```

### Reset de Configuração
```bash
# Backup de configurações atuais
sudo cp /etc/scripts-*.conf /tmp/backup-configs/

# Reset para padrão
sudo rm /etc/scripts-*.conf

# Reinicializar scripts para recriar configurações padrão
sudo ./scripts-manager.sh
```

---

**💡 Dica:** Sempre faça backup das configurações antes de alterações importantes!

```bash
sudo cp -r /etc/scripts-*.conf /var/backups/config-$(date +%Y%m%d)/
```