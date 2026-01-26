# Templates para Claude Code + Cursor

Este diretorio contem templates prontos para configurar seu ambiente de IA para DevOps.

## Estrutura

```
templates/
├── README.md                      # Este arquivo
├── cursorrules-devops.txt         # .cursorrules basico
├── cursorrules-agente.txt         # .cursorrules para agentes avancados
├── CLAUDE-devops.md               # CLAUDE.md basico
├── CLAUDE-completo.md             # CLAUDE.md completo (todos os detalhes)
├── claude-settings.json           # .claude/settings.json
└── subagents/                     # Subagentes especializados
    ├── k8s-troubleshoot.md        # Kubernetes troubleshooting
    ├── terraform-reviewer.md      # Terraform security & cost review
    ├── ci-security-analyst.md     # CI/CD vulnerability analysis
    ├── incident-analyzer.md       # Production incident investigation
    └── security-auditor.md        # Security audit & CVE triage
```

## Arquivos de Configuracao

### 1. `.cursorrules`

Define o comportamento do agente de IA.

**Opcoes:**
- `cursorrules-devops.txt` - Configuracao basica para DevOps
- `cursorrules-agente.txt` - Configuracao avancada para agentes

**Uso:**
```bash
cp templates/cursorrules-devops.txt .cursorrules
```

### 2. `CLAUDE.md`

Contexto do projeto para o Claude.

**Opcoes:**
- `CLAUDE-devops.md` - Template basico para comecar
- `CLAUDE-completo.md` - Template completo com todos os detalhes

**Uso:**
```bash
cp templates/CLAUDE-completo.md CLAUDE.md
# Edite com informacoes do seu projeto
```

### 3. `.claude/settings.json`

Permissoes e configuracoes do Claude Code.

**Uso:**
```bash
mkdir -p .claude
cp templates/claude-settings.json .claude/settings.json
```

## Subagentes Especializados

Os subagentes ficam em `.claude/agents/` e sao especialistas em dominios especificos.

### k8s-troubleshoot.md
Especialista em troubleshooting de Kubernetes.
- Diagnostico de pods, deployments, services
- Analise de logs e eventos
- Sugestoes de correcao

**Uso:**
```bash
mkdir -p .claude/agents
cp templates/subagents/k8s-troubleshoot.md .claude/agents/
```

**Invocar:** `@k8s-troubleshoot o deployment payment-service esta com erro`

### terraform-reviewer.md
Revisor de codigo Terraform focado em seguranca e custos.
- Security Groups, IAM, criptografia
- Otimizacao de custos
- Best practices

**Uso:**
```bash
cp templates/subagents/terraform-reviewer.md .claude/agents/
```

**Invocar:** `@terraform-reviewer analise todos os arquivos .tf`

### ci-security-analyst.md
Analista de seguranca de pipelines CI/CD.
- Triagem de CVEs
- Analise de reachability
- Supply chain security

**Uso:**
```bash
cp templates/subagents/ci-security-analyst.md .claude/agents/
```

**Invocar:** `@ci-security-analyst o workflow falhou no Trivy scan`

### incident-analyzer.md
Investigador de incidentes de producao.
- Correlacao temporal de eventos
- Pattern recognition
- Recomendacoes de acao

**Uso:**
```bash
cp templates/subagents/incident-analyzer.md .claude/agents/
```

**Invocar:** `@incident-analyzer o servico payment-api esta com latencia alta`

### security-auditor.md
Auditor de seguranca e compliance.
- CVE triage com risk scoring
- Security configuration review
- Kubernetes security audit

**Uso:**
```bash
cp templates/subagents/security-auditor.md .claude/agents/
```

**Invocar:** `@security-auditor faca audit de seguranca do namespace production`

## Setup Rapido Completo

Execute no diretorio do seu projeto:

```bash
# Criar estrutura de diretorios
mkdir -p .claude/agents

# Copiar configuracoes principais
cp /path/to/templates/cursorrules-agente.txt .cursorrules
cp /path/to/templates/CLAUDE-completo.md CLAUDE.md
cp /path/to/templates/claude-settings.json .claude/settings.json

# Copiar todos os subagentes
cp /path/to/templates/subagents/*.md .claude/agents/
```

## Personalizacao

Apos copiar, edite os arquivos para refletir:

1. **CLAUDE.md:**
   - Nome e arquitetura do projeto
   - Versoes especificas (K8s, Terraform, etc)
   - Padroes e convencoes da equipe
   - Contatos e escalacao

2. **.cursorrules:**
   - Regras especificas do seu ambiente
   - Restricoes de seguranca adicionais

3. **settings.json:**
   - Comandos permitidos/negados
   - MCPs habilitados

4. **Subagentes:**
   - Adapte as tools disponiveis
   - Ajuste personas para seu contexto

## Dicas

1. **Revise as permissoes** em `.claude/settings.json` - ajuste para seu nivel de confianca
2. **Mantenha CLAUDE.md atualizado** - e a "memoria" do projeto para a IA
3. **Versione estes arquivos** - commit no git para toda a equipe usar
4. **Comece com um subagente** - adicione mais conforme necessidade
5. **Teste em ambiente de dev** - antes de usar em producao
