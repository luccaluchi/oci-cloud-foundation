#!/bin/bash
# ============================================================================
# Script para configurar kubectl local para acessar K3s via Tailscale (Magic DNS)
# ============================================================================

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções auxiliares
log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Validações Iniciais ---
if ! command -v tailscale &> /dev/null; then
    error "Tailscale nao instalado."
fi

# --- Configurações ---
# Nome da máquina no Tailscale (Magic DNS)
K3S_SERVER_HOSTNAME="k3s-server-1"
SSH_USER="ubuntu"
# Caminho final do arquivo kubeconfig ajustado
KUBECONFIG_PATH="${HOME}/.kube/config-k3s-tailscale"

log "Buscando IP de conexao para: $K3S_SERVER_HOSTNAME..."

SERVER_IP=$(tailscale ip -4 "$K3S_SERVER_HOSTNAME" 2>/dev/null || echo "")

if [ -z "$SERVER_IP" ]; then
    error "Nao foi possível resolver o IP para '$K3S_SERVER_HOSTNAME'.\nVerifique se o nó está online no Tailscale: 'tailscale status'"
fi

log "Endereço encontrado: $SERVER_IP (MagicDNS: $K3S_SERVER_HOSTNAME)"

log "Baixando kubeconfig do servidor..."

if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${SSH_USER}@${SERVER_IP}" "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/k3s-temp.yaml; then
    error "Falha ao baixar kubeconfig via SSH. Verifique sua chave SSH e se o servidor está acessível."
fi

if [ ! -s /tmp/k3s-temp.yaml ]; then
    error "O arquivo baixado está vazio."
fi

log "Configurando kubeconfig para usar Magic DNS..."

sed "s/127.0.0.1/${K3S_SERVER_HOSTNAME}/g" /tmp/k3s-temp.yaml > "$KUBECONFIG_PATH"

# Limpar arquivo temporário
rm -f /tmp/k3s-temp.yaml

chmod 600 "$KUBECONFIG_PATH"

log "Kubeconfig salvo com sucesso em: $KUBECONFIG_PATH"
log ""
log "Para ativar neste terminal:"
echo -e "${GREEN}export KUBECONFIG=$KUBECONFIG_PATH${NC}"
log ""
log "Testando conexao..."

export KUBECONFIG="$KUBECONFIG_PATH"

if kubectl cluster-info &> /dev/null; then
    log "✓ Sucesso! Conectado via Magic DNS: https://${K3S_SERVER_HOSTNAME}:6443"
    echo ""
    kubectl get nodes -o wide
else
    warn "A conexao falhou. Possíveis causas:"
    echo "1. O certificado do K3s nao tem o SAN '${K3S_SERVER_HOSTNAME}'."
    echo "2. O Magic DNS do Tailscale nao está resolvendo na sua máquina local."
fi