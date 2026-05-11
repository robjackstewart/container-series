@description('Name for the Azure Container Registry')
param acrName string

@description('Name for the App Service Plan')
param appServicePlanName string

@description('Name for the Web App')
param webAppName string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Container image name (without registry prefix)')
param imageName string = 'rust-todo-api'

@description('Container image tag')
param imageTag string = 'latest'

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false  // Use managed identity instead!
    publicNetworkAccess: 'Enabled'
  }
}

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true  // Required for Linux
  }
}

// Web App for Containers
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  identity: {
    type: 'SystemAssigned'  // Managed identity for ACR pull
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/${imageName}:${imageTag}'
      acrUseManagedIdentityCreds: true  // Use managed identity to pull from ACR
      appSettings: [
        { name: 'DOCKER_REGISTRY_SERVER_URL', value: 'https://${acr.properties.loginServer}' }
        { name: 'WEBSITES_PORT', value: '8080' }
        { name: 'ENVIRONMENT', value: 'production' }
        { name: 'APP_VERSION', value: imageTag }
        { name: 'RUST_LOG', value: 'info' }
      ]
    }
    httpsOnly: true
  }
}

// Grant AcrPull role to Web App managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')  // AcrPull
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrLoginServer string = acr.properties.loginServer
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppPrincipalId string = webApp.identity.principalId