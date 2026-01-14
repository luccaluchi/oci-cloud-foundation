
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
variable "ssh_public_key_content" {
  description = "Conteúdo da chave pública SSH (ssh-rsa AAAA...)"
  type        = string
}

# ----------------------------------------------------------------------------
# Tailscale - Auth Keys
# ----------------------------------------------------------------------------
variable "tailscale_auth_key" {
  description = "Tailscale auth key para o servidor K3s (com tag:k3s-server pré-associada)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^tskey-auth-", var.tailscale_auth_key))
    error_message = "A auth key do Tailscale deve começar com 'tskey-auth-'"
  }
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
  description = "CIDR block para a subnet pública (Load Balancer)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block para a subnet privada (VMs K3s)"
  type        = string
  default     = "10.0.10.0/24"
}

# ----------------------------------------------------------------------------
# K3s
# IMPORTANTE: O K3S_TOKEN será gerado automaticamente pelo servidor K3s.
# ----------------------------------------------------------------------------

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
# Configurações do Cluster
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
