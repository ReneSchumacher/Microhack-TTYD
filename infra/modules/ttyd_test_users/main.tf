data "azuread_domains" "current" {
  only_initial = true
}

data "azuread_client_config" "current" {}

locals {
  tenant_domain = one(data.azuread_domains.current.domains).domain_name
  users = {
    for index in range(var.user_count) : format("%03d", index + 1) => {
      user_principal_name = format("ttyd%s_%s@%s", format("%03d", index + 1), var.environment_name, local.tenant_domain)
      display_name        = format("TTYD User %s %s", format("%03d", index + 1), var.environment_name)
      mail_nickname       = format("ttyd%s_%s", format("%03d", index + 1), var.environment_name)
    }
  }
}

resource "random_password" "user" {
  for_each = local.users

  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azuread_user" "this" {
  for_each = local.users

  user_principal_name   = each.value.user_principal_name
  display_name          = each.value.display_name
  mail_nickname         = each.value.mail_nickname
  password              = random_password.user[each.key].result
  force_password_change = false
  usage_location        = "DE"
}

resource "azuread_group" "this" {
  display_name            = format("TTYDUsers_%s", var.environment_name)
  security_enabled        = true
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]

  members = [
    for user in azuread_user.this : user.object_id
  ]
}
