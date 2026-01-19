# ----------------------------------------------------------------------------
# Data Sources - Availability Domains e Imagens
# ----------------------------------------------------------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Imagens Ubuntu 24.04 para ARM (Ampere A1)
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

# Imagens Ubuntu 24.04 para AMD (x86 Micro)
data "oci_core_images" "ubuntu_amd" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

# ============================================================================
# Token do K3s
# ============================================================================
resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

# ============================================================================
# VM NAT (AMD Micro) - Gateway para VMs privadas
# ============================================================================
resource "oci_core_instance" "nat" {
  count = local.selected.amd_nat_enabled ? 1 : 0

  display_name        = local.hostnames.nat
  compartment_id      = oci_identity_compartment.main.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  shape = "VM.Standard.E2.1.Micro"

  # Subnet PÚBLICA com IP público
  create_vnic_details {
    subnet_id                 = oci_core_subnet.public.id
    nsg_ids                   = [oci_core_network_security_group.nat_nsg.id]
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = "k3s-nat"
    skip_source_dest_check    = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_amd.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = var.admin_vm_ssh_public_key

    user_data = base64encode(templatefile("${path.module}/templates/cloud-init-nat.yaml.tftpl", {
      # Tenta usar a chave específica do NAT. Se for null, usa a genérica.
      tailscale_auth_key = coalesce(var.tailscale_auth_key_nat, var.tailscale_auth_key)

      hostname              = local.hostnames.nat
      private_subnet        = var.private_subnet_cidr
      github_deploy_key_b64 = base64encode(var.github_deploy_key)
      github_repo_url       = var.github_repo_url
      git_branch            = var.git_branch
    }))
  }

  lifecycle {
    ignore_changes = [
      metadata["user_data"],
      source_details[0].source_id
    ]
  }

  freeform_tags = local.common_tags
}

# Data sources para NAT IP
data "oci_core_vnic_attachments" "nat_vnic_attachments" {
  count          = local.selected.amd_nat_enabled ? 1 : 0
  compartment_id = oci_identity_compartment.main.id
  instance_id    = oci_core_instance.nat[0].id
}

data "oci_core_vnic" "nat_vnic" {
  count   = local.selected.amd_nat_enabled ? 1 : 0
  vnic_id = data.oci_core_vnic_attachments.nat_vnic_attachments[0].vnic_attachments[0].vnic_id
}

# ============================================================================
# K3S SERVER (Control Plane) - ARM Ampere
# ============================================================================
resource "oci_core_instance" "k3s_server" {
  count = local.selected.arm_server_count

  display_name        = local.hostnames.server
  compartment_id      = oci_identity_compartment.main.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  shape = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = local.selected.arm_server_ocpus
    memory_in_gbs = local.selected.arm_server_ram
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private.id
    nsg_ids                   = [oci_core_network_security_group.vm_nsg.id]
    assign_public_ip          = false
    assign_private_dns_record = true
    hostname_label            = "k3s-server-1"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = local.selected.arm_server_disk
  }

  metadata = {
    ssh_authorized_keys = var.admin_vm_ssh_public_key

    user_data = base64encode(templatefile("${path.module}/templates/cloud-init-k3s-server.yaml.tftpl", {
      # Tenta usar a chave específica do SERVER. Se for null, usa a genérica.
      tailscale_auth_key = coalesce(var.tailscale_auth_key_server, var.tailscale_auth_key)

      hostname              = local.hostnames.server
      k3s_token             = random_password.k3s_token.result
      github_deploy_key_b64 = base64encode(var.github_deploy_key)
      github_repo_url       = var.github_repo_url
      git_branch            = var.git_branch
      central_log_ip        = data.oci_core_vnic.nat_vnic[0].private_ip_address
    }))
  }

  depends_on = [oci_core_instance.nat, oci_core_subnet.private]

  lifecycle {
    ignore_changes = [
      metadata["user_data"],
      source_details[0].source_id
    ]
  }

  freeform_tags = local.common_tags
}

