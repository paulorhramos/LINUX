# 📚 Scripts de Automação Rocky Linux 10

## 📖 Descrição
Conjunto completo de scripts de automação para administração e manutenção de servidores Rocky Linux 10. Desenvolvidos com foco em segurança, performance e facilidade de uso.

## 🏗️ Estrutura do Projeto

```
LINUX/
├── scripts-manager.sh          # Gerenciador principal
├── post-install.sh            # Script pós-instalação
├── docker-infrastructure.sh   # Infraestrutura Docker
├── scripts/
│   ├── system/               # Scripts do sistema
│   │   ├── update-system.sh
│   │   ├── backup-system.sh
│   │   ├── security-hardening.sh
│   │   └── performance-tuning.sh
│   ├── monitoring/           # Scripts de monitoramento
│   │   ├── health-check.sh
│   │   ├── disk-monitor.sh
│   │   └── log-analyzer.sh
│   └── network/             # Scripts de rede
│       ├── firewall-rules.sh
│       ├── network-diagnostics.sh
│       └── vpn-setup.sh
└── docs/                    # Esta documentação
```

## 🚀 Início Rápido

### 1. Executar Script Pós-Instalação
```bash
sudo ./post-install.sh
```

### 2. Configurar Infraestrutura Docker (opcional)
```bash
sudo ./docker-infrastructure.sh
```

### 3. Usar o Gerenciador de Scripts
```bash
sudo ./scripts-manager.sh
```

## 📋 Scripts Disponíveis

### 🔧 Scripts do Sistema

#### `update-system.sh`
**Descrição:** Gerenciamento completo de atualizações do sistema
**Funcionalidades:**
- Atualização de pacotes
- Limpeza de cache
- Verificação de segurança
- Backup automático antes de updates
- Monitoramento de espaço em disco

**Uso:**
```bash
sudo ./scripts/system/update-system.sh
sudo ./scripts/system/update-system.sh auto    # Modo automático
```

#### `backup-system.sh`
**Descrição:** Sistema completo de backup com compressão e rotação
**Funcionalidades:**
- Backup incremental e completo
- Compressão inteligente
- Rotação automática
- Verificação de integridade
- Upload para serviços em nuvem

**Uso:**
```bash
sudo ./scripts/system/backup-system.sh
sudo ./scripts/system/backup-system.sh full    # Backup completo
sudo ./scripts/system/backup-system.sh incremental  # Backup incremental
```

#### `security-hardening.sh`
**Descrição:** Endurecimento de segurança do sistema
**Funcionalidades:**
- Configuração SSH segura
- Firewall automático
- Fail2ban
- Auditoria de permissões
- Políticas de senha
- SELinux/AppArmor

**Uso:**
```bash
sudo ./scripts/system/security-hardening.sh
```

#### `performance-tuning.sh`
**Descrição:** Otimização de performance do sistema
**Funcionalidades:**
- Tuning de kernel
- Otimização de I/O
- Configuração de swap
- Tuning de rede
- Otimização de CPU
- Configuração de memória

**Uso:**
```bash
sudo ./scripts/system/performance-tuning.sh
```

### 📊 Scripts de Monitoramento

#### `health-check.sh`
**Descrição:** Monitoramento completo de saúde do sistema
**Funcionalidades:**
- Verificação de CPU, RAM, Disco
- Status de serviços
- Conectividade de rede
- Logs de sistema
- Alertas automáticos

**Uso:**
```bash
sudo ./scripts/monitoring/health-check.sh
sudo ./scripts/monitoring/health-check.sh quick   # Verificação rápida
```

#### `disk-monitor.sh`
**Descrição:** Monitoramento avançado de discos e storage
**Funcionalidades:**
- Análise SMART
- Monitoramento de I/O
- Verificação de espaço
- Limpeza automática
- Alertas de falha

**Uso:**
```bash
sudo ./scripts/monitoring/disk-monitor.sh
sudo ./scripts/monitoring/disk-monitor.sh analyze  # Análise detalhada
```

#### `log-analyzer.sh`
**Descrição:** Análise inteligente de logs do sistema
**Funcionalidades:**
- Análise de padrões
- Detecção de anomalias
- Relatórios de segurança
- Compressão de logs
- Alertas personalizados

