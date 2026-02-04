# CLAUDE.md - EKS Upgrade Project Template

Use este template como base para projetos de upgrade de EKS/Kubernetes. Copie para o diretório raiz do seu projeto e customize conforme necessário.

---

# CLAUDE.md - EKS Upgrade Project

## Contexto do Cluster

- **Cluster Name**: [CLUSTER_NAME]
- **Region**: [REGION]
- **Current Version**: [CURRENT_VERSION]
- **Target Version**: [TARGET_VERSION]
- **Node Groups**: [LIST_NODE_GROUPS]
- **Account ID**: [AWS_ACCOUNT_ID]

## Addons Instalados

### AWS Managed Addons
- VPC CNI: v[VERSION]
- CoreDNS: v[VERSION]
- kube-proxy: v[VERSION]
- EBS CSI Driver: v[VERSION]
- EFS CSI Driver: v[VERSION] (se aplicável)

### Self-Managed Addons
- Karpenter: v[VERSION]
- Cluster Autoscaler: v[VERSION] (se aplicável)
- AWS Load Balancer Controller: v[VERSION]
- External-DNS: v[VERSION]
- External-Secrets: v[VERSION]
- Cert-Manager: v[VERSION]
- Ingress-NGINX: v[VERSION]
- Metrics Server: v[VERSION]
- ArgoCD: v[VERSION] (se aplicável)

## Regras para IA

### Pré-Upgrade (OBRIGATÓRIO)

1. **Sempre executar verificação de APIs deprecadas:**
   ```bash
   pluto detect-files -d ./manifests --target-versions k8s=v[TARGET_VERSION]
   kubent
   ```

2. **Verificar EKS Cluster Insights:**
   ```bash
   aws eks describe-cluster --name [CLUSTER_NAME] --query 'cluster.health'
   ```

3. **Consultar versões compatíveis de addons:**
   ```bash
   aws eks describe-addon-versions --kubernetes-version [TARGET_VERSION] \
     --query 'addons[*].[addonName,addonVersions[0].addonVersion]' \
     --output table
   ```

4. **Verificar release notes oficiais:**
   - EKS: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html
   - Kubernetes: https://kubernetes.io/releases/

### Ordem de Upgrade (CRÍTICO)

A ordem DEVE ser seguida para evitar incompatibilidades:

1. Atualizar managed addons para versões compatíveis com AMBAS as versões (atual e target)
2. Atualizar Karpenter/Cluster Autoscaler ANTES do control plane
3. Upgrade do Control Plane EKS (uma minor version por vez)
4. Atualizar Node Groups para AMI da nova versão
5. Atualizar demais addons self-managed
6. Validar com K8sGPT e testes de smoke

### Validação Pós-Upgrade

Verificar após cada etapa:
- [ ] Todos os pods em Running/Ready
- [ ] DNS resolution funcionando (CoreDNS)
- [ ] Persistent volumes acessíveis (CSI)
- [ ] Autoscaling funcionando (Karpenter/HPA)
- [ ] Ingress/Load Balancers ativos
- [ ] Certificados válidos (Cert-Manager)
- [ ] External-DNS atualizando registros
- [ ] Secrets sincronizando (External-Secrets)

### Rollback

Em caso de falha:

1. **Control Plane**: Não é possível rollback direto. Restaurar de backup ou criar novo cluster
2. **Node Groups**: Recriar com AMI da versão anterior
3. **Addons**: `helm rollback [release] [revision]` ou `kubectl apply` da versão anterior

**IMPORTANTE**: Documentar versões anteriores de TODOS os componentes antes do upgrade

### Backups Obrigatórios

Antes de iniciar:
- [ ] Snapshots de todos os PVs críticos
- [ ] Export de configmaps e secrets importantes
- [ ] Backup de Helm releases: `helm list -A > helm-releases-backup.txt`
- [ ] Documento com todas as versões atuais

## Comandos Úteis

```bash
# Verificar versão atual do cluster
aws eks describe-cluster --name [CLUSTER_NAME] --query 'cluster.version'

# Listar addons e versões
aws eks list-addons --cluster-name [CLUSTER_NAME]
aws eks describe-addon --cluster-name [CLUSTER_NAME] --addon-name [ADDON_NAME]

# Verificar node groups
aws eks list-nodegroups --cluster-name [CLUSTER_NAME]

# Upgrade control plane
aws eks update-cluster-version --name [CLUSTER_NAME] --kubernetes-version [TARGET_VERSION]

# Monitorar upgrade
aws eks describe-update --name [CLUSTER_NAME] --update-id [UPDATE_ID]
```

## Links de Referência

- [EKS Best Practices - Upgrades](https://aws.github.io/aws-eks-best-practices/upgrades/)
- [Karpenter Upgrading](https://karpenter.sh/docs/upgrading/)
- [EKS Add-on Compatibility](https://docs.aws.amazon.com/eks/latest/userguide/addon-compat.html)
- [Kubernetes Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)

## Histórico de Upgrades

| Data | De | Para | Responsável | Notas |
|------|-----|------|-------------|-------|
| [DATE] | [FROM] | [TO] | [NAME] | [NOTES] |

---

**Última atualização**: [DATE]
**Próximo upgrade planejado**: [DATE] - v[VERSION]
