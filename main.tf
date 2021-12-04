# Configure the Microsoft Azure Provider.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "vmaster" {
  name     = "vmaster-resources"
  location = "westus"
}

# Create virtual network
resource "azurerm_virtual_network" "vmaster" {
  name                = "vmasteracctvn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vmaster.location
  resource_group_name = azurerm_resource_group.vmaster.name
}

# Create subnet
resource "azurerm_subnet" "vmaster" {
  name                 = "vmasteracctsub"
  resource_group_name  = azurerm_resource_group.vmaster.name
  virtual_network_name = azurerm_virtual_network.vmaster.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IP Address
resource "azurerm_public_ip" "vmaster" {
  name                = "publicip"
  location            = azurerm_resource_group.vmaster.location
  resource_group_name = azurerm_resource_group.vmaster.name
  allocation_method   = "Static"
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "vmaster" {
  name                = "nsg"
  location            = azurerm_resource_group.vmaster.location
  resource_group_name = azurerm_resource_group.vmaster.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create virtual network interface
resource "azurerm_network_interface" "vmaster" {
  name                = "vmasteracctni"
  location            = azurerm_resource_group.vmaster.location
  resource_group_name = azurerm_resource_group.vmaster.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.vmaster.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.vmaster.id
  }
}

# Create a Linux virtual machine

resource "azurerm_virtual_machine" "vmaster" {
  name                  = "vmasteracctvm"
  location              = azurerm_resource_group.vmaster.location
  resource_group_name   = azurerm_resource_group.vmaster.name
  network_interface_ids = [azurerm_network_interface.vmaster.id]
  vm_size               = "Standard_B1s"

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }

  storage_os_disk {
    name          = "myosdisk1"
    caching       = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "master-vmaster"
    admin_username = "azurebitra"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "vmaster" {
  name                 = "master-vmaster"
  virtual_machine_id   = azurerm_virtual_machine.vmaster.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "wget -O AzureHello.sh https://git.io/AzureHello && sh AzureHello.sh"
    }
SETTINGS


  tags = {
    environment = "Production"
  }
}

output "ip" {
  value = azurerm_public_ip.vmaster.ip_address
}
