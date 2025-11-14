# 🚀 Guia de Instalação - Scripts Rocky Linux 10

## 📋 Pré-requisitos

### Sistema
- Rocky Linux 10 (versão mínima)
- Acesso root ou sudo
- Conexão com internet
- Mínimo 2GB RAM
- Mínimo 10GB espaço livre

### Pacotes Essenciais
```bash
sudo dnf install -y \
    bash \
    coreutils \
    util-linux \
    systemd \
    curl \
    wget \
    tar \
    gzip
```

## 🔽 Download e Instalação

### Método 1: Clone do Repositório
```bash
# Clone o repositório
git clone https://github.com/usuario/rocky-linux-scripts.git
cd rocky-linux-scripts

# Tornar scripts executáveis
chmod +x *.sh
chmod +x scripts/*/*.sh
```

### Método 2: Download Direto
```bash
# Download do arquivo compactado
wget https://github.com/usuario/rocky-linux-scripts/archive/main.zip
unzip main.zip
cd rocky-linux-scripts-main

# Tornar scripts executáveis
chmod +x *.sh
chmod +x scripts/*/*.sh
```

## 🛠️ Configuração Inicial

### 1. Executar Post-Install
```bash
sudo ./post-install.sh
```
**O que faz:**
- Configura repositórios essenciais
- Instala pacotes básicos
- Configura timezone e locale
- Otimiza configurações iniciais

### 2. Configurar Infraestrutura Docker (Opcional)
```bash
sudo ./docker-infrastructure.sh
```
**O que faz:**
- Instala Docker e Docker Compose
- Configura redes e volumes
- Prepara ambiente de containers

### 3. Inicializar Scripts Manager
```bash
sudo ./scripts-manager.sh
```
**O que faz:**
- Cria arquivos de configuração
- Configura logging
- Verifica dependências
- Apresenta menu principal

## ⚙️ Configuração Avançada

### Configurar Email para Notificações
```bash
# Editar configuração principal
sudo nano /etc/scripts-manager.conf

# Configurar parâmetros:
ENABLE_EMAIL_NOTIFICATIONS=true
ADMIN_EMAIL="admin@exemplo.com"
SMTP_SERVER="smtp.gmail.com"
```

### Configurar Agendamentos Automáticos
```bash
# Editar crontab
sudo crontab -e

# Adicionar agendamentos recomendados:
# Health check a cada 30 minutos
*/30 * * * * /caminho/para/scripts/monitoring/health-check.sh

# Backup diário às 02:00
0 2 * * * /caminho/para/scripts/system/backup-system.sh

# Update semanal aos domingos às 04:00
0 4 * * 0 /caminho/para/scripts/system/update-system.sh auto
```

### Configurar Firewall Inicial
```bash
# Executar configuração básica do firewall
sudo ./scripts/network/firewall-rules.sh

# Selecionar template "servidor web" ou "servidor ssh"
# Seguir menu interativo
```

## 🔐 Configuração de Segurança

### 1. Hardening Básico
```bash
sudo ./scripts/system/security-hardening.sh
```

### 2. Configurar SSH Seguro
```bash
# Editar configuração SSH
sudo nano /etc/ssh/sshd_config

# Configurações recomendadas:
Port 22222  # Mudar porta padrão
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
```

### 3. Configurar Fail2Ban
```bash
# Instalar se não estiver presente
sudo dnf install -y fail2ban

# Configurar regras básicas
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local

# Habilitar serviço
sudo systemctl enable --now fail2ban
```

## 📊 Configuração de Monitoramento

### 1. Configurar Health Check
```bash
# Editar configuração
sudo nano /etc/health-check.conf

# Ajustar thresholds:
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
```

### 2. Configurar Monitoramento de Disco
```bash
# Executar configuração inicial
sudo ./scripts/monitoring/disk-monitor.sh

# Configurar alertas SMART
sudo smartctl --all /dev/sda  # Verificar discos disponíveis
```

### 3. Configurar Análise de Logs
```bash
# Configurar rotação de logs
sudo nano /etc/logrotate.d/scripts-manager

# Conteúdo:
/var/log/scripts-*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 640 root root
}
```

## 🌐 Configuração de Rede

### 1. Configurar Diagnósticos de Rede
```bash
sudo ./scripts/network/network-diagnostics.sh
```

### 2. Setup VPN (Opcional)
```bash
# Para OpenVPN
sudo ./scripts/network/vpn-setup.sh openvpn

# Para WireGuard
sudo ./scripts/network/vpn-setup.sh wireguard
```

