@description(''Name for the AKS cluster'')
param clusterName string = ''container-series-aks''

@description(''Name for the Azure Container Registry'')
param acrName string = ''containerseriesacr''

@description(''Azure region'')
param location string = resourceGroup().location

@description(''Number of agent nodes'')
param nodeCount int = 3

@description(''VM size for nodes'')
param vmSize string = ''Standard_D2s_v3''

@description(''Kubernetes version'')
param kubernetesVersion string = ''1.28''

// Log Analytics Workspace for monitoring
resource logAnalytics ''Microsoft.OperationalInsights/workspaces@2022-10-01'' = {
  name: ''${clusterName}-logs''
  location: location
  properties: {
    sku: { name: ''PerGB2018'' }
    retentionInDays: 30
  }
}

// Azure Container Registry
resource acr ''Microsoft.ContainerRegistry/registries@2023-07-01'' = {
  name: acrName
  location: location
  sku: { name: ''Standard'' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: ''Enabled''
  }
}

// AKS Cluster
resource aks ''Microsoft.ContainerService/managedClusters@2023-10-01'' = {
  name: clusterName
  location: location
  identity: {
    type: ''SystemAssigned''
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: ''system''
        count: nodeCount
        vmSize: vmSize
        osType: ''Linux''
        mode: ''System''
        enableAutoScaling: true
        minCount: 1
        maxCount: 5
      }
    ]
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
    }
    networkProfile: {
      networkPlugin: ''azure''
      loadBalancerSku: ''standard''
    }
  }
}

// Grant AcrPull to AKS kubelet identity
resource acrPull ''Microsoft.Authorization/roleAssignments@2022-04-01'' = {
  name: guid(acr.id, aks.id, ''AcrPull'')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(''Microsoft.Authorization/roleDefinitions'', ''7f951dda-4ed3-4680-a7ca-43fe172d538d'')
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: ''ServicePrincipal''
  }
}

output aksName string = aks.name
output acrLoginServer string = acr.properties.loginServer
output aksResourceId string = aks.id
