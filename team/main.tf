data "azurerm_service_plan" "plan_frontend" { 
	name                = "plan-front-${local.plan_index}-v2" 
	resource_group_name = "rg-hackathon-shared-v2" 
}

data "azurerm_service_plan" "plan_backend" { 
	name                = "plan-back-${local.plan_index}-v2" 
	resource_group_name = "rg-hackathon-shared-v2" 
}

data "azurerm_resource_group" "team" { 
  name     = "rg-team-${var.team_id}-v2" 
}

resource "azurerm_application_insights" "team_app_insights" {
  name                = "copa-hackaton-2026-team-${local.team_name}-appi"
  location            = data.azurerm_resource_group.team.location
  resource_group_name = data.azurerm_resource_group.team.name
  application_type    = "web"
}

resource "azurerm_linux_web_app" "frontend-app" { 
  name                = "copab-hackaton-2026-team-${var.team_id}-frontend"
  resource_group_name = data.azurerm_resource_group.team.name 
  location            = data.azurerm_resource_group.team.location 
  service_plan_id     = data.azurerm_service_plan.plan_frontend.id
  site_config {}

   app_settings = { 
    "SCO_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.team_app_insights.connection_string
  } 
} 
 
resource "azurerm_linux_web_app" "backend-app" { 
  name                = "copab-hackaton-2026-team-${var.team_id}-api"
  resource_group_name = data.azurerm_resource_group.team.name 
  location            = data.azurerm_resource_group.team.location 
  service_plan_id     = data.azurerm_service_plan.plan_backend.id
 
  site_config { 
    application_stack { 
      dotnet_version = "10.0" 
    }
  } 
 
  app_settings = { 
    "PRODUCT_SERVICE_URL" = "https://catalogapi.internal.azurewebsites.net" 
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.team_app_insights.connection_string
    "ASPNETCORE_ENVIRONMENT"                = "Production"
    "SCO_DO_BUILD_DURING_DEPLOYMENT"        = "true"
  } 
} 
