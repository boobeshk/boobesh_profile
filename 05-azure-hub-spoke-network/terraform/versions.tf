terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Subscription comes from ARM_SUBSCRIPTION_ID (or `az login` defaults).
provider "azurerm" {
  features {}
}
