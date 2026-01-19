# ----------------------------------------------------------------------------
# Security List - Subnet Pública (Load Balancer + VM NAT)
# ----------------------------------------------------------------------------
resource "oci_core_security_list" "public" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-sl-public"
  freeform_tags  = local.common_tags

  # Egress: Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "Allow all outbound traffic"
  }

  # Ingress: HTTP/HTTPS para Load Balancer
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "HTTP from Internet"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    description = "HTTPS from Internet"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress: Tailscale UDP para VM NAT (porta primária)
  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "0.0.0.0/0"
    description = "Tailscale direct connection (UDP 41641)"
    udp_options {
      min = 41641
      max = 41641
    }
  }

  # Ingress: Tailscale STUN (UDP 3478) para NAT traversal
  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "0.0.0.0/0"
    description = "Tailscale STUN for NAT traversal"
    udp_options {
      min = 3478
      max = 3478
    }
  }

  # Ingress: ICMP Type 3 (Destination Unreachable) para PMTUD
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP Destination Unreachable (PMTUD)"
    icmp_options {
      type = 3
    }
  }

  # Ingress: ICMP Type 11 (Time Exceeded) para Traceroute
  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = "0.0.0.0/0"
    description = "ICMP Time Exceeded (Traceroute)"
    icmp_options {
      type = 11
    }
  }

  # Ingress: Tráfego da subnet privada (respostas do NAT)
  ingress_security_rules {
    protocol    = "all"
    source      = var.private_subnet_cidr
    description = "Traffic from private subnet (NAT responses)"
  }
}

# ----------------------------------------------------------------------------
# Security List - Subnet Privada (VMs K3s)
# Sem IP público, egress via VM NAT
# ----------------------------------------------------------------------------
resource "oci_core_security_list" "private" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-sl-private"
  freeform_tags  = local.common_tags

  # Egress: Permite todo tráfego (roteado via VM NAT)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "All outbound via NAT VM"
  }

  # Ingress: Comunicaçao interna VCN (K3s cluster + LB + NAT)
  ingress_security_rules {
    protocol    = "all"
    source      = var.vcn_cidr
    description = "VCN internal communication"
  }

  # Ingress: Tailscale UDP (Allow execution of direct connections)
  ingress_security_rules {
    protocol    = "17" # UDP
    source      = "0.0.0.0/0"
    description = "Tailscale direct connection (UDP 41641)"
    udp_options {
      min = 41641
      max = 41641
    }
  }
}

# ============================================================================
# NETWORK SECURITY GROUPS (Regras específicas por tipo de recurso)
# ============================================================================

# ----------------------------------------------------------------------------
# NSG - Load Balancer
# Aceita tráfego HTTP/HTTPS e encaminha para VMs (L4 passthrough)
# ----------------------------------------------------------------------------
resource "oci_core_network_security_group" "lb_nsg" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-nsg-lb"
  freeform_tags  = local.common_tags
}

# LB Ingress HTTP (80)
resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTP from Internet"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# LB Ingress HTTPS (443)
resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTPS from Internet"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# LB Egress para VMs (NodePorts)
resource "oci_core_network_security_group_security_rule" "lb_egress_to_vms" {
  network_security_group_id = oci_core_network_security_group.lb_nsg.id
  direction                 = "EGRESS"
  protocol                  = "6" # TCP
  destination               = var.private_subnet_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "Traffic to K3s VMs NodePorts"
  tcp_options {
    destination_port_range {
      min = local.ingress_http_nodeport
      max = local.ingress_https_nodeport
    }
  }
}

# ----------------------------------------------------------------------------
# NSG - VM NAT
# IP público, Tailscale, faz NAT para VMs privadas
# ----------------------------------------------------------------------------
resource "oci_core_network_security_group" "nat_nsg" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-nsg-nat"
  freeform_tags  = local.common_tags
}

# NAT Egress: Permite todo outbound (internet para VMs privadas)
resource "oci_core_network_security_group_security_rule" "nat_egress_all" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "All outbound for NAT"
}

#NAT Ingress: SSH do IP do administrador
resource "oci_core_network_security_group_security_rule" "nat_ingress_ssh" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "186.247.227.11/32"
  source_type               = "CIDR_BLOCK"
  description               = "SSH from admin IP"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# NAT Ingress: Tailscale UDP (conexao direta P2P)
resource "oci_core_network_security_group_security_rule" "nat_ingress_tailscale_udp" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Tailscale direct connection (UDP)"
  udp_options {
    destination_port_range {
      min = 41641
      max = 41641
    }
  }
}

# NAT Ingress: Tailscale STUN (UDP 3478) para NAT traversal
resource "oci_core_network_security_group_security_rule" "nat_ingress_stun" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "INGRESS"
  protocol                  = "17" # UDP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "Tailscale STUN for NAT traversal"
  udp_options {
    destination_port_range {
      min = 3478
      max = 3478
    }
  }
}

# NAT Ingress: Tráfego da subnet privada (para fazer NAT)
resource "oci_core_network_security_group_security_rule" "nat_ingress_private" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Traffic from private subnet for NAT"
}

# NAT Ingress: VCN interno (para SSH hop)
resource "oci_core_network_security_group_security_rule" "nat_ingress_vcn" {
  network_security_group_id = oci_core_network_security_group.nat_nsg.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "VCN internal traffic"
}

# ----------------------------------------------------------------------------
# NSG - VMs K3s (Server e Workers)
# Sem IP público, comunicaçao via VCN
# ----------------------------------------------------------------------------
resource "oci_core_network_security_group" "vm_nsg" {
  compartment_id = oci_identity_compartment.main.id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-nsg-vms"
  freeform_tags  = local.common_tags
}

# VMs Egress: Permite todo outbound (roteado via VM NAT)
resource "oci_core_network_security_group_security_rule" "vm_egress_all" {
  network_security_group_id = oci_core_network_security_group.vm_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "All outbound via NAT VM"
}

# VMs Ingress: Comunicaçao interna VCN (K3s cluster + LB + NAT)
resource "oci_core_network_security_group_security_rule" "vm_ingress_vcn" {
  network_security_group_id = oci_core_network_security_group.vm_nsg.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
  description               = "All traffic from VCN (K3s cluster + LB + NAT)"
}
