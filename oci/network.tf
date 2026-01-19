# ----------------------------------------------------------------------------
# VCN Principal
# ----------------------------------------------------------------------------
resource "oci_core_vcn" "main" {
  compartment_id = oci_identity_compartment.main.id
  cidr_block     = var.vcn_cidr
  display_name   = "${local.name_prefix}-vcn"
  dns_label      = "k3s${terraform.workspace}"
  freeform_tags  = local.common_tags
}

# ----------------------------------------------------------------------------
# Internet Gateway (apenas para subnet pública)
# ----------------------------------------------------------------------------
resource "oci_core_internet_gateway" "main" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-igw"
  enabled        = true
  freeform_tags  = local.common_tags
}

# ----------------------------------------------------------------------------
# Route Tables
# ----------------------------------------------------------------------------
# Recuperar o objeto Private IP da VM NAT (para pegar o ID)
data "oci_core_private_ips" "nat_private_ip" {
  count   = local.selected.amd_nat_enabled ? 1 : 0
  vnic_id = data.oci_core_vnic.nat_vnic[0].id
}

# Route Table Pública (LB + NAT VM → Internet Gateway)
resource "oci_core_route_table" "public" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-rt-public"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
    description       = "Default route to Internet via IGW"
  }
}

# Route Table Privada (VMs K3s → VM NAT como gateway)
# Usa o Private IP da VM NAT como next hop
resource "oci_core_route_table" "private" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-rt-private"
  freeform_tags  = local.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = data.oci_core_private_ips.nat_private_ip[0].private_ips[0].id
    description       = "Default route to Internet via NAT VM"
  }
}

# ----------------------------------------------------------------------------
# Subnets
# ----------------------------------------------------------------------------

# Subnet Pública (Load Balancer + VM NAT)
resource "oci_core_subnet" "public" {
  compartment_id             = oci_identity_compartment.main.id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${local.name_prefix}-subnet-public"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.common_tags
}

# Subnet Privada (VMs K3s - sem IP público)
resource "oci_core_subnet" "private" {
  compartment_id             = oci_identity_compartment.main.id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = "${local.name_prefix}-subnet-private"
  dns_label                  = "private"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true # VMs NAO podem ter IP público
  freeform_tags              = local.common_tags
}

# ----------------------------------------------------------------------------
# Default Security List (locked down)
# ----------------------------------------------------------------------------
resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  display_name               = "Default Security List - Locked Down"

  # Sem regras - tudo bloqueado por padrao
  # Regras sao gerenciadas via Security Lists específicas e NSGs
}
