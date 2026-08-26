#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int]$TeamId
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "No se encontro el comando '$Name' en PATH."
    }
}

function Invoke-Terraform {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & terraform @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform fallo al ejecutar: terraform $($Arguments -join ' ')"
    }
}

function Get-AzureResourceId {
    param(
        [Parameter(Mandatory = $true)][string]$ResourceGroupName,
        [Parameter(Mandatory = $true)][string]$ResourceType,
        [Parameter(Mandatory = $true)][string]$ResourceName
    )

    $query = "[?name=='$ResourceName'].id | [0]"
    $resourceId = & az resource list `
        --resource-group $ResourceGroupName `
        --resource-type $ResourceType `
        --query $query `
        --output tsv `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo consultar '$ResourceName' en Azure."
    }

    return $resourceId
}

Assert-Command -Name "az"
Assert-Command -Name "terraform"

& az account show --output none --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "No hay una sesion activa de Azure CLI. Ejecute 'az login' y vuelva a intentarlo."
}

$teamName = $TeamId.ToString("000")
$resourceGroupName = "rg-team-$TeamId-v2"
$terraformVariable = "team_id=$TeamId"
$workspaceName = "team-$TeamId"
$planFile = Join-Path $PSScriptRoot ".terraform/team-$TeamId.tfplan"

$resources = @(
    @{
        Address = "azurerm_application_insights.team_app_insights"
        Name = "appi-team-$teamName"
        Type = "Microsoft.Insights/components"
    },
    @{
        Address = "azurerm_linux_web_app.frontend-app"
        Name = "copab-hackaton-2026-team-$TeamId-frontend"
        Type = "Microsoft.Web/sites"
    },
    @{
        Address = "azurerm_linux_web_app.backend-app"
        Name = "copab-hackaton-2026-team-$TeamId-api"
        Type = "Microsoft.Web/sites"
    }
)

Push-Location $PSScriptRoot
try {
    Write-Host "Inicializando Terraform..."
    Invoke-Terraform -Arguments @("init", "-input=false")

    Write-Host "Seleccionando el estado del equipo $TeamId..."
    Invoke-Terraform -Arguments @("workspace", "select", "-or-create", $workspaceName)

    $stateOutput = @(& terraform state list 2>&1)
    $stateExitCode = $LASTEXITCODE
    $stateMessage = ($stateOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

    if ($stateExitCode -eq 0) {
        $stateResources = $stateOutput
    }
    elseif ($stateMessage -match "No state file was found") {
        Write-Host "El workspace aun no tiene estado; se comprobaran recursos existentes en Azure."
        $stateResources = @()
    }
    else {
        throw "No se pudo leer el estado de Terraform: $stateMessage"
    }

    foreach ($resource in $resources) {
        if ($stateResources -contains $resource.Address) {
            Write-Host "El recurso $($resource.Address) ya esta en el estado."
            continue
        }

        $resourceId = Get-AzureResourceId `
            -ResourceGroupName $resourceGroupName `
            -ResourceType $resource.Type `
            -ResourceName $resource.Name

        if ([string]::IsNullOrWhiteSpace($resourceId)) {
            Write-Host "El recurso $($resource.Name) no existe; Terraform lo creara."
            continue
        }

        Write-Host "Importando $($resource.Name) al estado de Terraform..."
        Invoke-Terraform -Arguments @(
            "import",
            "-input=false",
            "-var=$terraformVariable",
            $resource.Address,
            $resourceId.Trim()
        )
    }

    Write-Host "Generando el plan de Terraform..."
    Invoke-Terraform -Arguments @(
        "plan",
        "-input=false",
        "-var=$terraformVariable",
        "-out=$planFile"
    )

    Write-Host "Aplicando el plan de Terraform..."
    Invoke-Terraform -Arguments @("apply", "-input=false", "-auto-approve", $planFile)

    Write-Host "Infraestructura del equipo $TeamId desplegada correctamente."
}
finally {
    if (Test-Path $planFile) {
        Remove-Item $planFile -Force
    }
    Pop-Location
}
