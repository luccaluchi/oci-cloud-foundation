#module for compartiment e security dinamic groups for homelab

resource "oci_identity_compartment" "main" {
  compartment_id = var.tenancy_ocid
  name           = "${local.name_prefix}-compartment"
  description    = "Compartimento automatizado para o ambiente ${terraform.workspace}"
  enable_delete  = true
  freeform_tags  = local.common_tags
}