data "oci_core_vnic_attachments" "server_vnic_attachments" {
  count          = local.selected.arm_server_count
  compartment_id = oci_identity_compartment.main.id
  instance_id    = oci_core_instance.k3s_server[count.index].id
}

data "oci_core_vnic" "server_vnic" {
  count   = local.selected.arm_server_count
  vnic_id = data.oci_core_vnic_attachments.server_vnic_attachments[count.index].vnic_attachments[0].vnic_id
}

# ============================================================================
# K3S WORKERS - ARM Ampere
# ============================================================================
resource "oci_core_instance" "k3s_worker_arm" {
  count = local.selected.arm_worker_count

  display_name        = local.hostnames.worker_arm[count.index]
  compartment_id      = oci_identity_compartment.main.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  shape = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = local.selected.arm_worker_ocpus
    memory_in_gbs = local.selected.arm_worker_ram
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private.id
    nsg_ids                   = [oci_core_network_security_group.vm_nsg.id]
    assign_public_ip          = false
    assign_private_dns_record = true
    hostname_label            = "k3s-worker-arm-${count.index + 1}"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = local.selected.arm_worker_disk
  }

  metadata = {
    ssh_authorized_keys = var.admin_vm_ssh_public_key

    user_data = base64encode(templatefile("${path.module}/templates/cloud-init-k3s-agent.yaml.tftpl", {
      # Tenta usar a chave específica do AGENT. Se for null, usa a genérica.
      tailscale_auth_key = coalesce(var.tailscale_auth_key_agent, var.tailscale_auth_key)

      hostname              = local.hostnames.worker_arm[count.index]
      k3s_token             = random_password.k3s_token.result
      k3s_server_ip         = data.oci_core_vnic.server_vnic[0].private_ip_address
      github_deploy_key_b64 = base64encode(var.github_deploy_key)
      github_repo_url       = var.github_repo_url
      git_branch            = var.git_branch
      central_log_ip        = data.oci_core_vnic.nat_vnic[0].private_ip_address
    }))
  }

  depends_on = [oci_core_instance.k3s_server]

  lifecycle {
    ignore_changes = [
      metadata["user_data"],
      source_details[0].source_id
    ]
  }

  freeform_tags = local.common_tags
}

# ============================================================================
# K3S WORKER - AMD (Always Free Micro)
# ============================================================================
resource "oci_core_instance" "k3s_worker_amd" {
  count = local.selected.amd_worker_count

  display_name        = local.hostnames.worker_amd[count.index]
  compartment_id      = oci_identity_compartment.main.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  shape = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private.id
    nsg_ids                   = [oci_core_network_security_group.vm_nsg.id]
    assign_public_ip          = false
    assign_private_dns_record = true
    hostname_label            = "k3s-worker-amd-${count.index + 1}"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_amd.images[0].id
    boot_volume_size_in_gbs = local.selected.amd_worker_disk_size
  }

  metadata = {
    ssh_authorized_keys = var.admin_vm_ssh_public_key

    user_data = base64encode(templatefile("${path.module}/templates/cloud-init-k3s-agent.yaml.tftpl", {
      # Tenta usar a chave específica do AGENT. Se for null, usa a genérica.
      tailscale_auth_key = coalesce(var.tailscale_auth_key_agent, var.tailscale_auth_key)

      hostname              = local.hostnames.worker_amd[count.index]
      k3s_token             = random_password.k3s_token.result
      k3s_server_ip         = data.oci_core_vnic.server_vnic[0].private_ip_address
      github_deploy_key_b64 = base64encode(var.github_deploy_key)
      github_repo_url       = var.github_repo_url
      git_branch            = var.git_branch
      central_log_ip        = data.oci_core_vnic.nat_vnic[0].private_ip_address
    }))
  }

  depends_on = [oci_core_instance.k3s_server]

  lifecycle {
    ignore_changes = [
      metadata["user_data"],
      source_details[0].source_id
    ]
  }

  freeform_tags = local.common_tags
}
