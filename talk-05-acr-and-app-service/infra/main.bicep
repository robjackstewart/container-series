@description('Globally unique Azure Container Registry name.')
param acrName string

@description('Name of the Linux App Service plan.')
param appServicePlanName string

@description('Globally unique Web App name.')
param webAppName string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Repository name inside Azure Container Registry.')
param imageName string

@description('Container image tag to deploy.')
param imageTag string = 'latest'

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${webAppName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${webAppName}-appi'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/${imageName}:${imageTag}'
      alwaysOn: true
      ftpsState: 'Disabled'
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
        {
          name: 'ENVIRONMENT'
          value: 'production'
        }
        {
          name: 'APP_VERSION'
          value: imageTag
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, webApp.id, 'acr-pull')
  scope: acr
  properties: {
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

output acrLoginServer string = acr.properties.loginServer
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