**Uso:**
```bash
sudo ./scripts/monitoring/log-analyzer.sh
sudo ./scripts/monitoring/log-analyzer.sh security  # Análise de segurança
```

### 🌐 Scripts de Rede

#### `firewall-rules.sh`
**Descrição:** Gerenciamento completo de firewall
**Funcionalidades:**
- Configuração firewalld
- Templates de regras
- Backup/restore de configurações
- Monitoramento de tráfego
- Regras customizadas

**Uso:**
```bash
sudo ./scripts/network/firewall-rules.sh
sudo ./scripts/network/firewall-rules.sh template web  # Template web
```

#### `network-diagnostics.sh`
**Descrição:** Diagnósticos avançados de rede
**Funcionalidades:**
- Testes de conectividade
- Análise de latência
- Diagnóstico DNS
- Monitoramento de banda
- Troubleshooting automático

**Uso:**
```bash
sudo ./scripts/network/network-diagnostics.sh
sudo ./scripts/network/network-diagnostics.sh speedtest  # Teste de velocidade
```

#### `vpn-setup.sh`
**Descrição:** Configuração completa de VPN (OpenVPN + WireGuard)
**Funcionalidades:**
- Setup OpenVPN
- Configuração WireGuard
- Geração de certificados
- Configurações de cliente
- Monitoramento de conexões

**Uso:**
```bash
sudo ./scripts/network/vpn-setup.sh
sudo ./scripts/network/vpn-setup.sh openvpn    # Configurar apenas OpenVPN
sudo ./scripts/network/vpn-setup.sh wireguard  # Configurar apenas WireGuard
```

## 🎛️ Gerenciador de Scripts

### `scripts-manager.sh`
**Descrição:** Interface centralizada para todos os scripts
**Funcionalidades:**
- Menu interativo
- Execução por linha de comando
- Logging centralizado
- Configurações globais
- Agendamento automático
- Relatórios de status

### Interface Interativa
```bash
sudo ./scripts-manager.sh
```

### Linha de Comando
```bash
# Ver status do sistema
sudo ./scripts-manager.sh status

# Listar scripts disponíveis
sudo ./scripts-manager.sh list system
sudo ./scripts-manager.sh list monitoring
sudo ./scripts-manager.sh list network

# Executar script específico
sudo ./scripts-manager.sh run health-check
sudo ./scripts-manager.sh run backup-system
sudo ./scripts-manager.sh run firewall-rules

# Limpeza do sistema
sudo ./scripts-manager.sh cleanup
```

## 📁 Arquivos de Configuração

### Localização dos Arquivos
```
/etc/
├── scripts-manager.conf      # Configuração principal
├── update-system.conf        # Configuração de updates
├── backup-system.conf        # Configuração de backup
├── security-hardening.conf   # Configuração de segurança
├── performance-tuning.conf   # Configuração de performance
├── health-check.conf         # Configuração de monitoramento
├── disk-monitor.conf         # Configuração de disco
├── log-analyzer.conf         # Configuração de logs
├── firewall-rules.conf       # Configuração de firewall
├── network-diagnostics.conf  # Configuração de rede
└── vpn-setup.conf           # Configuração de VPN
```

### Logs
```
/var/log/
├── scripts-manager.log      # Log principal
├── update-system.log        # Log de updates
├── backup-system.log        # Log de backups
├── security-hardening.log   # Log de segurança
├── health-check.log         # Log de monitoramento
└── ...                      # Outros logs específicos
```

## 🔒 Considerações de Segurança

### Permissões
- Todos os scripts devem ser executados como **root**
- Permissões 755 para scripts executáveis
- Permissões 600 para arquivos de configuração sensíveis

### Autenticação
- Verificação de usuário root obrigatória
- Lock files para prevenir execução simultânea
- Logs de auditoria para todas as operações

### Backup
- Backup automático antes de operações críticas
- Verificação de integridade dos backups
- Criptografia de dados sensíveis

## 🔧 Configuração Automática

### Agendamento via Cron
```bash
# Adicionar no crontab (sudo crontab -e)

# Health check a cada 30 minutos
*/30 * * * * /path/to/scripts/monitoring/health-check.sh

# Backup diário às 02:00
0 2 * * * /path/to/scripts/system/backup-system.sh

# Update semanal aos domingos às 04:00
0 4 * * 0 /path/to/scripts/system/update-system.sh auto

# Análise de logs diária às 01:00
0 1 * * * /path/to/scripts/monitoring/log-analyzer.sh
```

