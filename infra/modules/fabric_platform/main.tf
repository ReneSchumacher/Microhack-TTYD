terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    fabric = {
      source = "microsoft/fabric"
    }

    time = {
      source = "hashicorp/time"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azuread_directory_role" "fabric_admin" {
  display_name = "Fabric Administrator"
}

locals {
  fabriccapacityid = "af870ea4-4979-4a38-9d3a-2bd8f68a0874"
}

locals {
  normalized_env = lower(replace(var.env_name, "-", ""))
  capacity_name  = substr("fab${local.normalized_env}", 0, 63)
  gateway_name   = "fabric-gateway-${var.env_name}"
  workspace_names = {
    for index in range(var.user_count) : format("%03d", index + 1) => format("Workspace%03d_%s", index + 1, var.env_name)
  }
}

resource "azurerm_fabric_capacity" "capacity" {
  name                   = local.capacity_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  administration_members = var.capacity_admin_members

  sku {
    name = "F2"
    tier = "Fabric"
  }

  tags = var.tags
}

resource "time_sleep" "capacity_stabilization" {
  create_duration = "120s"
  depends_on      = [azurerm_fabric_capacity.capacity]
}

# resource "azuread_directory_role_assignment" "fabric_admin_current_user" {
#   role_id             = azuread_directory_role.fabric_admin.template_id
#   principal_object_id = data.azurerm_client_config.current.object_id

#   lifecycle {
#     ignore_changes = all
#   }
#   depends_on = [
#     azurerm_fabric_capacity.capacity
#   ]

# }

data "fabric_capacity" "capacity" {
  display_name = local.capacity_name
  lifecycle {
    postcondition {
      condition     = self.state == "Active"
      error_message = "Fabric Capacity is not in Active state. Please check the Fabric Capacity status."
    }
  }
  depends_on = [
    time_sleep.capacity_stabilization
  ]
}

resource "fabric_gateway" "this" {
  type                            = "VirtualNetwork"
  display_name                    = local.gateway_name
  inactivity_minutes_before_sleep = 30
  number_of_member_gateways       = 1
  capacity_id                     = data.fabric_capacity.capacity.id

  virtual_network_azure_resource = {
    resource_group_name  = var.resource_group_name
    virtual_network_name = var.virtual_network_name
    subnet_name          = var.fabric_subnet_name
    subscription_id      = var.subscription_id
  }

  depends_on = [
    time_sleep.capacity_stabilization
  ]
}

resource "fabric_gateway_role_assignment" "ttydusers" {
  gateway_id = fabric_gateway.this.id
  principal = {
    id   = var.ttyd_group_object_id
    type = "Group"
  }
  role = "ConnectionCreator"
}

resource "fabric_workspace" "user" {
  for_each = local.workspace_names

  display_name = each.value
  description  = "Per-user Fabric workspace for ${var.env_name}."
  capacity_id  = data.fabric_capacity.capacity.id

  depends_on = [
    time_sleep.capacity_stabilization
  ]
}

resource "fabric_workspace_role_assignment" "user_member" {
  for_each = var.user_object_id_map

  workspace_id = fabric_workspace.user[each.key].id
  principal = {
    id   = each.value
    type = "User"
  }
  role = "Member"
}

# resource "fabric_workspace_outbound_gateway_rules" "user" {
#   for_each = fabric_workspace.user

#   workspace_id   = each.value.id
#   default_action = "Deny"
#   allowed_gateways = [
#     {
#       id = fabric_gateway.this.id
#     }
#   ]
# }
