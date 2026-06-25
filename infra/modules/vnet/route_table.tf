# ─────────────────────────────────────────────
# Route Table: rt-sqlhackmi  (ManagedInstance subnet)
# SQL MI requires a UDR with 0.0.0.0/0 → Internet so management
# traffic can reach the SQL MI control plane.
# Ref: https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/connectivity-architecture-overview#mandatory-inbound-security-rules-with-service-aided-subnet-configuration
# ─────────────────────────────────────────────
resource "azurerm_route_table" "sql_mi" {
  name                          = "rt-sqlhackmi"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true

  lifecycle {
    ignore_changes = [
      route
    ]
  }

  tags = merge(var.tags, {
    environment = var.env_name
  })
}

resource "azurerm_subnet_route_table_association" "managed_instance" {
  subnet_id      = azurerm_subnet.managed_instance.id
  route_table_id = azurerm_route_table.sql_mi.id
}