## 📁 Estrutura de Diretórios Criada

Após a instalação completa:
```
/etc/
├── scripts-manager.conf
├── update-system.conf
├── backup-system.conf
├── security-hardening.conf
├── performance-tuning.conf
├── health-check.conf
├── disk-monitor.conf
├── log-analyzer.conf
├── firewall-rules.conf
├── network-diagnostics.conf
└── vpn-setup.conf

/var/log/
├── scripts-manager.log
├── update-system.log
├── backup-system.log
├── security-hardening.log
├── performance-tuning.log
├── health-check.log
├── disk-monitor.log
├── log-analyzer.log
├── firewall-rules.log
├── network-diagnostics.log
└── vpn-setup.log

/var/backups/
├── system-backups/
├── config-backups/
└── scripts-manager/
```

## ✅ Verificação da Instalação

### 1. Teste Básico
```bash
# Verificar se scripts manager funciona
sudo ./scripts-manager.sh status

# Deve mostrar informações do sistema
```

### 2. Teste de Scripts Individuais
```bash
# Testar health check
sudo ./scripts/monitoring/health-check.sh quick

# Testar diagnósticos de rede
sudo ./scripts/network/network-diagnostics.sh speedtest
```

### 3. Verificar Logs
```bash
# Verificar se logs estão sendo criados
ls -la /var/log/scripts-*.log

# Verificar conteúdo do log principal
tail -f /var/log/scripts-manager.log
```

## 🔧 Solução de Problemas de Instalação

### Erro: Permissões Negadas
```bash
# Verificar se está executando como root
whoami

# Se não for root:
sudo su -
./scripts-manager.sh
```

### Erro: Comandos Não Encontrados
```bash
# Instalar dependências manualmente
sudo dnf install -y bash coreutils util-linux

# Verificar PATH
echo $PATH

# Adicionar se necessário
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin
```

### Erro: Scripts Não Executam
```bash
# Verificar permissões
ls -la *.sh

# Corrigir permissões se necessário
chmod +x *.sh
chmod +x scripts/*/*.sh

# Verificar sintaxe
bash -n scripts-manager.sh
```

### Erro: Arquivos de Configuração
```bash
# Criar diretórios necessários
sudo mkdir -p /etc /var/log /var/backups

# Verificar permissões
sudo chown root:root /etc/scripts-*.conf
sudo chmod 644 /etc/scripts-*.conf
```

## 🚀 Personalização Avançada

### 1. Customizar Templates de Backup
```bash
# Editar configuração de backup
sudo nano /etc/backup-system.conf

# Adicionar diretórios personalizados
CUSTOM_BACKUP_DIRS="/opt/aplicacoes /home/dados"
```

### 2. Configurar Múltiplos Ambientes
```bash
# Criar configurações por ambiente
sudo cp /etc/scripts-manager.conf /etc/scripts-manager-prod.conf
sudo cp /etc/scripts-manager.conf /etc/scripts-manager-dev.conf

# Usar configuração específica
SCRIPTS_CONFIG=/etc/scripts-manager-prod.conf sudo ./scripts-manager.sh
```

### 3. Integrar com Sistemas de Monitoramento
```bash
# Para Prometheus
sudo ./scripts/monitoring/health-check.sh prometheus > /var/lib/prometheus/scripts.prom

# Para Nagios
sudo ./scripts/monitoring/health-check.sh nagios
```

## 📋 Lista de Verificação Pós-Instalação

- [ ] Scripts executam sem erros
- [ ] Logs estão sendo criados
- [ ] Configurações estão personalizadas
- [ ] Agendamentos configurados no cron
- [ ] Firewall configurado adequadamente
- [ ] SSH configurado com segurança
- [ ] Backups funcionando
- [ ] Monitoramento ativo
- [ ] Notificações configuradas
- [ ] Documentação personalizada criada

---

## 🆘 Suporte

Em caso de problemas durante a instalação:

1. **Verificar logs:** `tail -f /var/log/scripts-manager.log`
2. **Executar diagnóstico:** `sudo ./scripts-manager.sh status`
3. **Verificar dependências:** `sudo ./scripts-manager.sh check-deps`
4. **Executar em modo debug:** `DEBUG=1 sudo ./scripts-manager.sh`

---

**Instalação concluída com sucesso! ✅**  
*Agora você tem um sistema Rocky Linux 10 totalmente automatizado!*