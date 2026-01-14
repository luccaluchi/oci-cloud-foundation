# ----------------------------------------------------------------------------
# Load Balancer Principal (Flexible Shape - Always Free)
# ----------------------------------------------------------------------------
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id             = oci_identity_compartment.main.id
  display_name               = "${local.name_prefix}-lb"
  shape                      = "flexible"
  subnet_ids                 = [oci_core_subnet.public.id]
  network_security_group_ids = [oci_core_network_security_group.lb_nsg.id]
  is_private                 = false
  freeform_tags              = local.common_tags

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

# ----------------------------------------------------------------------------
# Backend Set - HTTP (TCP Passthrough)
# Redireciona porta 80 do LB para NodePort 30080 nas VMs
# ----------------------------------------------------------------------------
resource "oci_load_balancer_backend_set" "http" {
  name             = "${local.name_prefix}-bes-http"
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = local.ingress_http_nodeport
    retries           = 3
    timeout_in_millis = 5000
    interval_ms       = 10000
  }
}

# ----------------------------------------------------------------------------
# Backend Set - HTTPS (TCP Passthrough)
# Redireciona porta 443 do LB para NodePort 30443 nas VMs
# TLS é terminado pelo Ingress Controller, nao pelo LB
# ----------------------------------------------------------------------------
resource "oci_load_balancer_backend_set" "https" {
  name             = "${local.name_prefix}-bes-https"
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = local.ingress_https_nodeport
    retries           = 3
    timeout_in_millis = 5000
    interval_ms       = 10000
  }
}

# ----------------------------------------------------------------------------
# Listener HTTP (80 → 30080) - TCP Passthrough
# ----------------------------------------------------------------------------
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.http.name
  port                     = 80
  protocol                 = "TCP" # L4 TCP passthrough
}

# ----------------------------------------------------------------------------
# Listener HTTPS (443 → 30443) - TCP Passthrough
# IMPORTANTE: Nao há ssl_configuration - TLS é terminado no cluster
# ----------------------------------------------------------------------------
resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "https"
  default_backend_set_name = oci_load_balancer_backend_set.https.name
  port                     = 443
  protocol                 = "TCP" # L4 TCP passthrough - sem TLS termination
}

# ============================================================================
# BACKENDS - K3s Server
# ============================================================================
resource "oci_load_balancer_backend" "server_http" {
  count            = local.selected.arm_server_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = oci_core_instance.k3s_server[count.index].private_ip
  port             = local.ingress_http_nodeport
  weight           = 1
}

resource "oci_load_balancer_backend" "server_https" {
  count            = local.selected.arm_server_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.https.name
  ip_address       = oci_core_instance.k3s_server[count.index].private_ip
  port             = local.ingress_https_nodeport
  weight           = 1
}

# ============================================================================
# BACKENDS - Workers ARM
# ============================================================================
resource "oci_load_balancer_backend" "worker_arm_http" {
  count            = local.selected.arm_worker_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = oci_core_instance.k3s_worker_arm[count.index].private_ip
  port             = local.ingress_http_nodeport
  weight           = 1
}

resource "oci_load_balancer_backend" "worker_arm_https" {
  count            = local.selected.arm_worker_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.https.name
  ip_address       = oci_core_instance.k3s_worker_arm[count.index].private_ip
  port             = local.ingress_https_nodeport
  weight           = 1
}

# ============================================================================
# BACKENDS - Workers AMD
# ============================================================================
resource "oci_load_balancer_backend" "worker_amd_http" {
  count            = local.selected.amd_worker_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = oci_core_instance.k3s_worker_amd[count.index].private_ip
  port             = local.ingress_http_nodeport
  weight           = 1
}

resource "oci_load_balancer_backend" "worker_amd_https" {
  count            = local.selected.amd_worker_count
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.https.name
  ip_address       = oci_core_instance.k3s_worker_amd[count.index].private_ip
  port             = local.ingress_https_nodeport
  weight           = 1
}
