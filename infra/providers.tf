terraform {
  required_version = ">= 1.5.0"

  required_providers {
    fabric = {
      source  = "microsoft/fabric"
      version = "~> 1.11"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.77"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 2.10"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

provider "azurerm" {
  subscription_id = var.SUBSCRIPTIONID
  features {}
}

provider "azuread" {}

provider "azapi" {}

provider "fabric" {
  use_cli = true
}
