# Demo finding only. The Terraform AKS workflow applies infra/** and does not apply this file.

resource "azurerm_network_security_rule" "demo_open_ssh" {
  name                        = "demo-open-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = "demo-not-applied"
  network_security_group_name = "demo-not-applied"
}

resource "azurerm_linux_virtual_machine" "demo" {
  name                  = "demo-not-applied"
  resource_group_name   = "demo-not-applied"
  location              = "eastus"
  size                  = "Standard_B1s"
  admin_username        = "demo"
  admin_password        = "DemoPassword123!"
  network_interface_ids = []

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
