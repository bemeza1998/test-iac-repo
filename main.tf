resource "azurerm_resource_group" "shared" { 
	name     = "rg-hackathon-shared"
	location = "centralus"
}

resource "azurerm_service_plan" "frontend" { 
	count               = 1
	name                = "plan-front-${format("%02d", count.index + 1)}"
	resource_group_name = azurerm_resource_group.shared.name
	location            = azurerm_resource_group.shared.location
	os_type             = "Linux"
	sku_name            = "B1"
}

resource "azurerm_service_plan" "backend" {
  count 			  = 1
  name 				  = "plan-back-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.shared.name
  location 			  = azurerm_resource_group.shared.location
  os_type             = "Linux"
  sku_name			  = "B1"
}