### Systemd Services
```bash
# Criar service para monitoramento contínuo
sudo cp examples/scripts-monitor.service /etc/systemd/system/
sudo systemctl enable scripts-monitor.service
sudo systemctl start scripts-monitor.service
```

## 📊 Monitoramento e Alertas

### Métricas Monitoradas
- **CPU:** Uso, load average, temperatura
- **Memória:** Uso, swap, buffers/cache
- **Disco:** Espaço livre, I/O, SMART status
- **Rede:** Conectividade, latência, throughput
- **Serviços:** Status, uptime, logs

### Tipos de Alerta
- **Critical:** Sistema em risco iminente
- **Warning:** Atenção necessária
- **Info:** Informações de status

### Notificações
- Email (SMTP configurável)
- Logs do sistema
- Status via API REST

## 🛠️ Troubleshooting

### Problemas Comuns

#### Script não executa
```bash
# Verificar permissões
ls -la script.sh

# Tornar executável
chmod +x script.sh

# Verificar sintaxe
bash -n script.sh
```

#### Logs não aparecem
```bash
# Verificar se diretório existe
sudo mkdir -p /var/log

# Verificar permissões
sudo chown root:root /var/log/scripts-*.log
sudo chmod 640 /var/log/scripts-*.log
```

#### Configuração não carrega
```bash
# Verificar sintaxe do arquivo de configuração
bash -n /etc/script-name.conf

# Recriar arquivo padrão
sudo rm /etc/script-name.conf
sudo ./script-name.sh  # Irá recriar
```

### Debugging
```bash
# Modo debug
export DEBUG=1
sudo ./script-name.sh

# Modo verbose
sudo ./script-name.sh -v

# Logs detalhados
tail -f /var/log/scripts-manager.log
```

## 📈 Performance

### Otimizações Implementadas
- Cache de resultados de comandos pesados
- Execução paralela quando possível
- Compressão de logs e backups
- Limpeza automática de arquivos temporários

### Benchmarks
- **Startup time:** < 2 segundos
- **Memory usage:** < 50MB por script
- **CPU impact:** < 5% durante execução

## 🔄 Atualizações

### Verificar Versão
```bash
grep "Versão:" scripts-manager.sh
```

### Atualizar Scripts
```bash
# Backup das configurações atuais
sudo cp -r /etc/scripts-*.conf /etc/backup-configs/

# Baixar nova versão
git pull origin main

# Aplicar permissões
chmod +x *.sh scripts/*/*.sh

# Testar configuração
sudo ./scripts-manager.sh status
```

## 📞 Suporte

### Logs de Debug
```bash
# Gerar relatório completo de debug
sudo ./scripts-manager.sh debug-report

# Verificar status de todos os componentes
sudo ./scripts-manager.sh health-check
```

### Informações do Sistema
```bash
# Coletar informações para suporte
sudo ./scripts-manager.sh system-info > system-report.txt
```

## 🏆 Boas Práticas

### Execução
1. **Sempre execute como root** para operações de sistema
2. **Faça backup** antes de mudanças importantes
3. **Teste** scripts em ambiente não-produtivo primeiro
4. **Monitore logs** após execução
5. **Configure alertas** para operações críticas

### Manutenção
1. **Revise configurações** periodicamente
2. **Atualize scripts** regularmente
3. **Monitore performance** do sistema
4. **Limpe logs antigos** para economizar espaço
5. **Documente mudanças** personalizadas

### Segurança
1. **Verifique permissões** dos scripts
2. **Use criptografia** para backups sensíveis
3. **Monitore atividade** através dos logs
4. **Mantenha sistema** sempre atualizado
5. **Configure firewall** adequadamente

---

## 🎯 Próximos Passos Sugeridos

1. **Personalizar configurações** de acordo com seu ambiente
2. **Configurar agendamentos** automáticos
3. **Testar todos os scripts** em ambiente controlado
4. **Configurar monitoramento** e alertas
5. **Documentar customizações** específicas

---

**Desenvolvido com ❤️ para Rocky Linux 10**  
*Scripts de automação profissional para administradores de sistema*