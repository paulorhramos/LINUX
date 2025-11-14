#!/bin/bash

# =============================================================================
# Exemplo de uso do Rocky Linux 10 Post-Install Script
# =============================================================================

echo "🚀 Bem-vindo ao assistente de configuração do Rocky Linux 10!"
echo
echo "Este script irá ajudá-lo a configurar seu sistema após uma instalação limpa."
echo

# Verificar se está no Rocky Linux
if ! grep -q "Rocky Linux" /etc/os-release 2>/dev/null; then
    echo "⚠️  Este sistema não parece ser Rocky Linux."
    echo "   O script foi otimizado para Rocky Linux 10."
    echo
    read -p "Deseja continuar mesmo assim? (s/N): " choice
    if [[ ! "$choice" =~ ^[SsYy]$ ]]; then
        echo "❌ Operação cancelada."
        exit 1
    fi
fi

# Verificar se é root
if [[ $EUID -ne 0 ]]; then
    echo "🔐 Este script precisa ser executado como root."
    echo "   Tentando usar sudo..."
    echo
    exec sudo "$0" "$@"
fi

# Menu principal
while true; do
    clear
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                Rocky Linux 10 Post-Install                    ║"
    echo "║                     Menu Principal                             ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║                                                                ║"
    echo "║  1. 🚀 Instalação Completa (Recomendado)                      ║"
    echo "║     Executa todas as configurações automaticamente            ║"
    echo "║                                                                ║"
    echo "║  2. 🔧 Instalação Personalizada                               ║"
    echo "║     Escolha quais componentes instalar                        ║"
    echo "║                                                                ║"
    echo "║  3. ⚙️  Editar Configurações                                   ║"
    echo "║     Modifica o arquivo config.conf                            ║"
    echo "║                                                                ║"
    echo "║  4. 📋 Verificar Sistema                                       ║"
    echo "║     Mostra informações do sistema atual                       ║"
    echo "║                                                                ║"
    echo "║  5. 📖 Documentação                                            ║"
    echo "║     Abre o README com instruções detalhadas                   ║"
    echo "║                                                                ║"
    echo "║  0. ❌ Sair                                                     ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo
    
    read -p "Digite sua escolha (0-5): " choice
    
    case $choice in
        1)
            echo "🚀 Iniciando instalação completa..."
            echo "   Isso pode levar alguns minutos..."
            echo
            ./post_install_rocky10.sh
            read -p "Pressione Enter para continuar..."
            ;;
        2)
            echo "🔧 Iniciando instalação personalizada..."
            ./post_install_rocky10.sh
            read -p "Pressione Enter para continuar..."
            ;;
        3)
            echo "⚙️ Abrindo editor de configurações..."
            if command -v nano &> /dev/null; then
                nano config.conf
            elif command -v vim &> /dev/null; then
                vim config.conf
            else
                echo "❌ Editor não encontrado. Instale nano ou vim."
            fi
            ;;
        4)
            clear
            echo "📋 Informações do Sistema:"
            echo "=========================="
            echo
            echo "📊 Distribuição:"
            cat /etc/os-release | head -2
            echo
            echo "💾 Memória:"
            free -h
            echo
            echo "💽 Armazenamento:"
            df -h / | tail -1
            echo
            echo "🏷️ Arquitetura:"
            uname -m
            echo
            echo "⚡ Uptime:"
            uptime
            echo
            read -p "Pressione Enter para continuar..."
            ;;
        5)
            if command -v less &> /dev/null; then
                less README.md
            elif command -v more &> /dev/null; then
                more README.md
            else
                cat README.md
            fi
            ;;
        0)
            echo "👋 Obrigado por usar o Rocky Linux Post-Install Script!"
            echo "   Visite nossa documentação para mais informações."
            exit 0
            ;;
        *)
            echo "❌ Opção inválida! Pressione Enter para tentar novamente..."
            read
            ;;
    esac
done