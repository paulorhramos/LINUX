#!groovy

// Script de inicialização do Jenkins
// Configura usuário admin e configurações básicas

import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// Desabilitar o setup wizard
if (!instance.isQuietingDown()) {
    System.setProperty("jenkins.install.runSetupWizard", "false")
}

// Configurar segurança
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Configurar agent-to-master security
if (instance.getInjector().getInstance(AdminWhitelistRule.class) != null) {
    instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)
}

// Configurar número de executors
instance.setNumExecutors(2)

// Salvar configurações
instance.save()

println "Jenkins configurado com sucesso!"
println "Usuário: admin"
println "Senha: admin123"
println "URL: http://localhost:8080"