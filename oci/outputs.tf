# ----------------------------------------------------------------------------
# Compartimento
# ----------------------------------------------------------------------------
output "compartment_id" {
  description = "OCID do compartimento do cluster"
  value       = oci_identity_compartment.main.id
}

# ----------------------------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------------------------
output "load_balancer_public_ip" {
  description = "IP público do Load Balancer (único ponto de entrada web)"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

# ----------------------------------------------------------------------------
# VM NAT (Gateway e Bastion)
# ----------------------------------------------------------------------------
output "nat_public_ip" {
  description = "IP público da VM NAT (use para acesso SSH via Tailscale)"
  value       = length(oci_core_instance.nat) > 0 ? oci_core_instance.nat[0].public_ip : null
}

output "nat_private_ip" {
  description = "IP privado da VM NAT (gateway para VMs K3s)"
  value       = length(data.oci_core_vnic.nat_vnic) > 0 ? data.oci_core_vnic.nat_vnic[0].private_ip_address : null
}

output "nat_interface_name" {
  description = "Nome da interface de rede da VM NAT (para verificaçao manual)"
  value       = "ens3" # Padrao Ubuntu na OCI
}

# ----------------------------------------------------------------------------
# VMs K3s - IPs Privados (sem IP público)
# ----------------------------------------------------------------------------
output "k3s_server_private_ip" {
  description = "IP privado do servidor K3s"
  value       = length(oci_core_instance.k3s_server) > 0 ? oci_core_instance.k3s_server[0].private_ip : null
}

output "k3s_workers_arm_private_ips" {
  description = "IPs privados dos workers ARM"
  value       = oci_core_instance.k3s_worker_arm[*].private_ip
}

output "k3s_workers_amd_private_ips" {
  description = "IPs privados dos workers AMD"
  value       = oci_core_instance.k3s_worker_amd[*].private_ip
}

# ----------------------------------------------------------------------------
# Hostnames
# ----------------------------------------------------------------------------
output "hostnames" {
  description = "Hostnames das VMs do cluster"
  value = {
    nat         = local.hostnames.nat
    server      = local.hostnames.server
    workers_amd = local.hostnames.worker_amd
    workers_arm = local.hostnames.worker_arm
  }
}
