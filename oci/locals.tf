locals {
  # Configurações base (compartilhadas por todos os ambientes)
  base_config = {
    # ARM Server (Control Plane)
    arm_server_ocpus = 1
    arm_server_ram   = 4
    arm_server_disk  = 50
    arm_server_count = 1

    # ARM Workers
    arm_worker_ocpus = 1
    arm_worker_ram   = 6
    arm_worker_disk  = 50
    arm_worker_count = 0

    # AMD Worker (sem IP público)
    amd_worker_count     = 0
    amd_worker_disk_size = 25

    # AMD NAT Gateway (com IP público)
    amd_nat_enabled = true
  }

  # Configurações específicas por ambiente (sobrescrevem as base)
  env_overrides = {
    dev = {
      arm_worker_count = 1
    }

    prod = {
      # Produçao: Usa 100% do Free Tier
      arm_server_ocpus     = 2
      arm_server_ram       = 10
      arm_worker_ram       = 7
      arm_worker_count     = 2
      amd_worker_disk_size = 50
    }
  }

  # Merge: base + overrides do workspace atual
  selected = merge(
    local.base_config,
    lookup(local.env_overrides, terraform.workspace, {})
  )

  # Prefixo para nomes de recursos
  name_prefix = "${var.project_name}-${terraform.workspace}"

  # Hostnames fixos
  hostnames = {
    nat        = "k3s-nat"
    server     = "k3s-server-1"
    worker_arm = ["k3s-worker-arm-1", "k3s-worker-arm-2", "k3s-worker-arm-3"]
    worker_amd = ["k3s-worker-amd-1"]
  }

  # Tags comuns para todos os recursos
  common_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
    ManagedBy   = "OpenTofu"
    Cluster     = "k3s"
  }

  # NodePorts para Ingress Controller
  ingress_http_nodeport  = 30080
  ingress_https_nodeport = 30443

  # IP privado fixo da VM NAT (primeiro IP disponível na subnet privada)
  # Usado como gateway padrao pelas VMs K3s
  nat_private_ip = cidrhost(var.private_subnet_cidr, 10)
}
