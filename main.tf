variable "cluster_name" {
  type = string
  default = "aks-many-pods-bug"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.cluster_name}-rg"
  location = "eastus2"
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name = "${var.cluster_name}"
  
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  dns_prefix = "${var.cluster_name}"

  default_node_pool {
    name       = "lin1"
    vm_size    = "Standard_B4ms"

    enable_auto_scaling = false
    node_count          = 1

    max_pods = 250
    os_sku   = "Ubuntu"

    #os_disk_type = "Ephemeral"  # Can't use for this VM type - it has too small temporary storage
  }

  network_profile {
    network_plugin = "azure"

    network_policy = "azure"
    #network_policy = "calico"  # Works just as well

    network_plugin_mode = "Overlay"
  }

  identity {
   type = "SystemAssigned"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "node_pool_win" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id

  name    = "win1"
  vm_size = "Standard_E8d_v5"

  enable_auto_scaling = false
  node_count          = 1

  max_pods = 250
  os_type  = "Windows"
  os_sku   = "Windows2022"

  os_disk_type = "Ephemeral"
  #kubelet_disk_type = "Temporary"  # This alone isn't sufficient
}
