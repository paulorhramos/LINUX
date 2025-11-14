# 🐳 Docker para Rocky Linux 10

Uma coleção completa de ferramentas Docker para desenvolvimento e produção no Rocky Linux 10.

## 📋 Índice

- [Estrutura do Projeto](#estrutura-do-projeto)
- [Instalação](#instalação)
- [Uso Rápido](#uso-rápido)
- [Serviços Disponíveis](#serviços-disponíveis)
- [Scripts Utilitários](#scripts-utilitários)
- [Dockerfiles](#dockerfiles)
- [Configurações](#configurações)
- [Solução de Problemas](#solução-de-problemas)

## 📁 Estrutura do Projeto

```
docker/
├── docker-compose.yml              # Stack completo de desenvolvimento
├── services/
│   ├── docker-compose.lemp.yml     # Stack LEMP (Linux, Nginx, MySQL, PHP)
│   ├── docker-compose.jenkins.yml  # Stack Jenkins CI/CD completo
│   ├── docker-compose.gitea.yml    # Gitea Git Server + PostgreSQL + Redis
│   ├── docker-compose.sonarqube.yml# SonarQube Code Quality + PostgreSQL
│   ├── docker-compose.nexus.yml    # Nexus Repository Manager
│   ├── docker-compose.portainer.yml# Portainer Docker Management
│   ├── docker-compose.elk.yml      # ELK Stack (Elasticsearch, Logstash, Kibana)
│   └── docker-compose.monitoring.yml# Monitoring (Grafana, Prometheus, AlertManager)
├── development/
│   ├── Dockerfile.nodejs           # Container Node.js
│   ├── Dockerfile.python           # Container Python
│   └── Dockerfile.php              # Container PHP-FPM
├── jenkins/                        # Configurações Jenkins
│   ├── casc.yaml                   # Configuration as Code
│   ├── plugins.txt                 # Lista de plugins
│   ├── init.groovy.d/              # Scripts de inicialização
│   ├── nginx/                      # Proxy reverso
│   └── redis/                      # Cache Redis
└── utilities/
    ├── install-docker-rocky10.sh   # Instalador Docker para Rocky Linux 10
    ├── docker-manager.sh           # Gerenciador de containers
    ├── jenkins-manager.sh          # Gerenciador Jenkins CI/CD
    └── services-manager.sh         # Gerenciador de todos os serviços
```

## 🚀 Instalação

### Opção 1: Instalador Automatizado (Recomendado)

```bash
# Instalar Docker no Rocky Linux 10
sudo ./utilities/install-docker-rocky10.sh
```

**Opções disponíveis:**
- **Instalação Completa**: Docker CE + Docker Compose + Otimizações
- **Instalação Básica**: Apenas Docker CE
- **Docker Compose**: Adiciona Compose a instalação existente
- **Teste**: Verifica instalação existente

### Opção 2: Usando o Script Principal

O Docker também é instalado pelo script principal de pós-instalação:

```bash
cd ../desktop/
sudo ./post_install_rocky10.sh
# Escolha opção 7 para Docker ou 0 para tudo
```

## ⚡ Uso Rápido

### Iniciar Stacks Específicos

```bash
# Stack completo de desenvolvimento
docker-compose up -d

# Serviços individuais
docker-compose -f services/docker-compose.lemp.yml up -d       # LEMP Stack
docker-compose -f services/docker-compose.jenkins.yml up -d    # Jenkins CI/CD
docker-compose -f services/docker-compose.gitea.yml up -d      # Git Server
docker-compose -f services/docker-compose.sonarqube.yml up -d  # Code Quality
docker-compose -f services/docker-compose.nexus.yml up -d      # Repository Manager
docker-compose -f services/docker-compose.portainer.yml up -d  # Docker Management
docker-compose -f services/docker-compose.elk.yml up -d        # ELK Logging
docker-compose -f services/docker-compose.monitoring.yml up -d # Monitoring

# OU usar o gerenciador universal
./utilities/services-manager.sh
```

### Gerenciar Containers

```bash
# Usar o gerenciador interativo
./utilities/docker-manager.sh

# Comandos diretos
docker-compose ps                    # Status dos serviços
docker-compose logs -f webapp        # Logs da aplicação
docker-compose down                  # Parar tudo
```

## 🛠️ Serviços Disponíveis

### Stack Principal (`docker-compose.yml`)

| Serviço | Porta | Descrição | Acesso |
|---------|-------|-----------|---------|
| **PostgreSQL** | 5432 | Banco de dados principal | `postgres://devuser:devpass123@localhost:5432/devdb` |
| **MySQL** | 3306 | Banco de dados alternativo | `mysql://devuser:devpass123@localhost:3306/devdb` |
| **Redis** | 6379 | Cache/Session store | `redis://localhost:6379` |
| **MongoDB** | 27017 | Banco NoSQL | `mongodb://admin:adminpass123@localhost:27017/devdb` |
| **Nginx** | 80, 443 | Reverse proxy/Web server | `http://localhost` |
| **Webapp** | 3000 | Aplicação Node.js | `http://localhost:3000` |
| **Adminer** | 8080 | Interface de banco | `http://localhost:8080` |
| **phpMyAdmin** | 8081 | Interface MySQL | `http://localhost:8081` |
| **Portainer** | 9000 | Interface Docker | `http://localhost:9000` |

### Stack LEMP (`services/docker-compose.lemp.yml`)

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| **Nginx** | 8082 | Web server |
| **PHP-FPM** | 9000 | PHP processor |
| **MySQL** | 3306 | Base de dados |

## 🔧 Scripts Utilitários

### 3. Gerenciador Jenkins (`jenkins-manager.sh`)

**Menu interativo completo para Jenkins CI/CD:**
- 🚀 Iniciar/parar stack Jenkins completo
- 📊 Monitoramento de serviços CI/CD
- 📋 Logs centralizados de todos os serviços
- 🔧 Rebuild e manutenção
- 💾 Backup automático de configurações
- 🔐 Reset de credenciais
- 👥 Gerenciamento de agents Jenkins
- 🌐 URLs de acesso rápido

**Uso:**
```bash
./utilities/jenkins-manager.sh
```

**Stack Jenkins inclui:**
- **Jenkins Master** com Configuration as Code
- **SonarQube** para análise de código
- **Nexus Repository** para artefatos
- **Gitea** Git server local
- **PostgreSQL** para metadados
- **Docker-in-Docker** para builds
- **Nginx** como proxy reverso
- **Redis** para cache

### 1. Instalador Docker (`install-docker-rocky10.sh`)

**Funcionalidades:**
- ✅ Remove versões antigas conflitantes
- ✅ Instala Docker CE oficial
- ✅ Instala Docker Compose
- ✅ Configura serviço systemd
- ✅ Otimiza configurações
- ✅ Configura firewall
- ✅ Adiciona usuário ao grupo docker
- ✅ Testa instalação

**Uso:**
```bash
sudo ./utilities/install-docker-rocky10.sh
```

### 2. Gerenciador Docker (`docker-manager.sh`)

**Menu interativo para:**
- 🚀 Iniciar/parar containers
- 🧹 Limpeza de sistema
- 📊 Monitoramento de recursos
- 📋 Visualização de logs
- 🔧 Rebuild de containers
- 💾 Backup de volumes
- 📦 Gerenciamento de imagens
- 🌐 Informações de rede

**Uso:**
```bash
./utilities/docker-manager.sh
```

## 📦 Dockerfiles

### Node.js (`Dockerfile.nodejs`)

```dockerfile
FROM node:18-alpine
# Otimizado para desenvolvimento
# Usuário não-root
# Healthcheck incluído
```

**Uso:**
```bash
docker build -f development/Dockerfile.nodejs -t minha-app-node .
```

### Python (`Dockerfile.python`)

```dockerfile
FROM python:3.11-alpine
# Suporte PostgreSQL, PIL, etc.
# Otimizado para Django/Flask
# Variáveis de ambiente configuradas
```

**Uso:**
```bash
docker build -f development/Dockerfile.python -t minha-app-python .
```

### PHP (`Dockerfile.php`)

```dockerfile
FROM php:8.2-fpm-alpine
# Extensões: PDO, MySQL, PostgreSQL, GD
# Composer incluído
# Nginx integrado
```

**Uso:**
```bash
docker build -f development/Dockerfile.php -t minha-app-php .
```

## ⚙️ Configurações

### Variáveis de Ambiente

Edite o `docker-compose.yml` para customizar:

```yaml
# PostgreSQL
POSTGRES_DB=meu_projeto
POSTGRES_USER=meu_usuario
POSTGRES_PASSWORD=minha_senha

# MySQL
MYSQL_DATABASE=meu_db
MYSQL_USER=usuario
MYSQL_PASSWORD=senha

# Redis
# (sem senha por padrão - para desenvolvimento)

# MongoDB
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=admin123
```

### Volumes Persistentes

```yaml
volumes:
  postgres_data:     # Dados PostgreSQL
  mysql_data:        # Dados MySQL  
  redis_data:        # Cache Redis
  mongodb_data:      # Dados MongoDB
  portainer_data:    # Config Portainer
```

### Redes

```yaml
networks:
  dev-network:       # Rede principal (172.20.0.0/16)
    driver: bridge
  lemp-network:      # Rede LEMP separada
```

## 🔍 Comandos Úteis

### Desenvolvimento

```bash
# Ver logs em tempo real
docker-compose logs -f

# Acessar container
docker-compose exec webapp bash
docker-compose exec postgres psql -U devuser -d devdb

# Rebuild específico
docker-compose up -d --build webapp

# Escalar serviço
docker-compose up -d --scale webapp=3
```

### Monitoramento

```bash
# Status dos serviços
docker-compose ps

# Uso de recursos
docker stats

# Logs de erro
docker-compose logs --tail=50 webapp | grep ERROR

# Saúde dos containers
docker-compose ps --filter "health=unhealthy"
```

### Backup e Restore

```bash
# Backup PostgreSQL
docker-compose exec postgres pg_dump -U devuser devdb > backup.sql

# Backup MySQL
docker-compose exec mysql mysqldump -u devuser -p devdb > backup.sql

# Backup volumes (usando script)
./utilities/docker-manager.sh
# Escolha opção 7
```

## 🆘 Solução de Problemas

### Problemas Comuns

#### Docker não inicia após instalação
```bash
# Verificar status
sudo systemctl status docker

# Reiniciar serviço
sudo systemctl restart docker

# Verificar logs
journalctl -u docker --no-pager
```

#### Permissões negadas
```bash
# Verificar grupos do usuário
groups $USER

# Adicionar ao grupo docker
sudo usermod -aG docker $USER

# Logout e login novamente
```

#### Portas em uso
```bash
# Verificar portas ocupadas
sudo netstat -tlnp | grep :3000

# Alterar portas no docker-compose.yml
ports:
  - "3001:3000"  # Muda porta local para 3001
```

#### Containers não se comunicam
```bash
# Verificar rede
docker network ls
docker network inspect docker_dev-network

# Verificar DNS interno
docker-compose exec webapp nslookup postgres
```

### Logs de Debug

```bash
# Logs detalhados do Docker
dockerd --debug

# Logs do Docker Compose
docker-compose --verbose up

# Logs específicos de um serviço
docker-compose logs --details webapp
```

### Performance

```bash
# Limpar recursos não utilizados
docker system prune -a

# Ver uso de disco
docker system df

# Otimizar imagens
docker image prune -a
```

## 📚 Documentação Adicional

- **Docker Official**: https://docs.docker.com/
- **Docker Compose**: https://docs.docker.com/compose/
- **Rocky Linux**: https://docs.rockylinux.org/
- **Container Best Practices**: https://docs.docker.com/develop/dev-best-practices/

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature
3. Faça commit das mudanças
4. Teste em Rocky Linux 10
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para detalhes.

---

**💡 Dica**: Use o script `docker-manager.sh` para operações diárias - ele fornece uma interface amigável para todas as operações comuns!