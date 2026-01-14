resource "oci_budget_budget" "budget_seguranca" {
  # Aplica ao compartimento raiz (Tenancy) para pegar todo o consumo da conta
  compartment_id = var.tenancy_ocid

  display_name = "Safety-Budget-${var.budget_amount}"
  description  = "Monitora gastos para garantir que nao passe de ${var.budget_amount} reais mensais"

  amount       = var.budget_amount # Utiliza valor definido na variável
  reset_period = "MONTHLY"

  target_type = "COMPARTMENT"
  targets     = [var.tenancy_ocid]

  freeform_tags = local.common_tags
}

# Alerta 1: Previsao de estouro (80%)
resource "oci_budget_alert_rule" "forecast_alert" {
  budget_id      = oci_budget_budget.budget_seguranca.id
  type           = "FORECAST"
  threshold      = 80
  threshold_type = "PERCENTAGE"

  display_name = "Forecast-Alert-80pct"
  description  = "Avisa se a previsao de gastos atingir 80% do orçamento"

  recipients = var.budget_alert_email
  message    = "ATENCAO: A previsao de gastos da sua conta Oracle Cloud atingiu 80% do limite de segurança (R$ ${var.budget_amount}). Verifique seus recursos."

  freeform_tags = local.common_tags
}

# Alerta 2: Gasto Real (100%)
resource "oci_budget_alert_rule" "actual_alert" {
  budget_id      = oci_budget_budget.budget_seguranca.id
  type           = "ACTUAL"
  threshold      = 100
  threshold_type = "PERCENTAGE"

  display_name = "Actual-Alert-100pct"
  description  = "Avisa quando o gasto real atingir 100% do orçamento"

  recipients = var.budget_alert_email
  message    = "URGENTE: Sua conta Oracle Cloud atingiu o limite de segurança de R$ ${var.budget_amount}. Verifique imediatamente!"

  freeform_tags = local.common_tags
}