# ATENCAO: Nao inclua valores sensíveis neste arquivo.
# Use terraform.tfvars (NAO VERSIONADO) para valores sensíveis.
# ============================================================================

# ----------------------------------------------------------------------------
# Autenticaçao OCI
# ----------------------------------------------------------------------------
variable "tenancy_ocid" {
  description = "OCID da tenancy OCI"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário OCI"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da API Key OCI"
  type        = string
}

variable "private_key_path" {
  description = "Caminho para a chave privada da API OCI"
  type        = string
}

variable "region" {
  description = "Regiao OCI (ex: sa-saopaulo-1)"
  type        = string
}

# ----------------------------------------------------------------------------
# SSH
# ----------------------------------------------------------------------------
variable "admin_vm_ssh_public_key" {
  description = "Conteúdo da chave pública SSH (ssh-ed25519 AAAA...)"
  type        = string
}

# ----------------------------------------------------------------------------
# Tailscale - Auth Keys (Estratégia Híbrida)
# ----------------------------------------------------------------------------
# 1. Chave Genérica (Fallback)
variable "tailscale_auth_key" {
  description = "Chave Tailscale padrão. Usada se as chaves específicas não forem fornecidas."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^tskey-auth-", var.tailscale_auth_key))
    error_message = "A auth key do Tailscale deve começar com 'tskey-auth-'"
  }
}

# 2. Chaves Específicas por Função (Recomendado para Tags automáticas)
variable "tailscale_auth_key_nat" {
  description = "Chave específica para a VM NAT (Ex: com tag:nat). Se null, usa a genérica."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_auth_key_server" {
  description = "Chave específica para o K3s Server (Ex: com tag:k3s-server). Se null, usa a genérica."
  type        = string
  sensitive   = true
  default     = null
}

variable "tailscale_auth_key_agent" {
  description = "Chave específica para K3s Agents (Ex: com tag:k3s-agent). Se null, usa a genérica."
  type        = string
  sensitive   = true
  default     = null
}

# ----------------------------------------------------------------------------
# Rede
# ----------------------------------------------------------------------------
variable "vcn_cidr" {
  description = "CIDR block para a VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block para a subnet pública (Load Balancer/NAT)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block para a subnet privada (VMs K3s)"
  type        = string
  default     = "10.0.10.0/24"
}

# ----------------------------------------------------------------------------
# Budget OCI
# ----------------------------------------------------------------------------
variable "budget_amount" {
  description = "Limite de gastos mensais em reais (R$) para alertas"
  type        = number
  default     = 10
}

variable "budget_alert_email" {
  description = "Email para receber alertas de budget"
  type        = string
}

# ----------------------------------------------------------------------------
# Configurações do Cluster & Tags
# ----------------------------------------------------------------------------
variable "environment" {
  description = "Nome do ambiente (prod, dev, staging)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nome do projeto para tags e recursos"
  type        = string
  default     = "k3s-cluster"
}

# ----------------------------------------------------------------------------
# GitOps & Automação (Ansible Pull)
# ----------------------------------------------------------------------------
variable "github_repo_url" {
  description = "URL SSH do repositório GitHub para ansible-pull"
  type        = string
  default     = "git@github.com:luccaluchi/oci-cloud-foundation.git"
}

variable "github_deploy_key" {
  description = "Chave privada SSH (Deploy Key) para a VM clonar o repo de infra"
  type        = string
  sensitive   = true
}

variable "git_branch" {
  description = "Branch do GitHub para ansible-pull configurar o ambiente"
  type        = string
  default     = "main"
}
