# 🚀 Rocky Linux 10 Post-Install Script

Um script abrangente e automatizado para configurar o Rocky Linux 10 após uma instalação limpa.

## 📋 Índice

- [Características](#características)
- [Instalação](#instalação)
- [Uso](#uso)
- [Configuração](#configuração)
- [Funcionalidades](#funcionalidades)
- [Estrutura de Arquivos](#estrutura-de-arquivos)
- [Logs](#logs)
- [Solução de Problemas](#solução-de-problemas)
- [Contribuindo](#contribuindo)

## ✨ Características

- 🔧 **Configuração automatizada** - Instala e configura ferramentas essenciais
- 🎨 **Interface colorida** - Output visual claro e informativo
- 📝 **Sistema de logs** - Registro detalhado de todas as ações
- ⚙️ **Altamente configurável** - Arquivo de configuração para personalização
- 🛡️ **Segurança** - Configuração de firewall e fail2ban
- 🐳 **Docker ready** - Instalação e configuração do Docker
- 🎵 **Multimídia** - Codecs e ferramentas de áudio/vídeo
- 💻 **Ferramentas de desenvolvimento** - IDEs, compiladores, e linguagens
- 🎯 **Menu interativo** - Execute partes específicas ou tudo automaticamente

## 📦 Instalação

### Pré-requisitos

- Rocky Linux 10 (instalação limpa)
- Acesso root ou sudo
- Conexão com a internet

### Download

```bash
# Clone ou baixe os arquivos
git clone [URL_DO_REPOSITORIO]
cd rocky-linux-post-install

# Ou baixe diretamente
curl -O https://raw.githubusercontent.com/[USER]/[REPO]/main/post_install_rocky10.sh
curl -O https://raw.githubusercontent.com/[USER]/[REPO]/main/config.conf
```

### Dar permissão de execução

```bash
chmod +x post_install_rocky10.sh
```

## 🚀 Uso

### Execução completa (recomendado)

```bash
sudo ./post_install_rocky10.sh
# Escolha opção 0 para executar tudo automaticamente
```

### Execução seletiva

```bash
sudo ./post_install_rocky10.sh
# Escolha as opções desejadas (1-11)
```

### Menu de opções

```
0. Executar tudo automaticamente
1. Atualização completa do sistema
2. Configurar repositórios adicionais
3. Instalar ferramentas de desenvolvimento
4. Instalar ferramentas multimídia
5. Instalar utilitários do sistema
6. Configurar firewall
7. Configurar Docker
8. Configurar Flatpak
9. Configurar atualizações automáticas
10. Otimizar sistema
11. Limpeza do sistema
```

## ⚙️ Configuração

Edite o arquivo `config.conf` para personalizar as instalações:

### Principais configurações

```bash
# Habilitar/desabilitar funcionalidades
ENABLE_UPDATES=true
ENABLE_REPOSITORIES=true
ENABLE_DEV_TOOLS=true
ENABLE_MULTIMEDIA=true

# Usuário padrão
DEFAULT_USER="prhr"

# Pacotes personalizados
CUSTOM_PACKAGES=(
    "telegram-desktop"
    "discord"
    "steam"
    "wine"
    "google-chrome-stable"
)

# Aplicativos Flatpak
FLATPAK_PACKAGES=(
    "com.spotify.Client"
    "com.discordapp.Discord"
)
```

## 🛠️ Funcionalidades

### 1. Atualização do Sistema
- Atualiza todos os pacotes para as versões mais recentes
- Configura mirrors mais rápidos

### 2. Repositórios Adicionais
- **EPEL** - Extra Packages for Enterprise Linux
- **PowerTools/CRB** - Repositório de ferramentas adicionais
- **RPM Fusion** - Repositórios free e non-free
- **Google Chrome** - Repositório oficial do Google Chrome

### 3. Ferramentas de Desenvolvimento
- **IDEs**: Visual Studio Code, Vim, Nano
- **Linguagens**: Python 3, Node.js, GCC, Make, CMake
- **Controle de versão**: Git
- **Containerização**: Docker, Docker Compose
- **Terminal**: Zsh, Tmux, Screen
- **Utilitários**: curl, wget, htop, tree, neofetch

### 4. Ferramentas Multimídia
- **Players**: VLC, Rhythmbox
- **Editores**: GIMP, Audacity
- **Codecs**: FFmpeg, GStreamer plugins
- **Gravação**: Brasero, OBS Studio

### 5. Utilitários do Sistema
- **Segurança**: Firewalld, Fail2ban
- **Backup**: Timeshift, Rsync
- **Particionamento**: GParted
- **Tweaks**: GNOME Tweaks, dconf-editor
- **Pacotes**: Flatpak, Snapd

### 6. Configurações de Segurança
- Configuração automática do firewall
- Regras básicas para SSH, HTTP, HTTPS
- Instalação e configuração do Fail2ban

### 7. Docker
- Instalação do Docker CE
- Docker Compose
- Adição do usuário ao grupo docker
- Configuração de inicialização automática

### 8. Flatpak
- Configuração do repositório Flathub
- Instalação de aplicativos essenciais via Flatpak

### 9. Atualizações Automáticas
- Configuração do dnf-automatic
- Atualizações de segurança automáticas

### 10. Otimizações
- **DNF**: Mirrors mais rápidos, downloads paralelos, cache
- **Kernel**: Configuração de swappiness e cache
- **Performance**: Ajustes de I/O e memória

## 📁 Estrutura de Arquivos

```
rocky-linux-post-install/
├── post_install_rocky10.sh    # Script principal
├── config.conf                # Arquivo de configuração
├── README.md                   # Esta documentação
└── logs/
    └── rocky_post_install.log  # Log de execução
```

## 📋 Logs

Os logs são salvos em `/var/log/rocky_post_install.log` e incluem:

- Timestamp de cada ação
- Sucesso/falha de instalações
- Erros e avisos
- Configurações aplicadas

### Visualizar logs

```bash
# Ver logs em tempo real
tail -f /var/log/rocky_post_install.log

# Ver logs com cores
cat /var/log/rocky_post_install.log | ccze -A

# Buscar por erros
grep -i error /var/log/rocky_post_install.log
```

## 🔧 Solução de Problemas

### Problemas comuns

#### Script não executa
```bash
# Verificar permissões
ls -la post_install_rocky10.sh
chmod +x post_install_rocky10.sh
```

#### Falha na instalação de pacotes
```bash
# Limpar cache do DNF
sudo dnf clean all
sudo dnf makecache

# Verificar conectividade
ping -c 3 google.com
```

#### Docker não funciona após instalação
```bash
# Verificar se o serviço está rodando
sudo systemctl status docker

# Reiniciar serviço
sudo systemctl restart docker

# Adicionar usuário ao grupo (fazer logout/login depois)
sudo usermod -aG docker $USER
```

### Logs de debug

Para mais informações de debug, edite `config.conf`:

```bash
VERBOSE_OUTPUT=true
SAVE_LOGS=true
```

## 🤝 Contribuindo

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

### Diretrizes de contribuição

- Mantenha o código bem documentado
- Teste em ambiente Rocky Linux 10
- Siga as convenções de shell script
- Atualize a documentação se necessário

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para detalhes.

## 🙏 Agradecimentos

- Comunidade Rocky Linux
- Contribuidores do EPEL
- Equipe do RPM Fusion
- Desenvolvedores de todas as ferramentas incluídas

## 📞 Suporte

- **Issues**: Use o sistema de issues do GitHub
- **Documentação**: Wiki do projeto
- **Comunidade**: Fórum Rocky Linux

---

**⚠️ Aviso**: Este script modifica configurações do sistema. Recomenda-se fazer backup antes da execução em sistemas de produção.

**💡 Dica**: Execute primeiro em uma VM para testar e familiarizar-se com as funcionalidades.